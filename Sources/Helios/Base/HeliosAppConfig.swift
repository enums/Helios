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

        var rt = try HeliosRuntimeConfig.load(configDir: configPath)
        rt = HeliosAppConfig.patchResources(rt, workspace: workspacePath)
        try rt.validate()
        runtime = rt
    }

    // MARK: - Init (from HeliosRuntimeConfig — preferred new path)

    public init(workspacePath wp: String, runtime rt: HeliosRuntimeConfig) {
        let ws = wp.hasSuffix("/") ? wp : wp + "/"
        workspacePath = ws
        publicPath    = ws + "Public/"
        viewsPath     = ws + "Resources/Views/"
        resourcesPath = ws + "Resources/"
        configPath    = ws + "Config/"
        runtime = HeliosAppConfig.patchResources(rt, workspace: ws)
    }

    // MARK: - Init (from legacy HeliosConfig — test/backward compat)

    /// Test-only initializer: inject a pre-built config without loading from disk.
    @available(*, deprecated, message: "Use init(workspacePath:runtime:) with HeliosRuntimeConfig instead.")
    public init(workspacePath wp: String, config: HeliosConfig) {
        let ws = wp.hasSuffix("/") ? wp : wp + "/"
        workspacePath = ws
        publicPath    = ws + "Public/"
        viewsPath     = ws + "Views/"
        resourcesPath = ws + "Resources/"
        configPath    = ws + "Config/"

        let rt = HeliosRuntimeConfig(
            environment: EnvironmentConfig(
                profile: .development,
                host: config.server.host,
                port: config.server.port
            ),
            resources: ResourceConfig.derived(from: ws),
            mysql: config.mysql,
            redis: config.redis,
            features: config.features
        )
        runtime = rt
    }

    // MARK: - Helpers

    private static func patchResources(_ rt: HeliosRuntimeConfig, workspace: String) -> HeliosRuntimeConfig {
        let ws = workspace.hasSuffix("/") ? workspace : workspace + "/"
        let derived = ResourceConfig.derived(from: ws)
        var merged = rt.resources.paths
        for (key, path) in derived.paths where merged[key] == nil {
            merged[key] = path
        }
        let patchedResources = ResourceConfig(paths: merged, requiredKeys: rt.resources.requiredKeys)
        return HeliosRuntimeConfig(
            environment: rt.environment,
            bootstrap: rt.bootstrap,
            resources: patchedResources,
            extensions: rt.extensions,
            configSources: rt.configSources,
            mysql: rt.mysql,
            redis: rt.redis,
            features: rt.features
        )
    }
}
