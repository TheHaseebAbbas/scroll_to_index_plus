# Design

## Context

All logic lives in `ScrollablePositionedController` (`lib/src/scrollable_positioned_controller.dart`). Items register their `BuildContext` in `_registry` from `PositionedListItem.didChangeDependencies`. `ScrollablePositionedList` wires the public `onFadeOut`/`onFadeIn` callbacks to a `FadeTransition`.

Constraints that shape the approach:
- **Heights cache.** `register()` tries to cache `box.size.height`, but on first build the element has no render object yet, so the `_heights` cache is almost never populated and the estimate falls back to 80 per item. This is inferred from reading the code and should be confirmed by a test early in implementation. It is also height-only, so horizontal lists are wrong.
- **Public surface.** `onFadeOut`/`onFadeIn` are public mutable `VoidCallback?` fields, and `scrollController` is a `ScrollController`. Both must stay as they are.
- **Platform.** `cacheExtent` is deprecated on current Flutter in favor of `scrollCacheExtent` (3.41+). The package currently declares Flutter `>=3.10`, and the 3 existing analyzer infos can only be fixed properly by raising that floor (see D10).
- **Tests.** No `test/` directory exists yet. Everything must run under `testWidgets` fake async.

## Goals / Non-Goals

**Goals:**
- An additive Dart API shipped as 2.0.0 (the major bump is only for the raised Flutter floor), with 1.0.0 behavior preserved for contiguous lists.
- `scrollToIndex`, `jumpToIndex` and `ensureIndexVisible` that are safe against dispose and cancellation, and testable with `pumpAndSettle`.
- No new dependencies.

**Non-Goals:**
- Reverse lists. `liveOffsetOf` already ignores `reverse`.
- Changing `onFadeOut`/`onFadeIn` types or the fade widget.
- A heights-measuring render object or per-item size listeners.
- Any other dependency or toolchain changes beyond the Flutter floor needed for `scrollCacheExtent`.

## Decisions

### D1. Cancellation by generation token
A private `int _generation` is incremented at the start of every `scrollToIndex` that scrolls. Each call captures its token, and after every `await` and frame callback it checks `_disposed || token != _generation` and returns if true. This is cheaper and simpler than `Completer` plumbing, and the cancelled call's future completes naturally.

`ensureIndexVisible` increments the token at its start, like `scrollToIndex`, so it supersedes any older scroll even when it ends up not moving the list. After its frame wait it returns if the token changed, so a newer call wins. When it decides to scroll, it continues as the same call and does not increment a second time.

*Alternative:* cancel through a `Completer` race. Rejected as more machinery for the same result.

### D2. Fade state flag
A private `_fadedOut` is set when `onFadeOut` is called. Any call that ends without being disposed calls `onFadeIn` if `_fadedOut` is true, then clears it. A newer fast-path call checks the flag at its end and restores the fade. A newer slow-path call calling `onFadeOut` again is harmless. On dispose the flag is reset and no callback is called, because `dispose` already nulls the callbacks.

### D3. Frame-driven waiting
A private helper `_waitFrames(Duration d, token)` records the first frame's `timeStamp` using `SchedulerBinding.scheduleFrameCallback`, re-schedules itself, and completes once `timeStamp - start >= d` or the token is stale. It calls `scheduleFrame()` so idle apps still produce frames. The phase-2 build wait runs the same way. At each frame's end (post-frame callback) it checks `liveOffsetOf(index)` and finishes early when the item is built, up to the `buildTimeout` of frame time. Under `pumpAndSettle`, frames keep being scheduled until the wait ends, so the test settles without timers.

*Alternative:* `AnimationController` or `Ticker` for timing. Rejected because the controller has no `TickerProvider`, and the list state owns the only ticker.

### D4. "Never attached" tracking
`scrollController` stays declared as `ScrollController` but is created as a private subclass whose `attach` override sets `_everAttached = true`. The debug assert fires only when `!_everAttached`. When `!hasClients` and it had been attached, calls return quietly. This is exact, whereas polling `hasClients` can miss an attach-then-detach before the first call.

### D5. Live measurement and the heights cache
A private `_refreshHeights()` walks `_registry`, reads each mounted item's main-axis extent from its render box, and writes it to `_heights` (an axis-aware extent, with the axis taken from the item's `Scrollable`). It runs at the start of `scrollToIndex`, `jumpToIndex`, `estimatedOffsetOf` and `ensureIndexVisible`, and at each phase-2 tick. `unregister` leaves `_heights` alone, so scrolled-away items keep their last measurement. `register()` keeps its early attempt, which is harmless. `extentOf` reads live and does not use the cache.

The `Scrollable` for an item is chosen as the ancestor whose `position` equals `scrollController.position`. This avoids picking an unrelated nested scroller (such as a horizontal scroller inside a card).

### D6. Estimate algorithm (option A)
Given known labels `K = _registry.keys ∪ _heights.keys`, sorted:
- If `K` has a gap (some `k[i+1] - k[i] > 1`), the estimate is the sum of `extent(l)` over `l ∈ K, l < index`. An unmeasured label counts as the average.
- If `K` is gap-free, the estimate is the sum over `l ∈ K, l < index` plus `max(0, index - (max(K) + 1)) × average`. For an index below `max(K)` this reduces to the known sum. For `K = {0..9}` and a target of 500, this equals the 1.0.0 `500 × average` result up to the difference between measured and average extents.
- If `K` is empty, the estimate is `index × 80`.

The check for the 0, 10, 20, 30 test is a gap in `K`, so the sparse rule applies.

*Alternatives rejected:* an opt-in `sparseLabels` flag, because the app would have to know about it and the hybrid needs no new API. Density extrapolation, because it cannot tell an unbuilt label from a missing one.

*Known weak spot:* a contiguous list with earlier jumps may show gaps in `K` and then underestimate. Best-effort is documented in the README.

### D7. Visibility geometry
`isIndexVisible` computes the item's start and end along the main axis from `getTransformTo(scrollableRenderBox)`, and intersects `[start, start + extent]` with `[0, viewportDimension]`. The visible fraction is `overlap / extent`, and the result is `fraction >= minVisible`. For a zero extent, it is true when `start` is inside the viewport. `minVisible` is clamped to `0..1`. `extentOf` and `isIndexBuilt` share one private helper that returns the live render box (or null), including the `mounted` and `attached` checks already in `liveOffsetOf`.

### D8. `ensureIndexVisible` flow
`afterFrame` → `await SchedulerBinding.instance.endOfFrame` (with the token check), then `_refreshHeights()`, then `isIndexVisible`. If visible, it applies the highlight when requested (re-arming the expiry from D9), restores the fade if an older slow path left it out (D2), and returns without moving. Otherwise it runs the `scrollToIndex` logic for `(index, alignment, highlight)` under the same token. The default `alignment` is `IndexAlignment.start`, matching `scrollToIndex`.

### D9. Highlight expiry
`highlightedIndex` gets a listener that (re)arms a single `Timer` of `highlightDuration` whenever the value becomes non-null, cancels it when the value becomes null, and on firing clears the value only if it still equals the armed index. A `Timer` is used on purpose. A frame loop would force continuous frames, and fake async advances `Timer` under `tester.pump`. `scrollToIndex` and `ensureIndexVisible` re-arm at completion, so a slow scroll does not consume the duration. `dispose` cancels the timer before disposing the notifier. All writes to `highlightedIndex` are guarded by `_disposed`.

### D10. Analyzer cleanliness
The 3 `cacheExtent` usages in the drop-in widgets migrate to `scrollCacheExtent`, and `pubspec.yaml` raises the `flutter` constraint to `>=3.41.0` (with the Dart SDK constraint raised to match what that Flutter ships). The public `cacheExtent` parameter of the drop-in widgets keeps its name and type, and is mapped to the new Flutter parameter internally (a pixel-based cache extent). This removes the infos for real, at the cost of dropping older Flutter versions.

*Alternative:* a scoped `// ignore: deprecated_member_use`, which keeps the old floor. Rejected by the user in favor of a clean migration.

## Risks / Trade-offs

- **[Estimate underestimates for contiguous lists with gaps in the known set]** → Documented as best-effort. The phase-2 wait and the exact correction still run, and the hybrid rule keeps the common cases at 1.0.0 behavior.
- **[`endOfFrame` never completes if no frame is produced]** → `endOfFrame` schedules a frame itself, and tests must pump. This is documented in the tests and README.
- **[Frame-time timeouts differ from wall-clock timeouts]** → Equivalent while rendering. With an unrendered or backgrounded app, the wait pauses, which is acceptable.
- **[Measuring on every tick costs O(registered items)]** → Registered items are only the built ones, a small number. The work is only done during scroll calls.
- **[A no-op `ensureIndexVisible` cancels an in-flight scroll to another item]** → Intentional: the newest call wins, consistently across all scrolling calls.
- **[Raising the Flutter floor excludes apps on older Flutter]** → Called out as breaking for the toolchain in the proposal and CHANGELOG. Apps that cannot upgrade stay on 1.0.0.
- **[Behavior change for horizontal lists and sparse estimates]** → Both were wrong in 1.0.0. Listed in the CHANGELOG.

## Migration Plan

Upgrade from 1.0.0 needs no code changes, but requires Flutter 3.41 or later. Apps on older Flutter stay on `^1.0.0`, which pub resolves correctly because 2.0.0 is a new major. Rollback is by pinning 1.0.0. The version is bumped to 2.0.0 and the CHANGELOG lists the breaking toolchain change and the behavior notes.

## Open Questions

- The exact `scrollCacheExtent` type and its mapping from the existing `cacheExtent` double should be checked against Flutter 3.41 during implementation. It does not affect the specs.
