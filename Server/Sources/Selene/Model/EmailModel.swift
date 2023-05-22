//
//  EmailModel.swift
//  
//
//  Created by Yuu Zheng on 2/26/23.
//

import Foundation
import SwiftyScript
import Fluent
import Helios

public final class EmailModel: SeleneModel {

    public static let schema = "Email"

    @ID(custom: "id")
    public var id: String?

    @Field(key: "title")
    public var title: String

    @Field(key: "sender")
    public var sender: String

    @Field(key: "receiver")
    public var receiver: String

    @Field(key: "date")
    public var date: String

    @Field(key: "read")
    public var isRead: Bool

    @Field(key: "delete")
    public var isDeleted: Bool

    public init() { }

    public func creator(database: Database) -> SchemaBuilder {
        database.schema(Self.schema)
            .field(.id, .string, .identifier(auto: false))
            .field(_title.key, .string, .required)
            .field(_sender.key, .string, .required)
            .field(_receiver.key, .string, .required)
            .field(_date.key, .string, .required)
            .field(_isRead.key, .bool, .required)
            .field(_isDeleted.key, .bool, .required)
    }

    public func render() -> [String : Any?] {
        return [
            _id.key.description: _id.value,
            _title.key.description: _title.value,
            _sender.key.description: _sender.value,
            _receiver.key.description: _receiver.value,
            _date.key.description: _date.value,
            _isRead.key.description: _isRead.value,
            _isDeleted.key.description: _isDeleted.value,
        ]
    }

}
