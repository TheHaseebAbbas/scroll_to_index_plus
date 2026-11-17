# Spec Delta

## Purpose

Defines the lifecycle-safe behavior of `scrollToIndex` and `jumpToIndex`. This covers calls on detached or disposed controllers, cancellation by newer calls, fade restoration, and timing driven by frames so the behavior is testable under fake async.

## ADDED Requirements

### Requirement: Calls on a detached controller are quiet
`scrollToIndex` and `jumpToIndex` SHALL return without throwing, without scrolling and without changing the highlight when the scroll controller currently has no clients. In debug builds, an assertion SHALL fire only if the scroll controller has never been attached.

#### Scenario: Called after detach
- **WHEN** the controller was attached earlier and the scroll view has since been removed
- **THEN** both calls return quietly in debug and release modes

#### Scenario: Never attached
- **WHEN** a call is made on a controller that has never been attached
- **THEN** a debug assertion explains that the scroll controller must be attached to a scroll view

### Requirement: Calls after dispose are quiet
After `dispose`, `scrollToIndex` and `jumpToIndex` SHALL return quietly and SHALL NOT touch the disposed scroll controller or highlight notifier. Calling `dispose` repeatedly SHALL NOT throw.

#### Scenario: Call after dispose
- **WHEN** `scrollToIndex(5)` is called after `dispose`
- **THEN** no exception is thrown

### Requirement: Dispose during an in-flight scroll
When the controller is disposed while a slow-path scroll is in progress, the scroll SHALL stop at its next step. It SHALL NOT jump, change the highlight or invoke fade callbacks afterwards, and its future SHALL complete.

#### Scenario: Dispose mid slow path
- **WHEN** an un-built target is being scrolled to and the controller is disposed before the build wait ends
- **THEN** the future completes
- **AND** no error is raised

### Requirement: Newer call cancels the older call
Each call to `scrollToIndex` or `ensureIndexVisible`, including an `ensureIndexVisible` call that ends up not moving the list, SHALL supersede any earlier scroll that is still in progress. The older call SHALL perform no further scroll or highlight work and SHALL complete its future. Only the newest call determines the final position.

#### Scenario: Two scrolls in a row
- **WHEN** `scrollToIndex(80)` is in its slow path and `scrollToIndex(5)` is called
- **THEN** the list ends at index 5
- **AND** the first call's future completes without moving the list afterwards

#### Scenario: Highlight follows the newest call
- **WHEN** two calls with `highlight: true` overlap
- **THEN** `highlightedIndex` ends as the newer call's index

### Requirement: Fade is always restored
When a slow-path scroll has faded the list out and is then cancelled or disposed, the list SHALL NOT be left faded out. A newer call SHALL restore the fade before finishing. Cancellation by dispose does not need to restore it.

#### Scenario: Superseded by a fast-path call
- **WHEN** a slow-path scroll has faded the list out and a newer call finds its target already built
- **THEN** the list fades back in
- **AND** its opacity is 1.0 once the newer call completes

### Requirement: Timing is driven by frames
Waiting during the slow path (fade duration, build timeout and polling for the target to build) SHALL be driven by frame callbacks and frame timestamps, not by `Future.delayed` or wall-clock time. The existing `fadeDuration` and `buildTimeout` semantics SHALL be kept.

#### Scenario: Widget test with pumpAndSettle
- **WHEN** a slow-path scroll is started inside a `testWidgets` body and `tester.pumpAndSettle()` is called
- **THEN** the scroll completes without `runAsync` and without leaving pending timers

#### Scenario: Target never builds
- **WHEN** the target does not build within `buildTimeout` of frame time
- **THEN** the scroll gives up, restores the fade and completes

### Requirement: 1.0.0 behavior is preserved
The fast path (target already built) SHALL still animate with `scrollDuration` and `scrollCurve`, and `jumpToIndex` SHALL still jump without animation or fade. Default parameter values and the `onFadeOut`/`onFadeIn` fields SHALL remain unchanged. The highlight SHALL still be applied when `highlight` is true.

#### Scenario: Built target
- **WHEN** the target is built
- **THEN** `scrollToIndex` animates to it without fading

#### Scenario: Jump
- **WHEN** `jumpToIndex` is called with a built target
- **THEN** the offset changes immediately
