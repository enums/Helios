//
//  HeliosApp.swift
//  
//
//  Created by Yuu Zheng on 2022/12/29.
//

import Foundation
import Vapor
import Leaf
import Fluent
import FluentMySQLDriver
import Redis
import Queues
import QueuesRedisDriver

public final class HeliosApp {
    
    public let app: Application
    public let config: HeliosAppConfig
    public let delegate: HeliosAppDelegate

    public var database: Database {
        return app.db
    }

    public var redis: Application.Redis {
        return app.redis
    }

    public init(app: Application, config: HeliosAppConfig, delegate: HeliosAppDelegate) {
        self.config = config
        self.app = app
        self.delegate = delegate
    }

    // MARK: - Setup Orchestration

    private func setup() throws {
        try configureServer()
        try configureStorage()
        configureViews()
        configureMiddleware()
        registerRoutes()
        registerBackgroundJobs()
    }

    // MARK: - Phase 1: Server

    /// Configure HTTP server host and port.
    private func configureServer() throws {
        let typedConfig = config.typed
        app.http.server.configuration.hostname = typedConfig.server.host
        app.http.server.configuration.port = typedConfig.server.port
    }

    // MARK: - Phase 2: Storage (MySQL + Redis + Queues driver)

    /// Configure database, Redis, and queue driver connections.
    private func configureStorage() throws {
        let typedConfig = config.typed

        // MySQL
        var tlsConfig = TLSConfiguration.makeClientConfiguration()
        switch typedConfig.mysql.tls {
        case .disable:
            tlsConfig.certificateVerification = .none
        case .require:
            break // keep system default (full verification)
        }
        app.databases.use(
            .mysql(
                hostname: typedConfig.mysql.host,
                port: typedConfig.mysql.port,
                username: typedConfig.mysql.username,
                password: typedConfig.mysql.password,
                database: typedConfig.mysql.database,
                tlsConfiguration: tlsConfig
            ),
            as: .mysql
        )

        // Redis
        let redisConfiguration = try RedisConfiguration(
            hostname: typedConfig.redis.host,
            port: typedConfig.redis.port,
            pool: .init(connectionRetryTimeout: .seconds(1))
        )
        app.redis.configuration = redisConfiguration

        // Queues driver (only if enabled)
        if typedConfig.features.enableQueues {
            app.queues.use(.redis(redisConfiguration))
        }

        // Model / Migration
        HeliosModelRegistrar.register(delegate.models(app: self), on: app)
    }

    // MARK: - Phase 3: Views & Static Files

    /// Configure Leaf template engine and static file serving.
    private func configureViews() {
        let typedConfig = config.typed

        if typedConfig.features.serveLeaf {
            app.views.use(.leaf)
        }

        if typedConfig.features.serveStaticFiles {
            app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
        }
    }

    // MARK: - Phase 4: Middleware (Filters)

    /// Register application-level middleware / filters from the delegate.
    /// Descriptor-based API takes priority; falls back to legacy builders.
    private func configureMiddleware() {
        let descriptors = delegate.filterDescriptors(app: self)
        if !descriptors.isEmpty {
            HeliosRouteRegistrar.registerFilters(descriptors, on: app, heliosApp: self)
        } else {
            HeliosRouteRegistrar.registerFilters(delegate.filters(app: self), on: app, heliosApp: self)
        }
    }

    // MARK: - Phase 5: Routes

    /// Register HTTP route handlers from the delegate.
    /// Descriptor-based API takes priority; falls back to legacy builders.
    private func registerRoutes() {
        let descriptors = delegate.routeDescriptors(app: self)
        if !descriptors.isEmpty {
            HeliosRouteRegistrar.registerRoutes(descriptors, on: app, heliosApp: self)
        } else {
            HeliosRouteRegistrar.registerRoutes(delegate.routes(app: self), on: app, heliosApp: self)
        }
    }

    // MARK: - Phase 6: Background Jobs (Timers + Tasks)

    /// Register scheduled timers and async tasks. Only active when queues are enabled.
    /// Descriptor-based API takes priority; falls back to legacy builders.
    private func registerBackgroundJobs() {
        let typedConfig = config.typed
        guard typedConfig.features.enableQueues else { return }

        let timerContext = HeliosTimerContext(app: self, queues: app.queues)
        let taskContext = HeliosTaskContext(app: self, queues: app.queues)

        // Timers: descriptor-first
        if typedConfig.features.enableTimers {
            let timerDescriptors = delegate.timerDescriptors(app: self)
            if !timerDescriptors.isEmpty {
                timerDescriptors.forEach { descriptor in
                    let timer = descriptor.makeTimer(timerContext)
                    timer.schedule(queue: app.queues)
                }
            } else {
                delegate.timers(app: self).forEach { builder in
                    let timer = builder(timerContext)
                    timer.schedule(queue: app.queues)
                }
            }
        }

        // Tasks: descriptor-first
        let taskDescriptors = delegate.taskDescriptors(app: self)
        if !taskDescriptors.isEmpty {
            taskDescriptors.forEach { descriptor in
                guard let task = descriptor.makeTask(taskContext) as? any HeliosTask else {
                    app.logger.critical("Descriptor '\(descriptor.name)' produced unrecognized task")
                    return
                }
                task.register(queue: app.queues)
            }
        } else {
            delegate.tasks(app: self).forEach { builder in
                guard let task = builder(taskContext) as? any HeliosTask else {
                    app.logger.critical("Unrecognized task builder: \(String(describing: builder))")
                    return
                }
                task.register(queue: app.queues)
            }
        }
    }

    // MARK: - Run

    /// Start the application: run migrations (if enabled), start jobs, then serve.
    public func run() throws {
        let typedConfig = config.typed
        if typedConfig.features.autoMigrate {
            try app.autoMigrate().wait()
        }
        if typedConfig.features.enableQueues {
            try app.queues.startInProcessJobs()
            try app.queues.startScheduledJobs()
        }
        try app.run()
    }

    public func shutdown() {
        app.shutdown()
    }
}

// MARK: - Factory

extension HeliosApp {

    public static func create(workspace: String, delegate: HeliosAppDelegate) throws -> HeliosApp {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        let app = Application(env)
        app.directory = DirectoryConfiguration(workingDirectory: workspace)
        let config = try HeliosAppConfig(dir: app.directory)
        let helios = HeliosApp(app: app, config: config, delegate: delegate)
        try helios.setup()
        return helios
    }
}
