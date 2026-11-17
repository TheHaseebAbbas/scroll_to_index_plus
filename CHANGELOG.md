## 2.0.0

**Breaking (toolchain):** requires Flutter 3.41 or newer (Dart 3.11), because
the drop-in widgets now use `scrollCacheExtent`. The Dart API of 1.0.0 is
unchanged; apps on older Flutter stay on `^1.0.0`.

New
- `isIndexBuilt`, `extentOf` and `isIndexVisible(index, {minVisible})` to query
  live render objects.
- `ensureIndexVisible(index, {alignment, minVisible, highlight, afterFrame})`:
  scrolls only when the item is not already visible; waits for the next frame
  first by default. Made for "scroll to the first invalid form field".
- `highlightDuration` constructor parameter: the highlight clears itself
  (default `null` keeps it until cleared).
- Sparse labels (enum indices, ids) are supported; README section "Scrolling to
  an invalid form field" and a form demo in the example app.

Changed
- `scrollToIndex` / `jumpToIndex` return quietly before the controller is
  attached or after it is disposed (the debug assert remains only if it was
  never attached).
- A newer `scrollToIndex` / `ensureIndexVisible` / `jumpToIndex` cancels an
  older scroll; the list is never left faded out, and a disposed controller is
  never touched.
- Waiting uses frame callbacks instead of `Future.delayed` / `DateTime.now()`,
  so slow-path scrolls work with `tester.pumpAndSettle()`.
- Offset estimates use live-measured, axis-aware extents (horizontal lists use
  width). For gap-free labels the estimate is as in 1.0.0; with gaps only the
  known labels below the target count. Estimates stay best-effort until built.
- `cacheExtent` of the drop-in widgets maps to `scrollCacheExtent`.

## 1.0.0

- Initial release
- ScrollToIndexListView, ScrollToIndexGridView, ScrollToIndexCustomScrollView, ScrollToIndexSingleChildScrollView
- ScrollablePositionedList + PositionedListItem lower-level API
- Optional controller — simple API or flexible API
- Built-in highlight with PositionedItemHighlight
- Variable / unknown item heights via two-phase scroll with fade transition
- initialScrollIndex support
- IndexAlignment.start / center / end
