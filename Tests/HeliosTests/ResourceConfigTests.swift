//
//  ResourceConfigTests.swift
//  HeliosTests
//
//  Tests for ResourceKey, ResourceConfig, and validation.
//

import XCTest
@testable import Helios

final class ResourceConfigTests: XCTestCase {

    // MARK: - ResourceKey

    func testWellKnownKeyRawValues() {
        XCTAssertEqual(ResourceKey.workspace.rawValue, "workspace")
        XCTAssertEqual(ResourceKey.publicDir.rawValue, "public")
        XCTAssertEqual(ResourceKey.resources.rawValue, "resources")
        XCTAssertEqual(ResourceKey.views.rawValue, "views")
        XCTAssertEqual(ResourceKey.config.rawValue, "config")
    }

    func testCustomKeyRawValue() {
        XCTAssertEqual(ResourceKey.custom("uploads").rawValue, "uploads")
        XCTAssertEqual(ResourceKey.custom("cache").rawValue, "cache")
    }

    func testKeyInitFromRawValue() {
        XCTAssertEqual(ResourceKey(rawValue: "workspace"), .workspace)
        XCTAssertEqual(ResourceKey(rawValue: "public"), .publicDir)
        XCTAssertEqual(ResourceKey(rawValue: "resources"), .resources)
        XCTAssertEqual(ResourceKey(rawValue: "views"), .views)
        XCTAssertEqual(ResourceKey(rawValue: "config"), .config)
        XCTAssertEqual(ResourceKey(rawValue: "custom_key"), .custom("custom_key"))
    }

    func testKeyHashability() {
        var set: Set<ResourceKey> = [.workspace, .publicDir, .custom("foo")]
        XCTAssertTrue(set.contains(.workspace))
        XCTAssertTrue(set.contains(.publicDir))
        XCTAssertTrue(set.contains(.custom("foo")))
        set.insert(.custom("foo"))  // duplicate
        XCTAssertEqual(set.count, 3)
    }

    func testKeyCodableRoundTrip() throws {
        let keys: [ResourceKey] = [.workspace, .publicDir, .resources, .views, .config, .custom("my_key")]
        for key in keys {
            let data = try JSONEncoder().encode(key)
            let decoded = try JSONDecoder().decode(ResourceKey.self, from: data)
            XCTAssertEqual(decoded, key, "Round-trip failed for \(key)")
        }
    }

    func testKeyDescription() {
        XCTAssertEqual(ResourceKey.workspace.description, "workspace")
        XCTAssertEqual(ResourceKey.publicDir.description, "public")
        XCTAssertEqual(ResourceKey.custom("foo").description, "foo")
    }

    // MARK: - ResourceConfig

    func testEmptyResourceConfig() {
        let config = ResourceConfig()
        XCTAssertTrue(config.paths.isEmpty)
        XCTAssertTrue(config.requiredKeys.isEmpty)
    }

    func testPathLookup() {
        let config = ResourceConfig(paths: [
            .workspace: "/app/",
            .publicDir: "/app/Public/",
        ])
        XCTAssertEqual(config.path(for: .workspace), "/app/")
        XCTAssertEqual(config.path(for: .publicDir), "/app/Public/")
        XCTAssertNil(config.path(for: .views))
    }

    func testDerivedFromWorkspace() {
        let config = ResourceConfig.derived(from: "/my/app")
        XCTAssertEqual(config.path(for: .workspace), "/my/app/")
        XCTAssertEqual(config.path(for: .publicDir), "/my/app/Public/")
        XCTAssertEqual(config.path(for: .resources), "/my/app/Resources/")
        XCTAssertEqual(config.path(for: .views), "/my/app/Resources/Views/")
        XCTAssertEqual(config.path(for: .config), "/my/app/Config/")
    }

    func testDerivedFromWorkspaceWithTrailingSlash() {
        let config = ResourceConfig.derived(from: "/my/app/")
        XCTAssertEqual(config.path(for: .workspace), "/my/app/")
        XCTAssertEqual(config.path(for: .config), "/my/app/Config/")
    }

    func testValidationPassesWhenAllRequiredKeysPresent() throws {
        let config = ResourceConfig(
            paths: [.workspace: "/app/", .config: "/app/Config/"],
            requiredKeys: [.workspace, .config]
        )
        XCTAssertNoThrow(try config.validate())
    }

    func testValidationFailsOnMissingRequiredKey() {
        let config = ResourceConfig(
            paths: [.workspace: "/app/"],
            requiredKeys: [.workspace, .config]
        )
        XCTAssertThrowsError(try config.validate()) { error in
            let desc = String(describing: error)
            XCTAssertTrue(desc.contains("config"), "Expected 'config' in error: \(desc)")
        }
    }

    func testValidationPassesWithNoRequiredKeys() throws {
        let config = ResourceConfig(paths: [:], requiredKeys: [])
        XCTAssertNoThrow(try config.validate())
    }

    func testCustomKeyInConfig() {
        let config = ResourceConfig(paths: [
            .custom("uploads"): "/var/uploads/",
        ])
        XCTAssertEqual(config.path(for: .custom("uploads")), "/var/uploads/")
        XCTAssertNil(config.path(for: .custom("other")))
    }

    func testCodableRoundTrip() throws {
        let config = ResourceConfig(
            paths: [
                .workspace: "/app/",
                .publicDir: "/app/Public/",
                .custom("data"): "/app/Data/",
            ],
            requiredKeys: [.workspace]
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ResourceConfig.self, from: data)
        XCTAssertEqual(decoded.path(for: .workspace), config.path(for: .workspace))
        XCTAssertEqual(decoded.path(for: .publicDir), config.path(for: .publicDir))
        XCTAssertEqual(decoded.path(for: .custom("data")), config.path(for: .custom("data")))
        XCTAssertTrue(decoded.requiredKeys.contains(.workspace))
    }
}
