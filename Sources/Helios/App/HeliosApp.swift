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

    /// Run setup, executing only the phases listed in `bootstrapConfig.enabledPhases`.
    /// Defaults to the bootstrap config stored in `config.runtime.bootstrap`.
    func setup(bootstrapConfig: BootstrapConfig? = nil) throws {
        let phases = bootstrapConfig ?? config.runtime.bootstrap
        if phases.isEnabled(.loadConfiguration) {
            try loadConfiguration()
        }
        if phases.isEnabled(.prepareResources) {
            try prepareResources()
        }
        if phases.isEnabled(.registerExtensions) {
            registerExtensions()
        }
        if phases.isEnabled(.initializeServices) {
            try configureServer()
            try configureStorage()
            configureViews()
        }
        if phases.isEnabled(.registerMiddleware) {
            configureMiddleware()
        }
        if phases.isEnabled(.registerRoutes) {
            registerRoutes()
        }
        if phases.isEnabled(.startBackgroundSystems) {
            registerBackgroundJobs()
        }
    }

    // MARK: - Phase 0: Load Configuration

    /// Validate the loaded runtime configuration.
    /// Throws if the config is invalid (e.g. bad port, missing required fields).
    private func loadConfiguration() throws {
        try config.runtime.validate()
    }

    // MARK: - Phase 1: Prepare Resources

    /// Validate the resource path configuration.
    /// Throws `ResourceConfigError` if any required keys are missing.
    private func prepareResources() throws {
        try config.runtime.resources.validate()
    }

    // MARK: - Phase 2: Register Extensions

    /// Log enabled extensions; skip (no-op) disabled ones.
    /// Disabled descriptors in `runtime.extensions` are filtered out here.
    private func registerExtensions() {
        let enabled = config.runtime.extensions.enabled
        for descriptor in enabled {
            app.logger.debug("Helios: registering extension '\(descriptor.key)' (kind: \(descriptor.kind.rawValue))")
        }
        let skipped = config.runtime.extensions.descriptors.filter { !$0.enabled }
        for descriptor in skipped {
            app.logger.debug("Helios: skipping disabled extension '\(descriptor.key)'")
        }
    }

    // MARK: - Phase 3: Server

    /// Configure HTTP server host and port.
    private func configureServer() throws {
        let env = config.runtime.environment
        app.http.server.configuration.hostname = env.host
        app.http.server.configuration.port = env.port
    }

    // MARK: - Phase 4: Storage (MySQL + Redis + Queues driver) — optional

    /// Configure database, Redis, and queue driver connections.
    /// Storage setup is skipped when mysql/redis are nil in the runtime config.
    private func configureStorage() throws {
        let runtime = config.runtime
        let features = runtime.features

        // MySQL — only if configured
        if let mysql = runtime.mysql {
            var tlsConfig = TLSConfiguration.makeClientConfiguration()
            switch mysql.tls {
            case .disable:
                tlsConfig.certificateVerification = .none
            case .require:
                break // keep system default (full verification)
            }
            app.databases.use(
                .mysql(
                    hostname: mysql.host,
                    port: mysql.port,
                    username: mysql.username,
                    password: mysql.password,
                    database: mysql.database,
                    tlsConfiguration: tlsConfig
                ),
                as: .mysql
            )
        }

        // Redis — only if configured
        if let redisConfig = runtime.redis {
            let redisConfiguration = try RedisConfiguration(
                hostname: redisConfig.host,
                port: redisConfig.port,
                pool: .init(connectionRetryTimeout: .seconds(1))
            )
            app.redis.configuration = redisConfiguration

            // Queues driver (only if enabled)
            if features.enableQueues {
                app.queues.use(.redis(redisConfiguration))
            }
        }

        // Model / Migration
        HeliosModelRegistrar.register(delegate.models(app: self), on: app)
    }

    // MARK: - Phase 5: Views & Static Files

    /// Configure Leaf template engine and static file serving.
    private func configureViews() {
        let features = config.runtime.features

        if features.serveLeaf {
            app.views.use(.leaf)
        }

        if features.serveStaticFiles {
            app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
        }
    }

    // MARK: - Phase 6: Middleware (Filters)

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

    // MARK: - Phase 7: Routes

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

    // MARK: - Phase 8: Background Jobs (Timers + Tasks)

    /// Register scheduled timers and async tasks. Only active when queues are enabled.
    /// Descriptor-based API takes priority; falls back to legacy builders.
    private func registerBackgroundJobs() {
        let features = config.runtime.features
        guard features.enableQueues else { return }

        let timerContext = HeliosTimerContext(app: self, queues: app.queues)
        let taskContext = HeliosTaskContext(app: self, queues: app.queues)

        // Timers: descriptor-first
        if features.enableTimers {
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
        let features = config.runtime.features
        if features.autoMigrate {
            try app.autoMigrate().wait()
        }
        if features.enableQueues {
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

    public static func create(
        workspace: String,
        delegate: HeliosAppDelegate,
        bootstrapConfig: BootstrapConfig = .default
    ) throws -> HeliosApp {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        let app = Application(env)
        app.directory = DirectoryConfiguration(workingDirectory: workspace)
        var appConfig = try HeliosAppConfig(dir: app.directory)
        // If a non-default bootstrap was requested, bake it into the stored runtime config
        if bootstrapConfig.enabledPhases != appConfig.runtime.bootstrap.enabledPhases {
            let rt = appConfig.runtime
            let patched = HeliosRuntimeConfig(
                environment: rt.environment,
                bootstrap: bootstrapConfig,
                resources: rt.resources,
                extensions: rt.extensions,
                configSources: rt.configSources,
                mysql: rt.mysql,
                redis: rt.redis,
                features: rt.features
            )
            appConfig = HeliosAppConfig(workspacePath: workspace, runtime: patched)
        }
        let helios = HeliosApp(app: app, config: appConfig, delegate: delegate)
        try helios.setup()
        return helios
    }

    /// Backward-compatible factory (original signature).
    public static func create(workspace: String, delegate: HeliosAppDelegate) throws -> HeliosApp {
        try create(workspace: workspace, delegate: delegate, bootstrapConfig: .default)
    }

    /// New factory: inject a `HeliosRuntimeConfig` directly (no disk loading).
    /// Use this in tests or when the caller already has a fully-configured runtime config.
    public static func create(
        workspace: String,
        delegate: HeliosAppDelegate,
        runtimeConfig: HeliosRuntimeConfig
    ) throws -> HeliosApp {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        let app = Application(env)
        app.directory = DirectoryConfiguration(workingDirectory: workspace)
        let appConfig = HeliosAppConfig(workspacePath: workspace, runtime: runtimeConfig)
        let helios = HeliosApp(app: app, config: appConfig, delegate: delegate)
        try helios.setup()
        return helios
    }
}
