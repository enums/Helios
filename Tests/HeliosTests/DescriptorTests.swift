//
//  DescriptorTests.swift
//  HeliosTests
//
//  Tests for descriptor/provider extension point API (#16).
//

import XCTest
import XCTVapor
import Vapor
import Queues
@testable import Helios

final class DescriptorTests: XCTestCase {

    // MARK: - Route descriptors

    func testRouteDescriptorRegistration() throws {
        let delegate = TestDelegate()
        delegate.routeDescriptorList = [
            HeliosRouteDescriptor(path: "desc-echo", method: .GET, handler: EchoHandler.self)
        ]

        let app = try makeTestApp(delegate: delegate)
        defer { app.shutdown() }

        try app.test(.GET, "desc-echo") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "echo-ok")
        }
    }

    func testRouteDescriptorWithClosureFactory() throws {
        let delegate = TestDelegate()
        delegate.routeDescriptorList = [
            HeliosRouteDescriptor(path: "closure-echo", method: .POST) { _ in
                EchoHandler()
            }
        ]

        let app = try makeTestApp(delegate: delegate)
        defer { app.shutdown() }

        try app.test(.POST, "closure-echo") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "echo-ok")
        }
    }

    func testRouteDescriptorTakesPriorityOverLegacy() throws {
        let delegate = TestDelegate()
        // Legacy route (should be ignored when descriptors are present)
        delegate.routeTable = ["legacy": [.GET: EchoHandler.builder]]
        // Descriptor route
        delegate.routeDescriptorList = [
            HeliosRouteDescriptor(path: "desc-only", method: .GET, handler: EchoHandler.self)
        ]

        let app = try makeTestApp(delegate: delegate)
        defer { app.shutdown() }

        // Descriptor route works
        try app.test(.GET, "desc-only") { res in
            XCTAssertEqual(res.status, .ok)
        }

        // Legacy route NOT registered (descriptors took priority)
        try app.test(.GET, "legacy") { res in
            XCTAssertEqual(res.status, .notFound)
        }
    }

    func testLegacyRoutesFallbackWhenNoDescriptors() throws {
        let delegate = TestDelegate()
        delegate.routeTable = ["legacy-echo": [.GET: EchoHandler.builder]]
        // No descriptors set → falls back to legacy

        let app = try makeTestApp(delegate: delegate)
        defer { app.shutdown() }

        try app.test(.GET, "legacy-echo") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "echo-ok")
        }
    }

    // MARK: - Filter descriptors

    func testFilterDescriptorRegistration() throws {
        let delegate = TestDelegate()
        delegate.routeDescriptorList = [
            HeliosRouteDescriptor(path: "filtered", method: .GET, handler: EchoHandler.self)
        ]
        delegate.filterDescriptorList = [
            HeliosFilterDescriptor(name: "TestHeader", filter: TestHeaderFilter.self)
        ]

        let app = try makeTestApp(delegate: delegate)
        defer { app.shutdown() }

        try app.test(.GET, "filtered") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.headers.first(name: "X-Helios-Test"), "filtered")
        }
    }

    func testFilterDescriptorTakesPriorityOverLegacy() throws {
        let delegate = TestDelegate()
        delegate.routeDescriptorList = [
            HeliosRouteDescriptor(path: "test", method: .GET, handler: EchoHandler.self)
        ]
        // Legacy filter adds X-Helios-Test header
        delegate.filterList = [TestHeaderFilter.builder]
        // Descriptor filter: a no-op filter that does NOT add X-Helios-Test
        delegate.filterDescriptorList = [
            HeliosFilterDescriptor(name: "NoOp") { _ in NoOpFilter() }
        ]

        let app = try makeTestApp(delegate: delegate)
        defer { app.shutdown() }

        try app.test(.GET, "test") { res in
            XCTAssertEqual(res.status, .ok)
            // Legacy filter should NOT have run (descriptor took priority)
            XCTAssertNil(res.headers.first(name: "X-Helios-Test"))
        }
    }

    // MARK: - Descriptor struct construction

    func testRouteDescriptorConvenienceInit() {
        let desc = HeliosRouteDescriptor(path: "api/hello", method: .GET, handler: EchoHandler.self)
        XCTAssertEqual(desc.path, "api/hello")
        XCTAssertEqual(desc.method, .GET)
    }

    func testFilterDescriptorConvenienceInit() {
        let desc = HeliosFilterDescriptor(filter: TestHeaderFilter.self)
        XCTAssertEqual(desc.name, "TestHeaderFilter")
    }

    func testFilterDescriptorCustomName() {
        let desc = HeliosFilterDescriptor(name: "MyFilter", filter: TestHeaderFilter.self)
        XCTAssertEqual(desc.name, "MyFilter")
    }

    func testTaskDescriptorConstruction() {
        let desc = HeliosTaskDescriptor(name: "test-task") { _ in
            StubTask()
        }
        XCTAssertEqual(desc.name, "test-task")
    }

    func testTimerDescriptorConstruction() {
        let desc = HeliosTimerDescriptor(name: "test-timer") { _ in
            StubTimer()
        }
        XCTAssertEqual(desc.name, "test-timer")
    }

    // MARK: - Delegate default returns empty descriptors

    func testDefaultDelegateReturnsEmptyDescriptors() {
        let delegate = TestDelegate()
        let app = Application(.testing)
        defer { app.shutdown() }
        let heliosApp = makeTestHeliosApp(app: app, delegate: delegate)

        XCTAssertTrue(delegate.routeDescriptors(app: heliosApp).isEmpty)
        XCTAssertTrue(delegate.filterDescriptors(app: heliosApp).isEmpty)
        XCTAssertTrue(delegate.taskDescriptors(app: heliosApp).isEmpty)
        XCTAssertTrue(delegate.timerDescriptors(app: heliosApp).isEmpty)
    }
}

// MARK: - Test Fixtures

private struct NoOpFilter: HeliosFilter {
    init() {}

    func filterResponse(request: Request, response: Response) async throws -> Response {
        return response
    }
}

private struct StubTask: HeliosTask {
    typealias Payload = String
    init() {}
    func dequeue(_ context: QueueContext, _ payload: String) async throws {}
}

private final class StubTimer: HeliosTimer {
    required init() {}
    func schedule(queue: Application.Queues) {}
    func run(context: QueueContext) async throws {}
}
