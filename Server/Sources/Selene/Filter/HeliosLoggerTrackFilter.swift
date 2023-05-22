//
//  HeliosLoggerTrackFilter.swift
//  Shared
//
//  Created by Yuu Zheng on 5/5/23.
//

import Foundation
import Dispatch
import Vapor
import Helios

public class HeliosLoggerTrackFilter: HeliosFilter {

    let queue = DispatchQueue(label: "helios.logger.filter.track")

    let source: String
    let host: String
    let port: String

    public required init() {
        fatalError()
    }

    public init(source: String, host: String, port: String) {
        self.source = source
        self.host = host
        self.port = port
    }

    public static func builder(source: String, host: String, port: String) -> () -> HeliosLoggerTrackFilter {
        return {
            .init(source: source, host: host, port: port)
        }
    }

    public func filterResponse(request: Request, response: Response) async throws -> Response {
        postTrackLog(request: request, response: response)
        return response
    }

    private func postTrackLog(request: Request, response: Response) {
        guard !host.isEmpty, let port = Int(port) else {
            return
        }
        let model = createModel(request: request, response: response)
        queue.async { [weak self] in
            guard let self else {
                return
            }
            guard let json = JSON(model.render()).rawString() else {
                return
            }
            let uri = URI(host: self.host, port: port, path: RequestPath.loggerTrack)
            _ = request.client.post(uri, content: json)
        }
    }

    private func createModel(request: Request, response: Response) -> TrackLogModel {
        let date = Date()
        let model = TrackLogModel()
        model.id = UUID().uuidString
        model.date = date.dateString
        model.time = date.timeString
        model.source = source
        model.url = request.url.string
        model.status = "\(response.status.code)"
        model.client = request.client()
        return model
    }
}
