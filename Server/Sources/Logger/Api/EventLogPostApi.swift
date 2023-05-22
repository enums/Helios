//
//  EventLogPostApi.swift
//  Postman
//
//  Created by Yuu Zheng on 5/5/23.
//

import Foundation
import Vapor
import Helios
import Selene

class EventLogPostApi: HeliosHandler {

    required init() { }

    func handle(req: Request) async throws -> AsyncResponseEncodable {
        if let body = req.body.string,
           let model = EventLogModel(body: body) {
            LogCenter.shared.eventLogCache.log(model: model)
        }
        return success()
    }
}
