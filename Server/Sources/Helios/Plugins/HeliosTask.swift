//
//  HeliosTask.swift
//  Helios
//
//  Created by Yuu Zheng on 12/30/22.
//

import Foundation
import Vapor
import Queues

public typealias HeliosAnyTask = AnyJob
public typealias HeliosAnyTaskBuilder = () -> HeliosAnyTask

public protocol HeliosTask: AsyncJob {

    init()

    func register(queue: Application.Queues)

}

public extension HeliosTask {

    static var builder: HeliosAnyTaskBuilder {
        return {
            Self.init()
        }
    }

    func register(queue: Application.Queues) {
        queue.add(self)
    }
}

