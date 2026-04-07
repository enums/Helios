//
//  ConfigTests.swift
//  HeliosTests
//
//  Config loading, validation, and HeliosAppConfig facade tests.
//
//  New-module unit tests live in their dedicated files:
//    BootstrapPhaseTests, RuntimeConfigTests, ConfigSourceTests,
//    ResourceConfigTests, ExtensionConfigTests.
//

import XCTest
@testable import Helios

final class ConfigTests: XCTestCase {

    // MARK: - Shared type defaults

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
        XCTAssertEqual(AppEnv(rawValue: "development"), .development)
        XCTAssertEqual(AppEnv(rawValue: "production"), .production)
        XCTAssertEqual(AppEnv(rawValue: "testing"), .testing)
    }

    // MARK: - Config loading (nested keys only)

    func testLoadBaseConfig() throws {
        let dir = try makeTempConfigDir(files: [
            "base.json": """
            {
                "environment": { "host": "localhost", "port": 3000 },
                "mysql": { "host": "db.local", "port": 3306, "username": "root", "password": "secret", "database": "helios_dev" },
                "redis": { "host": "redis.local", "port": 6380 }
            }
            """
        ])
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let config = try HeliosConfigLoader.loadRuntime(configDir: dir)
        XCTAssertEqual(config.environment.host, "localhost")
        XCTAssertEqual(config.environment.port, 3000)
        XCTAssertEqual(config.mysql?.host, "db.local")
        XCTAssertEqual(config.mysql?.port, 3306)
        XCTAssertEqual(config.mysql?.username, "root")
        XCTAssertEqual(config.mysql?.password, "secret")
        XCTAssertEqual(config.mysql?.database, "helios_dev")
        XCTAssertEqual(config.redis?.host, "redis.local")
        XCTAssertEqual(config.redis?.port, 6380)
    }

    func testEnvOverrideMergesOntoBase() throws {
        let dir = try makeTempConfigDir(files: [
            "base.json": """
            {
                "environment": { "host": "0.0.0.0", "port": 8080 },
                "mysql": { "host": "localhost", "username": "dev", "password": "dev", "database": "helios" },
                "redis": { "host": "127.0.0.1" }
            }
            """,
            "development.json": """
            {
                "environment": { "port": 3000 },
                "mysql": { "password": "dev-override" }
            }
            """
        ])
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let config = try HeliosConfigLoader.loadRuntime(configDir: dir)
        XCTAssertEqual(config.environment.port, 3000)
        XCTAssertEqual(config.mysql?.password, "dev-override")
        XCTAssertEqual(config.environment.host, "0.0.0.0")
        XCTAssertEqual(config.mysql?.host, "localhost")
        XCTAssertEqual(config.mysql?.username, "dev")
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

        let config = try HeliosConfigLoader.loadRuntime(configDir: dir)
        XCTAssertTrue(config.features.autoMigrate)
        XCTAssertFalse(config.features.serveLeaf)
        XCTAssertFalse(config.features.enableQueues)
        XCTAssertTrue(config.features.enableTimers)
        XCTAssertTrue(config.features.serveStaticFiles)
    }

    // MARK: - Validation

    func testValidationFailsOnMissingMySQLHost() {
        let config = HeliosRuntimeConfig(
            mysql: MySQLConfig(host: "", username: "u", password: "p", database: "d")
        )
        XCTAssertThrowsError(try config.validate()) { error in
            let desc = String(describing: error)
            XCTAssertTrue(desc.contains("mysql.host"), "Expected mysql.host error, got: \(desc)")
        }
    }

    func testValidationFailsOnInvalidPort() {
        let config = HeliosRuntimeConfig(
            environment: EnvironmentConfig(port: 99999),
            mysql: MySQLConfig(host: "db", username: "u", password: "p", database: "d")
        )
        XCTAssertThrowsError(try config.validate()) { error in
            let desc = String(describing: error)
            XCTAssertTrue(desc.contains("port"), "Expected port error, got: \(desc)")
        }
    }

    func testNoConfigFileProducesNoStorage() throws {
        let dir = NSTemporaryDirectory() + "helios-test-empty-\(UUID().uuidString)/"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let runtime = try HeliosConfigLoader.loadRuntime(configDir: dir)
        XCTAssertNil(runtime.mysql)
        XCTAssertNil(runtime.redis)
    }

    // MARK: - HeliosAppConfig facade

    func testAppConfigRuntimeInitializer() {
        let runtime = HeliosRuntimeConfig(
            environment: EnvironmentConfig(host: "rt-host", port: 4321),
            mysql: MySQLConfig(host: "rt-db", username: "u", password: "p", database: "d")
        )
        let appConfig = HeliosAppConfig(workspacePath: "/tmp/app/", runtime: runtime)
        XCTAssertEqual(appConfig.runtime.environment.host, "rt-host")
        XCTAssertEqual(appConfig.runtime.environment.port, 4321)
        XCTAssertEqual(appConfig.workspacePath, "/tmp/app/")
        XCTAssertEqual(appConfig.configPath, "/tmp/app/Config/")
    }

    func testAppConfigPatchesResourcePaths() {
        let runtime = HeliosRuntimeConfig()
        let appConfig = HeliosAppConfig(workspacePath: "/workspace/", runtime: runtime)
        XCTAssertEqual(appConfig.runtime.resources.path(for: .workspace), "/workspace/")
        XCTAssertEqual(appConfig.runtime.resources.path(for: .publicDir), "/workspace/Public/")
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
