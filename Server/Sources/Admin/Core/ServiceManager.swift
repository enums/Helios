//
//  ServiceManager.swift
//  
//
//  Created by Yuu Zheng on 2/25/23.
//

import Foundation
import Dispatch
import SwiftyScript
import Selene

class ServiceManager: ServiceCommandDelegate {

    static let shared = ServiceManager()

    let commandLine = ServiceCommand()

    var services: [Service] = []

    private let lock = NSLock()

    init() {
        commandLine.delegate = self
    }

    func run() {
        while true {
            print("> ".magenta, terminator: "")
            guard let line = readLine(), line.count > 0 else {
                continue
            }
            if let result = commandLine.runCommand(line) {
                print(result)
            }
        }
    }

    func reloadServices() async throws {
        let models = try await ServiceModel.query(on: app.database).all()
        var result = [Service]()
        let existingServices = services
        let newServices = models.map {
            Service(model: $0, task: commandLine.buildTask(name: $0.name_, command: "\(productPath)/\($0.name_)"))
        }
        newServices.forEach { newService in
            if let existingService = existingServices.first(where: { $0.id == newService.id }) {
                result.append(existingService)
            } else {
                result.append(newService)
            }

        }
        services = result
    }
}
