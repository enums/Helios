//
//  HeliosConfig.swift
//  Helios
//
//  Shared configuration sub-types used by HeliosRuntimeConfig.
//

import Foundation

// MARK: - Storage configs

public struct MySQLConfig: Codable, Sendable {
    public let host: String
    public let port: Int
    public let username: String
    public let password: String
    public let database: String
    public let tls: TLSMode

    // swiftlint:disable:next line_length
    public init(host: String, port: Int = 3306, username: String, password: String, database: String, tls: TLSMode = .disable) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.database = database
        self.tls = tls
    }
}

public struct RedisConfig: Codable, Sendable {
    public let host: String
    public let port: Int

    public init(host: String = "127.0.0.1", port: Int = 6379) {
        self.host = host
        self.port = port
    }
}

public struct FeatureFlags: Codable, Sendable {
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

public enum TLSMode: String, Codable, Sendable {
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
