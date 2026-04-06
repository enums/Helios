//
//  HeliosHandler.swift
//  
//
//  Created by Yuu Zheng on 12/29/22.
//

import Foundation
import Vapor

/// Builder that receives a `HeliosHandlerContext` and returns a configured handler.
/// **Breaking change:** previously `() -> HeliosHandler`.
public typealias HeliosHandlerBuilder = (HeliosHandlerContext) -> HeliosHandler

public protocol HeliosHandler {

    /// Legacy no-arg constructor.
    init()

    /// Context-aware constructor. Override to access app-level dependencies at init time.
    init(context: HeliosHandlerContext)

    func handle(req: Request) async throws -> AsyncResponseEncodable

}

public extension HeliosHandler {

    /// Default: falls back to no-arg init. Existing handlers continue to work.
    init(context: HeliosHandlerContext) {
        self.init()
    }

    /// Context-aware builder.
    static var builder: HeliosHandlerBuilder {
        return { context in
            Self.init(context: context)
        }
    }
}
