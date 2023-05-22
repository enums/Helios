//
//  OverallApi.swift
//  Admin
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

        var data: [String: Any] = [
            "Service": [
                "totalService": ServiceManager.shared.services.count,
                "runningService": ServiceManager.shared.services.filter { $0.task.isRunning }.count,
            ],
        ]

        let runningServices = ServiceManager.shared.services.filter { $0.task.isRunning }

        for service in runningServices {
            guard let port = Int(service.port) else {
                continue
            }
            do {
                let uri = URI(host: service.host, port: port, path: RequestPath.overall)
                let response = try await req.client.get(uri)
                guard response.status == .ok else {
                    continue
                }
                let json = try response.content.decode(JSON.self)
                data[service.name] = json.dictionaryObject?["data"]
            } catch (let error) {
                req.logger.log(level: .error, .init(stringLiteral: error.localizedDescription))
                continue
            }
        }

        return success(data)
    }
}
