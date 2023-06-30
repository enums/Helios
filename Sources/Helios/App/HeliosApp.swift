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

        // Service
        app.http.server.configuration.hostname = config.hostname.isEmpty ? HTTPServer.Configuration.defaultHostname : config.hostname
        app.http.server.configuration.port = Int(config.port) ?? HTTPServer.Configuration.defaultPort

        // Database
        var tslConfig = TLSConfiguration.makeClientConfiguration()
        tslConfig.certificateVerification = .none
        app.databases.use(
            .mysql(
                hostname: config.mysql_host,
                port: Int(config.mysql_port) ?? 3306,
                username: config.mysql_username,
                password: config.mysql_password,
                database: config.mysql_database,
                tlsConfiguration: tslConfig
            ),
            as: .mysql
        )

        // Redis / Queues
        let redisConfiguration = try RedisConfiguration(
            hostname: config.redis_host,
            port: Int(config.redis_port) ?? RedisConnection.Configuration.defaultPort,
            pool: .init(connectionRetryTimeout: .seconds(1))
        )
        app.redis.configuration = redisConfiguration
        app.queues.use(.redis(redisConfiguration))

        // Routes
        delegate.routes(app: self)
            .flatMap { (path: String, handlerMapper: [HTTPMethod : HeliosHandlerBuilder]) in
                handlerMapper.map { (method: HTTPMethod, builder: @escaping HeliosHandlerBuilder) in
                    (path, method, builder)
                }
            }.forEach { (path, method, builder) in
                app.on(method, path.pathComponents) { req async throws -> AnyAsyncResponse in
                    let handler = builder()
                    let result = try await handler.handle(req: req)
                    return AnyAsyncResponse(result)
                }
            }

        // Model / Migration
        delegate.models(app: self).forEach { builder in
            let model = builder()
            app.migrations.add(model)
        }

        // Views
        app.views.use(.leaf)

        // Filter / Middleware
        delegate.filters(app: self).forEach { builder in
            let plugin = builder()
            app.middleware.use(plugin)
        }
        app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

        
        // Timer
        delegate.timers(app: self).forEach { builder in
            let timer = builder()
            timer.schedule(queue: app.queues)
        }

        // Task
        delegate.tasks(app: self).forEach { builder in
            guard let task = builder() as? any HeliosTask else {
                app.logger.critical("Unrecognized task builder: \(String(describing: builder))")
                return
            }
            task.register(queue: app.queues)
        }

    }

    public func run() throws {
        try app.autoMigrate().wait()
        try app.queues.startInProcessJobs()
        try app.queues.startScheduledJobs()
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
