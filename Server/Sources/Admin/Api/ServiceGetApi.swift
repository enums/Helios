//
//  ServiceGetApi.swift
//  
//
//  Created by Yuu Zheng on 2/26/23.
//

import Foundation
import Vapor
import Helios
import Selene

class ServiceGetApi: HeliosHandler {

    required init() { }

    func handle(req: Request) async throws -> AsyncResponseEncodable {

        try await ServiceManager.shared.reloadServices()

        let data: [String: Any] = [
            "service": ServiceManager.shared.services.map {
                $0.render()
            }
        ]

        return success(data)
    }
}
