//
//  HeliosApiProxy.swift
//  
//
//  Created by Yuu Zheng on 2/28/23.
//

import Foundation
import Vapor
import Helios

open class HeliosApiProxy: HeliosHandler {

    public let downstreamHost: String
    public let downstreamPort: Int

    public required init() {
        downstreamHost = "localhost"
        downstreamPort = 8080
    }

    public init(host: String, port: Int) {
        downstreamHost = host
        downstreamPort = port
    }

    open func handle(req: Request) async throws -> AsyncResponseEncodable {
        var url = req.url
        url.host = downstreamHost
        url.port = downstreamPort
        let downstreamRequest = ClientRequest(
            method: req.method,
            url: url,
            headers: req.headers,
            body: req.body.data
        )
        let downstreamResponse = try await req.client.send(downstreamRequest)
        let body: Response.Body
        if let downstreamBody = downstreamResponse.body {
            body = .init(buffer: downstreamBody)
        } else {
            body = .empty
        }
        return Response(
            status: downstreamResponse.status,
            headers: req.headers,
            body: body
        )
    }

    private func buildClientRequest(req: Request) -> ClientRequest {
        var downstreamUri = req.url
        downstreamUri.host = downstreamHost
        downstreamUri.port = downstreamPort
        return ClientRequest(
            method: req.method,
            url: downstreamUri,
            headers: req.headers,
            body: req.body.data
        )
    }
}
