//
//  HeliosHandler.swift
//  
//
//  Created by Yuu Zheng on 12/29/22.
//

import Foundation
import Vapor

public typealias HeliosHanderBuilder = () -> HeliosHandler

public protocol HeliosHandler {

    init()

    func handle(req: Request) async throws -> AsyncResponseEncodable

}

public extension HeliosHandler {

    static var builder: HeliosHanderBuilder {
        return {
            Self.init()
        }
    }
}
