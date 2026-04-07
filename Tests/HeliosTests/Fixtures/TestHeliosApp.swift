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

    // Descriptor-based (new API)
    var routeDescriptorList: [HeliosRouteDescriptor] = []
    var filterDescriptorList: [HeliosFilterDescriptor] = []
    var taskDescriptorList: [HeliosTaskDescriptor] = []
    var timerDescriptorList: [HeliosTimerDescriptor] = []

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

    func routeDescriptors(app: HeliosApp) -> [HeliosRouteDescriptor] {
        routeDescriptorList
    }

    func filterDescriptors(app: HeliosApp) -> [HeliosFilterDescriptor] {
        filterDescriptorList
    }

    func taskDescriptors(app: HeliosApp) -> [HeliosTaskDescriptor] {
        taskDescriptorList
    }

    func timerDescriptors(app: HeliosApp) -> [HeliosTimerDescriptor] {
        timerDescriptorList
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

/// Default test runtime config — no real DB/Redis needed.
let testRuntimeConfig = HeliosRuntimeConfig(
    environment: EnvironmentConfig(profile: .test, host: "0.0.0.0", port: 8080),
    bootstrap: .webOnly,
    features: FeatureFlags(
        autoMigrate: false,
        serveLeaf: false,
        enableQueues: false,
        enableTimers: false,
        serveStaticFiles: false
    )
)

/// Create a minimal `HeliosApp` for test context construction.
/// Does NOT connect to any external services.
func makeTestHeliosApp(app: Application, delegate: TestDelegate = TestDelegate()) -> HeliosApp {
    let appConfig = HeliosAppConfig(workspacePath: "/tmp/helios-test/", runtime: testRuntimeConfig)
    return HeliosApp(app: app, config: appConfig, delegate: delegate)
}

// MARK: - App Factory

/// Create a lightweight Vapor `Application` for testing with routes and filters registered.
func makeTestApp(delegate: TestDelegate = TestDelegate()) throws -> Application {
    let app = Application(.testing)
    let heliosApp = makeTestHeliosApp(app: app, delegate: delegate)

    let handlerContext = HeliosHandlerContext(app: heliosApp)
    let filterContext = HeliosFilterContext(app: heliosApp)

    // Descriptor-first, fallback to legacy builders
    if !delegate.routeDescriptorList.isEmpty {
        HeliosRouteRegistrar.registerRoutes(delegate.routeDescriptorList, on: app, context: handlerContext)
    } else {
        HeliosRouteRegistrar.registerRoutes(delegate.routeTable, on: app, context: handlerContext)
    }

    if !delegate.filterDescriptorList.isEmpty {
        HeliosRouteRegistrar.registerFilters(delegate.filterDescriptorList, on: app, context: filterContext)
    } else {
        HeliosRouteRegistrar.registerFilters(delegate.filterList, on: app, context: filterContext)
    }

    return app
}
