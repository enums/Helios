//
//  AppDelegate.swift
//  Logger
//
//  Created by Yuu Zheng on 5/5/23.
//

import Foundation
import Vapor
import Helios
import Selene

class AppDelegate: HeliosAppDelegate {

    func models(app: HeliosApp) -> [HeliosAnyModelBuilder] {
        return [
            EventLogModel.builder,
            TrackLogModel.builder,
        ]
    }

    func routes(app: HeliosApp) -> [String : [HTTPMethod : HeliosHanderBuilder]] {
        return [
            RequestPath.healthcheck: [
                .GET: HealthCheckApi.builder
            ],

            RequestPath.overall: [
                .GET: OverallApi.builder
            ],

            RequestPath.loggerTrack: [
                .GET: TrackLogGetApi.builder,
                .POST: TrackLogPostApi.builder,
            ],

            RequestPath.loggerEvent: [
                .GET: EventLogGetApi.builder,
                .POST: EventLogPostApi.builder,
            ],
        ]
    }

    func filters(app: HeliosApp) -> [HeliosFilterBuilder] {
        return [
            HeliosHeaderFilter.builder
        ]
    }
}
