//
//  AppDelegate.swift
//  Postman
//
//  Created by Yuu Zheng on 5/5/23.
//

import Foundation
import Vapor
import Helios
import Selene

class AppDelegate: HeliosAppDelegate {

    func routes(app: HeliosApp) -> [String : [HTTPMethod : HeliosHanderBuilder]] {
        return [
            RequestPath.healthcheck: [
                .GET: HealthCheckApi.builder
            ]
        ]
    }

    func filters(app: HeliosApp) -> [HeliosFilterBuilder] {
        return [
            HeliosHeaderFilter.builder,
            HeliosLoggerTrackFilter.builder(source: "Postman", host: app.config.logger_host, port: app.config.logger_port),
        ]
    }
}
