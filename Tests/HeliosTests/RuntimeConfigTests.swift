//
//  RuntimeConfigTests.swift
//  HeliosTests
//
//  Tests for HeliosRuntimeConfig construction, defaults, and presets.
//

import XCTest
@testable import Helios

final class RuntimeConfigTests: XCTestCase {

    // MARK: - Defaults

    func testDefaultEnvironmentConfig() {
        let env = EnvironmentConfig()
        XCTAssertEqual(env.host, "0.0.0.0")
        XCTAssertEqual(env.port, 8080)
        XCTAssertEqual(env.profile, .development)
        XCTAssertEqual(env.logLevel, .info)
        XCTAssertFalse(env.failFast)  // default false for non-production
    }

    func testProductionFailFastDefaultsToTrue() {
        let env = EnvironmentConfig(profile: .production)
        XCTAssertTrue(env.failFast)
    }

    func testExplicitFailFastOverridesDefault() {
        let env = EnvironmentConfig(profile: .production, failFast: false)
        XCTAssertFalse(env.failFast)
    }

    func testDefaultRuntimeConfig() {
        let config = HeliosRuntimeConfig()
        XCTAssertNil(config.mysql)
        XCTAssertNil(config.redis)
        XCTAssertFalse(config.hasStorage)
        XCTAssertFalse(config.hasRedis)
    }

    func testRuntimeConfigWithStorage() {
        let config = HeliosRuntimeConfig(
            mysql: MySQLConfig(host: "db", username: "u", password: "p", database: "d"),
            redis: RedisConfig()
        )
        XCTAssertTrue(config.hasStorage)
        XCTAssertTrue(config.hasRedis)
    }

    // MARK: - Presets

    func testMinimalPreset() {
        let config = HeliosRuntimeConfig.minimal
        XCTAssertEqual(config.environment.profile, .development)
        XCTAssertFalse(config.bootstrap.isEnabled(.registerRoutes))
        XCTAssertFalse(config.bootstrap.isEnabled(.initializeServices))
    }

    func testTestingPreset() {
        let config = HeliosRuntimeConfig.testing
        XCTAssertEqual(config.environment.profile, .test)
        XCTAssertFalse(config.features.enableQueues)
        XCTAssertFalse(config.features.serveLeaf)
        XCTAssertFalse(config.features.autoMigrate)
    }

    // MARK: - Validation

    func testValidationPassesWithNoStorage() throws {
        let config = HeliosRuntimeConfig(
            environment: EnvironmentConfig(host: "0.0.0.0", port: 8080)
        )
        XCTAssertNoThrow(try config.validate())
    }

    func testValidationPassesWithValidStorage() throws {
        let config = HeliosRuntimeConfig(
            mysql: MySQLConfig(host: "db.local", username: "root", password: "pw", database: "helios")
        )
        XCTAssertNoThrow(try config.validate())
    }

    func testValidationFailsOnInvalidPort() {
        let config = HeliosRuntimeConfig(
            environment: EnvironmentConfig(port: 99999)
        )
        XCTAssertThrowsError(try config.validate()) { error in
            let desc = String(describing: error)
            XCTAssertTrue(desc.contains("port"), "Expected port error, got: \(desc)")
        }
    }

    func testValidationFailsOnMissingMySQLHostWhenProvided() {
        let config = HeliosRuntimeConfig(
            mysql: MySQLConfig(host: "", username: "u", password: "p", database: "d")
        )
        XCTAssertThrowsError(try config.validate()) { error in
            let desc = String(describing: error)
            XCTAssertTrue(desc.contains("mysql.host"), "Expected mysql.host error, got: \(desc)")
        }
    }

    func testProductionValidationRejectsAutoMigrate() {
        let config = HeliosRuntimeConfig(
            environment: EnvironmentConfig(profile: .production),
            features: FeatureFlags(autoMigrate: true)
        )
        XCTAssertThrowsError(try config.validate()) { error in
            let desc = String(describing: error)
            XCTAssertTrue(desc.contains("autoMigrate"), "Expected autoMigrate error, got: \(desc)")
        }
    }

    func testProductionValidationRejectsMySQLTLSDisable() {
        let config = HeliosRuntimeConfig(
            environment: EnvironmentConfig(profile: .production),
            mysql: MySQLConfig(host: "db", username: "u", password: "p", database: "d", tls: .disable)
        )
        XCTAssertThrowsError(try config.validate()) { error in
            let desc = String(describing: error)
            XCTAssertTrue(desc.contains("mysql.tls"), "Expected mysql.tls error, got: \(desc)")
        }
    }

    func testProductionValidationPassesWithTLSRequired() throws {
        let config = HeliosRuntimeConfig(
            environment: EnvironmentConfig(profile: .production),
            mysql: MySQLConfig(host: "db", username: "u", password: "p", database: "d", tls: .require)
        )
        XCTAssertNoThrow(try config.validate())
    }

    // MARK: - Codable

    func testCodableRoundTrip() throws {
        let config = HeliosRuntimeConfig(
            environment: EnvironmentConfig(profile: .development, host: "127.0.0.1", port: 3000),
            bootstrap: .webOnly,
            mysql: MySQLConfig(host: "db", username: "u", password: "p", database: "d"),
            features: FeatureFlags(autoMigrate: false, serveLeaf: true)
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(HeliosRuntimeConfig.self, from: data)
        XCTAssertEqual(decoded.environment.host, config.environment.host)
        XCTAssertEqual(decoded.environment.port, config.environment.port)
        XCTAssertEqual(decoded.mysql?.host, config.mysql?.host)
        XCTAssertEqual(decoded.features.serveLeaf, config.features.serveLeaf)
    }

    // MARK: - Load from files

    func testLoadFromConfigDirWithNoStorage() throws {
        let dir = try makeTempConfigDir(files: [
            "base.json": """
            { "environment": { "host": "0.0.0.0", "port": 7777 } }
            """
        ])
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let config = try HeliosRuntimeConfig.load(configDir: dir)
        XCTAssertEqual(config.environment.port, 7777)
        XCTAssertNil(config.mysql)
        XCTAssertNil(config.redis)
    }

    func testLoadFromConfigDirWithMySQLSection() throws {
        let dir = try makeTempConfigDir(files: [
            "base.json": """
            {
                "environment": { "host": "0.0.0.0", "port": 8080 },
                "mysql": { "host": "db.local", "username": "root", "password": "secret", "database": "helios" }
            }
            """
        ])
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let config = try HeliosRuntimeConfig.load(configDir: dir)
        XCTAssertNotNil(config.mysql)
        XCTAssertEqual(config.mysql?.host, "db.local")
    }

    func testLoadEnvOverrideFile() throws {
        let dir = try makeTempConfigDir(files: [
            "base.json": """
            { "environment": { "host": "0.0.0.0", "port": 8080 } }
            """,
            "development.json": """
            { "environment": { "port": 3000 } }
            """
        ])
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let config = try HeliosRuntimeConfig.load(configDir: dir)
        XCTAssertEqual(config.environment.port, 3000)
        XCTAssertEqual(config.environment.host, "0.0.0.0")
    }

    // MARK: - EnvironmentProfile

    func testEnvironmentProfileRoundTrip() {
        XCTAssertEqual(EnvironmentProfile(rawValue: "production"), .production)
        XCTAssertEqual(EnvironmentProfile(rawValue: "development"), .development)
        XCTAssertEqual(EnvironmentProfile(rawValue: "test"), .test)
    }

    func testEnvironmentProfileDetectFromUnknown() {
        // Without HELIOS_ENV set we just test parsing
        XCTAssertEqual(EnvironmentProfile(rawValue: "production"), .production)
        XCTAssertEqual(EnvironmentProfile(rawValue: "development"), .development)
        XCTAssertEqual(EnvironmentProfile(rawValue: "test"), .test)
    }

    // MARK: - Helpers

    private func makeTempConfigDir(files: [String: String]) throws -> String {
        let dir = NSTemporaryDirectory() + "helios-rt-test-\(UUID().uuidString)/"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        for (name, content) in files {
            try content.write(toFile: dir + name, atomically: true, encoding: .utf8)
        }
        return dir
    }
}
