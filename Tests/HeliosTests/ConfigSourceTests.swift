//
//  ConfigSourceTests.swift
//  HeliosTests
//
//  Tests for ConfigSource enum and RuntimeConfigLoader.
//

import XCTest
@testable import Helios

final class ConfigSourceTests: XCTestCase {

    // MARK: - ConfigSource Codable

    func testInlineSourceCodable() throws {
        let source = ConfigSource.inline(.object(["key": .string("value")]))
        let data = try JSONEncoder().encode(source)
        let decoded = try JSONDecoder().decode(ConfigSource.self, from: data)
        if case .inline(let v) = decoded {
            XCTAssertEqual(v["key"]?.stringValue, "value")
        } else {
            XCTFail("Expected .inline, got \(decoded)")
        }
    }

    func testFileSourceCodable() throws {
        let source = ConfigSource.file(path: "/etc/helios/base.json")
        let data = try JSONEncoder().encode(source)
        let decoded = try JSONDecoder().decode(ConfigSource.self, from: data)
        if case .file(let path) = decoded {
            XCTAssertEqual(path, "/etc/helios/base.json")
        } else {
            XCTFail("Expected .file, got \(decoded)")
        }
    }

    func testEnvSourceCodable() throws {
        let source = ConfigSource.env(prefix: "MYAPP_")
        let data = try JSONEncoder().encode(source)
        let decoded = try JSONDecoder().decode(ConfigSource.self, from: data)
        if case .env(let prefix) = decoded {
            XCTAssertEqual(prefix, "MYAPP_")
        } else {
            XCTFail("Expected .env, got \(decoded)")
        }
    }

    func testOverrideSourceCodable() throws {
        let source = ConfigSource.override(.object(["debug": .bool(true)]))
        let data = try JSONEncoder().encode(source)
        let decoded = try JSONDecoder().decode(ConfigSource.self, from: data)
        if case .override(let v) = decoded {
            XCTAssertEqual(v["debug"]?.boolValue, true)
        } else {
            XCTFail("Expected .override, got \(decoded)")
        }
    }

    // MARK: - ConfigSourceLoader: inline

    func testLoadInlineSource() throws {
        let source = ConfigSource.inline(.object([
            "server": .object(["host": .string("localhost"), "port": .int(3000)]),
        ]))
        let result = try ConfigSourceLoader.load(source)
        XCTAssertNotNil(result)
        let serverRaw = result?["server"] as? [String: Any]
        XCTAssertEqual(serverRaw?["host"] as? String, "localhost")
        XCTAssertEqual(serverRaw?["port"] as? Int, 3000)
    }

    func testLoadNullInlineReturnsNil() throws {
        let source = ConfigSource.inline(.null)
        let result = try ConfigSourceLoader.load(source)
        XCTAssertNil(result)
    }

    // MARK: - ConfigSourceLoader: file

    func testLoadMissingFileReturnsNil() throws {
        let source = ConfigSource.file(path: "/nonexistent/path/config.json")
        let result = try ConfigSourceLoader.load(source)
        XCTAssertNil(result)
    }

    func testLoadExistingFile() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let json = """
        { "mysql": { "host": "file-db", "username": "u", "password": "p", "database": "d" } }
        """
        try json.write(toFile: dir + "base.json", atomically: true, encoding: .utf8)

        let source = ConfigSource.file(path: dir + "base.json")
        let result = try ConfigSourceLoader.load(source)
        XCTAssertNotNil(result)
        let mysqlRaw = result?["mysql"] as? [String: Any]
        XCTAssertEqual(mysqlRaw?["host"] as? String, "file-db")
    }

    func testLoadRelativeFilePath() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let json = "{ \"environment\": { \"host\": \"relative-host\" } }"
        try json.write(toFile: dir + "custom.json", atomically: true, encoding: .utf8)

        let source = ConfigSource.file(path: "custom.json")
        let result = try ConfigSourceLoader.load(source, configDir: dir)
        let envRaw = result?["environment"] as? [String: Any]
        XCTAssertEqual(envRaw?["host"] as? String, "relative-host")
    }

    // MARK: - DefaultRuntimeConfigLoader

    func testLoadFromInlineSources() throws {
        let sources: [ConfigSource] = [
            .inline(.object([
                "environment": .object(["host": .string("0.0.0.0"), "port": .int(8080)]),
                "mysql": .object([
                    "host": .string("db.local"),
                    "username": .string("root"),
                    "password": .string("secret"),
                    "database": .string("helios"),
                ]),
            ])),
        ]
        let loader = DefaultRuntimeConfigLoader()
        let config = try loader.load(sources: sources, configDir: nil)
        XCTAssertEqual(config.environment.host, "0.0.0.0")
        XCTAssertEqual(config.environment.port, 8080)
        XCTAssertEqual(config.mysql?.host, "db.local")
    }

    func testLaterSourceOverridesEarlier() throws {
        let sources: [ConfigSource] = [
            .inline(.object(["environment": .object(["host": .string("base-host"), "port": .int(8080)])])),
            .override(.object(["environment": .object(["host": .string("override-host")])])),
        ]
        let loader = DefaultRuntimeConfigLoader()
        let config = try loader.load(sources: sources, configDir: nil)
        XCTAssertEqual(config.environment.host, "override-host")
        XCTAssertEqual(config.environment.port, 8080)  // from base, not overridden
    }

    func testInlineSourceWithNoMySQLProducesNilStorage() throws {
        let sources: [ConfigSource] = [
            .inline(.object(["environment": .object(["host": .string("0.0.0.0")])])),
        ]
        let loader = DefaultRuntimeConfigLoader()
        let config = try loader.load(sources: sources, configDir: nil)
        XCTAssertNil(config.mysql)
        XCTAssertNil(config.redis)
    }

    func testInlineSourceWithMySQLProducesStorage() throws {
        let sources: [ConfigSource] = [
            .inline(.object([
                "mysql": .object([
                    "host": .string("db"),
                    "username": .string("u"),
                    "password": .string("p"),
                    "database": .string("d"),
                ]),
            ])),
        ]
        let loader = DefaultRuntimeConfigLoader()
        let config = try loader.load(sources: sources, configDir: nil)
        XCTAssertNotNil(config.mysql)
        XCTAssertEqual(config.mysql?.host, "db")
    }

    func testLoadFromFileSources() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }

        try """
        { "environment": { "host": "0.0.0.0", "port": 8080 } }
        """.write(toFile: dir + "base.json", atomically: true, encoding: .utf8)
        try """
        { "environment": { "port": 9090 } }
        """.write(toFile: dir + "development.json", atomically: true, encoding: .utf8)

        let sources: [ConfigSource] = [
            .file(path: dir + "base.json"),
            .file(path: dir + "development.json"),
        ]
        let loader = DefaultRuntimeConfigLoader()
        let config = try loader.load(sources: sources, configDir: dir)
        XCTAssertEqual(config.environment.host, "0.0.0.0")
        XCTAssertEqual(config.environment.port, 9090)  // overridden
    }

    func testBootstrapPhasesFromInlineSource() throws {
        let sources: [ConfigSource] = [
            .inline(.object([
                "bootstrap": .object([
                    "enabledPhases": .array([.string("loadConfiguration"), .string("registerRoutes")]),
                ]),
            ])),
        ]
        let loader = DefaultRuntimeConfigLoader()
        let config = try loader.load(sources: sources, configDir: nil)
        XCTAssertTrue(config.bootstrap.isEnabled(.loadConfiguration))
        XCTAssertTrue(config.bootstrap.isEnabled(.registerRoutes))
        XCTAssertFalse(config.bootstrap.isEnabled(.initializeServices))
    }

    // MARK: - End-to-end loader tests (schema fidelity)

    func testLoaderParsesResourcesWithPathsSchema() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let json = """
        {
            "resources": {
                "paths": { "workspace": "/app", "public": "/app/pub" },
                "requiredKeys": ["workspace"]
            }
        }
        """
        try json.write(toFile: dir + "base.json", atomically: true, encoding: .utf8)
        let config = try HeliosRuntimeConfig.load(configDir: dir)
        XCTAssertEqual(config.resources.path(for: .workspace), "/app")
        XCTAssertEqual(config.resources.path(for: .public_), "/app/pub")
        XCTAssertTrue(config.resources.requiredKeys.contains(.workspace))
    }

    func testLoaderParsesResourcesFlatShorthand() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let json = """
        {
            "resources": { "workspace": "/flat", "config": "/flat/cfg" }
        }
        """
        try json.write(toFile: dir + "base.json", atomically: true, encoding: .utf8)
        let config = try HeliosRuntimeConfig.load(configDir: dir)
        XCTAssertEqual(config.resources.path(for: .workspace), "/flat")
        XCTAssertEqual(config.resources.path(for: .config), "/flat/cfg")
    }

    func testLoaderParsesExtensionsWithDescriptorsSchema() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let json = """
        {
            "extensions": {
                "descriptors": [
                    { "key": "auth", "kind": "middleware", "enabled": true, "config": { "secret": "abc" } },
                    { "key": "cache", "kind": "storage", "enabled": false }
                ]
            }
        }
        """
        try json.write(toFile: dir + "base.json", atomically: true, encoding: .utf8)
        let config = try HeliosRuntimeConfig.load(configDir: dir)
        XCTAssertEqual(config.extensions.descriptors.count, 2)
        let auth = config.extensions.descriptor(forKey: "auth")
        XCTAssertNotNil(auth)
        XCTAssertEqual(auth?.kind, .middleware)
        XCTAssertTrue(auth?.enabled == true)
        // config field must survive the load path
        XCTAssertEqual(auth?.config?["secret"]?.stringValue, "abc")
        let cache = config.extensions.descriptor(forKey: "cache")
        XCTAssertEqual(cache?.enabled, false)
    }

    func testLoaderParsesExtensionsFlatArray() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let json = """
        {
            "extensions": [
                { "key": "payments", "kind": "service", "config": { "currency": "USD" } }
            ]
        }
        """
        try json.write(toFile: dir + "base.json", atomically: true, encoding: .utf8)
        let config = try HeliosRuntimeConfig.load(configDir: dir)
        XCTAssertEqual(config.extensions.descriptors.count, 1)
        XCTAssertEqual(config.extensions.descriptors[0].config?["currency"]?.stringValue, "USD")
    }

    func testLoaderResourceRequiredKeysValidation() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let json = """
        {
            "resources": {
                "paths": {},
                "requiredKeys": ["workspace"]
            }
        }
        """
        try json.write(toFile: dir + "base.json", atomically: true, encoding: .utf8)
        let config = try HeliosRuntimeConfig.load(configDir: dir)
        XCTAssertThrowsError(try config.validate()) { error in
            let desc = String(describing: error)
            XCTAssertTrue(desc.contains("workspace"), "Expected workspace key error, got: \(desc)")
        }
    }

    // MARK: - Helpers

    private func makeTempDir() throws -> String {
        let dir = NSTemporaryDirectory() + "helios-src-test-\(UUID().uuidString)/"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }
}
