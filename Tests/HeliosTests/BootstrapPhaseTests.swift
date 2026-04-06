//
//  BootstrapPhaseTests.swift
//  HeliosTests
//
//  Tests for BootstrapPhase enum, BootstrapConfig, and phase filtering.
//

import XCTest
@testable import Helios

final class BootstrapPhaseTests: XCTestCase {

    // MARK: - BootstrapPhase enum

    func testAllCasesCount() {
        // 7 phases as specified
        XCTAssertEqual(BootstrapPhase.allCases.count, 7)
    }

    func testAllCasesContainsExpectedPhases() {
        let all = Set(BootstrapPhase.allCases)
        XCTAssertTrue(all.contains(.loadConfiguration))
        XCTAssertTrue(all.contains(.prepareResources))
        XCTAssertTrue(all.contains(.registerExtensions))
        XCTAssertTrue(all.contains(.registerMiddleware))
        XCTAssertTrue(all.contains(.registerRoutes))
        XCTAssertTrue(all.contains(.initializeServices))
        XCTAssertTrue(all.contains(.startBackgroundSystems))
    }

    func testRawValues() {
        XCTAssertEqual(BootstrapPhase.loadConfiguration.rawValue, "loadConfiguration")
        XCTAssertEqual(BootstrapPhase.prepareResources.rawValue, "prepareResources")
        XCTAssertEqual(BootstrapPhase.registerExtensions.rawValue, "registerExtensions")
        XCTAssertEqual(BootstrapPhase.registerMiddleware.rawValue, "registerMiddleware")
        XCTAssertEqual(BootstrapPhase.registerRoutes.rawValue, "registerRoutes")
        XCTAssertEqual(BootstrapPhase.initializeServices.rawValue, "initializeServices")
        XCTAssertEqual(BootstrapPhase.startBackgroundSystems.rawValue, "startBackgroundSystems")
    }

    func testRawValueRoundTrip() {
        for phase in BootstrapPhase.allCases {
            XCTAssertEqual(BootstrapPhase(rawValue: phase.rawValue), phase)
        }
    }

    func testCodableRoundTrip() throws {
        for phase in BootstrapPhase.allCases {
            let data = try JSONEncoder().encode(phase)
            let decoded = try JSONDecoder().decode(BootstrapPhase.self, from: data)
            XCTAssertEqual(decoded, phase)
        }
    }

    // MARK: - BootstrapConfig

    func testDefaultConfigContainsAllPhases() {
        let config = BootstrapConfig.default
        XCTAssertEqual(config.enabledPhases.count, BootstrapPhase.allCases.count)
        for phase in BootstrapPhase.allCases {
            XCTAssertTrue(config.isEnabled(phase), "Expected \(phase) to be enabled in default config")
        }
    }

    func testMinimalConfigContainsOnlyLoadAndResources() {
        let config = BootstrapConfig.minimal
        XCTAssertTrue(config.isEnabled(.loadConfiguration))
        XCTAssertTrue(config.isEnabled(.prepareResources))
        XCTAssertFalse(config.isEnabled(.registerExtensions))
        XCTAssertFalse(config.isEnabled(.registerMiddleware))
        XCTAssertFalse(config.isEnabled(.registerRoutes))
        XCTAssertFalse(config.isEnabled(.initializeServices))
        XCTAssertFalse(config.isEnabled(.startBackgroundSystems))
    }

    func testWebOnlyConfigNoBackgroundSystems() {
        let config = BootstrapConfig.webOnly
        XCTAssertTrue(config.isEnabled(.registerRoutes))
        XCTAssertTrue(config.isEnabled(.registerMiddleware))
        XCTAssertTrue(config.isEnabled(.initializeServices))
        XCTAssertFalse(config.isEnabled(.startBackgroundSystems))
    }

    func testWorkerOnlyConfigNoRoutes() {
        let config = BootstrapConfig.workerOnly
        XCTAssertTrue(config.isEnabled(.initializeServices))
        XCTAssertTrue(config.isEnabled(.startBackgroundSystems))
        XCTAssertFalse(config.isEnabled(.registerRoutes))
        XCTAssertFalse(config.isEnabled(.registerMiddleware))
    }

    func testCustomPhaseSelection() {
        let config = BootstrapConfig(enabledPhases: [.registerMiddleware, .registerRoutes])
        XCTAssertFalse(config.isEnabled(.loadConfiguration))
        XCTAssertFalse(config.isEnabled(.initializeServices))
        XCTAssertTrue(config.isEnabled(.registerMiddleware))
        XCTAssertTrue(config.isEnabled(.registerRoutes))
    }

    func testEmptyPhaseSelection() {
        let config = BootstrapConfig(enabledPhases: [])
        for phase in BootstrapPhase.allCases {
            XCTAssertFalse(config.isEnabled(phase))
        }
    }

    func testBootstrapConfigCodableRoundTrip() throws {
        let config = BootstrapConfig(enabledPhases: [.registerRoutes, .registerMiddleware])
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(BootstrapConfig.self, from: data)
        XCTAssertEqual(decoded.enabledPhases, config.enabledPhases)
    }

    func testBootstrapConfigIsEnabled() {
        let config = BootstrapConfig(enabledPhases: [.loadConfiguration, .initializeServices])
        XCTAssertTrue(config.isEnabled(.loadConfiguration))
        XCTAssertTrue(config.isEnabled(.initializeServices))
        XCTAssertFalse(config.isEnabled(.registerRoutes))
        XCTAssertFalse(config.isEnabled(.startBackgroundSystems))
    }
}
