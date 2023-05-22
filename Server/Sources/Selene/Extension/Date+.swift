//
//  Date+.swift
//  Shared
//
//  Created by Yuu Zheng on 5/6/23.
//

import Foundation

public extension Date {

    static var dateFormatter: DateFormatter = {
        let that = DateFormatter.init()
        that.timeZone = TimeZone.init(secondsFromGMT: 8 * 3600)
        that.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return that
    }()

    var dateString: String {
        Self.dateFormatter.string(from: self).components(separatedBy: " ")[0]
    }

    var timeString: String {
        Self.dateFormatter.string(from: self).components(separatedBy: " ")[1]
    }

}
