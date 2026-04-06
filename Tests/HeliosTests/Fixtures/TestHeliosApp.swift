//
//  TestHeliosApp.swift
//  HeliosTests
//
//  Minimal test harness for Helios.
//  Provides a lightweight HeliosApp that does NOT require MySQL or Redis,
//  so tests can run locally without external infrastructure.
//

import Foundation
import Vapor
import XCTVapor
@testable import Helios

// MARK: - Minimal Test Delegate

/// A bare-bones delegate that registers only what each test needs.
/// Override `routes`, `filters`, etc. in subclasses or per-test closures.
final class TestDelegate: HeliosAppDelegate {

    var routeTable: [String: [HTTPMethod: HeliosHandlerBuilder]] = [:]
    var filterList: [HeliosFilterBuilder] = []
    var modelList: [HeliosAnyModelBuilder] = []
    var timerList: [HeliosTimerBuilder] = []

    func routes(app: HeliosApp) -> [String: [HTTPMethod: HeliosHandlerBuilder]] {
        routeTable
    }

    func filters(app: HeliosApp) -> [HeliosFilterBuilder] {
        filterList
    }

    func models(app: HeliosApp) -> [HeliosAnyModelBuilder] {
        modelList
    }

    func timers(app: HeliosApp) -> [HeliosTimerBuilder] {
        timerList
    }

    func tasks(app: HeliosApp) -> [HeliosAnyTaskBuilder] {
        []
    }
}

// MARK: - Test Handler: echoes back a fixed response

struct EchoHandler: HeliosHandler {
    init() {}
    func handle(req: Request) async throws -> AsyncResponseEncodable {
        Response(status: .ok, body: .init(string: "echo-ok"))
    }
}

struct JsonEchoHandler: HeliosHandler {
    struct Payload: Content {
        let message: String
    }
    init() {}
    func handle(req: Request) async throws -> AsyncResponseEncodable {
        Payload(message: "hello from helios")
    }
}

// MARK: - Test Filter: appends a custom header

struct TestHeaderFilter: HeliosFilter {
    init() {}

    func filterResponse(request: Request, response: Response) async throws -> Response {
        response.headers.add(name: "X-Helios-Test", value: "filtered")
        return response
    }
}

// MARK: - App Factory

/// Create a lightweight Vapor `Application` for testing.
/// Does NOT connect to MySQL or Redis — suitable for route / handler / filter tests.
func makeTestApp(delegate: TestDelegate = TestDelegate()) throws -> Application {
    let app = Application(.testing)

    // Register routes from delegate
    delegate.routeTable
        .flatMap { (path, handlerMap) in
            handlerMap.map { (method, builder) in (path, method, builder) }
        }
        .forEach { (path, method, builder) in
            app.on(method, path.pathComponents) { req async throws -> AnyAsyncResponse in
                let handler = builder()
                let result = try await handler.handle(req: req)
                return AnyAsyncResponse(result)
            }
        }

    // Register filters
    delegate.filterList.forEach { builder in
        let filter = builder()
        app.middleware.use(filter)
    }

    return app
}
