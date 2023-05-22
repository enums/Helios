//
//  LogCache.swift
//  Logger
//
//  Created by Yuu Zheng on 5/5/23.
//

import Foundation
import FluentKit
import Selene

class LogCache<T: LogModelProtocol> {

    private let queue = DispatchQueue(label: "logger.cache")

    private var cache: [T] = []

    var cacheSize: Int {
        T.cacheSize
    }

    var cacheUsed: Int {
        cache.count
    }

    func log(model: T) {
        queue.async { [weak self] in
            self?.cache.append(model)
        }
    }

    func renderLogs(count: Int) -> [[String : Any?]] {
        queue.sync {
            if count <= 0 || count >= cache.count {
                return cache.map { $0.render() }
            } else {
                let startIndex = cache.count - count
                return Array(cache[startIndex...]).map { $0.render() }
            }
        }
    }

    func overallRender() -> [String: Any] {
        return [
            "cacheSize": cacheSize,
            "cacheUsed": cacheUsed,
        ]
    }
}
