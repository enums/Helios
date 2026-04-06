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

// MARK: - Test Helpers

/// Default test config — no real DB/Redis needed.
let testConfig = HeliosConfig(
    server: ServerConfig(),
    mysql: MySQLConfig(host: "test", username: "test", password: "test", database: "test"),
    redis: RedisConfig(),
    features: FeatureFlags()
)

/// Create a minimal `HeliosApp` for test context construction.
/// Does NOT connect to any external services.
func makeTestHeliosApp(app: Application, delegate: TestDelegate = TestDelegate()) -> HeliosApp {
    let appConfig = HeliosAppConfig(workspacePath: "/tmp/helios-test/", config: testConfig)
    return HeliosApp(app: app, config: appConfig, delegate: delegate)
}

// MARK: - App Factory

/// Create a lightweight Vapor `Application` for testing with routes and filters registered.
func makeTestApp(delegate: TestDelegate = TestDelegate()) throws -> Application {
    let app = Application(.testing)
    let heliosApp = makeTestHeliosApp(app: app, delegate: delegate)

    let handlerContext = HeliosHandlerContext(app: heliosApp)
    let filterContext = HeliosFilterContext(app: heliosApp)

    HeliosRouteRegistrar.registerRoutes(delegate.routeTable, on: app, context: handlerContext)
    HeliosRouteRegistrar.registerFilters(delegate.filterList, on: app, context: filterContext)

    return app
}
