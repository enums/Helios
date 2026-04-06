//
//  HeliosConfigLoader.swift
//  Helios
//
//  Unified config loading API.
//  New code should use `loadRuntime(configDir:)` or `HeliosRuntimeConfig.load(configDir:)`.
//  Legacy `load(configDir:)` delegates to the new runtime system.
//

import Foundation

public enum HeliosConfigLoader {

    // MARK: - Primary API: load HeliosRuntimeConfig

    /// Load, merge, validate, and return a `HeliosRuntimeConfig`.
    /// This is the preferred entry point.
    public static func loadRuntime(configDir: String) throws -> HeliosRuntimeConfig {
        let runtime = try HeliosRuntimeConfig.load(configDir: configDir)
        try runtime.validate()
        return runtime
    }

    /// Load a `HeliosRuntimeConfig` from an explicit list of `ConfigSource`s.
    /// Sources are merged in order; later sources override earlier ones.
    public static func loadRuntime(sources: [ConfigSource], configDir: String? = nil) throws -> HeliosRuntimeConfig {
        let loader = DefaultRuntimeConfigLoader()
        return try loader.load(sources: sources, configDir: configDir)
    }

    // MARK: - Legacy API (backward compat)

    /// Load and return a legacy `HeliosConfig`.
    /// Delegates to the new runtime loader and converts the result.
    @available(*, deprecated, renamed: "loadRuntime(configDir:)", message: "Use loadRuntime(configDir:) which returns HeliosRuntimeConfig.")
    public static func load(configDir: String) throws -> HeliosConfig {
        let runtime = try loadRuntime(configDir: configDir)
        return runtime.asLegacyConfig()
    }
}

// MARK: - Errors

public enum HeliosConfigError: Error, CustomStringConvertible {
    case invalidFormat(String)
    case validationFailed([String])

    public var description: String {
        switch self {
        case .invalidFormat(let file):
            return "Helios config error: '\(file)' is not a valid JSON object"
        case .validationFailed(let errors):
            return "Helios config validation failed:\n" + errors.map { "  • \($0)" }.joined(separator: "\n")
        }
    }
}
