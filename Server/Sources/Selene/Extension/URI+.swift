//
//  URI+.swift
//  Shared
//
//  Created by Yuu Zheng on 5/4/23.
//

import Foundation
import Vapor

public extension URI {

    init(host: String, port: Int?, path: String) {
        self.init(scheme: "http", host: host, port: port, path: path)
    }
}
