//
//  LogModelProtocol.swift
//  Shared
//
//  Created by Yuu Zheng on 5/6/23.
//

import Foundation

public protocol LogModelProtocol: SeleneModel {
    static var cacheSize: Int { get }
}
