# Tasks

## 1. Test scaffold and baseline

- [x] 1.1 Create `test/` with a shared harness (a helper that builds a `ScrollablePositionedList` with a `ListView`, nested-in-Card items and variable heights). Verify `flutter test` runs one smoke test.
- [x] 1.2 Add a test that confirms the heights cache is empty after first build in 1.0.0 (item registered, `estimatedOffsetOf` uses the 80 fallback). Verify it documents the baseline, to be flipped in group 3.

## 2. Controller foundations (attach tracking, disposal, live helpers)

- [x] 2.1 Add the private tracking `ScrollController` subclass (`attach` sets `_everAttached`), plus `_disposed` and `_generation` state in `scrollable_positioned_controller.dart`. Verify `scrollController` is still typed `ScrollController` and `flutter analyze` is unchanged.
- [x] 2.2 Add the shared live-render-box helper (mounted/attached checks, the Scrollable matched by `position == scrollController.position`) and make `liveOffsetOf` use it. Verify with a test that an item inside a Card, and inside a nested horizontal scroller, resolves against the list's scrollable.
- [x] 2.3 Make `dispose` idempotent and guard `highlightedIndex` writes. Verify a test that `dispose()` twice and a call after dispose do not throw.

## 3. Visibility queries and heights cache

- [x] 3.1 Implement `isIndexBuilt` and the axis-aware `extentOf`. Verify tests: Card-nested item, size change after a frame, horizontal list returns width, unbuilt returns null/false.
- [x] 3.2 Implement `isIndexVisible(minVisible)` with the viewport-intersection geometry (clamp `minVisible`, zero-extent rule). Verify tests: fully visible, 40% visible at 0.3/0.5/1.0, built-but-outside (large cache extent), unbuilt.
- [x] 3.3 Implement `_refreshHeights()`, keep heights after unregister, and apply alignment from the live extent when built. Verify tests: scrolled-away item keeps its measurement, an item that grew before a scroll is used, and the task 1.2 baseline test is updated to the new behavior.

## 4. Sparse-label estimation

- [x] 4.1 Rewrite `estimatedOffsetOf` per design D6 (gap in known labels, gap-free extrapolation, empty fallback of 80 each). Verify unit tests for each branch, including known `{0,10,20}` with target 30, and `{0..9}` with target 500.
- [x] 4.2 Add the lazy-list widget test with labels 0, 10, 20, 30 of different heights where 30 starts unbuilt. Verify `scrollToIndex(30)` ends with 30 built at the requested alignment.
- [x] 4.3 Add a regression test for a contiguous lazy list (1000 items, target 500) showing the estimate stays at 1.0.0 scale. Verify it passes.

## 5. Robust scrollToIndex / jumpToIndex

- [x] 5.1 Return quietly when unattached or disposed, and keep the debug assert only for never-attached. Verify tests: detach-then-call, never-attached assert fires, call-after-dispose, with no throws.
- [x] 5.2 Replace `Future.delayed` and `DateTime.now()` with the frame-timestamp helper (D3) for the fade wait and the build wait. Verify a `testWidgets` slow-path scroll finishes with `pumpAndSettle` with no `runAsync` and no pending timers.
- [x] 5.3 Add the generation-token checks after every await and frame callback, and the `_fadedOut` restore (D1/D2). Verify tests: overlapping scrolls end at the newest index, and the superseded slow path leaves opacity at 1.0.
- [x] 5.4 Verify dispose during a slow-path scroll: the future completes, there are no jumps on the disposed controller and no exceptions, and the build-timeout path restores the fade.
- [x] 5.5 Verify the fast path, `jumpToIndex` and default parameter values are unchanged (1.0.0 regression tests).

## 6. ensureIndexVisible

- [x] 6.1 Implement `ensureIndexVisible` with `alignment`, `minVisible`, `highlight` (default false) and `afterFrame` using `SchedulerBinding.endOfFrame` (D8). Verify tests: already visible does not move, already visible with `highlight: true` highlights without moving, off-screen built item scrolls with `alignment: 0.1`, repeat call scrolls again after the user scrolls away, `minVisible` fraction respected.
- [x] 6.2 Test the cancel semantics. Verify: a newer call during the `afterFrame` wait wins, and a no-op `ensureIndexVisible` (item already visible) cancels an in-flight slow-path scroll to another item and leaves the list at opacity 1.0.
- [x] 6.3 Test the form-field scenario end to end. Verify with an enum-labelled form in Cards, fields at non-contiguous labels, a large cache extent, and error text appearing above the target in the same frame.

## 7. Highlight duration

- [x] 7.1 Add `highlightDuration` to the constructor and implement the listener-armed `Timer` (D9), including re-arm on scroll completion and cancel on clear, replace and dispose. Verify tests with `tester.pump(duration)`: clears after the duration, replacement is not cleared early, a slow scroll does not consume it, and no pending timer remains after dispose.
- [x] 7.2 Verify that the default (`null`) keeps the highlight until `clearHighlight`.

## 8. Docs, example, version, analyzer

- [x] 8.1 Migrate the 3 `cacheExtent` usages in `lib/src/widgets/` to `scrollCacheExtent` (keeping the widgets' public `cacheExtent` parameter), and raise the `flutter` (>=3.41.0) and Dart SDK constraints in `pubspec.yaml` and `example/pubspec.yaml`. Verify `flutter analyze` reports no issues and a widget test shows the cache extent still builds off-screen items.
- [x] 8.2 Add the README section "Scrolling to an invalid form field" (enum-label pattern with `PositionedListItem(index: Field.name.index, ...)` and `ensureIndexVisible(Field.name.index, alignment: 0.1)`, the built-fields and large-cache-extent requirement, and the sparse-label best-effort note). Also document the new API under the README's API section and `highlightDuration`. Verify the snippets compile by comparing with the example.
- [x] 8.3 Add a short form demo to the example app (enum fields in Cards, a Save button that validates and scrolls to the first invalid field). Verify `flutter analyze` in `example/` is clean and the demo runs.
- [x] 8.4 Bump `pubspec.yaml` (and the README install snippet, if it names a version) to 2.0.0 and add the CHANGELOG 2.0.0 entry, including the behavior notes (horizontal measurement, sparse estimates, no throw after dispose) and the raised minimum Flutter version as a breaking toolchain change. Verify the CHANGELOG matches the final API.

## 9. Final integration

- [x] 9.1 Run `flutter analyze` (package and example) and `flutter test`. Verify both are clean.
- [x] 9.2 Compare the exported public API against 1.0.0. Verify nothing is removed or renamed, no defaults changed and no dependencies added, then list the new public API in the final message.

## Workflow follow-up

- Archive the change after review (`/opsx:archive`).
