# Proposal

## Why

A production app uses `scroll_to_index_plus` to scroll to the first invalid form field after a failed save. Its fields are `PositionedListItem`s nested in cards, with sparse enum-based labels, and all built. The package has three gaps that the app currently works around with its own code:

- The package cannot say whether an item is already in view, and the item's height is private.
- Offset estimation assumes contiguous labels.
- `scrollToIndex` throws when the controller is not attached or has been disposed, cannot be cancelled, and uses wall-clock polling that cannot be tested under fake async.

This release closes these gaps without breaking any 1.0.0 Dart API. Because it also raises the minimum Flutter version (see below), it ships as **2.0.0**, not 1.1.0.

## What Changes

- **Visibility queries** (additive): `isIndexBuilt`, `extentOf` (live, axis-aware main-axis size) and `isIndexVisible(index, minVisible)` on `ScrollablePositionedController`.
- **`ensureIndexVisible`** (additive): scrolls only when the item is not already sufficiently visible. It optionally waits one frame (`SchedulerBinding.endOfFrame`) so that layout changes, such as error text appearing, settle before measuring.
- **Sparse labels**: `estimatedOffsetOf` uses known labels only when the known labels have gaps. When the known labels are gap-free it keeps the 1.0.0 `index × average` extrapolation, so contiguous lazy lists do not regress. Estimates are best-effort until the item is built.
- **Heights cache**: heights are refreshed from live render objects at scroll and estimate time and kept after items unregister. 1.0.0 measured too early, so the cache was effectively empty. Measurement is now axis-aware (horizontal lists use width).
- **Robust navigation**:
  - `scrollToIndex` and `jumpToIndex` return quietly when called before attach or after dispose. The debug assert remains only if the controller was never attached.
  - A newer `scrollToIndex` cancels an older one. Every `await` in the slow path is guarded, and the fade is always restored.
  - `Future.delayed` and `DateTime.now()` polling are replaced by frame callbacks, so the slow path works under `pumpAndSettle`.
- **`highlightDuration`**: new optional controller constructor parameter. The default `null` keeps the highlight until cleared. The timer starts when the scroll completes.
- **Hygiene**: new `test/` suite, a README section "Scrolling to an invalid form field", a CHANGELOG 2.0.0 entry, a version bump from 1.0.0 to 2.0.0 (a major bump because of the raised Flutter floor), an example form demo, and a clean `flutter analyze`. The 3 pre-existing `cacheExtent` deprecation infos are fixed by migrating to `scrollCacheExtent`.
- **BREAKING (toolchain):** the minimum Flutter version is raised to 3.41 (with a matching Dart SDK constraint) because `scrollCacheExtent` does not exist earlier. This is why the version becomes 2.0.0. The Dart API of the package, including the drop-in widgets, does not change.
- **`ensureIndexVisible` on an already-visible item** does not move the list, but it still applies the highlight when `highlight: true` and supersedes any older in-flight scroll.

No existing parameter defaults change, nothing is renamed, and no dependencies are added.

## Capabilities

### New Capabilities
- `index-visibility`: querying whether an indexed item is built, how large it is, and how much of it is in the viewport. Includes `ensureIndexVisible`.
- `offset-estimation`: best-effort offset and extent estimation for items that are not yet built, including sparse or non-contiguous labels and a live-measured heights cache.
- `scroll-navigation`: lifecycle-safe `scrollToIndex` and `jumpToIndex` (not-attached and disposed handling, cancellation by newer calls, fade restoration, frame-driven timing).
- `highlight-lifetime`: optional auto-expiry of the highlighted index via `highlightDuration`.

### Modified Capabilities
<!-- None: the repository has no existing specs. -->

## Impact

- **Code:** `lib/src/scrollable_positioned_controller.dart` (most of the change). A small touch in `lib/src/scrollable_positioned_list.dart` only if fade wiring needs it. `lib/src/widgets/*` migrate `cacheExtent` to `scrollCacheExtent`, and `pubspec.yaml` raises the Flutter and Dart SDK constraints.
- **Public API:** additive only. New members are `isIndexBuilt`, `extentOf`, `isIndexVisible`, `ensureIndexVisible` and the `highlightDuration` constructor parameter.
- **Behavior changes:**
  - `scrollToIndex` and `jumpToIndex` no longer throw after dispose or when unattached (only a debug assert for never-attached remains).
  - Horizontal lists now measure by width instead of height.
  - Estimates for sparse labels differ from 1.0.0.
- **Tests and docs:** new `test/` directory, README, CHANGELOG, `pubspec.yaml` version, and the example app.
- **Dependencies:** none added.
- **Out of scope:** reverse lists, and changing the `onFadeOut`/`onFadeIn` public fields.
