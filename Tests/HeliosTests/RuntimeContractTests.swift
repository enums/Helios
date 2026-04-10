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
        let lhs = HeliosRuntimeMetadata(name: "x", kind: .task)
        let rhs = HeliosRuntimeMetadata(name: "x", kind: .task)
        let other = HeliosRuntimeMetadata(name: "y", kind: .task)
        XCTAssertEqual(lhs, rhs)
        XCTAssertNotEqual(lhs, other)
    }

    func testMetadataHashable() {
        let meta1 = HeliosRuntimeMetadata(name: "job-a", kind: .task)
        let meta2 = HeliosRuntimeMetadata(name: "job-a", kind: .task)
        let meta3 = HeliosRuntimeMetadata(name: "job-b", kind: .timer)
        let set: Set<HeliosRuntimeMetadata> = [meta1, meta2, meta3]
        XCTAssertEqual(set.count, 2)
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

    // MARK: - Kind mismatch precondition
    //
    // These tests verify that passing the wrong `kind` to a descriptor
    // triggers a precondition failure. We cannot directly test precondition
    // crashes in XCTest without process isolation, so instead we verify
    // that correct-kind paths work and document the invariant.

    func testTaskDescriptorCorrectKindAccepted() {
        let meta = HeliosRuntimeMetadata(name: "valid", kind: .task)
        let desc = HeliosTaskDescriptor(metadata: meta) { _ in RCStubTask() }
        XCTAssertEqual(desc.metadata.kind, .task)
    }

    func testTimerDescriptorCorrectKindAccepted() {
        let meta = HeliosRuntimeMetadata(name: "valid", kind: .timer)
        let desc = HeliosTimerDescriptor(metadata: meta) { _ in RCStubTimer() }
        XCTAssertEqual(desc.metadata.kind, .timer)
    }

    func testTaskDescriptorTypeBasedCorrectKind() {
        let meta = HeliosRuntimeMetadata(name: "typed", kind: .task, criticality: .critical)
        let desc = HeliosTaskDescriptor(metadata: meta, task: RCStubTask.self)
        XCTAssertEqual(desc.metadata.kind, .task)
        XCTAssertEqual(desc.metadata.criticality, .critical)
    }

    func testTimerDescriptorTypeBasedCorrectKind() {
        let meta = HeliosRuntimeMetadata(name: "typed", kind: .timer, retryPolicy: .fixed(maxAttempts: 1))
        let desc = HeliosTimerDescriptor(metadata: meta, timer: RCStubTimer.self)
        XCTAssertEqual(desc.metadata.kind, .timer)
        XCTAssertEqual(desc.metadata.retryPolicy, .fixed(maxAttempts: 1))
    }

    // MARK: - Shutdown contract (documented behavior)
    //
    // These tests verify the shutdown contract rules are reflected in the
    // type system and metadata. Full shutdown behavior testing requires
    // integration with a running Vapor Application and is out of scope
    // for unit tests.

    func testCriticalTaskMetadataPreserved() {
        // Rule: critical tasks should be identifiable for future grace-period shutdown
        let meta = HeliosRuntimeMetadata(
            name: "critical-cleanup",
            kind: .task,
            criticality: .critical,
            retryPolicy: .fixed(maxAttempts: 3)
        )
        let desc = HeliosTaskDescriptor(metadata: meta, task: RCStubTask.self)
        XCTAssertEqual(desc.metadata.criticality, .critical)
        XCTAssertEqual(desc.metadata.retryPolicy, .fixed(maxAttempts: 3))
        // Metadata is available for shutdown coordinator to inspect
        XCTAssertEqual(desc.metadata.name, "critical-cleanup")
    }

    func testCriticalTimerMetadataPreserved() {
        let meta = HeliosRuntimeMetadata(
            name: "heartbeat",
            kind: .timer,
            criticality: .critical,
            scheduleDescription: "every 30s"
        )
        let desc = HeliosTimerDescriptor(metadata: meta, timer: RCStubTimer.self)
        XCTAssertEqual(desc.metadata.criticality, .critical)
        XCTAssertEqual(desc.metadata.scheduleDescription, "every 30s")
    }

    func testRetryPolicyLogDescriptionForShutdownDiagnostics() {
        // Rule: cancellation path must be visible in logs
        // logDescription is used in registration logging and should work
        // for all policy variants
        XCTAssertEqual(HeliosRetryPolicy.noRetry.logDescription, "none")
        XCTAssertEqual(HeliosRetryPolicy.fixed(maxAttempts: 1).logDescription, "fixed(1)")
        XCTAssertEqual(HeliosRetryPolicy.fixed(maxAttempts: 10).logDescription, "fixed(10)")
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
