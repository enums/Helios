//
//  HeliosFilter.swift
//  
//
//  Created by Yuu Zheng on 12/29/22.
//

import Foundation
import Vapor

/// Builder that receives a `HeliosFilterContext` and returns a configured filter.
/// **Breaking change:** previously `() -> HeliosFilter`.
public typealias HeliosFilterBuilder = (HeliosFilterContext) -> HeliosFilter

public protocol HeliosFilter: AsyncMiddleware {

    /// Legacy no-arg constructor.
    init()

    /// Context-aware constructor. Override to access app-level dependencies at init time.
    init(context: HeliosFilterContext)

    func filterRequest(request: Request) async throws -> Response?

    func filterResponse(request: Request, response: Response) async throws -> Response
}

public extension HeliosFilter {

    /// Default: falls back to no-arg init.
    init(context: HeliosFilterContext) {
        self.init()
    }

    static var builder: HeliosFilterBuilder {
        return { context in
            Self.init(context: context)
        }
    }

    func filterRequest(request: Request) async throws -> Response? {
        return nil
    }

    func filterResponse(request: Request, response: Response) async throws -> Response {
        return response
    }

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        if let response = try await filterRequest(request: request) {
            return response
        } else {
            let response = try await next.respond(to: request)
            return try await filterResponse(request: request, response: response)
        }
    }
}
