//
//  HeliosModelRegistrar.swift
//  Helios
//
//  Shared model/migration registration logic.
//

import Foundation
import Vapor
import Fluent

public enum HeliosModelRegistrar {

    /// Register database models (migrations) on a Vapor `Application`.
    public static func register(_ builders: [HeliosAnyModelBuilder], on app: Application) {
        builders.forEach { builder in
            let model = builder()
            app.migrations.add(model)
        }
    }
}
