import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'index_alignment.dart';

/// A [ScrollController] that remembers whether it was ever attached.
class _TrackingScrollController extends ScrollController {
  _TrackingScrollController(this._onAttach);

  final VoidCallback _onAttach;

  @override
  void attach(ScrollPosition position) {
    super.attach(position);
    _onAttach();
  }
}

/// Live geometry of a registered item, resolved from its render objects.
class _LiveItem {
  const _LiveItem({
    required this.scrollable,
    required this.start,
    required this.extent,
  });

  final ScrollableState scrollable;

  /// Leading edge of the item along the main axis, relative to the
  /// scrollable's own render box.
  final double start;

  /// Main-axis size of the item.
  final double extent;
}

/// Controls scroll navigation for a [ScrollablePositionedList].
///
/// Create a single instance, keep it in your widget's [State], and call
/// [dispose] when the widget is removed from the tree.
///
/// ```dart
/// class _MyState extends State<MyWidget> {
///   final _controller = ScrollablePositionedController();
///
///   @override
///   void dispose() {
///     _controller.dispose();
///     super.dispose();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return ScrollablePositionedList(
///       controller: _controller,
///       initialScrollIndex: 10,
///       enableHighlight: true,
///       child: ListView.builder(
///         controller: _controller.scrollController,
///         itemBuilder: (context, index) => PositionedListItem(
///           index: index,
///           child: MyItemWidget(index),
///         ),
///       ),
///     );
///   }
/// }
/// ```
///
/// ## Labels
///
/// The `index` of a [PositionedListItem] is a *label*. Labels do not have to
/// be contiguous or start at zero, so enum indices or ids work. Offsets of
/// items that are not built yet are estimated from the labels the controller
/// has seen so far, and the estimate is best-effort until the item is built.
class ScrollablePositionedController {
  ScrollablePositionedController({
    /// Duration of the fade-out / fade-in when navigating to an un-built item.
    this.fadeDuration = const Duration(milliseconds: 150),

    /// Duration of the animated scroll when the target item is already visible.
    this.scrollDuration = const Duration(milliseconds: 380),

    /// Curve used for the smooth scroll animation.
    this.scrollCurve = Curves.easeInOut,

    /// How long to wait for an off-screen item to build before giving up.
    this.buildTimeout = const Duration(milliseconds: 600),

    /// How long a highlight stays before it clears itself.
    ///
    /// `null` (the default) keeps the highlight until [clearHighlight] is
    /// called or [highlightedIndex] changes.
    this.highlightDuration,
  }) {
    highlightedIndex.addListener(_armHighlightTimer);
  }

  final Duration fadeDuration;
  final Duration scrollDuration;
  final Curve scrollCurve;
  final Duration buildTimeout;

  /// When non-null, [highlightedIndex] returns to `null` this long after a
  /// highlight starts. For highlights set by [scrollToIndex] and
  /// [ensureIndexVisible] the time is measured from when the scroll finishes.
  final Duration? highlightDuration;

  /// Attach this to your [ScrollView] as its `controller:` parameter.
  late final ScrollController scrollController =
      _TrackingScrollController(() => _everAttached = true);

  /// The index of the currently highlighted item, or `null` if none.
  ///
  /// [PositionedListItem] widgets listen to this notifier and animate their
  /// decoration automatically when [ScrollablePositionedList.enableHighlight]
  /// is `true`.
  ///
  /// You can also set this directly to highlight without scrolling:
  /// ```dart
  /// controller.highlightedIndex.value = 5;
  /// ```
  final ValueNotifier<int?> highlightedIndex = ValueNotifier(null);

  // index → BuildContext (populated by PositionedListItem on build)
  final Map<int, BuildContext> _registry = {};

  // Last measured main-axis extent per label. Entries survive after the item
  // leaves the tree so estimates for items below it stay informed.
  final Map<int, double> _heights = {};

  // Wired by _ScrollablePositionedListState
  VoidCallback? onFadeOut;
  VoidCallback? onFadeIn;

  bool _disposed = false;
  bool _everAttached = false;

  // Incremented by every call that scrolls; older calls compare against it
  // after each await and stop when it has moved on.
  int _generation = 0;

  // True while a scroll started by a call has faded the list out.
  bool _fadedOut = false;

  // True while a scroll is running; the highlight timer is paused meanwhile.
  bool _scrolling = false;

  Timer? _highlightTimer;

  bool _isStale(int token) => _disposed || token != _generation;

  // ── Internal registration ──────────────────────────────────────────────────

  /// Called by [PositionedListItem] when it enters the tree.
  void register(int index, BuildContext ctx) {
    // The render object does not exist yet on the very first build, so
    // extents are measured lazily (see [_refreshHeights]).
    _registry[index] = ctx;
  }

  /// Called by [PositionedListItem] when it leaves the tree.
  ///
  /// The last measured extent stays in the cache.
  void unregister(int index) => _registry.remove(index);

  // ── Live render-object helpers ─────────────────────────────────────────────

  RenderBox? _boxOf(BuildContext ctx) {
    if (!ctx.mounted) return null;
    try {
      final box = ctx.findRenderObject();
      if (box is RenderBox && box.attached && box.hasSize) return box;
    } catch (_) {
      // Inactive element during tree surgery — treat as not built.
    }
    return null;
  }

  /// The [Scrollable] driving [scrollController] that is an ancestor of [ctx].
  ScrollableState? _scrollableOf(BuildContext ctx) {
    final positions = scrollController.positions;
    ScrollableState? found;
    ScrollableState? nearest;
    try {
      ctx.visitAncestorElements((element) {
        if (element is StatefulElement && element.state is ScrollableState) {
          final state = element.state as ScrollableState;
          nearest ??= state;
          if (positions.contains(state.position)) {
            found = state;
            return false;
          }
        }
        return true;
      });
    } catch (_) {
      return null;
    }
    return found ?? nearest;
  }

  double? _extentOfContext(BuildContext ctx) {
    final box = _boxOf(ctx);
    if (box == null) return null;
    final scrollable = _scrollableOf(ctx);
    final axis = scrollable?.widget.axis ?? Axis.vertical;
    return axis == Axis.vertical ? box.size.height : box.size.width;
  }

  _LiveItem? _resolve(int index) {
    if (_disposed) return null;
    final ctx = _registry[index];
    if (ctx == null) return null;

    // Guard against defunct elements (e.g. item recycled by a lazy list).
    if (!ctx.mounted) {
      _registry.remove(index);
      return null;
    }

    final itemBox = _boxOf(ctx);
    final scrollable = _scrollableOf(ctx);
    if (itemBox == null || scrollable == null) return null;

    final RenderObject? scrollRo;
    try {
      scrollRo = scrollable.context.findRenderObject();
    } catch (_) {
      return null;
    }
    if (scrollRo is! RenderBox || !scrollRo.attached) return null;

    final Matrix4 transform;
    try {
      transform = itemBox.getTransformTo(scrollRo);
    } catch (_) {
      return null;
    }
    final origin = MatrixUtils.transformPoint(transform, Offset.zero);
    final axis = scrollable.widget.axis;

    return _LiveItem(
      scrollable: scrollable,
      start: axis == Axis.vertical ? origin.dy : origin.dx,
      extent: axis == Axis.vertical ? itemBox.size.height : itemBox.size.width,
    );
  }

  /// Re-measures every currently built item.
  void _refreshHeights() {
    for (final entry in _registry.entries.toList()) {
      final extent = _extentOfContext(entry.value);
      if (extent != null) _heights[entry.key] = extent;
    }
  }

  // ── Visibility queries ─────────────────────────────────────────────────────

  /// Whether an item with this label is currently built and attached.
  bool isIndexBuilt(int index) => _resolve(index) != null;

  /// The live main-axis size of the item with this label (height in a
  /// vertical list, width in a horizontal one), or `null` if it is not built.
  double? extentOf(int index) => _resolve(index)?.extent;

  /// Whether at least [minVisible] (0..1) of the item's main-axis extent is
  /// inside the viewport right now.
  ///
  /// Uses the live render objects. Returns `false` when the item is not
  /// built. An item that is built only because of the cache extent but lies
  /// outside the viewport is not visible.
  bool isIndexVisible(int index, {double minVisible = 1.0}) {
    final live = _resolve(index);
    if (live == null) return false;

    final position = live.scrollable.position;
    if (!position.hasViewportDimension) return false;
    final viewport = position.viewportDimension;
    final fraction = math.max(0.0, math.min(1.0, minVisible));

    if (live.extent <= 0) {
      return live.start >= 0 && live.start <= viewport;
    }

    final overlap = math.min(live.start + live.extent, viewport) -
        math.max(live.start, 0.0);
    final visible = math.max(0.0, overlap);
    // Small tolerance for floating-point layout rounding.
    return visible + 0.01 >= live.extent * fraction;
  }

  // ── Offset helpers ─────────────────────────────────────────────────────────

  double get _averageHeight {
    if (_heights.isEmpty) return 80.0;
    return _heights.values.reduce((a, b) => a + b) / _heights.length;
  }

  /// Precise offset derived from the live [RenderObject].
  /// Returns `null` if the item has not been built yet or is no longer active.
  double? liveOffsetOf(int index) {
    final live = _resolve(index);
    if (live == null) return null;
    return live.start + live.scrollable.position.pixels;
  }

  /// Estimated offset of the item with this label.
  ///
  /// Labels may be sparse (for example enum indices or ids). The estimate is
  /// best-effort until the item is built:
  ///
  /// * If the labels seen so far contain a gap, only the labels below
  ///   [index] count as items above it.
  /// * If they form a contiguous run, labels beyond the highest known one are
  ///   extrapolated at the average extent, as in 1.0.0.
  double estimatedOffsetOf(int index) {
    _refreshHeights();

    final known = <int>{..._registry.keys, ..._heights.keys}.toList()..sort();
    final average = _averageHeight;

    var hasGap = false;
    for (var i = 1; i < known.length; i++) {
      if (known[i] - known[i - 1] > 1) {
        hasGap = true;
        break;
      }
    }

    double offset = 0;
    var knownBelow = 0;
    for (final label in known) {
      if (label >= index) break;
      offset += _heights[label] ?? average;
      knownBelow++;
    }

    // Contiguous labels: every label below [index] is assumed to exist, so
    // the ones never seen count as an average-sized item (1.0.0 behavior).
    if (!hasGap && index > knownBelow) {
      offset += (index - knownBelow) * average;
    }
    return offset;
  }

  double _applyAlignment(double rawOffset, int index, double alignment) {
    if (alignment == IndexAlignment.start) return rawOffset;
    final itemHeight = extentOf(index) ?? _heights[index] ?? _averageHeight;
    final viewportSize = scrollController.position.viewportDimension;
    return rawOffset - (viewportSize - itemHeight) * alignment;
  }

  double _clamp(double offset) => offset.clamp(
        scrollController.position.minScrollExtent,
        scrollController.position.maxScrollExtent,
      );

  // ── Frame-driven waiting ───────────────────────────────────────────────────

  /// Completes after [duration] of frame time, or as soon as [token] is stale.
  Future<void> _waitFrames(Duration duration, int token) {
    final completer = Completer<void>();
    final binding = SchedulerBinding.instance;
    Duration? start;

    void onFrame(Duration timeStamp) {
      if (_isStale(token)) {
        completer.complete();
        return;
      }
      start ??= timeStamp;
      if (timeStamp - start! >= duration) {
        completer.complete();
        return;
      }
      binding.scheduleFrameCallback(onFrame);
    }

    binding.scheduleFrameCallback(onFrame);
    return completer.future;
  }

  /// Completes with the live offset of [index] as soon as it is built, or
  /// with `null` after [buildTimeout] of frame time or when [token] is stale.
  Future<double?> _waitForBuilt(int index, int token) {
    final completer = Completer<double?>();
    final binding = SchedulerBinding.instance;
    Duration? start;

    void check(Duration timeStamp) {
      if (_isStale(token)) {
        completer.complete(null);
        return;
      }
      final precise = liveOffsetOf(index);
      if (precise != null) {
        completer.complete(precise);
        return;
      }
      start ??= timeStamp;
      if (timeStamp - start! >= buildTimeout) {
        completer.complete(null);
        return;
      }
      binding.addPostFrameCallback(check);
      binding.scheduleFrame();
    }

    binding.addPostFrameCallback(check);
    binding.scheduleFrame();
    return completer.future;
  }

  // ── Highlight timer ────────────────────────────────────────────────────────

  void _armHighlightTimer() {
    _highlightTimer?.cancel();
    _highlightTimer = null;

    final duration = highlightDuration;
    final armed = highlightedIndex.value;
    if (_disposed || _scrolling || duration == null || armed == null) return;

    _highlightTimer = Timer(duration, () {
      _highlightTimer = null;
      if (!_disposed && highlightedIndex.value == armed) {
        highlightedIndex.value = null;
      }
    });
  }

  void _setHighlight(int index) {
    if (_disposed) return;
    highlightedIndex.value = index;
  }

  // ── Scroll lifecycle bookkeeping ───────────────────────────────────────────

  /// Starts a scrolling call and returns its token. Supersedes older calls.
  int _begin() {
    _scrolling = true;
    _highlightTimer?.cancel();
    _highlightTimer = null;
    return ++_generation;
  }

  /// Ends a scrolling call. Only the newest call restores the fade and
  /// resumes the highlight timer.
  void _end(int token) {
    if (_disposed || token != _generation) return;
    if (_fadedOut) {
      _fadedOut = false;
      onFadeIn?.call();
    }
    _scrolling = false;
    _armHighlightTimer();
  }

  bool get _canScroll {
    if (_disposed) return false;
    if (!scrollController.hasClients) {
      assert(
        _everAttached,
        'scrollController has no clients and was never attached. '
        'Did you attach it to a ScrollView via controller.scrollController?',
      );
      return false;
    }
    return true;
  }

  // ── Public navigation API ──────────────────────────────────────────────────

  /// Smoothly scrolls to [index].
  ///
  /// - If the item is already built → single animated scroll.
  /// - If not yet built → fades out, jumps to estimated position, waits for
  ///   the item to build, corrects to exact position, then fades back in.
  ///
  /// A newer call to [scrollToIndex] or [ensureIndexVisible] cancels this one.
  /// Calling before the controller is attached, or after [dispose], returns
  /// quietly. A debug assertion fires only if [scrollController] was never
  /// attached to a [ScrollView].
  ///
  /// [alignment] — where the item lands in the viewport;
  /// use [IndexAlignment] constants or any `double` between 0.0 and 1.0.
  ///
  /// [highlight] — set to `false` to scroll without changing the highlight.
  /// Has no visual effect when [ScrollablePositionedList.enableHighlight]
  /// is `false`.
  Future<void> scrollToIndex(
    int index, {
    double alignment = IndexAlignment.start,
    bool highlight = true,
  }) async {
    if (!_canScroll) return;
    final token = _begin();
    try {
      await _scrollTo(index, alignment, highlight, token);
    } finally {
      _end(token);
    }
  }

  Future<void> _scrollTo(
    int index,
    double alignment,
    bool highlight,
    int token,
  ) async {
    if (highlight) _setHighlight(index);

    _refreshHeights();
    final live = liveOffsetOf(index);

    // Fast path — item is already in the render tree
    if (live != null) {
      // An older slow-path scroll may have faded the list out.
      if (_fadedOut) {
        _fadedOut = false;
        onFadeIn?.call();
      }
      await scrollController.animateTo(
        _clamp(_applyAlignment(live, index, alignment)),
        duration: scrollDuration,
        curve: scrollCurve,
      );
      return;
    }

    // Slow path — item not yet built; hide the two-phase jump with a fade
    _fadedOut = true;
    onFadeOut?.call();
    await _waitFrames(fadeDuration, token);
    if (_isStale(token) || !scrollController.hasClients) return;

    // Phase 1: rough instant jump to estimated position
    scrollController.jumpTo(_clamp(estimatedOffsetOf(index)));

    // Phase 2: wait for the item to build and register itself
    final precise = await _waitForBuilt(index, token);
    if (_isStale(token) || !scrollController.hasClients) return;
    if (precise != null) {
      _refreshHeights();
      scrollController
          .jumpTo(_clamp(_applyAlignment(precise, index, alignment)));
    }
  }

  /// Scrolls to [index] only if at least [minVisible] of it is not already
  /// inside the viewport.
  ///
  /// If the item is already sufficiently visible the scroll position does not
  /// change (the highlight is still applied when [highlight] is `true`);
  /// otherwise this behaves like [scrollToIndex]. Like every scrolling call
  /// it cancels an older scroll that is still running.
  ///
  /// With [afterFrame] (the default) it first waits for the end of the next
  /// frame, so layout changes such as error text appearing above or below the
  /// target settle before measuring.
  ///
  /// [highlight] defaults to `false`, unlike [scrollToIndex].
  Future<void> ensureIndexVisible(
    int index, {
    double alignment = IndexAlignment.start,
    double minVisible = 1.0,
    bool highlight = false,
    bool afterFrame = true,
  }) async {
    if (!_canScroll) return;
    final token = _begin();
    try {
      if (afterFrame) {
        await SchedulerBinding.instance.endOfFrame;
        if (_isStale(token) || !scrollController.hasClients) return;
      }
      _refreshHeights();
      if (isIndexVisible(index, minVisible: minVisible)) {
        if (highlight) _setHighlight(index);
        return;
      }
      await _scrollTo(index, alignment, highlight, token);
    } finally {
      _end(token);
    }
  }

  /// Immediately jumps to [index] without animation or fade.
  ///
  /// Returns quietly when called before the controller is attached or after
  /// [dispose], like [scrollToIndex].
  ///
  /// [highlight] — set to `false` to jump without changing the highlight.
  void jumpToIndex(
    int index, {
    double alignment = IndexAlignment.start,
    bool highlight = true,
  }) {
    if (!_canScroll) return;
    // A jump supersedes any scroll still in flight.
    final token = _begin();
    try {
      if (highlight) _setHighlight(index);
      _refreshHeights();
      final raw = liveOffsetOf(index) ?? estimatedOffsetOf(index);
      scrollController.jumpTo(_clamp(_applyAlignment(raw, index, alignment)));
    } finally {
      _end(token);
    }
  }

  /// Clears the current highlight without scrolling.
  void clearHighlight() {
    if (_disposed) return;
    highlightedIndex.value = null;
  }

  /// Releases the internal [ScrollController] and [ValueNotifier].
  /// Always call this in your widget's [State.dispose].
  ///
  /// Scrolls still in flight stop at their next step. Calling it more than
  /// once is harmless.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _highlightTimer?.cancel();
    _highlightTimer = null;
    highlightedIndex.removeListener(_armHighlightTimer);
    scrollController.dispose();
    highlightedIndex.dispose();
    onFadeOut = null;
    onFadeIn = null;
  }
}
