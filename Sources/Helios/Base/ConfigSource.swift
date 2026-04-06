//
//  ConfigSource.swift
//  Helios
//
//  Abstraction for configuration sources in the layered loading pipeline.
//  Supports inline values, files, environment variable prefixes, and overrides.
//

import Foundation

// MARK: - ConfigSource

/// A single source in a layered configuration loading pipeline.
///
/// Sources are evaluated in order; later sources override earlier ones.
/// Typical ordering: `.file("base.json")`, `.file("<env>.json")`, `.env(prefix:)`, `.override(…)`
public enum ConfigSource: Codable, Sendable {
    /// An inline JSON value (useful for testing or programmatic defaults).
    case inline(JSONValue)
    /// A JSON file at the given absolute or config-relative path.
    case file(path: String)
    /// Environment variables with the given prefix (e.g. `"HELIOS_"`).
    /// Variable names are mapped to nested keys by splitting on `_`.
    case env(prefix: String)
    /// A high-priority inline override applied after all other sources.
    case override(JSONValue)

    // MARK: Codable

    private enum Tag: String, Codable {
        case inline, file, env, override
    }

    private enum CodingKeys: String, CodingKey {
        case type, value, path, prefix
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let tag = try container.decode(Tag.self, forKey: .type)
        switch tag {
        case .inline:
            self = .inline(try container.decode(JSONValue.self, forKey: .value))
        case .file:
            self = .file(path: try container.decode(String.self, forKey: .path))
        case .env:
            self = .env(prefix: try container.decode(String.self, forKey: .prefix))
        case .override:
            self = .override(try container.decode(JSONValue.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .inline(let val):
            try container.encode(Tag.inline, forKey: .type)
            try container.encode(val, forKey: .value)
        case .file(let path):
            try container.encode(Tag.file, forKey: .type)
            try container.encode(path, forKey: .path)
        case .env(let prefix):
            try container.encode(Tag.env, forKey: .type)
            try container.encode(prefix, forKey: .prefix)
        case .override(let val):
            try container.encode(Tag.override, forKey: .type)
            try container.encode(val, forKey: .value)
        }
    }
}

// MARK: - ConfigSourceLoader

/// Resolves a single `ConfigSource` into a raw dictionary `[String: Any]`.
public enum ConfigSourceLoader {

    /// Load a single source and return its raw dictionary representation.
    /// Returns `nil` if the source produces no values (e.g. missing file).
    public static func load(_ source: ConfigSource, configDir: String? = nil) throws -> [String: Any]? {
        switch source {
        case .inline(let jsonValue):
            return jsonValueToDict(jsonValue)

        case .override(let jsonValue):
            return jsonValueToDict(jsonValue)

        case .file(let path):
            let resolvedPath = resolvedFilePath(path, configDir: configDir)
            return try loadJSONFile(at: resolvedPath)

        case .env(let prefix):
            return loadEnvVars(prefix: prefix)
        }
    }

    // MARK: - Private helpers

    private static func resolvedFilePath(_ path: String, configDir: String?) -> String {
        // Absolute path — use as-is
        if path.hasPrefix("/") { return path }
        // Relative — resolve against configDir if provided
        if let dir = configDir {
            let base = dir.hasSuffix("/") ? dir : dir + "/"
            return base + path
        }
        return path
    }

    private static func loadJSONFile(at path: String) throws -> [String: Any]? {
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let fileName = URL(fileURLWithPath: path).lastPathComponent
            throw HeliosConfigError.invalidFormat(fileName)
        }
        return json
    }

    /// Load env vars with the given prefix, stripping the prefix and
    /// converting to lowercased keys (e.g. HELIOS_SERVER_HOST → server.host).
    private static func loadEnvVars(prefix: String) -> [String: Any] {
        var result: [String: Any] = [:]
        let env = ProcessInfo.processInfo.environment
        let upperPrefix = prefix.uppercased()
        for (key, value) in env {
            guard key.uppercased().hasPrefix(upperPrefix), !value.isEmpty else { continue }
            let stripped = String(key.dropFirst(upperPrefix.count))
            let parts = stripped.split(separator: "_").map { $0.lowercased() }
            guard !parts.isEmpty else { continue }
            setNestedValue(in: &result, path: parts, value: value)
        }
        return result
    }

    private static func setNestedValue(in dict: inout [String: Any], path: [String], value: Any) {
        guard !path.isEmpty else { return }
        if path.count == 1 {
            dict[path[0]] = value
            return
        }
        var nested = dict[path[0]] as? [String: Any] ?? [:]
        setNestedValue(in: &nested, path: Array(path.dropFirst()), value: value)
        dict[path[0]] = nested
    }

    private static func jsonValueToDict(_ value: JSONValue) -> [String: Any]? {
        guard case .object(let obj) = value else { return nil }
        return obj.mapValues { jsonValueToAny($0) }
    }

    static func jsonValueToAny(_ value: JSONValue) -> Any {
        switch value {
        case .null:               return NSNull()
        case .bool(let boolVal):   return boolVal
        case .int(let intVal):     return intVal
        case .double(let dblVal):  return dblVal
        case .string(let strVal):  return strVal
        case .array(let arrVal):   return arrVal.map { jsonValueToAny($0) }
        case .object(let objVal):  return objVal.mapValues { jsonValueToAny($0) }
        }
    }
}
