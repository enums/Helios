//
//  TrackLogModel.swift
//  Postman
//
//  Created by Yuu Zheng on 5/5/23.
//

import Foundation
import SwiftyScript
import Fluent
import Helios

public final class TrackLogModel: LogModelProtocol {

    public static let schema = "TrackLog"
    public static let cacheSize = 10000

    @ID(custom: "id")
    public var id: String?

    @Field(key: "date")
    public var date: String

    @Field(key: "time")
    public var time: String

    @Field(key: "source")
    public var source: String

    @Field(key: "url")
    public var url: String

    @Field(key: "status")
    public var status: String

    @Field(key: "client")
    public var client: String

    public init() { }

    public init?(body: String) {
        let json = JSON(parseJSON: body)
        guard json.type == .dictionary else {
            return nil
        }
        guard let id = json["id"].string,
              let date = json["date"].string,
              let time = json["time"].string,
              let source = json["source"].string,
              let url = json["url"].string,
              let status = json["status"].string,
              let client = json["client"].string else {
            return nil
        }
        self.id = id
        self.date = date
        self.time = time
        self.source = source
        self.url = url
        self.status = status
        self.client = client
    }

    public func creator(database: Database) -> SchemaBuilder {
        database.schema(Self.schema)
            .field(.id, .string, .identifier(auto: false))
            .field(_date.key, .string, .required)
            .field(_time.key, .string, .required)
            .field(_source.key, .string, .required)
            .field(_url.key, .string, .required)
            .field(_status.key, .string, .required)
            .field(_client.key, .string, .required)
    }

    public func render() -> [String : Any?] {
        return [
            _id.key.description: _id.value,
            _date.key.description: _date.value,
            _time.key.description: _time.value,
            _source.key.description: _source.value,
            _url.key.description: _url.value,
            _status.key.description: _status.value,
            _client.key.description: _client.value,
        ]
    }

}
