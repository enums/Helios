//
//  HeliosModel.swift
//  
//
//  Created by Yuu Zheng on 12/29/22.
//

import Foundation
import Fluent

public typealias HeliosAnyModel = AnyModel & AsyncMigration
public typealias HeliosAnyModelBuilder = () -> HeliosAnyModel

public protocol HeliosModel: Model, AsyncMigration {

    func creator(database: Database) -> SchemaBuilder
}

public extension HeliosModel {

    static var builder: HeliosAnyModelBuilder {
        return {
            Self.init()
        }
    }

    func prepare(on database: Database) async throws {
        try await creator(database: database).create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(Self.schema).delete()
    }
}
