//
//  HeliosView.swift
//  
//
//  Created by Yuu Zheng on 2/25/23.
//

import Foundation
import Vapor
import Helios

public let HeliosViewCommonParams = [
    ("host_name", "平行宇宙")
]

open class SeleneView: HeliosView {

    open var template: String {
        ""
    }

    required public init() { }

    open func handle(req: Request) async throws -> AsyncResponseEncodable {
        guard canHandle(req: req) else {
            return Response(status: .badRequest)
        }
        let param = render(req: req).merging(HeliosViewCommonParams) { $1 }
        return try await req.view.render(template, param)
    }

}
