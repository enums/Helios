//
//  RenderValue.swift
//  
//
//  Created by Yuu Zheng on 2/25/23.
//

import Foundation

public protocol RenderValue: Codable { }

extension String: RenderValue { }
extension Int: RenderValue { }
extension Bool: RenderValue { }
