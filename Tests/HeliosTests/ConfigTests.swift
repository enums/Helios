//
//  ConfigTests.swift
//  HeliosTests
//
//  Tests for HeliosConfig (legacy), HeliosRuntimeConfig, BootstrapPhase/Config,
//  EnvironmentConfig, ResourceConfig, ExtensionConfig, ConfigSource, and loaders.
//

import XCTest
@testable import Helios

// Suppress deprecation warnings for the legacy types being tested here.
// This file intentionally tests the backward-compat surface.
#if swift(>=5.7)
// ok
#endif

final class ConfigTests: XCTestCase {

    // MARK: - Legacy Typed Config Model (backward compat tests)

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
        XCTAssertEqual(AppEnv(rawValue: "development"), .development)
        XCTAssertEqual(AppEnv(rawValue: "production"), .production)
        XCTAssertEqual(AppEnv(rawValue: "testing"), .testing)
    }

    // MARK: - Config Loader (legacy, from temp files)

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
        XCTAssertEqual(config.server.port, 3000)
        XCTAssertEqual(config.mysql.password, "dev-override")
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
        XCTAssertTrue(config.features.enableTimers)
        XCTAssertTrue(config.features.serveStaticFiles)
    }

    // MARK: - Validation (legacy loader)

    func testValidationFailsOnMissingMySQLHost() throws {
        // With the new runtime system, a mysql section with empty host
        // results in mysql being nil (not configured), so no validation error.
        // Instead, test that providing mysql with an explicit empty host via runtime config fails.
        let config = HeliosRuntimeConfig(
            mysql: MySQLConfig(host: "", username: "u", password: "p", database: "d")
        )
        XCTAssertThrowsError(try config.validate()) { error in
            let desc = String(describing: error)
            XCTAssertTrue(desc.contains("mysql.host"), "Expected mysql.host error, got: \(desc)")
        }
    }

    func testValidationFailsOnInvalidPort() throws {
        let config = HeliosRuntimeConfig(
            environment: EnvironmentConfig(port: 99999),
            mysql: MySQLConfig(host: "db", username: "u", password: "p", database: "d")
        )
        XCTAssertThrowsError(try config.validate()) { error in
            let desc = String(describing: error)
            XCTAssertTrue(desc.contains("environment.port") || desc.contains("port"), "Expected port error, got: \(desc)")
        }
    }

    func testValidationFailsOnNoConfigFile() throws {
        // With the new optional storage model, missing config files no longer cause errors.
        // A default HeliosRuntimeConfig with no storage is produced.
        let dir = NSTemporaryDirectory() + "helios-test-empty-\(UUID().uuidString)/"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let runtime = try HeliosConfigLoader.loadRuntime(configDir: dir)
        XCTAssertNil(runtime.mysql)
        XCTAssertNil(runtime.redis)
    }

    // MARK: - HeliosAppConfig facade (legacy)

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

    // MARK: - P0: BootstrapPhase + BootstrapConfig

    func testBootstrapConfigDefaultContainsAllPhases() {
        let config = BootstrapConfig.default
        for phase in BootstrapPhase.allCases {
            XCTAssertTrue(config.isEnabled(phase), "Default config should enable \(phase)")
        }
    }

    func testBootstrapConfigMinimal() {
        let config = BootstrapConfig.minimal
        XCTAssertTrue(config.isEnabled(.loadConfiguration))
        XCTAssertTrue(config.isEnabled(.prepareResources))
        XCTAssertFalse(config.isEnabled(.registerMiddleware))
        XCTAssertFalse(config.isEnabled(.registerRoutes))
        XCTAssertFalse(config.isEnabled(.startBackgroundSystems))
    }

    func testBootstrapConfigWebOnly() {
        let config = BootstrapConfig.webOnly
        XCTAssertTrue(config.isEnabled(.initializeServices))
        XCTAssertTrue(config.isEnabled(.registerMiddleware))
        XCTAssertTrue(config.isEnabled(.registerRoutes))
        XCTAssertFalse(config.isEnabled(.startBackgroundSystems))
    }

    func testBootstrapConfigWorkerOnly() {
        let config = BootstrapConfig.workerOnly
        XCTAssertTrue(config.isEnabled(.initializeServices))
        XCTAssertTrue(config.isEnabled(.startBackgroundSystems))
        XCTAssertFalse(config.isEnabled(.registerRoutes))
        XCTAssertFalse(config.isEnabled(.registerMiddleware))
    }

    func testBootstrapConfigCustom() {
        let config = BootstrapConfig(enabledPhases: [.loadConfiguration, .registerRoutes])
        XCTAssertTrue(config.isEnabled(.loadConfiguration))
        XCTAssertTrue(config.isEnabled(.registerRoutes))
        XCTAssertFalse(config.isEnabled(.initializeServices))
        XCTAssertFalse(config.isEnabled(.startBackgroundSystems))
    }

    func testBootstrapPhaseRawValues() {
        XCTAssertEqual(BootstrapPhase.loadConfiguration.rawValue, "loadConfiguration")
        XCTAssertEqual(BootstrapPhase.startBackgroundSystems.rawValue, "startBackgroundSystems")
        XCTAssertEqual(BootstrapPhase(rawValue: "registerRoutes"), .registerRoutes)
        XCTAssertNil(BootstrapPhase(rawValue: "nonExistent"))
    }

    // MARK: - P1: EnvironmentConfig

    func testEnvironmentConfigDefaults() {
        let env = EnvironmentConfig()
        XCTAssertEqual(env.host, "0.0.0.0")
        XCTAssertEqual(env.port, 8080)
        XCTAssertEqual(env.profile, .development)
        XCTAssertFalse(env.failFast)  // development defaults to false
    }

    func testEnvironmentConfigProductionFailFast() {
        let env = EnvironmentConfig(profile: .production)
        XCTAssertTrue(env.failFast)  // production defaults to true
    }

    func testEnvironmentConfigCustomFailFast() {
        let env = EnvironmentConfig(profile: .production, failFast: false)
        XCTAssertFalse(env.failFast)  // explicit override
    }

    func testEnvironmentProfileRawValues() {
        XCTAssertEqual(EnvironmentProfile.production.rawValue, "production")
        XCTAssertEqual(EnvironmentProfile.development.rawValue, "development")
        XCTAssertEqual(EnvironmentProfile.test.rawValue, "test")
        XCTAssertEqual(EnvironmentProfile(rawValue: "test"), .test)
        XCTAssertNil(EnvironmentProfile(rawValue: "staging"))
    }

    // MARK: - P1: HeliosRuntimeConfig

    func testRuntimeConfigDefaults() {
        let config = HeliosRuntimeConfig()
        XCTAssertNil(config.mysql)
        XCTAssertNil(config.redis)
        XCTAssertFalse(config.hasStorage)
        XCTAssertFalse(config.hasRedis)
    }

    func testRuntimeConfigWithStorage() {
        let mysql = MySQLConfig(host: "db", username: "u", password: "p", database: "d")
        let redis = RedisConfig(host: "redis", port: 6379)
        let config = HeliosRuntimeConfig(mysql: mysql, redis: redis)
        XCTAssertTrue(config.hasStorage)
        XCTAssertTrue(config.hasRedis)
        XCTAssertEqual(config.mysql?.host, "db")
        XCTAssertEqual(config.redis?.port, 6379)
    }

    func testRuntimeConfigMinimalPreset() {
        let config = HeliosRuntimeConfig.minimal
        XCTAssertEqual(config.environment.profile, .development)
        XCTAssertTrue(config.bootstrap.isEnabled(.loadConfiguration))
        XCTAssertFalse(config.bootstrap.isEnabled(.startBackgroundSystems))
        XCTAssertNil(config.mysql)
    }

    func testRuntimeConfigTestingPreset() {
        let config = HeliosRuntimeConfig.testing
        XCTAssertEqual(config.environment.profile, .test)
        XCTAssertFalse(config.features.enableQueues)
        XCTAssertFalse(config.features.serveLeaf)
        XCTAssertFalse(config.features.autoMigrate)
    }

    func testRuntimeConfigValidationPortRange() {
        let config = HeliosRuntimeConfig(
            environment: EnvironmentConfig(port: 99999)
        )
        XCTAssertThrowsError(try config.validate()) { error in
            let desc = String(describing: error)
            XCTAssertTrue(desc.contains("environment.port"), "Expected port error, got: \(desc)")
        }
    }

    func testRuntimeConfigValidationMySQLRequired() {
        let config = HeliosRuntimeConfig(
            mysql: MySQLConfig(host: "", username: "", password: "", database: "")
        )
        XCTAssertThrowsError(try config.validate()) { error in
            let desc = String(describing: error)
            XCTAssertTrue(desc.contains("mysql.host"), "Expected mysql.host error, got: \(desc)")
        }
    }

    func testRuntimeConfigProductionSafety() {
        let config = HeliosRuntimeConfig(
            environment: EnvironmentConfig(profile: .production),
            mysql: MySQLConfig(host: "db", username: "u", password: "p", database: "d", tls: .disable),
            features: FeatureFlags(autoMigrate: true)
        )
        XCTAssertThrowsError(try config.validate()) { error in
            let desc = String(describing: error)
            XCTAssertTrue(desc.contains("autoMigrate") || desc.contains("tls"), "Expected production safety error, got: \(desc)")
        }
    }

    func testRuntimeConfigNoStoragePassesValidation() throws {
        let config = HeliosRuntimeConfig(
            environment: EnvironmentConfig(profile: .development)
        )
        // No mysql/redis set, no validation errors expected
        XCTAssertNoThrow(try config.validate())
    }

    // MARK: - P1: HeliosRuntimeConfig loaded from file

    func testRuntimeConfigLoaderFromFile() throws {
        let dir = try makeTempConfigDir(files: [
            "base.json": """
            {
                "environment": { "host": "127.0.0.1", "port": 9000 },
                "mysql": { "host": "rdb", "username": "admin", "password": "pw", "database": "app" }
            }
            """
        ])
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let config = try HeliosRuntimeConfig.load(configDir: dir)
        XCTAssertEqual(config.environment.host, "127.0.0.1")
        XCTAssertEqual(config.environment.port, 9000)
        XCTAssertEqual(config.mysql?.host, "rdb")
        XCTAssertEqual(config.mysql?.username, "admin")
    }

    func testRuntimeConfigLegacyServerKeyFallback() throws {
        // "server" key should fall back for host/port in runtime loader
        let dir = try makeTempConfigDir(files: [
            "base.json": """
            {
                "server": { "host": "srv-host", "port": 4000 }
            }
            """
        ])
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let config = try HeliosRuntimeConfig.load(configDir: dir)
        XCTAssertEqual(config.environment.host, "srv-host")
        XCTAssertEqual(config.environment.port, 4000)
    }

    // MARK: - P1: asLegacyConfig bridge

    func testAsLegacyConfigBridge() {
        let runtime = HeliosRuntimeConfig(
            environment: EnvironmentConfig(host: "bridge-host", port: 7777),
            mysql: MySQLConfig(host: "mydb", username: "u", password: "p", database: "d"),
            redis: RedisConfig(host: "myredis", port: 6379)
        )
        let legacy = runtime.asLegacyConfig()
        XCTAssertEqual(legacy.server.host, "bridge-host")
        XCTAssertEqual(legacy.server.port, 7777)
        XCTAssertEqual(legacy.mysql.host, "mydb")
        XCTAssertEqual(legacy.redis.host, "myredis")
    }

    func testAsLegacyConfigWithNoStorageDefaults() {
        let runtime = HeliosRuntimeConfig(
            environment: EnvironmentConfig(host: "h", port: 1)
        )
        let legacy = runtime.asLegacyConfig()
        // mysql/redis are nil → bridged to defaults
        XCTAssertEqual(legacy.mysql.host, "")
        XCTAssertEqual(legacy.redis.host, "127.0.0.1")
    }

    // MARK: - P2: ConfigSource

    func testConfigSourceInline() throws {
        let source = ConfigSource.inline(.object(["server": .object(["port": .int(5000)])]))
        let result = try ConfigSourceLoader.load(source)
        let serverDict = result?["server"] as? [String: Any]
        XCTAssertEqual(serverDict?["port"] as? Int, 5000)
    }

    func testConfigSourceOverride() throws {
        let source = ConfigSource.override(.object(["key": .string("value")]))
        let result = try ConfigSourceLoader.load(source)
        XCTAssertEqual(result?["key"] as? String, "value")
    }

    func testConfigSourceFileNotFound() throws {
        let source = ConfigSource.file(path: "/nonexistent/config.json")
        let result = try ConfigSourceLoader.load(source)
        XCTAssertNil(result)
    }

    func testConfigSourceFile() throws {
        let dir = try makeTempConfigDir(files: [
            "test.json": """
            { "hello": "world", "num": 42 }
            """
        ])
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let source = ConfigSource.file(path: dir + "test.json")
        let result = try ConfigSourceLoader.load(source)
        XCTAssertEqual(result?["hello"] as? String, "world")
        XCTAssertEqual(result?["num"] as? Int, 42)
    }

    func testConfigSourceRelativeFile() throws {
        let dir = try makeTempConfigDir(files: [
            "relative.json": """
            { "flag": true }
            """
        ])
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let source = ConfigSource.file(path: "relative.json")
        let result = try ConfigSourceLoader.load(source, configDir: dir)
        XCTAssertEqual(result?["flag"] as? Bool, true)
    }

    func testLoadRuntimeFromSources() throws {
        let sources: [ConfigSource] = [
            .inline(.object([
                "environment": .object(["host": .string("inline-host"), "port": .int(3333)])
            ])),
            .override(.object([
                "environment": .object(["port": .int(9999)])  // override wins
            ]))
        ]
        let config = try HeliosConfigLoader.loadRuntime(sources: sources)
        XCTAssertEqual(config.environment.host, "inline-host")
        XCTAssertEqual(config.environment.port, 9999)
    }

    func testLoadRuntimeSourcesMergeOrder() throws {
        let sources: [ConfigSource] = [
            .inline(.object(["environment": .object(["port": .int(1111)])])),
            .inline(.object(["environment": .object(["port": .int(2222)])])),  // later wins
        ]
        let config = try HeliosConfigLoader.loadRuntime(sources: sources)
        XCTAssertEqual(config.environment.port, 2222)
    }

    // MARK: - P3: ResourceConfig

    func testResourceConfigDerived() {
        let rc = ResourceConfig.derived(from: "/app/")
        XCTAssertEqual(rc.path(for: .workspace), "/app/")
        XCTAssertEqual(rc.path(for: .publicDir), "/app/Public/")
        XCTAssertEqual(rc.path(for: .resources), "/app/Resources/")
        XCTAssertEqual(rc.path(for: .views), "/app/Resources/Views/")
        XCTAssertEqual(rc.path(for: .config), "/app/Config/")
    }

    func testResourceConfigDerivedWithoutTrailingSlash() {
        let rc = ResourceConfig.derived(from: "/app")
        XCTAssertEqual(rc.path(for: .workspace), "/app/")
        XCTAssertEqual(rc.path(for: .publicDir), "/app/Public/")
    }

    func testResourceKeyRawValues() {
        XCTAssertEqual(ResourceKey.workspace.rawValue, "workspace")
        XCTAssertEqual(ResourceKey.publicDir.rawValue, "public")
        XCTAssertEqual(ResourceKey.resources.rawValue, "resources")
        XCTAssertEqual(ResourceKey.views.rawValue, "views")
        XCTAssertEqual(ResourceKey.config.rawValue, "config")
        XCTAssertEqual(ResourceKey.custom("uploads").rawValue, "uploads")
    }

    func testResourceKeyRoundTrip() {
        XCTAssertEqual(ResourceKey(rawValue: "public"), .publicDir)
        XCTAssertEqual(ResourceKey(rawValue: "custom-key"), .custom("custom-key"))
    }

    func testResourceConfigCustomPath() {
        let rc = ResourceConfig(paths: [
            .workspace: "/root/",
            .custom("uploads"): "/root/Uploads/"
        ])
        XCTAssertEqual(rc.path(for: .custom("uploads")), "/root/Uploads/")
        XCTAssertNil(rc.path(for: .views))
    }

    func testResourceConfigValidationPass() throws {
        let rc = ResourceConfig(
            paths: [.workspace: "/app/", .config: "/app/Config/"],
            requiredKeys: [.workspace, .config]
        )
        XCTAssertNoThrow(try rc.validate())
    }

    func testResourceConfigValidationFail() {
        let rc = ResourceConfig(
            paths: [.workspace: "/app/"],
            requiredKeys: [.workspace, .config, .views]
        )
        XCTAssertThrowsError(try rc.validate()) { error in
            let desc = String(describing: error)
            XCTAssertTrue(desc.contains("config") || desc.contains("views"), "Expected missing key error, got: \(desc)")
        }
    }

    // MARK: - P4: ExtensionConfig

    func testExtensionConfigEmpty() {
        let ext = ExtensionConfig.empty
        XCTAssertTrue(ext.descriptors.isEmpty)
        XCTAssertTrue(ext.enabled.isEmpty)
    }

    func testExtensionConfigEnabledFilter() {
        let ext = ExtensionConfig(descriptors: [
            ExtensionDescriptor(key: "auth", enabled: true, kind: .service),
            ExtensionDescriptor(key: "legacy", enabled: false, kind: .middleware),
            ExtensionDescriptor(key: "payments", enabled: true, kind: .routeProvider)
        ])
        XCTAssertEqual(ext.enabled.count, 2)
        XCTAssertEqual(ext.enabled.map(\.key).sorted(), ["auth", "payments"])
    }

    func testExtensionConfigFilterByKind() {
        let ext = ExtensionConfig(descriptors: [
            ExtensionDescriptor(key: "db", enabled: true, kind: .storage),
            ExtensionDescriptor(key: "cache", enabled: true, kind: .storage),
            ExtensionDescriptor(key: "auth", enabled: true, kind: .service),
        ])
        let storageExt = ext.descriptors(ofKind: .storage)
        XCTAssertEqual(storageExt.count, 2)
        let serviceExt = ext.descriptors(ofKind: .service)
        XCTAssertEqual(serviceExt.count, 1)
    }

    func testExtensionConfigDescriptorLookup() {
        let ext = ExtensionConfig(descriptors: [
            ExtensionDescriptor(key: "oauth", enabled: true, kind: .service, config: .bool(true))
        ])
        let desc = ext.descriptor(forKey: "oauth")
        XCTAssertNotNil(desc)
        XCTAssertEqual(desc?.key, "oauth")
        XCTAssertEqual(desc?.config?.boolValue, true)
        XCTAssertNil(ext.descriptor(forKey: "unknown"))
    }

    func testExtensionDescriptorDefaultEnabled() {
        let desc = ExtensionDescriptor(key: "test", kind: .timer)
        XCTAssertTrue(desc.enabled)
    }

    func testExtensionKindAllCases() {
        XCTAssertEqual(ExtensionKind.allCases.count, 6)
        XCTAssertTrue(ExtensionKind.allCases.contains(.service))
        XCTAssertTrue(ExtensionKind.allCases.contains(.storage))
    }

    // MARK: - JSONValue (used in ConfigSource + ExtensionConfig)

    func testJSONValueAccessors() {
        let b: JSONValue = true
        XCTAssertEqual(b.boolValue, true)
        XCTAssertNil(b.intValue)

        let i: JSONValue = 42
        XCTAssertEqual(i.intValue, 42)
        XCTAssertEqual(i.doubleValue, 42.0)

        let d: JSONValue = 3.14
        XCTAssertEqual(d.doubleValue, 3.14)
        XCTAssertEqual(d.intValue, 3)

        let s: JSONValue = "hello"
        XCTAssertEqual(s.stringValue, "hello")

        let n: JSONValue = nil
        XCTAssertTrue(n.isNull)

        let a: JSONValue = [1, 2, 3]
        XCTAssertEqual(a.arrayValue?.count, 3)

        let o: JSONValue = ["x": 1]
        XCTAssertEqual(o.objectValue?["x"]?.intValue, 1)
        XCTAssertEqual(o["x"]?.intValue, 1)
        XCTAssertEqual(a[0]?.intValue, 1)
    }

    func testJSONValueCodableRoundTrip() throws {
        let original: JSONValue = [
            "name": "helios",
            "version": 2,
            "enabled": true,
            "tags": ["swift", "vapor"],
            "extra": nil
        ]
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - HeliosAppConfig (new runtime path)

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
        // patchResources should derive default paths
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
