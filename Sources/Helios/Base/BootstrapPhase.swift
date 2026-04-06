//
//  BootstrapPhase.swift
//  Helios
//
//  Phase-driven bootstrap system for Helios applications.
//  Allows selective setup of only the phases an application needs.
//

import Foundation

// MARK: - BootstrapPhase

/// Defines the discrete phases of Helios application startup.
/// Each phase corresponds to a distinct area of infrastructure setup.
public enum BootstrapPhase: String, CaseIterable, Codable, Sendable, Hashable {
    /// Load and validate configuration from files and environment variables.
    case loadConfiguration

    /// Prepare framework resources: paths, directories, working directory.
    case prepareResources

    /// Register extensions, plugins, and provider descriptors.
    case registerExtensions

    /// Configure middleware stack (filters).
    case registerMiddleware

    /// Register HTTP route handlers.
    case registerRoutes

    /// Initialize services: storage (database, cache), view engine, static files.
    case initializeServices

    /// Start background systems: queues, scheduled timers, async tasks.
    case startBackgroundSystems
}

// MARK: - BootstrapConfig

/// Configures which phases are executed during `HeliosApp.setup()`.
/// Use `BootstrapConfig.default` for a full production setup.
/// Use `BootstrapConfig.minimal` for lightweight testing or API-only apps.
public struct BootstrapConfig: Codable, Sendable {

    /// The phases that will be executed during application bootstrap, in order.
    public let enabledPhases: [BootstrapPhase]

    public init(enabledPhases: [BootstrapPhase]) {
        self.enabledPhases = enabledPhases
    }

    /// Full production bootstrap — all phases enabled, in standard order.
    public static let `default` = BootstrapConfig(enabledPhases: BootstrapPhase.allCases)

    /// Minimal bootstrap — configuration and resources only; no services, routes, or background jobs.
    /// Useful for CLIs, workers, or lightweight test setups.
    public static let minimal = BootstrapConfig(enabledPhases: [
        .loadConfiguration,
        .prepareResources,
    ])

    /// Web-only bootstrap — everything except background systems.
    public static let webOnly = BootstrapConfig(enabledPhases: [
        .loadConfiguration,
        .prepareResources,
        .registerExtensions,
        .registerMiddleware,
        .registerRoutes,
        .initializeServices,
    ])

    /// Background-worker bootstrap — services and background jobs, no HTTP routes.
    public static let workerOnly = BootstrapConfig(enabledPhases: [
        .loadConfiguration,
        .prepareResources,
        .registerExtensions,
        .initializeServices,
        .startBackgroundSystems,
    ])

    /// Returns true if the given phase is enabled in this configuration.
    public func isEnabled(_ phase: BootstrapPhase) -> Bool {
        enabledPhases.contains(phase)
    }
}
