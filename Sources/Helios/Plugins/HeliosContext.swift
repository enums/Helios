//
//  HeliosContext.swift
//  Helios
//
//  Context structs passed to framework extension points during construction,
//  so they can access app-level dependencies at init time.
//

import Foundation
import Vapor
import Queues

/// Context provided to `HeliosHandler` at construction time.
public struct HeliosHandlerContext {
    public let app: HeliosApp

    public init(app: HeliosApp) {
        self.app = app
    }
}

/// Context provided to `HeliosFilter` at construction time.
public struct HeliosFilterContext {
    public let app: HeliosApp

    public init(app: HeliosApp) {
        self.app = app
    }
}

/// Context provided to `HeliosTask` at construction time.
public struct HeliosTaskContext {
    public let app: HeliosApp
    public let queues: Application.Queues

    public init(app: HeliosApp, queues: Application.Queues) {
        self.app = app
        self.queues = queues
    }
}

/// Context provided to `HeliosTimer` at construction time.
public struct HeliosTimerContext {
    public let app: HeliosApp
    public let queues: Application.Queues

    public init(app: HeliosApp, queues: Application.Queues) {
        self.app = app
        self.queues = queues
    }
}
