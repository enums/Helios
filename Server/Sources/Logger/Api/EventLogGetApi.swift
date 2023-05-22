//
//  EventLogGetApi.swift
//  Logger
//
//  Created by Yuu Zheng on 5/5/23.
//

import Foundation
import Vapor
import Helios
import Selene

class EventLogGetApi: HeliosHandler {

    required init() { }

    func handle(req: Request) async throws -> AsyncResponseEncodable {
        if let countParam = req.query(name: "count"), let count = Int(countParam) {
            let data: [String: Any] = [
                "logs": LogCenter.shared.eventLogCache.renderLogs(count: count)
            ]
            return success(data)
        } else {
            return illegalRequest()
        }
    }
}
