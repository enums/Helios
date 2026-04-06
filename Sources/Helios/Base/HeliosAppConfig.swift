//
//  HeliosAppConfig.swift
//  Helios
//
//  Thin facade that loads typed config and exposes workspace paths.
//  Replaces the old [String: String] + @dynamicMemberLookup approach.
//

import Foundation
import Vapor

public final class HeliosAppConfig {

    public let workspacePath: String
    public let publicPath: String
    public let viewsPath: String
    public let resourcesPath: String
    public let configPath: String

    /// The typed configuration loaded from JSON + env vars.
    public let typed: HeliosConfig

    public init(dir: DirectoryConfiguration) throws {
        workspacePath = dir.workingDirectory
        publicPath = dir.publicDirectory
        viewsPath = dir.viewsDirectory
        resourcesPath = dir.resourcesDirectory
        configPath = workspacePath + "Config/"

        typed = try HeliosConfigLoader.load(configDir: configPath)
    }

    /// Test-only initializer: inject a pre-built config without loading from disk.
    public init(workspacePath: String, config: HeliosConfig) {
        self.workspacePath = workspacePath
        self.publicPath = workspacePath + "Public/"
        self.viewsPath = workspacePath + "Views/"
        self.resourcesPath = workspacePath + "Resources/"
        self.configPath = workspacePath + "Config/"
        self.typed = config
    }
}
