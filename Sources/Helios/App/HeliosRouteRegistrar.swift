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

    // MARK: - Legacy builder-based registration

    /// Register handler-based routes on a Vapor `Application`.
    /// Context is created once and captured by route closures (not per-request).
    public static func registerRoutes(
        _ routes: [String: [HTTPMethod: HeliosHandlerBuilder]],
        on app: Application,
        heliosApp: HeliosApp
    ) {
        let context = HeliosHandlerContext(app: heliosApp)
        registerRoutes(routes, on: app, context: context)
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

    // MARK: - Descriptor-based registration

    /// Register routes from descriptors. Context is created once and captured.
    public static func registerRoutes(
        _ descriptors: [HeliosRouteDescriptor],
        on app: Application,
        heliosApp: HeliosApp
    ) {
        let context = HeliosHandlerContext(app: heliosApp)
        registerRoutes(descriptors, on: app, context: context)
    }

    /// Convenience overload for tests.
    public static func registerRoutes(
        _ descriptors: [HeliosRouteDescriptor],
        on app: Application,
        context: HeliosHandlerContext
    ) {
        descriptors.forEach { descriptor in
            app.on(descriptor.method, descriptor.path.pathComponents) { req async throws -> AnyAsyncResponse in
                let handler = descriptor.makeHandler(context)
                let result = try await handler.handle(req: req)
                return AnyAsyncResponse(result)
            }
        }
    }

    // MARK: - Legacy filter registration

    /// Register filters (middleware) on a Vapor `Application`.
    public static func registerFilters(
        _ filters: [HeliosFilterBuilder],
        on app: Application,
        heliosApp: HeliosApp
    ) {
        let context = HeliosFilterContext(app: heliosApp)
        registerFilters(filters, on: app, context: context)
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

    // MARK: - Descriptor-based filter registration

    /// Register filters from descriptors. Context is created once and captured.
    public static func registerFilters(
        _ descriptors: [HeliosFilterDescriptor],
        on app: Application,
        heliosApp: HeliosApp
    ) {
        let context = HeliosFilterContext(app: heliosApp)
        registerFilters(descriptors, on: app, context: context)
    }

    /// Convenience overload for tests.
    public static func registerFilters(
        _ descriptors: [HeliosFilterDescriptor],
        on app: Application,
        context: HeliosFilterContext
    ) {
        descriptors.forEach { descriptor in
            let filter = descriptor.makeFilter(context)
            app.middleware.use(filter)
        }
    }
}
