//
//  ConfigTests.swift
//  HeliosTests
//
//  Tests for HeliosConfig, HeliosConfigLoader, and validation logic.
//

import XCTest
@testable import Helios

final class ConfigTests: XCTestCase {

    // MARK: - Typed Config Model

    func testDefaultServerConfig() {
        let server = ServerConfig()
        XCTAssertEqual(server.host, "0.0.0.0")
        XCTAssertEqual(server.port, 8080)
    }

    func testDefaultFeatureFlags() {
        let flags = FeatureFlags()
        XCTAssertFalse(flags.autoMigrate)
        XCTAssertTrue(flags.serveLeaf)
        XCTAssertTrue(flags.enableQueues)
        XCTAssertTrue(flags.enableTimers)
        XCTAssertTrue(flags.serveStaticFiles)
    }

    func testTLSModeRoundTrip() {
        XCTAssertEqual(TLSMode(rawValue: "disable"), .disable)
        XCTAssertEqual(TLSMode(rawValue: "require"), .require)
        XCTAssertNil(TLSMode(rawValue: "invalid"))
    }

    func testAppEnvDetectDefaults() {
        // Without HELIOS_ENV set, should default to development
        // (env may be set in CI, so we just test parsing)
        XCTAssertEqual(AppEnv(rawValue: "development"), .development)
        XCTAssertEqual(AppEnv(rawValue: "production"), .production)
        XCTAssertEqual(AppEnv(rawValue: "testing"), .testing)
    }

    // MARK: - Config Loader (from temp files)

    func testLoadBaseConfig() throws {
        let dir = try makeTempConfigDir(files: [
            "base.json": """
            {
                "server": { "host": "localhost", "port": 3000 },
                "mysql": { "host": "db.local", "port": 3306, "username": "root", "password": "secret", "database": "helios_dev" },
                "redis": { "host": "redis.local", "port": 6380 }
            }
            """
        ])
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let config = try HeliosConfigLoader.load(configDir: dir)
        XCTAssertEqual(config.server.host, "localhost")
        XCTAssertEqual(config.server.port, 3000)
        XCTAssertEqual(config.mysql.host, "db.local")
        XCTAssertEqual(config.mysql.port, 3306)
        XCTAssertEqual(config.mysql.username, "root")
        XCTAssertEqual(config.mysql.password, "secret")
        XCTAssertEqual(config.mysql.database, "helios_dev")
        XCTAssertEqual(config.redis.host, "redis.local")
        XCTAssertEqual(config.redis.port, 6380)
    }

    func testLegacyConfigJsonFallback() throws {
        let dir = try makeTempConfigDir(files: [
            "config.json": """
            {
                "hostname": "legacy-host",
                "port": "9090",
                "mysql_host": "legacy-db",
                "mysql_port": "3307",
                "mysql_username": "admin",
                "mysql_password": "pw",
                "mysql_database": "legacy_db",
                "redis_host": "legacy-redis",
                "redis_port": "6381"
            }
            """
        ])
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let config = try HeliosConfigLoader.load(configDir: dir)
        XCTAssertEqual(config.server.host, "legacy-host")
        XCTAssertEqual(config.server.port, 9090)
        XCTAssertEqual(config.mysql.host, "legacy-db")
        XCTAssertEqual(config.mysql.database, "legacy_db")
        XCTAssertEqual(config.redis.host, "legacy-redis")
        XCTAssertEqual(config.redis.port, 6381)
    }

    func testEnvOverrideMergesOntoBase() throws {
        let dir = try makeTempConfigDir(files: [
            "base.json": """
            {
                "server": { "host": "0.0.0.0", "port": 8080 },
                "mysql": { "host": "localhost", "username": "dev", "password": "dev", "database": "helios" },
                "redis": { "host": "127.0.0.1" }
            }
            """,
            "development.json": """
            {
                "server": { "port": 3000 },
                "mysql": { "password": "dev-override" }
            }
            """
        ])
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let config = try HeliosConfigLoader.load(configDir: dir)
        // Overridden
        XCTAssertEqual(config.server.port, 3000)
        XCTAssertEqual(config.mysql.password, "dev-override")
        // Not overridden — kept from base
        XCTAssertEqual(config.server.host, "0.0.0.0")
        XCTAssertEqual(config.mysql.host, "localhost")
        XCTAssertEqual(config.mysql.username, "dev")
    }

    func testFeatureFlagsFromConfig() throws {
        let dir = try makeTempConfigDir(files: [
            "base.json": """
            {
                "mysql": { "host": "db", "username": "u", "password": "p", "database": "d" },
                "features": { "autoMigrate": true, "serveLeaf": false, "enableQueues": false }
            }
            """
        ])
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let config = try HeliosConfigLoader.load(configDir: dir)
        XCTAssertTrue(config.features.autoMigrate)
        XCTAssertFalse(config.features.serveLeaf)
        XCTAssertFalse(config.features.enableQueues)
        // Defaults for unspecified flags
        XCTAssertTrue(config.features.enableTimers)
        XCTAssertTrue(config.features.serveStaticFiles)
    }

    // MARK: - Validation

    func testValidationFailsOnMissingMySQLHost() throws {
        let dir = try makeTempConfigDir(files: [
            "base.json": """
            {
                "mysql": { "username": "u", "password": "p", "database": "d" }
            }
            """
        ])
        defer { try? FileManager.default.removeItem(atPath: dir) }

        XCTAssertThrowsError(try HeliosConfigLoader.load(configDir: dir)) { error in
            let desc = String(describing: error)
            XCTAssertTrue(desc.contains("mysql.host"), "Expected mysql.host error, got: \(desc)")
        }
    }

    func testValidationFailsOnInvalidPort() throws {
        let dir = try makeTempConfigDir(files: [
            "base.json": """
            {
                "server": { "port": 99999 },
                "mysql": { "host": "db", "username": "u", "password": "p", "database": "d" }
            }
            """
        ])
        defer { try? FileManager.default.removeItem(atPath: dir) }

        XCTAssertThrowsError(try HeliosConfigLoader.load(configDir: dir)) { error in
            let desc = String(describing: error)
            XCTAssertTrue(desc.contains("server.port"), "Expected port error, got: \(desc)")
        }
    }

    func testValidationFailsOnNoConfigFile() throws {
        let dir = NSTemporaryDirectory() + "helios-test-empty-\(UUID().uuidString)/"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: dir) }

        // No config files at all — should still produce a config (all defaults)
        // but fail validation because mysql.host is empty
        XCTAssertThrowsError(try HeliosConfigLoader.load(configDir: dir)) { error in
            let desc = String(describing: error)
            XCTAssertTrue(desc.contains("mysql.host"), "Expected mysql.host error, got: \(desc)")
        }
    }

    // MARK: - HeliosAppConfig facade

    func testAppConfigTestInitializer() {
        let config = HeliosConfig(
            server: ServerConfig(host: "test", port: 1234),
            mysql: MySQLConfig(host: "db", username: "u", password: "p", database: "d"),
            redis: RedisConfig(),
            features: FeatureFlags()
        )
        let appConfig = HeliosAppConfig(workspacePath: "/tmp/test/", config: config)
        XCTAssertEqual(appConfig.typed.server.host, "test")
        XCTAssertEqual(appConfig.typed.server.port, 1234)
        XCTAssertEqual(appConfig.workspacePath, "/tmp/test/")
    }

    // MARK: - Helpers

    private func makeTempConfigDir(files: [String: String]) throws -> String {
        let dir = NSTemporaryDirectory() + "helios-test-\(UUID().uuidString)/"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        for (name, content) in files {
            try content.write(toFile: dir + name, atomically: true, encoding: .utf8)
        }
        return dir
    }
}
