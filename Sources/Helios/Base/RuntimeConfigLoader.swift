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

    public init() {} // swiftlint:disable:this unneeded_synthesized_initializer

    public func load(sources: [ConfigSource], configDir: String?) throws -> HeliosRuntimeConfig {
        var merged: [String: Any] = [:]
        for source in sources {
            if let raw = try ConfigSourceLoader.load(source, configDir: configDir) {
                merged = deepMerge(base: merged, override: raw)
            }
        }
        return try buildRuntimeConfig(from: merged)
    }

    // MARK: - Merge

    private func deepMerge(base: [String: Any], override: [String: Any]) -> [String: Any] {
        var result = base
        for (key, value) in override {
            if let baseDict = result[key] as? [String: Any],
               let overrideDict = value as? [String: Any] {
                result[key] = deepMerge(base: baseDict, override: overrideDict)
            } else {
                result[key] = value
            }
        }
        return result
    }

    // MARK: - Build HeliosRuntimeConfig (orchestrator)

    private func buildRuntimeConfig(from raw: [String: Any]) throws -> HeliosRuntimeConfig {
        HeliosRuntimeConfig(
            environment: buildEnvironment(from: raw),
            bootstrap: buildBootstrap(from: raw),
            resources: buildResources(from: raw),
            extensions: buildExtensions(from: raw),
            configSources: [],
            mysql: buildMySQL(from: raw),
            redis: buildRedis(from: raw),
            features: buildFeatures(from: raw)
        )
    }

    // MARK: - Environment

    private func buildEnvironment(from raw: [String: Any]) -> EnvironmentConfig {
        let envRaw = raw["environment"] as? [String: Any] ?? [:]

        let profileStr = stringValue(envRaw["profile"]) ?? ""
        let profile = EnvironmentProfile(rawValue: profileStr) ?? .detect()

        let host = stringValue(envRaw["host"]) ?? "0.0.0.0"
        let port = intValue(envRaw["port"]) ?? 8080

        let logLevelStr = stringValue(envRaw["logLevel"]) ?? "info"
        let logLevel = Logger.Level(rawValue: logLevelStr) ?? .info

        return EnvironmentConfig(
            profile: profile,
            host: host,
            port: port,
            logLevel: logLevel,
            failFast: boolValue(envRaw["failFast"])
        )
    }

    // MARK: - Bootstrap

    private func buildBootstrap(from raw: [String: Any]) -> BootstrapConfig {
        let bootstrapRaw = raw["bootstrap"] as? [String: Any] ?? [:]
        if let phaseStrings = bootstrapRaw["enabledPhases"] as? [String] {
            let phases = phaseStrings.compactMap { BootstrapPhase(rawValue: $0) }
            return BootstrapConfig(enabledPhases: phases)
        }
        return .default
    }

    // MARK: - Resources

    private func buildResources(from raw: [String: Any]) -> ResourceConfig {
        let resourcesRaw = raw["resources"] as? [String: Any] ?? [:]
        if let pathsDict = resourcesRaw["paths"] as? [String: Any] {
            let paths = parseResourcePaths(pathsDict)
            let requiredRaw = resourcesRaw["requiredKeys"] as? [String] ?? []
            let required = Set(requiredRaw.map { ResourceKey(rawValue: $0) })
            return ResourceConfig(paths: paths, requiredKeys: required)
        }
        return ResourceConfig(paths: parseResourcePaths(resourcesRaw))
    }

    private func parseResourcePaths(_ dict: [String: Any]) -> [ResourceKey: String] {
        dict.compactMapValues { stringValue($0) }
            .reduce(into: [:]) { result, pair in
                result[ResourceKey(rawValue: pair.key)] = pair.value
            }
    }

    // MARK: - Extensions

    private func buildExtensions(from raw: [String: Any]) -> ExtensionConfig {
        let extRaw = raw["extensions"]
        let descriptorDicts: [[String: Any]]?
        if let extObj = extRaw as? [String: Any],
           let descs = extObj["descriptors"] as? [[String: Any]] {
            descriptorDicts = descs
        } else if let directArray = extRaw as? [[String: Any]] {
            descriptorDicts = directArray
        } else {
            descriptorDicts = nil
        }
        guard let dicts = descriptorDicts else { return .empty }
        let descriptors = dicts.compactMap { parseExtensionDescriptor($0) }
        return ExtensionConfig(descriptors: descriptors)
    }

    private func parseExtensionDescriptor(
        _ dict: [String: Any]
    ) -> ExtensionDescriptor? {
        guard let key = stringValue(dict["key"]),
              let kindStr = stringValue(dict["kind"]),
              let kind = ExtensionKind(rawValue: kindStr) else { return nil }
        let enabled = boolValue(dict["enabled"]) ?? true
        let config: JSONValue? = (dict["config"] as Any?)
            .flatMap { anyToJSONValue($0) }
        return ExtensionDescriptor(
            key: key, enabled: enabled, kind: kind, config: config
        )
    }

    // MARK: - MySQL (optional)

    private func buildMySQL(from raw: [String: Any]) -> MySQLConfig? {
        guard let section = raw["mysql"] as? [String: Any],
              let host = stringValue(section["host"]),
              !host.isEmpty else { return nil }
        let port = intValue(section["port"]) ?? 3306
        let username = stringValue(section["username"]) ?? ""
        let password = stringValue(section["password"]) ?? ""
        let database = stringValue(section["database"]) ?? ""
        let tls = TLSMode(
            rawValue: stringValue(section["tls"]) ?? "disable"
        ) ?? .disable
        return MySQLConfig(
            host: host, port: port,
            username: username, password: password,
            database: database, tls: tls
        )
    }

    // MARK: - Redis (optional)

    private func buildRedis(from raw: [String: Any]) -> RedisConfig? {
        guard let section = raw["redis"] as? [String: Any] else {
            return nil
        }
        let host = stringValue(section["host"]) ?? "127.0.0.1"
        let port = intValue(section["port"]) ?? 6379
        return RedisConfig(host: host, port: port)
    }

    // MARK: - Features

    private func buildFeatures(from raw: [String: Any]) -> FeatureFlags {
        let feat = raw["features"] as? [String: Any] ?? [:]
        return FeatureFlags(
            autoMigrate: boolValue(feat["autoMigrate"]) ?? false,
            serveLeaf: boolValue(feat["serveLeaf"]) ?? true,
            enableQueues: boolValue(feat["enableQueues"]) ?? true,
            enableTimers: boolValue(feat["enableTimers"]) ?? true,
            serveStaticFiles: boolValue(feat["serveStaticFiles"]) ?? true
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
        if let intVal = value as? Int { return intVal }
        if let doubleVal = value as? Double { return Int(doubleVal) }
        if let strVal = value as? String { return Int(strVal) }
        return nil
    }

    private func boolValue(_ value: Any?) -> Bool? {
        guard let value = value else { return nil }
        if let boolVal = value as? Bool { return boolVal }
        if let intVal = value as? Int { return intVal != 0 }
        if let strVal = value as? String {
            switch strVal.lowercased() {
            case "true", "1", "yes": return true
            case "false", "0", "no": return false
            default: return nil
            }
        }
        return nil
    }

    /// Convert a JSONSerialization `Any` into a typed `JSONValue`.
    private func anyToJSONValue(_ value: Any) -> JSONValue? {
        if value is NSNull { return .null }
        if let boolVal = value as? Bool { return .bool(boolVal) }
        if let intVal = value as? Int { return .int(intVal) }
        if let doubleVal = value as? Double { return .double(doubleVal) }
        if let strVal = value as? String { return .string(strVal) }
        if let arrVal = value as? [Any] {
            return .array(arrVal.compactMap { anyToJSONValue($0) })
        }
        if let objVal = value as? [String: Any] {
            return .object(objVal.compactMapValues { anyToJSONValue($0) })
        }
        return nil
    }
}
