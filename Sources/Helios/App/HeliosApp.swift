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

    private func setup() throws {
        let c = config.typed

        // Server
        app.http.server.configuration.hostname = c.server.host
        app.http.server.configuration.port = c.server.port

        // Database
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

        // Redis / Queues
        let redisConfiguration = try RedisConfiguration(
            hostname: c.redis.host,
            port: c.redis.port,
            pool: .init(connectionRetryTimeout: .seconds(1))
        )
        app.redis.configuration = redisConfiguration

        if c.features.enableQueues {
            app.queues.use(.redis(redisConfiguration))
        }

        // Routes
        HeliosRouteRegistrar.registerRoutes(delegate.routes(app: self), on: app)

        // Model / Migration
        delegate.models(app: self).forEach { builder in
            let model = builder()
            app.migrations.add(model)
        }

        // Views
        if c.features.serveLeaf {
            app.views.use(.leaf)
        }

        // Filter / Middleware
        HeliosRouteRegistrar.registerFilters(delegate.filters(app: self), on: app)

        if c.features.serveStaticFiles {
            app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
        }

        // Timer — only when queues are enabled
        if c.features.enableQueues && c.features.enableTimers {
            delegate.timers(app: self).forEach { builder in
                let timer = builder()
                timer.schedule(queue: app.queues)
            }
        }

        // Task — only when queues are enabled
        if c.features.enableQueues {
            delegate.tasks(app: self).forEach { builder in
                guard let task = builder() as? any HeliosTask else {
                    app.logger.critical("Unrecognized task builder: \(String(describing: builder))")
                    return
                }
                task.register(queue: app.queues)
            }
        }
    }

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
