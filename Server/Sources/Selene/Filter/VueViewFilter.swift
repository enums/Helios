//
//  VueViewFilter.swift
//  Selene
//
//  Created by Yuu Zheng on 5/22/23.
//

import Foundation
import Vapor
import Helios

public class VueViewFilter: HeliosFilter {

    lazy var indexView = IndexView()

    public required init() { }

    public func filterResponse(request: Request, response: Response) async throws -> Response {
        if response.status == .notFound {
            let indexResponse = try await indexView.handle(req: request)
            return try await indexResponse.encodeResponse(for: request)
        } else {
            return response
        }
    }

}
