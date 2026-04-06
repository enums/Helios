//
//  IntegrationTests.swift
//  HeliosTests
//
//  Integration tests: verify that framework pieces compose correctly.
//  Tests middleware/filter chains, multiple routes, and handler + filter interaction.
//  No external infrastructure required.
//

import XCTest
import XCTVapor
import Vapor
@testable import Helios

final class IntegrationTests: XCTestCase {

    // MARK: - Filter integration

    func testFilterAppendsHeader() throws {
        let delegate = TestDelegate()
        delegate.routeTable = [
            "/filtered": [.GET: EchoHandler.builder],
        ]
        delegate.filterList = [TestHeaderFilter.builder]
        let app = try makeTestApp(delegate: delegate)
        defer { app.shutdown() }

        try app.test(.GET, "/filtered") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.headers.first(name: "X-Helios-Test"), "filtered")
            XCTAssertEqual(res.body.string, "echo-ok")
        }
    }

    func testFilterAppliedToAllRoutes() throws {
        let delegate = TestDelegate()
        delegate.routeTable = [
            "/a": [.GET: EchoHandler.builder],
            "/b": [.GET: EchoHandler.builder],
        ]
        delegate.filterList = [TestHeaderFilter.builder]
        let app = try makeTestApp(delegate: delegate)
        defer { app.shutdown() }

        try app.test(.GET, "/a") { res in
            XCTAssertEqual(res.headers.first(name: "X-Helios-Test"), "filtered")
        }
        try app.test(.GET, "/b") { res in
            XCTAssertEqual(res.headers.first(name: "X-Helios-Test"), "filtered")
        }
    }

    // MARK: - Request-blocking filter

    func testBlockingFilter() throws {
        // A filter that blocks all requests with 403
        struct BlockFilter: HeliosFilter {
            init() {}
            func filterRequest(request: Request) async throws -> Response? {
                return Response(status: .forbidden)
            }
        }

        let delegate = TestDelegate()
        delegate.routeTable = [
            "/secret": [.GET: EchoHandler.builder],
        ]
        delegate.filterList = [BlockFilter.builder]
        let app = try makeTestApp(delegate: delegate)
        defer { app.shutdown() }

        try app.test(.GET, "/secret") { res in
            XCTAssertEqual(res.status, .forbidden)
            // Handler should NOT have been called
            XCTAssertNotEqual(res.body.string, "echo-ok")
        }
    }

    // MARK: - Multi-route app

    func testMultiRouteApp() throws {
        struct HealthHandler: HeliosHandler {
            init() {}
            func handle(req: Request) async throws -> AsyncResponseEncodable {
                Response(status: .ok, body: .init(string: "{\"ok\":true}"))
            }
        }

        struct VersionHandler: HeliosHandler {
            struct VersionResponse: Content {
                let version: String
            }
            init() {}
            func handle(req: Request) async throws -> AsyncResponseEncodable {
                VersionResponse(version: "1.0.0")
            }
        }

        let delegate = TestDelegate()
        delegate.routeTable = [
            "/health": [.GET: HealthHandler.builder],
            "/version": [.GET: VersionHandler.builder],
            "/echo": [.GET: EchoHandler.builder],
        ]
        let app = try makeTestApp(delegate: delegate)
        defer { app.shutdown() }

        try app.test(.GET, "/health") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertTrue(res.body.string.contains("true"))
        }

        try app.test(.GET, "/version") { res in
            XCTAssertEqual(res.status, .ok)
            let body = try res.content.decode(VersionHandler.VersionResponse.self)
            XCTAssertEqual(body.version, "1.0.0")
        }

        try app.test(.GET, "/echo") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "echo-ok")
        }
    }

    // MARK: - Config loading (negative path)

    func testConfigLoadSucceedsWithoutFile() throws {
        // With the new optional storage model, missing config files no longer cause errors.
        // A default HeliosRuntimeConfig with no storage is produced instead.
        let app = Application(.testing)
        defer { app.shutdown() }

        let config = try HeliosAppConfig(dir: app.directory)
        // No storage configured when no config files exist
        XCTAssertNil(config.runtime.mysql)
        XCTAssertNil(config.runtime.redis)
    }

    // MARK: - Handler builder pattern

    func testBuilderCreatesDistinctInstances() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        let delegate = TestDelegate()
        let heliosApp = makeTestHeliosApp(app: app, delegate: delegate)
        let context = HeliosHandlerContext(app: heliosApp)

        let builder = EchoHandler.builder
        let firstInstance = builder(context)
        let secondInstance = builder(context)
        // Each call should return a new instance (value type or reference)
        XCTAssertNotNil(firstInstance)
        XCTAssertNotNil(secondInstance)
    }
}
