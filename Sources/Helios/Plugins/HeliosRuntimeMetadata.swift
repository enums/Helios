//
//  HeliosRuntimeMetadata.swift
//  Helios
//
//  Runtime metadata attached to Task / Timer descriptors.
//  Part of runtime contract first pass (#27).
//

import Foundation

/// Runtime metadata attached to every Task / Timer descriptor.
public struct HeliosRuntimeMetadata: Equatable, Hashable, Sendable {

    /// Human-readable name for logging / debugging.
    public let name: String

    /// Whether this is a task or a timer.
    public let kind: HeliosRuntimeKind

    /// How important this job is to the application.
    public let criticality: HeliosCriticality

    /// What to do when execution fails.
    public let retryPolicy: HeliosRetryPolicy

    /// Optional human-readable schedule description (e.g. "every 5 minutes").
    public let scheduleDescription: String?

    public init(
        name: String,
        kind: HeliosRuntimeKind,
        criticality: HeliosCriticality = .normal,
        retryPolicy: HeliosRetryPolicy = .noRetry,
        scheduleDescription: String? = nil
    ) {
        self.name = name
        self.kind = kind
        self.criticality = criticality
        self.retryPolicy = retryPolicy
        self.scheduleDescription = scheduleDescription
    }
}

// MARK: - Supporting Types

public enum HeliosRuntimeKind: String, Equatable, Hashable, Sendable {
    case task
    case timer
}

public enum HeliosCriticality: String, Equatable, Hashable, Sendable {
    case normal
    case critical
}

public enum HeliosRetryPolicy: Equatable, Hashable, Sendable {
    case noRetry
    case fixed(maxAttempts: Int)
}

extension HeliosRetryPolicy {

    /// Human-readable description for logging.
    public var logDescription: String {
        switch self {
        case .noRetry: return "none"
        case .fixed(let maxAttempts): return "fixed(\(maxAttempts))"
        }
    }
}
