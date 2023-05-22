//
//  EventLogModel.swift
//  Postman
//
//  Created by Yuu Zheng on 5/5/23.
//

import Foundation
import SwiftyScript
import Fluent
import Helios

public final class EventLogModel: LogModelProtocol {

    public static let schema = "EventLog"
    public static let cacheSize = 10000

    @ID(custom: "id")
    public var id: String?

    @Field(key: "date")
    public var date: String

    @Field(key: "time")
    public var time: String

    @Field(key: "source")
    public var source: String

    @Field(key: "topic")
    public var topic: String

    @Field(key: "type")
    public var type: String

    @Field(key: "content")
    public var content: String

    public init() { }

    public init?(body: String) {
        let json = JSON(parseJSON: body)
        guard json.type == .dictionary else {
            return nil
        }
        guard let id = json["id"].string,
              let date = json["date"].string,
              let time = json["time"].string,
              !date.isEmpty, !time.isEmpty,
              let source = json["source"].string,
              let topic = json["topic"].string,
              let type = json["type"].string,
              let content = json["content"].string else {
            return nil
        }
        let overrideDate = Date()
        self.id = id
        self.date = overrideDate.dateString
        self.time = overrideDate.timeString
        self.source = source
        self.topic = topic
        self.type = type
        self.content = content
    }

    public func creator(database: Database) -> SchemaBuilder {
        database.schema(Self.schema)
            .field(.id, .string, .identifier(auto: false))
            .field(_date.key, .string, .required)
            .field(_time.key, .string, .required)
            .field(_source.key, .string, .required)
            .field(_topic.key, .string, .required)
            .field(_type.key, .string, .required)
            .field(_content.key, .string, .required)
    }

    public func render() -> [String : Any?] {
        return [
            _id.key.description: _id.value,
            _date.key.description: _date.value,
            _time.key.description: _time.value,
            _source.key.description: _source.value,
            _topic.key.description: _topic.value,
            _type.key.description: _type.value,
            _content.key.description: _content.value,
        ]
    }

}
