//
//  HeliosFilter.swift
//  
//
//  Created by Yuu Zheng on 12/29/22.
//

import Foundation
import Vapor

public typealias HeliosFilterBuilder = () -> HeliosFilter

public protocol HeliosFilter: AsyncMiddleware {

    init()

    func filterRequest(request: Request) async throws -> Response?

    func filterResponse(request: Request, response: Response) async throws -> Response
}

public extension HeliosFilter {

    static var builder: HeliosFilterBuilder {
        return {
            Self.init()
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
