//
//  HeliosAppDelegate.swift
//  
//
//  Created by Yuu Zheng on 12/29/22.
//

import Foundation
import Vapor
import Fluent

public protocol HeliosAppDelegate {

    func routes(app: HeliosApp) -> [String: [HTTPMethod: HeliosHandlerBuilder]]

    func models(app: HeliosApp) -> [HeliosAnyModelBuilder]

    func filters(app: HeliosApp) -> [HeliosFilterBuilder]

    func timers(app: HeliosApp) -> [HeliosTimerBuilder]

    func tasks(app: HeliosApp) -> [HeliosAnyTaskBuilder]
}

public extension HeliosAppDelegate {

    func routes(app: HeliosApp) -> [String: [HTTPMethod: HeliosHandlerBuilder]] {
        return [:]
    }

    func models(app: HeliosApp) -> [HeliosAnyModelBuilder] {
        return []
    }

    func filters(app: HeliosApp) -> [HeliosFilterBuilder] {
        return []
    }

    func timers(app: HeliosApp) -> [HeliosTimerBuilder] {
        return []
    }

    func tasks(app: HeliosApp) -> [HeliosAnyTaskBuilder] {
        return []
    }
}

extension HTTPMethod: Hashable { }
