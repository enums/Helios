//
//  DelayFilter.swift
//  
//
//  Created by Yuu Zheng on 2/27/23.
//

import Foundation
import Vapor
import Helios

public class DelayFilter: HeliosFilter {

    public required init() { }

    public func filterRequest(request: Request) async throws -> Response? {
        try await Task.sleep(nanoseconds: 500 * 1000000)
        return nil
    }

}
