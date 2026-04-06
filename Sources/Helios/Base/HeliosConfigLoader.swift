//
//  HeliosConfigLoader.swift
//  Helios
//
//  Three-layer config loading: base.json → <env>.json → environment variables.
//  Falls back to legacy config.json for backward compatibility.
//

import Foundation

public enum HeliosConfigLoader {

    // MARK: - Public API

    /// Load, merge, validate, and return a typed `HeliosConfig`.
    /// Throws `HeliosConfigError` on missing required fields or invalid values.
    public static func load(configDir: String) throws -> HeliosConfig {
        let env = AppEnv.detect()
        let dir = configDir.hasSuffix("/") ? configDir : configDir + "/"

        // Layer 1: base config
        var base = try loadJSON(at: dir, fileName: "base.json")
            ?? loadJSON(at: dir, fileName: "config.json")  // legacy fallback
            ?? [:]

        // Layer 2: environment override (e.g. production.json, development.json)
        if let envOverride = try loadJSON(at: dir, fileName: "\(env.rawValue).json") {
            base = merge(base: base, override: envOverride)
        }

        // Layer 3: environment variables
        applyEnvVars(to: &base)

        // Build typed config
        let config = try build(from: base, env: env)

        // Validate
        try validate(config, env: env)

        return config
    }

    // MARK: - JSON Loading

    private static func loadJSON(at dir: String, fileName: String) throws -> [String: Any]? {
        let url = URL(fileURLWithPath: dir + fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HeliosConfigError.invalidFormat(fileName)
        }
        return json
    }

    // MARK: - Merge

    /// Shallow-merge override into base. Override values win.
    /// Supports nested dictionaries (one level deep).
    private static func merge(base: [String: Any], override: [String: Any]) -> [String: Any] {
        var result = base
        for (key, value) in override {
            if let baseDict = result[key] as? [String: Any],
               let overrideDict = value as? [String: Any] {
                result[key] = merge(base: baseDict, override: overrideDict)
            } else {
                result[key] = value
            }
        }
        return result
    }

    // MARK: - Environment Variables

    /// Explicit env var whitelist. Only these keys are recognized.
    private static let envVarMapping: [(envKey: String, configPath: [String])] = [
        ("HELIOS_SERVER_HOST",     ["server", "host"]),
        ("HELIOS_SERVER_PORT",     ["server", "port"]),
        ("HELIOS_MYSQL_HOST",      ["mysql", "host"]),
        ("HELIOS_MYSQL_PORT",      ["mysql", "port"]),
        ("HELIOS_MYSQL_USERNAME",  ["mysql", "username"]),
        ("HELIOS_MYSQL_PASSWORD",  ["mysql", "password"]),
        ("HELIOS_MYSQL_DATABASE",  ["mysql", "database"]),
        ("HELIOS_MYSQL_TLS",       ["mysql", "tls"]),
        ("HELIOS_REDIS_HOST",      ["redis", "host"]),
        ("HELIOS_REDIS_PORT",      ["redis", "port"]),
        ("HELIOS_AUTO_MIGRATE",    ["features", "autoMigrate"]),
    ]

    private static func applyEnvVars(to config: inout [String: Any]) {
        let env = ProcessInfo.processInfo.environment
        for mapping in envVarMapping {
            guard let value = env[mapping.envKey], !value.isEmpty else { continue }
            setNestedValue(in: &config, path: mapping.configPath, value: value)
        }
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

    // MARK: - Build Typed Config

    private static func build(from raw: [String: Any], env: AppEnv) throws -> HeliosConfig {
        // Server
        let serverRaw = raw["server"] as? [String: Any] ?? [:]
        // Legacy flat key fallback
        let serverHost = stringValue(serverRaw["host"]) ?? stringValue(raw["hostname"]) ?? "0.0.0.0"
        let serverPort = intValue(serverRaw["port"]) ?? intValue(raw["port"]) ?? 8080

        // MySQL
        let mysqlRaw = raw["mysql"] as? [String: Any] ?? [:]
        let mysqlHost = stringValue(mysqlRaw["host"]) ?? stringValue(raw["mysql_host"]) ?? ""
        let mysqlPort = intValue(mysqlRaw["port"]) ?? intValue(raw["mysql_port"]) ?? 3306
        let mysqlUsername = stringValue(mysqlRaw["username"]) ?? stringValue(raw["mysql_username"]) ?? ""
        let mysqlPassword = stringValue(mysqlRaw["password"]) ?? stringValue(raw["mysql_password"]) ?? ""
        let mysqlDatabase = stringValue(mysqlRaw["database"]) ?? stringValue(raw["mysql_database"]) ?? ""
        let mysqlTLS = TLSMode(rawValue: stringValue(mysqlRaw["tls"]) ?? "disable") ?? .disable

        // Redis
        let redisRaw = raw["redis"] as? [String: Any] ?? [:]
        let redisHost = stringValue(redisRaw["host"]) ?? stringValue(raw["redis_host"]) ?? "127.0.0.1"
        let redisPort = intValue(redisRaw["port"]) ?? intValue(raw["redis_port"]) ?? 6379

        // Features
        let featuresRaw = raw["features"] as? [String: Any] ?? [:]
        let autoMigrate = boolValue(featuresRaw["autoMigrate"]) ?? boolValue(raw["auto_migrate"]) ?? false
        let serveLeaf = boolValue(featuresRaw["serveLeaf"]) ?? true
        let enableQueues = boolValue(featuresRaw["enableQueues"]) ?? true
        let enableTimers = boolValue(featuresRaw["enableTimers"]) ?? true
        let serveStaticFiles = boolValue(featuresRaw["serveStaticFiles"]) ?? true

        return HeliosConfig(
            server: ServerConfig(host: serverHost, port: serverPort),
            mysql: MySQLConfig(host: mysqlHost, port: mysqlPort, username: mysqlUsername, password: mysqlPassword, database: mysqlDatabase, tls: mysqlTLS),
            redis: RedisConfig(host: redisHost, port: redisPort),
            features: FeatureFlags(autoMigrate: autoMigrate, serveLeaf: serveLeaf, enableQueues: enableQueues, enableTimers: enableTimers, serveStaticFiles: serveStaticFiles)
        )
    }

    // MARK: - Validation

    private static func validate(_ config: HeliosConfig, env: AppEnv) throws {
        var errors: [String] = []

        // Required fields
        if config.mysql.host.isEmpty { errors.append("mysql.host is required") }
        if config.mysql.username.isEmpty { errors.append("mysql.username is required") }
        if config.mysql.database.isEmpty { errors.append("mysql.database is required") }

        // Port ranges
        if config.server.port < 1 || config.server.port > 65535 {
            errors.append("server.port must be 1–65535 (got \(config.server.port))")
        }
        if config.mysql.port < 1 || config.mysql.port > 65535 {
            errors.append("mysql.port must be 1–65535 (got \(config.mysql.port))")
        }
        if config.redis.port < 1 || config.redis.port > 65535 {
            errors.append("redis.port must be 1–65535 (got \(config.redis.port))")
        }

        // Production safety
        if env == .production {
            if config.features.autoMigrate {
                errors.append("features.autoMigrate must not be true in production")
            }
            if config.mysql.tls == .disable {
                errors.append("mysql.tls should not be 'disable' in production (set to 'require' or remove to use default)")
            }
        }

        guard errors.isEmpty else {
            throw HeliosConfigError.validationFailed(errors)
        }
    }

    // MARK: - Value Converters

    private static func stringValue(_ value: Any?) -> String? {
        guard let value else { return nil }
        if let str = value as? String { return str.isEmpty ? nil : str }
        return String(describing: value)
    }

    private static func intValue(_ value: Any?) -> Int? {
        guard let value else { return nil }
        if let int = value as? Int { return int }
        if let double = value as? Double { return Int(double) }
        if let str = value as? String { return Int(str) }
        return nil
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        guard let value else { return nil }
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

// MARK: - Errors

public enum HeliosConfigError: Error, CustomStringConvertible {
    case invalidFormat(String)
    case validationFailed([String])

    public var description: String {
        switch self {
        case .invalidFormat(let file):
            return "Helios config error: '\(file)' is not a valid JSON object"
        case .validationFailed(let errors):
            return "Helios config validation failed:\n" + errors.map { "  • \($0)" }.joined(separator: "\n")
        }
    }
}
