//
//  LogCenter.swift
//  Logger
//
//  Created by Yuu Zheng on 5/5/23.
//

import Foundation
import Dispatch
import Vapor
import Selene

class LogCenter {

    static let shared = LogCenter()

    private init() { }
    
    var trackLogCache = LogCache<TrackLogModel>()
    var eventLogCache = LogCache<EventLogModel>()

    func overallRender() -> [String: Any] {
        return [
            "track": trackLogCache.overallRender(),
            "event": eventLogCache.overallRender()
        ]
    }
}
