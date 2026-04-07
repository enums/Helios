//
//  HeliosRuntimeConfig.swift
//  Helios
//
//  New top-level framework runtime configuration.
//  Framework-agnostic: storage (MySQL/Redis) is optional.
//

import Foundation
import Logging

// MARK: - HeliosRuntimeConfig

/// The primary framework-level configuration for Helios.
///
/// The primary framework-level configuration for Helios.
/// Storage (MySQL, Redis) is optional — nil means not configured; apps handle their own storage
/// via delegate or extension.
public struct HeliosRuntimeConfig: Codable, Sendable {

    // MARK: Framework-level config

    /// Runtime environment: profile, host, port, log level, failure policy.
    public let environment: EnvironmentConfig

    /// Bootstrap phase configuration — controls which setup phases run.
    public let bootstrap: BootstrapConfig

    /// Typed resource path configuration.
    public let resources: ResourceConfig

    /// Extension/plugin registry.
    public let extensions: ExtensionConfig

    /// Ordered config sources used to build this config (for introspection).
    public let configSources: [ConfigSource]

    // MARK: Optional storage

    /// MySQL database configuration. `nil` means no database configured.
    public let mysql: MySQLConfig?

    /// Redis cache/queue configuration. `nil` means no Redis configured.
    public let redis: RedisConfig?

    /// Feature flags.
    public let features: FeatureFlags

    // MARK: Init

    public init(
        environment: EnvironmentConfig = .detected,
        bootstrap: BootstrapConfig = .default,
        resources: ResourceConfig = ResourceConfig(),
        extensions: ExtensionConfig = .empty,
        configSources: [ConfigSource] = [],
        mysql: MySQLConfig? = nil,
        redis: RedisConfig? = nil,
        features: FeatureFlags = FeatureFlags()
    ) {
        self.environment = environment
        self.bootstrap = bootstrap
        self.resources = resources
        self.extensions = extensions
        self.configSources = configSources
        self.mysql = mysql
        self.redis = redis
        self.features = features
    }

    // MARK: - Convenience accessors

    /// Convenience: whether storage (MySQL) has been configured.
    public var hasStorage: Bool { mysql != nil }

    /// Convenience: whether Redis has been configured.
    public var hasRedis: Bool { redis != nil }

    // MARK: - Presets

    /// Minimal framework config — no storage, default phases, development profile.
    public static let minimal = HeliosRuntimeConfig(
        environment: EnvironmentConfig(profile: .development),
        bootstrap: .minimal
    )

    /// Testing config — no storage, no background systems.
    public static let testing = HeliosRuntimeConfig(
        environment: EnvironmentConfig(profile: .test),
        bootstrap: .webOnly,
        features: FeatureFlags(
            autoMigrate: false,
            serveLeaf: false,
            enableQueues: false,
            enableTimers: false,
            serveStaticFiles: false
        )
    )

    // MARK: - Loader

    /// Load a `HeliosRuntimeConfig` from a standard config directory using the default loader.
    public static func load(configDir: String, extraSources: [ConfigSource] = []) throws -> HeliosRuntimeConfig {
        let env = EnvironmentProfile.detect()
        let dir = configDir.hasSuffix("/") ? configDir : configDir + "/"

        var sources: [ConfigSource] = [
            .file(path: dir + "base.json"),
            .file(path: dir + "\(env.rawValue).json"),
            .env(prefix: "HELIOS_"),
        ]
        sources.append(contentsOf: extraSources)

        let loader = DefaultRuntimeConfigLoader()
        var config = try loader.load(sources: sources, configDir: dir)

        // Store the sources used for introspection
        config = HeliosRuntimeConfig(
            environment: config.environment,
            bootstrap: config.bootstrap,
            resources: config.resources,
            extensions: config.extensions,
            configSources: sources,
            mysql: config.mysql,
            redis: config.redis,
            features: config.features
        )
        return config
    }

    // MARK: - Validation

    /// Validate this config.
    /// Storage fields are only validated when `mysql` / `redis` are non-nil.
    public func validate() throws {
        var errors: [String] = []

        // Resource paths — check required keys
        do {
            try resources.validate()
        } catch let err as ResourceConfigError {
            errors.append(String(describing: err))
        }

        // Port ranges
        if environment.port < 1 || environment.port > 65535 {
            errors.append("environment.port must be 1–65535 (got \(environment.port))")
        }

        if let mysql = mysql {
            if mysql.host.isEmpty  { errors.append("mysql.host is required") }
            if mysql.username.isEmpty { errors.append("mysql.username is required") }
            if mysql.database.isEmpty { errors.append("mysql.database is required") }
            if mysql.port < 1 || mysql.port > 65535 {
                errors.append("mysql.port must be 1–65535 (got \(mysql.port))")
            }
        }

        if let redis = redis {
            if redis.port < 1 || redis.port > 65535 {
                errors.append("redis.port must be 1–65535 (got \(redis.port))")
            }
        }

        // Production safety checks
        if environment.profile == .production {
            if features.autoMigrate {
                errors.append("features.autoMigrate must not be true in production")
            }
            if let mysql = mysql, mysql.tls == .disable {
                let logger = Logger(label: "helios.config")
                logger.warning("mysql.tls is 'disable' in production — consider enabling TLS")
            }
        }

        guard errors.isEmpty else {
            throw HeliosConfigError.validationFailed(errors)
        }
    }
}
