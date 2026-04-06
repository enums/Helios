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
        let c = config.typed
        app.http.server.configuration.hostname = c.server.host
        app.http.server.configuration.port = c.server.port
    }

    // MARK: - Phase 2: Storage (MySQL + Redis + Queues driver)

    /// Configure database, Redis, and queue driver connections.
    private func configureStorage() throws {
        let c = config.typed

        // MySQL
        var tlsConfig = TLSConfiguration.makeClientConfiguration()
        switch c.mysql.tls {
        case .disable:
            tlsConfig.certificateVerification = .none
        case .require:
            break // keep system default (full verification)
        }
        app.databases.use(
            .mysql(
                hostname: c.mysql.host,
                port: c.mysql.port,
                username: c.mysql.username,
                password: c.mysql.password,
                database: c.mysql.database,
                tlsConfiguration: tlsConfig
            ),
            as: .mysql
        )

        // Redis
        let redisConfiguration = try RedisConfiguration(
            hostname: c.redis.host,
            port: c.redis.port,
            pool: .init(connectionRetryTimeout: .seconds(1))
        )
        app.redis.configuration = redisConfiguration

        // Queues driver (only if enabled)
        if c.features.enableQueues {
            app.queues.use(.redis(redisConfiguration))
        }

        // Model / Migration
        HeliosModelRegistrar.register(delegate.models(app: self), on: app)
    }

    // MARK: - Phase 3: Views & Static Files

    /// Configure Leaf template engine and static file serving.
    private func configureViews() {
        let c = config.typed

        if c.features.serveLeaf {
            app.views.use(.leaf)
        }

        if c.features.serveStaticFiles {
            app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
        }
    }

    // MARK: - Phase 4: Middleware (Filters)

    /// Register application-level middleware / filters from the delegate.
    private func configureMiddleware() {
        HeliosRouteRegistrar.registerFilters(delegate.filters(app: self), on: app)
    }

    // MARK: - Phase 5: Routes

    /// Register HTTP route handlers from the delegate.
    private func registerRoutes() {
        HeliosRouteRegistrar.registerRoutes(delegate.routes(app: self), on: app)
    }

    // MARK: - Phase 6: Background Jobs (Timers + Tasks)

    /// Register scheduled timers and async tasks. Only active when queues are enabled.
    private func registerBackgroundJobs() {
        let c = config.typed
        guard c.features.enableQueues else { return }

        let timerContext = HeliosTimerContext(app: self, queues: app.queues)
        let taskContext = HeliosTaskContext(app: self, queues: app.queues)

        if c.features.enableTimers {
            delegate.timers(app: self).forEach { builder in
                let timer = builder(timerContext)
                timer.schedule(queue: app.queues)
            }
        }

        delegate.tasks(app: self).forEach { builder in
            guard let task = builder(taskContext) as? any HeliosTask else {
                app.logger.critical("Unrecognized task builder: \(String(describing: builder))")
                return
            }
            task.register(queue: app.queues)
        }
    }

    // MARK: - Run

    /// Start the application: run migrations (if enabled), start jobs, then serve.
    public func run() throws {
        let c = config.typed
        if c.features.autoMigrate {
            try app.autoMigrate().wait()
        }
        if c.features.enableQueues {
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
