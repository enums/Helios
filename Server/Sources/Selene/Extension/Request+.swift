//
//  Request+.swift
//  
//
//  Created by Yuu Zheng on 2/26/23.
//

import Foundation
import Vapor

public extension Request {

    static let headerClientIpName = "x-helios-ip"
    static let headerClientPortName = "x-helios-port"

    func query(name: String) -> String? {
        return query[String.self, at: name]
    }

    func action() -> String? {
        return query(name: "action")
    }

    func clientIp() -> String? {
        return headers.first(name: Self.headerClientIpName)
    }

    func clientPort() -> String? {
        return headers.first(name: Self.headerClientPortName)
    }

    func client() -> String {
        let ip = clientIp() ?? "UNKNOW"
        let port = clientPort() ?? "UNKNOW"
        return "\(ip):\(port)"
    }
}
