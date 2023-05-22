//
//  TrackLogPostApi.swift
//  Logger
//
//  Created by Yuu Zheng on 5/5/23.
//

import Foundation
import Vapor
import Helios
import Selene

class TrackLogPostApi: HeliosHandler {

    required init() { }

    func handle(req: Request) async throws -> AsyncResponseEncodable {
        if let body = req.body.string,
           let model = TrackLogModel(body: body) {
            LogCenter.shared.trackLogCache.log(model: model)
        }
        return success()
    }
}
