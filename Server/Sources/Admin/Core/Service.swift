//
//  Service.swift
//  
//
//  Created by Yuu Zheng on 2/26/23.
//

import Foundation
import Vapor
import SwiftyScript

class Service {

    let id: String
    let name: String
    let host: String
    let port: String
    let task: ScriptTask

    init(model: ServiceModel, task: ScriptTask) {
        id = model.id ?? UUID().uuidString
        name = model.name_
        host = model.host
        port = model.port

        self.task = task
    }

    func render() -> [String: Any] {
        let startDate: String
        if let date = task.startDate {
            startDate = Utils.dateFormatter.string(from: date)
        } else {
            startDate = "N/A"
        }
        return [
            "id": id,
            "name": name,
            "isRunning": task.isRunning,
            "isHealthy": false,
            "startDate": startDate,
        ]
    }

    func buildURI(path: String) -> URI {
        return .init(host: host, port: Int(port), path: path)
    }
}

