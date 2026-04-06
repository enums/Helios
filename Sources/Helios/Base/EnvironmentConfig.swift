//
//  EnvironmentConfig.swift
//  Helios
//
//  Runtime environment configuration for Helios.
//  Captures profile, network binding, logging, and failure policy.
//

import Foundation
import Logging

// MARK: - EnvironmentProfile

/// The deployment profile under which the application is running.
public enum EnvironmentProfile: String, CaseIterable, Codable, Sendable {
    case production
    case development
    case test

    /// Detect from the HELIOS_ENV environment variable, defaulting to `.development`.
    public static func detect() -> EnvironmentProfile {
        let raw = ProcessInfo.processInfo.environment["HELIOS_ENV"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        switch raw {
        case "production", "prod":   return .production
        case "testing", "test":      return .test
        default:                     return .development
        }
    }
}

// MARK: - EnvironmentConfig

/// Framework-level environment configuration.
/// Captures network binding, log level, deployment profile, and failure policy.
public struct EnvironmentConfig: Codable, Sendable {

    /// Deployment profile: production, development, or test.
    public let profile: EnvironmentProfile

    /// HTTP server bind host.
    public let host: String

    /// HTTP server bind port.
    public let port: Int

    /// Minimum log level for the application.
    public let logLevel: Logger.Level

    /// When true, any bootstrap error terminates the process immediately.
    /// Defaults to true in production, false elsewhere.
    public let failFast: Bool

    public init(
        profile: EnvironmentProfile = .development,
        host: String = "0.0.0.0",
        port: Int = 8080,
        logLevel: Logger.Level = .info,
        failFast: Bool? = nil
    ) {
        self.profile = profile
        self.host = host
        self.port = port
        self.logLevel = logLevel
        self.failFast = failFast ?? (profile == .production)
    }

    /// Default environment config, auto-detecting profile from HELIOS_ENV.
    public static var detected: EnvironmentConfig {
        EnvironmentConfig(profile: .detect())
    }
}

// Logger.Level already conforms to Codable via swift-log.
// No additional conformance needed.
