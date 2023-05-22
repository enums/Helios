//
//  AppDelegate.swift
//  Logger
//
//  Created by Yuu Zheng on 2023/5/5.
//

import Foundation
import Helios
import Fluent

#if os(macOS)
let workspace = "/Users/yuuzheng/Developer/Helios/Workspace/Postman/"
#else
let workspace = "/home/yuuzheng/Developer/Helios/Workspace/Postman/"
#endif

let app = try HeliosApp.create(
    workspace: workspace,
    delegate: AppDelegate()
)
defer { app.shutdown() }
try app.run()
