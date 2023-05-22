//
//  AppDelegate.swift
//  
//
//  Created by Yuu Zheng on 2/28/23.
//

import Foundation
import Vapor
import Helios
import Selene

class AppDelegate: HeliosAppDelegate {

    func models(app: HeliosApp) -> [HeliosAnyModelBuilder] {
        return [
            ServiceModel.builder
        ]
    }

    func routes(app: HeliosApp) -> [String: [HTTPMethod: HeliosHanderBuilder]] {
        return [
            RequestPath.healthcheck: [
                .GET: HealthCheckApi.builder
            ],

            RequestPath.overall: [
                .GET: OverallApi.builder
            ],

            "/api/service": [
                .GET: ServiceGetApi.builder,
                .POST: ServiceActionApi.builder
            ],
        ]
    }

    func filters(app: HeliosApp) -> [HeliosFilterBuilder] {
        return [
            HeliosHeaderFilter.builder,
            HeliosLoggerTrackFilter.builder(source: "Admin", host: app.config.logger_host, port: app.config.logger_port),
        ]
    }

}
