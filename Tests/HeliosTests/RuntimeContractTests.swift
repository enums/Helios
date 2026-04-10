//
//  RuntimeContractTests.swift
//  HeliosTests
//
//  Tests for runtime contract metadata types and descriptor integration (#27).
//

import XCTest
import Vapor
import Queues
@testable import Helios

final class RuntimeContractTests: XCTestCase {

    // MARK: - HeliosRuntimeMetadata

    func testMetadataDefaults() {
        let meta = HeliosRuntimeMetadata(name: "test", kind: .task)
        XCTAssertEqual(meta.name, "test")
        XCTAssertEqual(meta.kind, .task)
        XCTAssertEqual(meta.criticality, .normal)
        XCTAssertEqual(meta.retryPolicy, .noRetry)
        XCTAssertNil(meta.scheduleDescription)
    }

    func testMetadataFullInit() {
        let meta = HeliosRuntimeMetadata(
            name: "important-job",
            kind: .timer,
            criticality: .critical,
            retryPolicy: .fixed(maxAttempts: 3),
            scheduleDescription: "every 5 minutes"
        )
        XCTAssertEqual(meta.name, "important-job")
        XCTAssertEqual(meta.kind, .timer)
        XCTAssertEqual(meta.criticality, .critical)
        XCTAssertEqual(meta.retryPolicy, .fixed(maxAttempts: 3))
        XCTAssertEqual(meta.scheduleDescription, "every 5 minutes")
    }

    func testMetadataEquality() {
        let a = HeliosRuntimeMetadata(name: "x", kind: .task)
        let b = HeliosRuntimeMetadata(name: "x", kind: .task)
        let c = HeliosRuntimeMetadata(name: "y", kind: .task)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - HeliosRuntimeKind

    func testRuntimeKindRawValues() {
        XCTAssertEqual(HeliosRuntimeKind.task.rawValue, "task")
        XCTAssertEqual(HeliosRuntimeKind.timer.rawValue, "timer")
    }

    // MARK: - HeliosCriticality

    func testCriticalityRawValues() {
        XCTAssertEqual(HeliosCriticality.normal.rawValue, "normal")
        XCTAssertEqual(HeliosCriticality.critical.rawValue, "critical")
    }

    // MARK: - HeliosRetryPolicy

    func testRetryPolicyEquality() {
        XCTAssertEqual(HeliosRetryPolicy.noRetry, HeliosRetryPolicy.noRetry)
        XCTAssertEqual(HeliosRetryPolicy.fixed(maxAttempts: 3), HeliosRetryPolicy.fixed(maxAttempts: 3))
        XCTAssertNotEqual(HeliosRetryPolicy.noRetry, HeliosRetryPolicy.fixed(maxAttempts: 1))
        XCTAssertNotEqual(HeliosRetryPolicy.fixed(maxAttempts: 2), HeliosRetryPolicy.fixed(maxAttempts: 5))
    }

    func testRetryPolicyLogDescription() {
        XCTAssertEqual(HeliosRetryPolicy.noRetry.logDescription, "none")
        XCTAssertEqual(HeliosRetryPolicy.fixed(maxAttempts: 3).logDescription, "fixed(3)")
    }

    // MARK: - HeliosTaskDescriptor metadata

    func testTaskDescriptorConvenienceInitMetadata() {
        let desc = HeliosTaskDescriptor(name: "my-task") { _ in RCStubTask() }
        XCTAssertEqual(desc.name, "my-task")
        XCTAssertEqual(desc.metadata.kind, .task)
        XCTAssertEqual(desc.metadata.criticality, .normal)
        XCTAssertEqual(desc.metadata.retryPolicy, .noRetry)
    }

    func testTaskDescriptorFullMetadata() {
        let meta = HeliosRuntimeMetadata(
            name: "critical-task",
            kind: .task,
            criticality: .critical,
            retryPolicy: .fixed(maxAttempts: 5)
        )
        let desc = HeliosTaskDescriptor(metadata: meta) { _ in RCStubTask() }
        XCTAssertEqual(desc.metadata, meta)
        XCTAssertEqual(desc.name, "critical-task")
    }

    func testTaskDescriptorTypeBasedInit() {
        let desc = HeliosTaskDescriptor(task: RCStubTask.self)
        XCTAssertEqual(desc.name, "RCStubTask")
        XCTAssertEqual(desc.metadata.kind, .task)
    }

    func testTaskDescriptorTypeBasedInitCustomName() {
        let desc = HeliosTaskDescriptor(name: "custom", task: RCStubTask.self)
        XCTAssertEqual(desc.name, "custom")
        XCTAssertEqual(desc.metadata.kind, .task)
    }

    func testTaskDescriptorTypeBasedInitWithMetadata() {
        let meta = HeliosRuntimeMetadata(name: "retry-task", kind: .task, retryPolicy: .fixed(maxAttempts: 2))
        let desc = HeliosTaskDescriptor(metadata: meta, task: RCStubTask.self)
        XCTAssertEqual(desc.name, "retry-task")
        XCTAssertEqual(desc.metadata.retryPolicy, .fixed(maxAttempts: 2))
    }

    // MARK: - HeliosTimerDescriptor metadata

    func testTimerDescriptorConvenienceInitMetadata() {
        let desc = HeliosTimerDescriptor(name: "my-timer") { _ in RCStubTimer() }
        XCTAssertEqual(desc.name, "my-timer")
        XCTAssertEqual(desc.metadata.kind, .timer)
        XCTAssertEqual(desc.metadata.criticality, .normal)
        XCTAssertEqual(desc.metadata.retryPolicy, .noRetry)
    }

    func testTimerDescriptorFullMetadata() {
        let meta = HeliosRuntimeMetadata(
            name: "critical-timer",
            kind: .timer,
            criticality: .critical,
            retryPolicy: .fixed(maxAttempts: 2),
            scheduleDescription: "hourly"
        )
        let desc = HeliosTimerDescriptor(metadata: meta) { _ in RCStubTimer() }
        XCTAssertEqual(desc.metadata, meta)
        XCTAssertEqual(desc.name, "critical-timer")
    }

    func testTimerDescriptorTypeBasedInit() {
        let desc = HeliosTimerDescriptor(timer: RCStubTimer.self)
        XCTAssertEqual(desc.name, "RCStubTimer")
        XCTAssertEqual(desc.metadata.kind, .timer)
    }

    func testTimerDescriptorTypeBasedInitWithMetadata() {
        let meta = HeliosRuntimeMetadata(name: "scheduled-cleanup", kind: .timer, criticality: .critical)
        let desc = HeliosTimerDescriptor(metadata: meta, timer: RCStubTimer.self)
        XCTAssertEqual(desc.name, "scheduled-cleanup")
        XCTAssertEqual(desc.metadata.criticality, .critical)
    }
}

// MARK: - Test Fixtures

private struct RCStubTask: HeliosTask {
    typealias Payload = String
    init() {}
    func dequeue(_ context: QueueContext, _ payload: String) async throws {}
}

private final class RCStubTimer: HeliosTimer {
    required init() {}
    func schedule(queue: Application.Queues) {}
    func run(context: QueueContext) async throws {}
}
