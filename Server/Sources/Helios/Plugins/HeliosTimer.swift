//
//  HeliosTimer.swift
//  Helios
//
//  Created by Yuu Zheng on 12/30/22.
//

import Foundation
import Vapor
import Queues

public typealias HeliosTimerBuilder = () -> HeliosTimer

public protocol HeliosTimer: AsyncScheduledJob {

    init()

    func schedule(queue: Application.Queues)

}

public extension HeliosTimer {

    static var builder: HeliosTimerBuilder {
        return {
            Self.init()
        }
    }
}
