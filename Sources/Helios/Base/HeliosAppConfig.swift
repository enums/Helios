//
//  HeliosAppConfig.swift
//  Helios
//
//  Facade combining workspace paths with typed runtime configuration.
//

import Foundation
import Vapor

public final class HeliosAppConfig {

    // MARK: - Path properties

    public let workspacePath: String
    public let publicPath: String
    public let viewsPath: String
    public let resourcesPath: String
    public let configPath: String

    // MARK: - Runtime config

    /// The framework-agnostic runtime configuration.
    public let runtime: HeliosRuntimeConfig

    // MARK: - Init (from DirectoryConfiguration — production path)

    public init(dir: DirectoryConfiguration) throws {
        workspacePath = dir.workingDirectory
        publicPath = dir.publicDirectory
        viewsPath = dir.viewsDirectory
        resourcesPath = dir.resourcesDirectory
        configPath = workspacePath + "Config/"

        var runtimeCfg = try HeliosRuntimeConfig.load(configDir: configPath)
        runtimeCfg = HeliosAppConfig.patchResources(runtimeCfg, workspace: workspacePath)
        try runtimeCfg.validate()
        runtime = runtimeCfg
    }

    // MARK: - Init (from HeliosRuntimeConfig — preferred)

    public init(workspacePath path: String, runtime runtimeConfig: HeliosRuntimeConfig) {
        let root = path.hasSuffix("/") ? path : path + "/"
        workspacePath = root
        publicPath    = root + "Public/"
        viewsPath     = root + "Resources/Views/"
        resourcesPath = root + "Resources/"
        configPath    = root + "Config/"
        runtime = HeliosAppConfig.patchResources(runtimeConfig, workspace: root)
    }

    // MARK: - Helpers

    private static func patchResources(_ config: HeliosRuntimeConfig, workspace: String) -> HeliosRuntimeConfig {
        let root = workspace.hasSuffix("/") ? workspace : workspace + "/"
        let derived = ResourceConfig.derived(from: root)
        var merged = config.resources.paths
        for (key, path) in derived.paths where merged[key] == nil {
            merged[key] = path
        }
        let patchedResources = ResourceConfig(paths: merged, requiredKeys: config.resources.requiredKeys)
        return HeliosRuntimeConfig(
            environment: config.environment,
            bootstrap: config.bootstrap,
            resources: patchedResources,
            extensions: config.extensions,
            configSources: config.configSources,
            mysql: config.mysql,
            redis: config.redis,
            features: config.features
        )
    }
}
