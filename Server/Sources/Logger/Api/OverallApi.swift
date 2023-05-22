//
//  OverallApi.swift
//  Logger
//
//  Created by Yuu Zheng on 5/5/23.
//

import Foundation
import Vapor
import Helios
import Selene

class OverallApi: HeliosHandler {

    required init() { }

    func handle(req: Request) async throws -> AsyncResponseEncodable {

        let data: [String: Any] = LogCenter.shared.overallRender()

        return success(data)
    }
}
