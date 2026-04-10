# Runtime Contract: Shutdown & Cancellation

> Part of Helios runtime contract (#27). This document defines the
> minimum behavioral guarantees for Task / Timer lifecycle during
> application shutdown.

## Rules

1. **No completion guarantee for in-flight work.**
   The framework does NOT guarantee that a Task or Timer already executing
   will run to successful completion when shutdown is initiated.

2. **No new work after shutdown.**
   Once shutdown begins, the framework MUST NOT accept new task dispatches
   or schedule new timer firings.

3. **No silent swallowing of cancellation.**
   If a Task or Timer is cancelled during shutdown, the cancellation MUST
   be observable — either through logging or through the error propagation
   path. The framework MUST NOT silently discard a cancellation.

4. **Cancellation path visibility.**
   When a Task or Timer is cancelled, logs MUST include enough context to
   identify which job was affected (at minimum: name + kind from its
   `HeliosRuntimeMetadata`).

## Current Implementation Status

- **Rule 1:** Inherent — Vapor/Queues does not add completion guarantees.
- **Rule 2:** Inherent — `Application.shutdown()` stops the event loop.
- **Rule 3:** Partial — errors during dequeue are logged by Queues driver,
  but cancellation-specific logging is not yet added at the Helios layer.
- **Rule 4:** Addressed in PR 1 (registration logging). Runtime failure
  logging with metadata context is a future enhancement.

## Future Work

- Add Helios-layer error logging that attaches `HeliosRuntimeMetadata`
  to task/timer failure events (beyond what the Queues driver provides).
- Consider a `HeliosShutdownCoordinator` that gives in-flight critical
  tasks a grace period before forced cancellation.
