//
//  AthHandler+.swift
//  
//
//  Created by Yuu Zheng on 2/26/23.
//

import Foundation
import Vapor
import Helios

public extension HeliosHandler {

    func success(_ data: [String: Any]) -> AsyncResponseEncodable {
        let data: [String: Any] = [
            "success": true,
            "data": data
        ]
        return JSON(data)
    }

    func success(_ message: String = "ok") -> AsyncResponseEncodable {
        let data: [String: Any] = [
            "success": true,
            "message": message
        ]
        return JSON(data)
    }

    func failed(_ message: String = "error") -> AsyncResponseEncodable {
        let data: [String: Any] = [
            "success": false,
            "message": message,
        ]
        return JSON(data)
    }

    func illegalRequest() -> AsyncResponseEncodable {
        let message = "illegal request"
        return failed(message)
    }

    func illegalParam(_ name: String) -> AsyncResponseEncodable {
        let message = "illegal param: \(name)"
        return failed(message)
    }

    func notFound(_ name: String) -> AsyncResponseEncodable {
        let message = "not found: \(name)"
        return failed(message)
    }
}
