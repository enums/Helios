//
//  SmokeTests.swift
//  HeliosTests
//
//  Smoke tests: verify the most basic framework behaviors
//  without external infrastructure (no MySQL, no Redis).
//

import XCTest
import XCTVapor
@testable import Helios

final class SmokeTests: XCTestCase {

    // MARK: - Framework types compile and instantiate

    func testHandlerProtocolConformance() throws {
        // EchoHandler conforms to HeliosHandler and can be built via .builder
        let handler = EchoHandler.builder()
        XCTAssertNotNil(handler)
    }

    func testFilterProtocolConformance() throws {
        let filter = TestHeaderFilter.builder()
        XCTAssertNotNil(filter)
    }

    func testDelegateDefaultsAreEmpty() throws {
        // A minimal delegate with default implementations returns empty collections
        let delegate = TestDelegate()
        let app = Application(.testing)
        defer { app.shutdown() }
        let config = try? HeliosAppConfig(dir: app.directory)
        // Config may fail without config.json — that's expected.
        // We're testing that the delegate protocol defaults work.
        XCTAssertTrue(delegate.routeTable.isEmpty)
        XCTAssertTrue(delegate.filterList.isEmpty)
        XCTAssertTrue(delegate.modelList.isEmpty)
        XCTAssertTrue(delegate.timerList.isEmpty)
        _ = config // suppress unused warning
    }

    // MARK: - Minimal route registration

    func testSingleRouteResponds() throws {
        let delegate = TestDelegate()
        delegate.routeTable = [
            "/ping": [.GET: EchoHandler.builder],
        ]
        let app = try makeTestApp(delegate: delegate)
        defer { app.shutdown() }

        try app.test(.GET, "/ping") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "echo-ok")
        }
    }

    func testJsonHandlerReturnsValidJson() throws {
        let delegate = TestDelegate()
        delegate.routeTable = [
            "/api/hello": [.GET: JsonEchoHandler.builder],
        ]
        let app = try makeTestApp(delegate: delegate)
        defer { app.shutdown() }

        try app.test(.GET, "/api/hello") { res in
            XCTAssertEqual(res.status, .ok)
            let body = try res.content.decode(JsonEchoHandler.Payload.self)
            XCTAssertEqual(body.message, "hello from helios")
        }
    }

    func testUnregisteredRouteReturns404() throws {
        let delegate = TestDelegate()
        delegate.routeTable = [
            "/exists": [.GET: EchoHandler.builder],
        ]
        let app = try makeTestApp(delegate: delegate)
        defer { app.shutdown() }

        try app.test(.GET, "/does-not-exist") { res in
            XCTAssertEqual(res.status, .notFound)
        }
    }

    func testMultipleMethodsOnSameRoute() throws {
        let delegate = TestDelegate()
        delegate.routeTable = [
            "/multi": [
                .GET: EchoHandler.builder,
                .POST: EchoHandler.builder,
            ],
        ]
        let app = try makeTestApp(delegate: delegate)
        defer { app.shutdown() }

        try app.test(.GET, "/multi") { res in
            XCTAssertEqual(res.status, .ok)
        }
        try app.test(.POST, "/multi") { res in
            XCTAssertEqual(res.status, .ok)
        }
    }
}
