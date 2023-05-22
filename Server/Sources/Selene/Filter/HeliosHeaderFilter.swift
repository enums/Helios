//
//  HeliosHeaderFilter.swift
//  
//
//  Created by Yuu Zheng on 2/27/23.
//

import Foundation
import Vapor
import Helios

public class HeliosHeaderFilter: HeliosFilter {

    public required init() { }

    public func filterResponse(request: Request, response: Response) async throws -> Response {
        #if DEBUG
        response.headers.replaceOrAdd(name: HTTPHeaders.Name.accessControlAllowOrigin, value: "*")
        #else
        response.headers.replaceOrAdd(name: HTTPHeaders.Name.accessControlAllowOrigin, value: "*")
        #endif

        response.headers.replaceOrAdd(name: HTTPHeaders.Name.accessControlAllowHeaders, value: [
            HTTPHeaders.Name.xRequestedWith.description,
            HTTPHeaders.Name.contentType.description,
        ].joined(separator: ","))

        response.headers.replaceOrAdd(name: HTTPHeaders.Name.accessControlAllowMethods, value: [
            HTTPMethod.GET.string,
            HTTPMethod.POST.string,
        ].joined(separator: ","))

        response.headers.replaceOrAdd(name: HTTPHeaders.Name.accessControlAllowCredentials, value: "true")

        return response
    }
}
