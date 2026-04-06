//
//  BootstrapWiringTests.swift
//  HeliosTests
//
//  Tests that HeliosApp.setup() actually respects BootstrapPhase selections.
//  Verifies phase-aware wiring: skipping phases, ResourceConfig validation,
//  ExtensionConfig filtering, and the new runtimeConfig factory.
//
//  No external infrastructure (MySQL/Redis) required.
//

import XCTest
import XCTVapor
import Vapor
@testable import Helios

final class BootstrapWiringTests: XCTestCase {

    // MARK: - Helpers

    /// Build a minimal runtime config that skips storage and background systems.
    private func testRuntime(
        bootstrap: BootstrapConfig = .webOnly,
        extensions: ExtensionConfig = .empty,
        resources: ResourceConfig = ResourceConfig()
    ) -> HeliosRuntimeConfig {
        HeliosRuntimeConfig(
            environment: EnvironmentConfig(profile: .test, host: "0.0.0.0", port: 8080),
            bootstrap: bootstrap,
            resources: resources,
            extensions: extensions,
            features: FeatureFlags(
                autoMigrate: false,
                serveLeaf: false,
                enableQueues: false,
                enableTimers: false,
                serveStaticFiles: false
            )
        )
    }

    /// Create a Vapor Application + HeliosApp for testing; caller must shut down.
    private func makeHelios(
        bootstrap: BootstrapConfig = .webOnly,
        extensions: ExtensionConfig = .empty,
        resources: ResourceConfig = ResourceConfig(),
        delegate: TestDelegate = TestDelegate()
    ) throws -> (Application, HeliosApp) {
        let vaporApp = Application(.testing)
        let runtime = testRuntime(bootstrap: bootstrap, extensions: extensions, resources: resources)
        let appConfig = HeliosAppConfig(workspacePath: "/tmp/helios-wiring-test/", runtime: runtime)
        let heliosApp = HeliosApp(app: vaporApp, config: appConfig, delegate: delegate)
        return (vaporApp, heliosApp)
    }

    // MARK: - P0: Phase-aware setup

    func testSetupWithAllPhasesDisabledIsNoop() throws {
        let (app, helios) = try makeHelios(bootstrap: BootstrapConfig(enabledPhases: []))
        defer { app.shutdown() }
        // No phases enabled — setup() must not throw and must be a no-op
        XCTAssertNoThrow(try helios.setup())
    }

    func testSetupWithOnlyLoadConfigurationPhase() throws {
        let (app, helios) = try makeHelios(
            bootstrap: BootstrapConfig(enabledPhases: [.loadConfiguration])
        )
        defer { app.shutdown() }
        // loadConfiguration calls runtime.validate(), which should pass for default test config
        XCTAssertNoThrow(try helios.setup())
    }

    func testSetupWithOnlyPrepareResourcesPhase() throws {
        let (app, helios) = try makeHelios(
            bootstrap: BootstrapConfig(enabledPhases: [.prepareResources])
        )
        defer { app.shutdown() }
        XCTAssertNoThrow(try helios.setup())
    }

    func testSetupWithOnlyRegisterExtensionsPhase() throws {
        let extensions = ExtensionConfig(descriptors: [
            ExtensionDescriptor(key: "auth", enabled: true, kind: .service),
            ExtensionDescriptor(key: "legacy", enabled: false, kind: .middleware),
        ])
        let (app, helios) = try makeHelios(
            bootstrap: BootstrapConfig(enabledPhases: [.registerExtensions]),
            extensions: extensions
        )
        defer { app.shutdown() }
        XCTAssertNoThrow(try helios.setup())
    }

    func testSetupMinimalPresetSkipsRoutes() throws {
        let delegate = TestDelegate()
        delegate.routeTable = ["/ping": [.GET: EchoHandler.builder]]

        let (app, helios) = try makeHelios(
            bootstrap: .minimal,
            delegate: delegate
        )
        defer { app.shutdown() }
        try helios.setup()

        // Routes should NOT be registered because .registerRoutes is disabled in .minimal
        try app.test(.GET, "/ping") { res in
            XCTAssertEqual(res.status, .notFound,
                "Expected 404: registerRoutes phase is disabled in .minimal bootstrap")
        }
    }

    func testSetupWebOnlyPresetRegistersRoutes() throws {
        let delegate = TestDelegate()
        delegate.routeDescriptorList = [
            HeliosRouteDescriptor(path: "wiring-ping", method: .GET, handler: EchoHandler.self)
        ]

        let (app, helios) = try makeHelios(
            bootstrap: .webOnly,
            delegate: delegate
        )
        defer { app.shutdown() }
        try helios.setup()

        try app.test(.GET, "wiring-ping") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "echo-ok")
        }
    }

    func testSetupRegistersMiddlewareWhenPhaseEnabled() throws {
        let delegate = TestDelegate()
        delegate.routeDescriptorList = [
            HeliosRouteDescriptor(path: "mw-test", method: .GET, handler: EchoHandler.self)
        ]
        delegate.filterDescriptorList = [
            HeliosFilterDescriptor(name: "TestHeader", filter: TestHeaderFilter.self)
        ]

        let (app, helios) = try makeHelios(
            bootstrap: BootstrapConfig(enabledPhases: [.registerMiddleware, .registerRoutes]),
            delegate: delegate
        )
        defer { app.shutdown() }
        try helios.setup()

        try app.test(.GET, "mw-test") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.headers.first(name: "X-Helios-Test"), "filtered")
        }
    }

    func testSetupSkipsMiddlewareWhenPhaseDisabled() throws {
        let delegate = TestDelegate()
        delegate.routeDescriptorList = [
            HeliosRouteDescriptor(path: "no-mw", method: .GET, handler: EchoHandler.self)
        ]
        delegate.filterDescriptorList = [
            HeliosFilterDescriptor(name: "TestHeader", filter: TestHeaderFilter.self)
        ]

        let (app, helios) = try makeHelios(
            // registerMiddleware is intentionally omitted
            bootstrap: BootstrapConfig(enabledPhases: [.registerRoutes]),
            delegate: delegate
        )
        defer { app.shutdown() }
        try helios.setup()

        try app.test(.GET, "no-mw") { res in
            XCTAssertEqual(res.status, .ok)
            // Middleware was NOT registered, so the header should be absent
            XCTAssertNil(res.headers.first(name: "X-Helios-Test"))
        }
    }

    // MARK: - P1: runtimeConfig factory

    func testCreateWithRuntimeConfigFactory() throws {
        let runtime = testRuntime(bootstrap: .webOnly)
        let delegate = TestDelegate()
        delegate.routeDescriptorList = [
            HeliosRouteDescriptor(path: "rt-factory", method: .GET, handler: EchoHandler.self)
        ]

        // Use the new runtimeConfig factory (no disk loading)
        var vaporEnv = try Environment.detect()
        try LoggingSystem.bootstrap(from: &vaporEnv)
        let vaporApp = Application(vaporEnv)
        defer { vaporApp.shutdown() }

        let appConfig = HeliosAppConfig(workspacePath: "/tmp/rt-factory/", runtime: runtime)
        let helios = HeliosApp(app: vaporApp, config: appConfig, delegate: delegate)
        try helios.setup()

        try vaporApp.test(.GET, "rt-factory") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "echo-ok")
        }
    }

    func testRuntimeConfigBakedIntoBoostrap() throws {
        let customBootstrap = BootstrapConfig(enabledPhases: [.registerRoutes])
        let runtime = testRuntime(bootstrap: customBootstrap)
        let appConfig = HeliosAppConfig(workspacePath: "/tmp/baked/", runtime: runtime)
        XCTAssertEqual(appConfig.runtime.bootstrap.enabledPhases, customBootstrap.enabledPhases)
    }

    // MARK: - P3: ResourceConfig validation during setup

    func testPrepareResourcesPhaseValidatesResourceConfig() throws {
        // A resource config with a required key that is not populated should fail validation.
        let strictResources = ResourceConfig(
            paths: [.workspace: "/tmp/"],
            requiredKeys: [.workspace, .config]  // .config path is missing
        )
        let runtime = testRuntime(
            bootstrap: BootstrapConfig(enabledPhases: [.prepareResources]),
            resources: strictResources
        )
        let vaporApp = Application(.testing)
        defer { vaporApp.shutdown() }

        let appConfig = HeliosAppConfig(workspacePath: "/tmp/", runtime: runtime)
        let helios = HeliosApp(app: vaporApp, config: appConfig, delegate: TestDelegate())

        // setup() should throw because .config key is missing
        XCTAssertThrowsError(try helios.setup()) { error in
            let desc = String(describing: error)
            XCTAssertTrue(desc.contains("config"), "Expected missing 'config' key error, got: \(desc)")
        }
    }

    func testPrepareResourcesPhasePassesWhenAllRequiredKeysPresent() throws {
        let resources = ResourceConfig(
            paths: [.workspace: "/tmp/", .config: "/tmp/Config/"],
            requiredKeys: [.workspace, .config]
        )
        let (app, helios) = try makeHelios(
            bootstrap: BootstrapConfig(enabledPhases: [.prepareResources]),
            resources: resources
        )
        defer { app.shutdown() }
        XCTAssertNoThrow(try helios.setup())
    }

    func testPrepareResourcesNotCalledWhenPhaseDisabled() throws {
        // Even if resources would fail validation, skipping the phase must not throw.
        let badResources = ResourceConfig(
            paths: [:],
            requiredKeys: [.workspace, .config, .views]
        )
        let (app, helios) = try makeHelios(
            // prepareResources deliberately excluded
            bootstrap: BootstrapConfig(enabledPhases: [.loadConfiguration]),
            resources: badResources
        )
        defer { app.shutdown() }
        XCTAssertNoThrow(try helios.setup())
    }

    // MARK: - P4: ExtensionConfig filtering during registerExtensions

    func testRegisterExtensionsPhaseFiltersDisabledExtensions() throws {
        // Only enabled descriptors are processed; disabled ones are logged and skipped.
        let extensions = ExtensionConfig(descriptors: [
            ExtensionDescriptor(key: "enabled-svc", enabled: true, kind: .service),
            ExtensionDescriptor(key: "disabled-svc", enabled: false, kind: .service),
        ])
        let (app, helios) = try makeHelios(
            bootstrap: BootstrapConfig(enabledPhases: [.registerExtensions]),
            extensions: extensions
        )
        defer { app.shutdown() }
        XCTAssertNoThrow(try helios.setup())

        // Verify the registry still correctly reports enabled vs all
        XCTAssertEqual(helios.config.runtime.extensions.enabled.count, 1)
        XCTAssertEqual(helios.config.runtime.extensions.enabled[0].key, "enabled-svc")
        XCTAssertEqual(helios.config.runtime.extensions.descriptors.count, 2)
    }

    func testRegisterExtensionsPhaseWithEmptyRegistryIsNoop() throws {
        let (app, helios) = try makeHelios(
            bootstrap: BootstrapConfig(enabledPhases: [.registerExtensions]),
            extensions: .empty
        )
        defer { app.shutdown() }
        XCTAssertNoThrow(try helios.setup())
    }

    func testRegisterExtensionsSkippedWhenPhaseDisabled() throws {
        // Even with a non-empty extension registry, skipping the phase must be safe.
        let extensions = ExtensionConfig(descriptors: [
            ExtensionDescriptor(key: "x", enabled: true, kind: .storage),
        ])
        let (app, helios) = try makeHelios(
            bootstrap: BootstrapConfig(enabledPhases: []),
            extensions: extensions
        )
        defer { app.shutdown() }
        XCTAssertNoThrow(try helios.setup())
    }

    // MARK: - P2: ConfigSource stored for introspection

    func testConfigSourcesStoredForIntrospection() throws {
        let sources: [ConfigSource] = [
            .inline(.object(["environment": .object(["port": .int(7654)])])),
        ]
        let loader = DefaultRuntimeConfigLoader()
        var config = try loader.load(sources: sources, configDir: nil)
        // Store sources for introspection (mirrors HeliosRuntimeConfig.load behaviour)
        config = HeliosRuntimeConfig(
            environment: config.environment,
            bootstrap: config.bootstrap,
            resources: config.resources,
            extensions: config.extensions,
            configSources: sources,
            mysql: config.mysql,
            redis: config.redis,
            features: config.features
        )
        XCTAssertEqual(config.environment.port, 7654)
        XCTAssertEqual(config.configSources.count, 1)
        if case .inline = config.configSources[0] {
            // Expected
        } else {
            XCTFail("Expected .inline source")
        }
    }

    func testLayeredSourcesMergeInOrder() throws {
        let sources: [ConfigSource] = [
            .inline(.object(["environment": .object(["host": .string("base"), "port": .int(1111)])])),
            .override(.object(["environment": .object(["host": .string("override")])])),
        ]
        let loader = DefaultRuntimeConfigLoader()
        let config = try loader.load(sources: sources, configDir: nil)
        XCTAssertEqual(config.environment.host, "override")
        XCTAssertEqual(config.environment.port, 1111)
    }
}
