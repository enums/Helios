//
//  HeliosConfig.swift
//  Helios
//
//  Typed configuration model for Helios.
//  Replaces the old [String: String] + @dynamicMemberLookup approach.
//

import Foundation

// MARK: - Top-level Config

public struct HeliosConfig {
    public let server: ServerConfig
    public let mysql: MySQLConfig
    public let redis: RedisConfig
    public let features: FeatureFlags

    public init(server: ServerConfig, mysql: MySQLConfig, redis: RedisConfig, features: FeatureFlags) {
        self.server = server
        self.mysql = mysql
        self.redis = redis
        self.features = features
    }
}

// MARK: - Sub-configs

public struct ServerConfig {
    public let host: String
    public let port: Int

    public init(host: String = "0.0.0.0", port: Int = 8080) {
        self.host = host
        self.port = port
    }
}

public struct MySQLConfig {
    public let host: String
    public let port: Int
    public let username: String
    public let password: String
    public let database: String
    public let tls: TLSMode

    public init(host: String, port: Int = 3306, username: String, password: String, database: String, tls: TLSMode = .disable) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.database = database
        self.tls = tls
    }
}

public struct RedisConfig {
    public let host: String
    public let port: Int

    public init(host: String = "127.0.0.1", port: Int = 6379) {
        self.host = host
        self.port = port
    }
}

public struct FeatureFlags {
    public let autoMigrate: Bool
    public let serveLeaf: Bool
    public let enableQueues: Bool
    public let enableTimers: Bool
    public let serveStaticFiles: Bool

    public init(
        autoMigrate: Bool = false,
        serveLeaf: Bool = true,
        enableQueues: Bool = true,
        enableTimers: Bool = true,
        serveStaticFiles: Bool = true
    ) {
        self.autoMigrate = autoMigrate
        self.serveLeaf = serveLeaf
        self.enableQueues = enableQueues
        self.enableTimers = enableTimers
        self.serveStaticFiles = serveStaticFiles
    }
}

// MARK: - Enums

public enum TLSMode: String, Codable {
    case disable
    case require
}

public enum AppEnv: String, Codable {
    case development
    case production
    case testing

    public static func detect() -> AppEnv {
        let raw = ProcessInfo.processInfo.environment["HELIOS_ENV"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        switch raw {
        case "production", "prod": return .production
        case "testing", "test": return .testing
        default: return .development
        }
    }
}
