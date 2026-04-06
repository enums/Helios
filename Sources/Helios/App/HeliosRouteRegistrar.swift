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
    public static func registerRoutes(
        _ routes: [String: [HTTPMethod: HeliosHandlerBuilder]],
        on app: Application
    ) {
        routes
            .flatMap { (path: String, handlerMap: [HTTPMethod: HeliosHandlerBuilder]) in
                handlerMap.map { (method: HTTPMethod, builder: @escaping HeliosHandlerBuilder) in
                    (path, method, builder)
                }
            }
            .forEach { (path, method, builder) in
                app.on(method, path.pathComponents) { req async throws -> AnyAsyncResponse in
                    let handler = builder()
                    let result = try await handler.handle(req: req)
                    return AnyAsyncResponse(result)
                }
            }
    }

    /// Register filters (middleware) on a Vapor `Application`.
    public static func registerFilters(
        _ filters: [HeliosFilterBuilder],
        on app: Application
    ) {
        filters.forEach { builder in
            let filter = builder()
            app.middleware.use(filter)
        }
    }
}
