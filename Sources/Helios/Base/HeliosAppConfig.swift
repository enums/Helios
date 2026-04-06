//
//  HeliosAppConfig.swift
//  Helios
//
//  Facade combining workspace paths with typed configuration.
//  Now backed by HeliosRuntimeConfig; legacy HeliosConfig available via `typed`.
//

import Foundation
import Vapor

public final class HeliosAppConfig {

    // MARK: - Legacy path properties (backward compat)

    public let workspacePath: String
    public let publicPath: String
    public let viewsPath: String
    public let resourcesPath: String
    public let configPath: String

    // MARK: - New primary config

    /// The new framework-agnostic runtime configuration.
    public let runtime: HeliosRuntimeConfig

    // MARK: - Legacy typed config (backward compat)

    /// Legacy typed config derived from the runtime config.
    @available(*, deprecated, renamed: "runtime", message: "Use `runtime` (HeliosRuntimeConfig) for new code.")
    public var typed: HeliosConfig { runtime.asLegacyConfig() }

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

    // MARK: - Init (from HeliosRuntimeConfig — preferred new path)

    public init(workspacePath path: String, runtime runtimeConfig: HeliosRuntimeConfig) {
        let root = path.hasSuffix("/") ? path : path + "/"
        workspacePath = root
        publicPath    = root + "Public/"
        viewsPath     = root + "Resources/Views/"
        resourcesPath = root + "Resources/"
        configPath    = root + "Config/"
        runtime = HeliosAppConfig.patchResources(runtimeConfig, workspace: root)
    }

    // MARK: - Init (from legacy HeliosConfig — test/backward compat)

    /// Test-only initializer: inject a pre-built config without loading from disk.
    @available(*, deprecated, message: "Use init(workspacePath:runtime:) with HeliosRuntimeConfig instead.")
    public init(workspacePath path: String, config: HeliosConfig) {
        let root = path.hasSuffix("/") ? path : path + "/"
        workspacePath = root
        publicPath    = root + "Public/"
        viewsPath     = root + "Views/"
        resourcesPath = root + "Resources/"
        configPath    = root + "Config/"

        let runtimeCfg = HeliosRuntimeConfig(
            environment: EnvironmentConfig(
                profile: .development,
                host: config.server.host,
                port: config.server.port
            ),
            resources: ResourceConfig.derived(from: root),
            mysql: config.mysql,
            redis: config.redis,
            features: config.features
        )
        runtime = runtimeCfg
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
