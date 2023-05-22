//
//  HeliosModel.swift
//  
//
//  Created by Yuu Zheng on 2/25/23.
//

import Foundation
import FluentKit
import Helios

public protocol SeleneModel: HeliosModel {

    func render() -> [String: Any?]

}

