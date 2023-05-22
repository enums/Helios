//
//  HealthCheckApi.swift
//  
//
//  Created by Yuu Zheng on 2/26/23.
//

import Foundation
import Vapor
import Helios

public class HealthCheckApi: HeliosHandler {

    public static let response = "ok"

    required public init() { }

    public func handle(req: Request) async throws -> AsyncResponseEncodable {
        return Self.response
    }
}
