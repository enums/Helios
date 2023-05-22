//
//  main.swift
//  
//
//  Created by Yuu Zheng on 2/28/23.
//

import Foundation
import Helios
import Fluent
import SwiftyScript
import Selene

#if DEBUG
let isDebug = true
#else
let isDebug = false
#endif

#if os(macOS)
let username = "yuuzheng"

let workspace = "/Users/\(username)/Developer/Helios/Workspace/Admin/"
let xcodePath = "Helios-dxsdbvzcvyvfwyaqqsncsyoxcxvb"
let xcodeProductPath = "/Users/\(username)/Library/Developer/Xcode/DerivedData/\(xcodePath)/Build/Products/Debug"
let productPath = isDebug ? xcodeProductPath : "/Users/\(username)/Developer/Helios/Server/.build/release"
#else
let workspace = "/home/yuuzheng/Developer/Helios/Workspace/Admin/"
let productPath = "/home/yuuzheng/Developer/Helios/Server/.build/release"
#endif


let app = try HeliosApp.create(
    workspace: workspace,
    delegate: AppDelegate()
)
defer { app.shutdown() }

let queue = DispatchQueue(label: "helios", qos: .userInteractive)
queue.async {
    do {
        try app.run()
    } catch (let error) {
        print(error)
    }
}

Task.DefaultValue.output = .log
Language.Bash.environment!["PATH"]! += ":/usr/local/bin"

HeliosSignalTrap.shared.trap(signal: SIGINT) { _ in
    if let log = ServiceManager.shared.commandLine.runCommand("exit") {
        print(log)
    }
    exit(0)
}

await ServiceManager.shared.run()
