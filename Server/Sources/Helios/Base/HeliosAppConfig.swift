//
//  HeliosAppConfig.swift
//  
//
//  Created by Yuu Zheng on 12/29/22.
//

import Foundation
import Vapor

@dynamicMemberLookup
public final class HeliosAppConfig {

    public let workspacePath: String

    public let publicPath: String
    public let viewsPath: String
    public let resourcesPath: String
    public var configPath: String

    public let config: [String: String]

    public init(dir: DirectoryConfiguration) throws {
        workspacePath = dir.workingDirectory
        publicPath = dir.publicDirectory
        viewsPath = dir.viewsDirectory
        resourcesPath = dir.resourcesDirectory
        configPath = workspacePath + "Config/"

        let url = URL(fileURLWithPath: configPath + "config.json")
        let data = try Data(contentsOf: url)
        config = try JSONDecoder().decode([String: String].self, from: data)
    }

    public subscript(dynamicMember name: String) -> String {
        return config[name] ?? ""
    }
}

