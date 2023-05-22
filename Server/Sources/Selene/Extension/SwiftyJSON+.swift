//
//  SwiftyJSON+.swift
//  
//
//  Created by Yuu Zheng on 2/26/23.
//

import Foundation
import Vapor

extension JSON: AsyncResponseEncodable {

    public func encodeResponse(for request: Request) async throws -> Response {
        let response = Response()
        response.headers.contentType = .json
        response.body = .init(data: try rawData())
        return response
    }
}
