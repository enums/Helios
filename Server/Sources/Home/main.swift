//
//  AppDelegate.swift
//  Home
//
//  Created by Yuu Zheng on 2023/2/25.
//

import Foundation
import Helios
import Fluent

#if os(macOS)
let workspace = "/Users/yuuzheng/Developer/Helios/Workspace/Home/"
#else
let workspace = "/home/yuuzheng/Developer/Helios/Workspace/Home/"
#endif

let app = try HeliosApp.create(
    workspace: workspace,
    delegate: AppDelegate()
)
defer { app.shutdown() }
try app.run()
