//
//  ExtensionConfigTests.swift
//  HeliosTests
//
//  Tests for ExtensionConfig, ExtensionDescriptor, ExtensionKind, and JSONValue.
//

import XCTest
@testable import Helios

final class ExtensionConfigTests: XCTestCase {

    // MARK: - JSONValue

    func testJSONValueNullCoding() throws {
        let value: JSONValue = .null
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, .null)
        XCTAssertTrue(decoded.isNull)
    }

    func testJSONValueBoolCoding() throws {
        for bool in [true, false] {
            let value = JSONValue.bool(bool)
            let data = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
            XCTAssertEqual(decoded, value)
            XCTAssertEqual(decoded.boolValue, bool)
        }
    }

    func testJSONValueIntCoding() throws {
        let value = JSONValue.int(42)
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, value)
        XCTAssertEqual(decoded.intValue, 42)
    }

    func testJSONValueDoubleCoding() throws {
        let value = JSONValue.double(3.14)
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, value)
        XCTAssertNotNil(decoded.doubleValue)
    }

    func testJSONValueStringCoding() throws {
        let value = JSONValue.string("hello")
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, value)
        XCTAssertEqual(decoded.stringValue, "hello")
    }

    func testJSONValueArrayCoding() throws {
        let value = JSONValue.array([.int(1), .string("two"), .bool(true)])
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, value)
        XCTAssertEqual(decoded.arrayValue?.count, 3)
    }

    func testJSONValueObjectCoding() throws {
        let value = JSONValue.object(["key": .string("val"), "num": .int(99)])
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, value)
        XCTAssertEqual(decoded["key"]?.stringValue, "val")
        XCTAssertEqual(decoded["num"]?.intValue, 99)
    }

    func testJSONValueNestedObjectCoding() throws {
        let value: JSONValue = .object([
            "server": .object([
                "host": .string("localhost"),
                "port": .int(8080),
            ]),
            "enabled": .bool(true),
        ])
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded["server"]?["host"]?.stringValue, "localhost")
        XCTAssertEqual(decoded["server"]?["port"]?.intValue, 8080)
        XCTAssertEqual(decoded["enabled"]?.boolValue, true)
    }

    func testJSONValueLiterals() {
        let nilVal: JSONValue = nil
        let boolVal: JSONValue = true
        let intVal: JSONValue = 42
        let floatVal: JSONValue = 3.14
        let stringVal: JSONValue = "hello"
        let arrayVal: JSONValue = [1, 2, 3]
        let objectVal: JSONValue = ["key": "value"]

        XCTAssertTrue(nilVal.isNull)
        XCTAssertEqual(boolVal.boolValue, true)
        XCTAssertEqual(intVal.intValue, 42)
        XCTAssertNotNil(floatVal.doubleValue)
        XCTAssertEqual(stringVal.stringValue, "hello")
        XCTAssertEqual(arrayVal.arrayValue?.count, 3)
        XCTAssertEqual(objectVal["key"]?.stringValue, "value")
    }

    func testJSONValueSubscriptArray() {
        let value: JSONValue = [10, 20, 30]
        XCTAssertEqual(value[0]?.intValue, 10)
        XCTAssertEqual(value[1]?.intValue, 20)
        XCTAssertEqual(value[2]?.intValue, 30)
        XCTAssertNil(value[3])
    }

    func testIntToDoubleConversion() {
        let value = JSONValue.int(5)
        XCTAssertEqual(value.doubleValue, 5.0)
    }

    func testDoubleToIntConversion() {
        let value = JSONValue.double(7.0)
        XCTAssertEqual(value.intValue, 7)
    }

    // MARK: - ExtensionKind

    func testExtensionKindAllCases() {
        XCTAssertEqual(ExtensionKind.allCases.count, 6)
    }

    func testExtensionKindRawValues() {
        XCTAssertEqual(ExtensionKind.service.rawValue, "service")
        XCTAssertEqual(ExtensionKind.middleware.rawValue, "middleware")
        XCTAssertEqual(ExtensionKind.routeProvider.rawValue, "routeProvider")
        XCTAssertEqual(ExtensionKind.backgroundTask.rawValue, "backgroundTask")
        XCTAssertEqual(ExtensionKind.timer.rawValue, "timer")
        XCTAssertEqual(ExtensionKind.storage.rawValue, "storage")
    }

    func testExtensionKindCodable() throws {
        for kind in ExtensionKind.allCases {
            let data = try JSONEncoder().encode(kind)
            let decoded = try JSONDecoder().decode(ExtensionKind.self, from: data)
            XCTAssertEqual(decoded, kind)
        }
    }

    // MARK: - ExtensionDescriptor

    func testDescriptorDefaults() {
        let descriptor = ExtensionDescriptor(key: "payments", kind: .service)
        XCTAssertEqual(descriptor.key, "payments")
        XCTAssertTrue(descriptor.enabled)
        XCTAssertEqual(descriptor.kind, .service)
        XCTAssertNil(descriptor.config)
    }

    func testDescriptorDisabled() {
        let descriptor = ExtensionDescriptor(key: "feature-x", enabled: false, kind: .middleware)
        XCTAssertFalse(descriptor.enabled)
    }

    func testDescriptorWithConfig() {
        let config: JSONValue = .object(["url": .string("https://api.example.com")])
        let descriptor = ExtensionDescriptor(key: "oauth", kind: .service, config: config)
        XCTAssertEqual(descriptor.config?["url"]?.stringValue, "https://api.example.com")
    }

    func testDescriptorCodable() throws {
        let descriptor = ExtensionDescriptor(
            key: "my-ext",
            enabled: true,
            kind: .timer,
            config: .object(["interval": .int(60)])
        )
        let data = try JSONEncoder().encode(descriptor)
        let decoded = try JSONDecoder().decode(ExtensionDescriptor.self, from: data)
        XCTAssertEqual(decoded.key, descriptor.key)
        XCTAssertEqual(decoded.enabled, descriptor.enabled)
        XCTAssertEqual(decoded.kind, descriptor.kind)
        XCTAssertEqual(decoded.config?["interval"]?.intValue, 60)
    }

    // MARK: - ExtensionConfig

    func testEmptyRegistry() {
        let config = ExtensionConfig.empty
        XCTAssertTrue(config.descriptors.isEmpty)
        XCTAssertTrue(config.enabled.isEmpty)
    }

    func testEnabledFiltering() {
        let config = ExtensionConfig(descriptors: [
            ExtensionDescriptor(key: "a", enabled: true, kind: .service),
            ExtensionDescriptor(key: "b", enabled: false, kind: .middleware),
            ExtensionDescriptor(key: "c", enabled: true, kind: .timer),
        ])
        let enabled = config.enabled
        XCTAssertEqual(enabled.count, 2)
        XCTAssertTrue(enabled.contains { $0.key == "a" })
        XCTAssertTrue(enabled.contains { $0.key == "c" })
    }

    func testDescriptorsOfKind() {
        let config = ExtensionConfig(descriptors: [
            ExtensionDescriptor(key: "a", kind: .service),
            ExtensionDescriptor(key: "b", kind: .middleware),
            ExtensionDescriptor(key: "c", kind: .service),
        ])
        let services = config.descriptors(ofKind: .service)
        XCTAssertEqual(services.count, 2)
        XCTAssertTrue(services.allSatisfy { $0.kind == .service })
    }

    func testDescriptorForKey() {
        let config = ExtensionConfig(descriptors: [
            ExtensionDescriptor(key: "auth", kind: .middleware),
            ExtensionDescriptor(key: "cache", kind: .storage),
        ])
        XCTAssertNotNil(config.descriptor(forKey: "auth"))
        XCTAssertNil(config.descriptor(forKey: "missing"))
    }

    func testExtensionConfigCodable() throws {
        let config = ExtensionConfig(descriptors: [
            ExtensionDescriptor(key: "x", enabled: true, kind: .routeProvider),
        ])
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ExtensionConfig.self, from: data)
        XCTAssertEqual(decoded.descriptors.count, 1)
        XCTAssertEqual(decoded.descriptors[0].key, "x")
    }
}
