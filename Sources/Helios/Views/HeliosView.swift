//
//  HeliosView.swift
//  
//
//  Created by Yuu Zheng on 12/29/22.
//

import Foundation
import Vapor
import Leaf

public protocol HeliosView: HeliosHandler {

    func template(req: Request) -> String

    func canHandle(req: Request) -> Bool

    func render(req: Request) -> [String: String]

}

public extension HeliosView {

    func canHandle(req: Request) -> Bool {
        return true
    }

    func render(req: Request) -> [String: String] {
        return [:]
    }

    func handle(req: Request) async throws -> AsyncResponseEncodable {
        guard canHandle(req: req) else {
            return Response(status: .badRequest)
        }
        let param = render(req: req)
        let template = template(req: req)
        return try await req.view.render(template, param)
    }
}
