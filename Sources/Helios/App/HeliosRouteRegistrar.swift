//
//  HeliosRouteRegistrar.swift
//  Helios
//
//  Shared route + filter registration logic used by both HeliosApp (production)
//  and the test harness, so registration semantics stay in sync.
//

import Foundation
import Vapor

public enum HeliosRouteRegistrar {

    /// Register handler-based routes on a Vapor `Application`.
    /// Context is created once and captured by route closures (not per-request).
    public static func registerRoutes(
        _ routes: [String: [HTTPMethod: HeliosHandlerBuilder]],
        on app: Application,
        heliosApp: HeliosApp
    ) {
        let context = HeliosHandlerContext(app: heliosApp)
        routes
            .flatMap { (path: String, handlerMap: [HTTPMethod: HeliosHandlerBuilder]) in
                handlerMap.map { (method: HTTPMethod, builder: @escaping HeliosHandlerBuilder) in
                    (path, method, builder)
                }
            }
            .forEach { (path, method, builder) in
                app.on(method, path.pathComponents) { req async throws -> AnyAsyncResponse in
                    let handler = builder(context)
                    let result = try await handler.handle(req: req)
                    return AnyAsyncResponse(result)
                }
            }
    }

    /// Convenience overload for tests: creates a minimal context-free registration.
    /// Uses a lightweight shim so test harness doesn't need a full HeliosApp.
    public static func registerRoutes(
        _ routes: [String: [HTTPMethod: HeliosHandlerBuilder]],
        on app: Application,
        context: HeliosHandlerContext
    ) {
        routes
            .flatMap { (path: String, handlerMap: [HTTPMethod: HeliosHandlerBuilder]) in
                handlerMap.map { (method: HTTPMethod, builder: @escaping HeliosHandlerBuilder) in
                    (path, method, builder)
                }
            }
            .forEach { (path, method, builder) in
                app.on(method, path.pathComponents) { req async throws -> AnyAsyncResponse in
                    let handler = builder(context)
                    let result = try await handler.handle(req: req)
                    return AnyAsyncResponse(result)
                }
            }
    }

    /// Register filters (middleware) on a Vapor `Application`.
    public static func registerFilters(
        _ filters: [HeliosFilterBuilder],
        on app: Application,
        heliosApp: HeliosApp
    ) {
        let context = HeliosFilterContext(app: heliosApp)
        filters.forEach { builder in
            let filter = builder(context)
            app.middleware.use(filter)
        }
    }

    /// Convenience overload for tests.
    public static func registerFilters(
        _ filters: [HeliosFilterBuilder],
        on app: Application,
        context: HeliosFilterContext
    ) {
        filters.forEach { builder in
            let filter = builder(context)
            app.middleware.use(filter)
        }
    }
}
