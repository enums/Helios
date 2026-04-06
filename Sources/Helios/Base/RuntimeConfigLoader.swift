//
//  RuntimeConfigLoader.swift
//  Helios
//
//  Protocol and default implementation for layered HeliosRuntimeConfig loading.
//

import Foundation
import Logging

// MARK: - RuntimeConfigLoader Protocol

/// Loads and merges configuration from an ordered list of `ConfigSource`s
/// to produce a `HeliosRuntimeConfig`.
public protocol RuntimeConfigLoader {
    /// Load configuration from the given sources and return a runtime config.
    func load(sources: [ConfigSource], configDir: String?) throws -> HeliosRuntimeConfig
}

// MARK: - DefaultRuntimeConfigLoader

/// The default implementation: merges all sources in order (later wins),
/// then builds a `HeliosRuntimeConfig` from the merged raw dictionary.
public struct DefaultRuntimeConfigLoader: RuntimeConfigLoader {

    public init() {}

    public func load(sources: [ConfigSource], configDir: String?) throws -> HeliosRuntimeConfig {
        // Merge all sources in order
        var merged: [String: Any] = [:]
        for source in sources {
            if let raw = try ConfigSourceLoader.load(source, configDir: configDir) {
                merged = shallowDeepMerge(base: merged, override: raw)
            }
        }
        return try buildRuntimeConfig(from: merged)
    }

    // MARK: - Merge

    /// Recursively merges override into base (override wins for leaf values).
    private func shallowDeepMerge(base: [String: Any], override: [String: Any]) -> [String: Any] {
        var result = base
        for (key, value) in override {
            if let baseDict = result[key] as? [String: Any],
               let overrideDict = value as? [String: Any] {
                result[key] = shallowDeepMerge(base: baseDict, override: overrideDict)
            } else {
                result[key] = value
            }
        }
        return result
    }

    // MARK: - Build HeliosRuntimeConfig

    private func buildRuntimeConfig(from raw: [String: Any]) throws -> HeliosRuntimeConfig {
        // --- Environment ---
        let envRaw = raw["environment"] as? [String: Any] ?? [:]
        // Also check legacy "server" key for host/port backward compat
        let serverRaw = raw["server"] as? [String: Any] ?? [:]

        let profileStr = stringValue(envRaw["profile"]) ?? ""
        let profile = EnvironmentProfile(rawValue: profileStr) ?? .detect()

        let host = stringValue(envRaw["host"])
            ?? stringValue(serverRaw["host"])
            ?? stringValue(raw["hostname"])
            ?? "0.0.0.0"
        let port = intValue(envRaw["port"])
            ?? intValue(serverRaw["port"])
            ?? intValue(raw["port"])
            ?? 8080

        let logLevelStr = stringValue(envRaw["logLevel"]) ?? "info"
        let logLevel = Logger.Level(rawValue: logLevelStr) ?? .info

        let failFast = boolValue(envRaw["failFast"])

        let environment = EnvironmentConfig(
            profile: profile,
            host: host,
            port: port,
            logLevel: logLevel,
            failFast: failFast
        )

        // --- Bootstrap ---
        let bootstrapRaw = raw["bootstrap"] as? [String: Any] ?? [:]
        let bootstrap: BootstrapConfig
        if let phaseStrings = bootstrapRaw["enabledPhases"] as? [String] {
            let phases = phaseStrings.compactMap { BootstrapPhase(rawValue: $0) }
            bootstrap = BootstrapConfig(enabledPhases: phases)
        } else {
            bootstrap = .default
        }

        // --- Resources ---
        let resourcesRaw = raw["resources"] as? [String: Any] ?? [:]
        let resourcePaths: [ResourceKey: String] = resourcesRaw.compactMapValues { stringValue($0) }
            .reduce(into: [:]) { dict, kv in
                dict[ResourceKey(rawValue: kv.key)] = kv.value
            }
        let resources = ResourceConfig(paths: resourcePaths)

        // --- Extensions ---
        let extensionConfig: ExtensionConfig
        if let extArray = raw["extensions"] as? [[String: Any]] {
            let descriptors = extArray.compactMap { d -> ExtensionDescriptor? in
                guard let key = stringValue(d["key"]),
                      let kindStr = stringValue(d["kind"]),
                      let kind = ExtensionKind(rawValue: kindStr) else { return nil }
                let enabled = boolValue(d["enabled"]) ?? true
                return ExtensionDescriptor(key: key, enabled: enabled, kind: kind)
            }
            extensionConfig = ExtensionConfig(descriptors: descriptors)
        } else {
            extensionConfig = .empty
        }

        // --- Config Sources (just record what was asked; stored for introspection) ---
        // We leave configSources empty here since the caller provided them to us.
        // The RuntimeConfig stores the resolved state, not the source list.

        // --- Legacy storage (MySQL / Redis) — optional ---
        let mysqlRaw = raw["mysql"] as? [String: Any]
        let redisRaw = raw["redis"] as? [String: Any]
        let featuresRaw = raw["features"] as? [String: Any] ?? [:]

        let mysql: MySQLConfig? = mysqlRaw.flatMap { r -> MySQLConfig? in
            guard let host = stringValue(r["host"]) ?? stringValue(raw["mysql_host"]),
                  !host.isEmpty else { return nil }
            let port = intValue(r["port"]) ?? intValue(raw["mysql_port"]) ?? 3306
            let username = stringValue(r["username"]) ?? stringValue(raw["mysql_username"]) ?? ""
            let password = stringValue(r["password"]) ?? stringValue(raw["mysql_password"]) ?? ""
            let database = stringValue(r["database"]) ?? stringValue(raw["mysql_database"]) ?? ""
            let tls = TLSMode(rawValue: stringValue(r["tls"]) ?? "disable") ?? .disable
            return MySQLConfig(host: host, port: port, username: username, password: password, database: database, tls: tls)
        }

        let redis: RedisConfig? = redisRaw.flatMap { r -> RedisConfig? in
            let host = stringValue(r["host"]) ?? stringValue(raw["redis_host"]) ?? "127.0.0.1"
            let port = intValue(r["port"]) ?? intValue(raw["redis_port"]) ?? 6379
            return RedisConfig(host: host, port: port)
        }

        let autoMigrate = boolValue(featuresRaw["autoMigrate"]) ?? boolValue(raw["auto_migrate"]) ?? false
        let serveLeaf = boolValue(featuresRaw["serveLeaf"]) ?? true
        let enableQueues = boolValue(featuresRaw["enableQueues"]) ?? true
        let enableTimers = boolValue(featuresRaw["enableTimers"]) ?? true
        let serveStaticFiles = boolValue(featuresRaw["serveStaticFiles"]) ?? true

        let features = FeatureFlags(
            autoMigrate: autoMigrate,
            serveLeaf: serveLeaf,
            enableQueues: enableQueues,
            enableTimers: enableTimers,
            serveStaticFiles: serveStaticFiles
        )

        return HeliosRuntimeConfig(
            environment: environment,
            bootstrap: bootstrap,
            resources: resources,
            extensions: extensionConfig,
            configSources: [],
            mysql: mysql,
            redis: redis,
            features: features
        )
    }

    // MARK: - Value converters

    private func stringValue(_ value: Any?) -> String? {
        guard let value = value else { return nil }
        if let str = value as? String { return str.isEmpty ? nil : str }
        return String(describing: value)
    }

    private func intValue(_ value: Any?) -> Int? {
        guard let value = value else { return nil }
        if let int = value as? Int { return int }
        if let double = value as? Double { return Int(double) }
        if let str = value as? String { return Int(str) }
        return nil
    }

    private func boolValue(_ value: Any?) -> Bool? {
        guard let value = value else { return nil }
        if let bool = value as? Bool { return bool }
        if let int = value as? Int { return int != 0 }
        if let str = value as? String {
            switch str.lowercased() {
            case "true", "1", "yes": return true
            case "false", "0", "no": return false
            default: return nil
            }
        }
        return nil
    }
}
