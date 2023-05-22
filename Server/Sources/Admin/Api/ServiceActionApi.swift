//
//  ServiceActionApi.swift
//  
//
//  Created by Yuu Zheng on 2/26/23.
//

import Foundation
import Vapor
import Helios
import Selene

class ServiceActionApi: HeliosHandler {

    required init() { }

    func handle(req: Request) async throws -> AsyncResponseEncodable {
        guard let action = req.action() else {
            return failed("unknow action")
        }
        let actionMapper: [String: (Request) async throws -> AsyncResponseEncodable] = [
            "update": actionUpdate,
            "build": actionBuild,
            "clean": actionClean,
            "status": actionStatus,
            "statusAll": actionStatusAll,
            "run": actionRun,
            "runAll": actionRunAll,
            "kill": actionKill,
            "killAll": actionKillAll,
            "reboot": actionReboot,
            "rebootAll": actionRebootAll,
            "healthCheck": actionHealthCheck,
        ]
        return try await actionMapper[action]?(req) ?? failed("unknow action")
    }

    private func actionUpdate(req: Request) async throws -> AsyncResponseEncodable {
        let log = ServiceManager.shared.commandLine.update()
        return success(log)
    }

    private func actionBuild(req: Request) async throws -> AsyncResponseEncodable {
        let log = ServiceManager.shared.commandLine.build()
        return success(log)
    }

    private func actionClean(req: Request) async throws -> AsyncResponseEncodable {
        let log = ServiceManager.shared.commandLine.clean()
        return success(log)
    }

    private func actionStatus(req: Request) async throws -> AsyncResponseEncodable {
        guard let name = req.query(name: "name") else {
            return illegalParam("name")
        }
        let log = ServiceManager.shared.commandLine.taskStatus(name: name)
        return success(log)
    }

    private func actionStatusAll(req: Request) async throws -> AsyncResponseEncodable {
        let log = ServiceManager.shared.commandLine.allTaskStatus()
        return success(log)
    }

    private func actionRun(req: Request) async throws -> AsyncResponseEncodable {
        guard let name = req.query(name: "name") else {
            return illegalParam("name")
        }
        let log = ServiceManager.shared.commandLine.runTask(name: name)
        return success(log)
    }

    private func actionRunAll(req: Request) async throws -> AsyncResponseEncodable {
        let log = ServiceManager.shared.commandLine.runAllTask()
        return success(log)
    }

    private func actionKill(req: Request) async throws -> AsyncResponseEncodable {
        guard let name = req.query(name: "name") else {
            return illegalParam("name")
        }
        let log = ServiceManager.shared.commandLine.killTask(name: name)
        return success(log)
    }

    private func actionKillAll(req: Request) async throws -> AsyncResponseEncodable {
        let log = ServiceManager.shared.commandLine.killAllTask()
        return success(log)
    }

    private func actionReboot(req: Request) async throws -> AsyncResponseEncodable {
        guard let name = req.query(name: "name") else {
            return illegalParam("name")
        }
        let log = ServiceManager.shared.commandLine.rebootTask(name: name)
        return success(log)
    }

    private func actionRebootAll(req: Request) async throws -> AsyncResponseEncodable {
        let log = ServiceManager.shared.commandLine.rebootAllTask()
        return success(log)
    }

    private func actionHealthCheck(req: Request) async throws -> AsyncResponseEncodable {
        guard let name = req.query(name: "name") else {
            return illegalParam("name")
        }
        guard let service = ServiceManager.shared.services.first(where: { $0.name == name }) else {
            return notFound(name)
        }
        do {
            let response = try await req.client.get(service.buildURI(path: RequestPath.healthcheck))
            let body = try response.content.decode(String.self)
            return body == HealthCheckApi.response ? success() : failed(body)
        } catch(let error) {
            return failed(error.localizedDescription)
        }
    }

}
