//
//  HeliosRouteDescriptor.swift
//  Helios
//
//  Descriptor for route extension points. Separates declaration metadata
//  (path, method) from instance construction (makeHandler).
//

import Foundation
import Vapor

/// A route declaration that pairs HTTP path + method with a context-aware handler factory.
public struct HeliosRouteDescriptor {

    /// The route path, e.g. `"api/users"`.
    public let path: String

    /// The HTTP method (GET, POST, …).
    public let method: HTTPMethod

    /// Factory that receives a `HeliosHandlerContext` and returns a configured handler.
    public let makeHandler: (HeliosHandlerContext) -> HeliosHandler

    public init(
        path: String,
        method: HTTPMethod,
        makeHandler: @escaping (HeliosHandlerContext) -> HeliosHandler
    ) {
        self.path = path
        self.method = method
        self.makeHandler = makeHandler
    }
}

// MARK: - Convenience initializer from HeliosHandler type

extension HeliosRouteDescriptor {

    /// Create a descriptor that uses the handler type's context-aware init.
    public init<H: HeliosHandler>(path: String, method: HTTPMethod, handler: H.Type) {
        self.path = path
        self.method = method
        self.makeHandler = { context in H.init(context: context) }
    }
}
