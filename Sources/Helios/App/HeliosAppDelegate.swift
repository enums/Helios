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

    // MARK: - Legacy builder-based API (still supported)

    func routes(app: HeliosApp) -> [String: [HTTPMethod: HeliosHandlerBuilder]]

    func models(app: HeliosApp) -> [HeliosAnyModelBuilder]

    func filters(app: HeliosApp) -> [HeliosFilterBuilder]

    func timers(app: HeliosApp) -> [HeliosTimerBuilder]

    func tasks(app: HeliosApp) -> [HeliosAnyTaskBuilder]

    // MARK: - Descriptor-based API (preferred)
    //
    // Override these to declare extension points via descriptors.
    // When non-empty, these take priority over the legacy builder methods.

    func routeDescriptors(app: HeliosApp) -> [HeliosRouteDescriptor]

    func filterDescriptors(app: HeliosApp) -> [HeliosFilterDescriptor]

    func taskDescriptors(app: HeliosApp) -> [HeliosTaskDescriptor]

    func timerDescriptors(app: HeliosApp) -> [HeliosTimerDescriptor]
}

public extension HeliosAppDelegate {

    // MARK: - Legacy defaults

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

    // MARK: - Descriptor defaults (empty → fallback to legacy)

    func routeDescriptors(app: HeliosApp) -> [HeliosRouteDescriptor] {
        return []
    }

    func filterDescriptors(app: HeliosApp) -> [HeliosFilterDescriptor] {
        return []
    }

    func taskDescriptors(app: HeliosApp) -> [HeliosTaskDescriptor] {
        return []
    }

    func timerDescriptors(app: HeliosApp) -> [HeliosTimerDescriptor] {
        return []
    }
}

extension HTTPMethod: Hashable { }
