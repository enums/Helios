//
//  ResourceConfig.swift
//  Helios
//
//  Typed resource path configuration for Helios.
//  Uses ResourceKey enum instead of raw strings for well-known paths.
//

import Foundation

// MARK: - ResourceKey

/// Well-known resource path keys used by the Helios framework.
/// Use `.custom(_:)` for application-defined paths.
public enum ResourceKey: Hashable, Codable, Sendable, CustomStringConvertible {
    /// The application workspace / working directory root.
    case workspace
    /// The public web-serving directory (rawValue: "public").
    case publicDir
    /// The resources directory for bundled assets.
    case resources
    /// The Leaf views/templates directory.
    case views
    /// The configuration files directory.
    case config
    /// An application-defined custom key.
    case custom(String)

    /// The string identifier used as the dictionary key and in JSON encoding.
    public var rawValue: String {
        switch self {
        case .workspace:    return "workspace"
        case .publicDir:      return "public"
        case .resources:    return "resources"
        case .views:        return "views"
        case .config:       return "config"
        case .custom(let s): return s
        }
    }

    public var description: String { rawValue }

    public init(rawValue: String) {
        switch rawValue {
        case "workspace":   self = .workspace
        case "public":      self = .publicDir
        case "resources":   self = .resources
        case "views":       self = .views
        case "config":      self = .config
        default:            self = .custom(rawValue)
        }
    }

    // MARK: Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self.init(rawValue: raw)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// MARK: - ResourceConfig

/// Configures resource paths for a Helios application.
/// Maps typed `ResourceKey`s to absolute path strings.
public struct ResourceConfig: Codable, Sendable {

    /// The path mapping from resource key to absolute path string.
    public let paths: [ResourceKey: String]

    /// Keys that must be present for the config to be considered valid.
    public let requiredKeys: Set<ResourceKey>

    public init(paths: [ResourceKey: String] = [:], requiredKeys: Set<ResourceKey> = []) {
        self.paths = paths
        self.requiredKeys = requiredKeys
    }

    /// Build a default resource config from a workspace root path.
    public static func derived(from workspacePath: String) -> ResourceConfig {
        let root = workspacePath.hasSuffix("/") ? workspacePath : workspacePath + "/"
        return ResourceConfig(paths: [
            .workspace: root,
            .publicDir:   root + "Public/",
            .resources: root + "Resources/",
            .views:     root + "Resources/Views/",
            .config:    root + "Config/",
        ])
    }

    /// Return the path for a given key, or nil if not set.
    public func path(for key: ResourceKey) -> String? {
        paths[key]
    }

    /// Validate that all required keys are present.
    /// Throws `ResourceConfigError` listing any missing keys.
    public func validate() throws {
        let missing = requiredKeys.filter { paths[$0] == nil }
        guard missing.isEmpty else {
            throw ResourceConfigError.missingRequiredKeys(missing)
        }
    }

    // MARK: - Codable with ResourceKey dict

    private enum CodingKeys: String, CodingKey {
        case paths, requiredKeys
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawPaths = try container.decode([String: String].self, forKey: .paths)
        paths = Dictionary(uniqueKeysWithValues: rawPaths.map { (ResourceKey(rawValue: $0.key), $0.value) })
        let rawRequired = try container.decodeIfPresent([String].self, forKey: .requiredKeys) ?? []
        requiredKeys = Set(rawRequired.map { ResourceKey(rawValue: $0) })
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let rawPaths = Dictionary(uniqueKeysWithValues: paths.map { ($0.key.rawValue, $0.value) })
        try container.encode(rawPaths, forKey: .paths)
        try container.encode(requiredKeys.map(\.rawValue).sorted(), forKey: .requiredKeys)
    }
}

// MARK: - ResourceConfigError

public enum ResourceConfigError: Error, CustomStringConvertible {
    case missingRequiredKeys(Set<ResourceKey>)

    public var description: String {
        switch self {
        case .missingRequiredKeys(let keys):
            let list = keys.map(\.rawValue).sorted().joined(separator: ", ")
            return "ResourceConfig: missing required keys: \(list)"
        }
    }
}
