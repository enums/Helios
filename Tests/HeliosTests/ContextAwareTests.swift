//
//  ContextAwareTests.swift
//  HeliosTests
//
//  Tests for context-aware Task / Timer construction (#14).
//

import XCTest
import XCTVapor
import Vapor
import Queues
@testable import Helios

final class ContextAwareTests: XCTestCase {

    // MARK: - Context structs

    func testTaskContextHoldsReferences() {
        let app = Application(.testing)
        defer { app.shutdown() }
        let heliosApp = makeTestHeliosApp(app: app)

        let taskCtx = HeliosTaskContext(app: heliosApp, queues: app.queues)
        let timerCtx = HeliosTimerContext(app: heliosApp, queues: app.queues)

        XCTAssertNotNil(taskCtx.app)
        XCTAssertNotNil(timerCtx.app)
    }

    // MARK: - Legacy init() still works via default implementation

    func testLegacyTimerBuilderStillWorks() {
        let app = Application(.testing)
        defer { app.shutdown() }
        let heliosApp = makeTestHeliosApp(app: app)

        let ctx = HeliosTimerContext(app: heliosApp, queues: app.queues)
        let timer = LegacyTimer.builder(ctx)
        XCTAssertNotNil(timer)
        XCTAssertTrue(timer is LegacyTimer)
    }

    func testLegacyTaskBuilderStillWorks() {
        let app = Application(.testing)
        defer { app.shutdown() }
        let heliosApp = makeTestHeliosApp(app: app)

        let ctx = HeliosTaskContext(app: heliosApp, queues: app.queues)
        let task = LegacyTask.builder(ctx)
        XCTAssertNotNil(task)
    }

    // MARK: - Context-aware init receives context

    func testContextAwareTimerReceivesContext() {
        let app = Application(.testing)
        defer { app.shutdown() }
        let runtimeConfig = HeliosRuntimeConfig(
            environment: EnvironmentConfig(host: "ctx-test", port: 9999),
            mysql: MySQLConfig(host: "test", username: "u", password: "p", database: "d"),
            redis: RedisConfig(),
            features: FeatureFlags()
        )
        let appConfig = HeliosAppConfig(workspacePath: "/tmp/test/", runtime: runtimeConfig)
        let delegate = TestDelegate()
        let heliosApp = HeliosApp(app: app, config: appConfig, delegate: delegate)

        let ctx = HeliosTimerContext(app: heliosApp, queues: app.queues)
        let timer = ContextAwareTimer.builder(ctx)
        guard let contextAwareTimer = timer as? ContextAwareTimer else {
            return XCTFail("Expected ContextAwareTimer from builder")
        }
        XCTAssertEqual(contextAwareTimer.serverHost, "ctx-test")
    }
}

// MARK: - Test Fixtures

private final class LegacyTimer: HeliosTimer {
    required init() {}

    func schedule(queue: Application.Queues) {}
    func run(context: QueueContext) async throws {}
}

private struct LegacyTask: HeliosTask {
    typealias Payload = String
    init() {}

    func dequeue(_ context: QueueContext, _ payload: String) async throws {}
}

private final class ContextAwareTimer: HeliosTimer {
    let serverHost: String

    required init() {
        self.serverHost = ""
    }

    required init(context: HeliosTimerContext) {
        self.serverHost = context.app.config.runtime.environment.host
    }

    func schedule(queue: Application.Queues) {}
    func run(context: QueueContext) async throws {}
}
