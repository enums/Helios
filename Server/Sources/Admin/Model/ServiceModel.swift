//
//  ServiceModel.swift
//  Admin
//
//  Created by Yuu Zheng on 5/4/23.
//

import Foundation
import SwiftyScript
import Fluent
import Helios
import Selene

public final class ServiceModel: SeleneModel {

    public static let schema = "Service"

    @ID(custom: "id")
    public var id: String?

    @Field(key: "name")
    public var name_: String

    @Field(key: "host")
    public var host: String

    @Field(key: "port")
    public var port: String

    public init() { }

    public func creator(database: Database) -> SchemaBuilder {
        database.schema(Self.schema)
            .field(.id, .string, .identifier(auto: false))
            .field(_name_.key, .string, .required)
            .field(_host.key, .string, .required)
            .field(_port.key, .string, .required)
    }

    public func render() -> [String : Any?] {
        return [
            _id.key.description: _id.value,
            _name_.key.description: _name_.value,
            _host.key.description: _host.value,
            _port.key.description: _port.value,
        ]
    }

}
