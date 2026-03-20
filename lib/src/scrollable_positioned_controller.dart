import 'package:flutter/material.dart';

import 'index_alignment.dart';

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
  });

  final Duration fadeDuration;
  final Duration scrollDuration;
  final Curve scrollCurve;
  final Duration buildTimeout;

  /// Attach this to your [ScrollView] as its `controller:` parameter.
  final ScrollController scrollController = ScrollController();

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

  // Measured height cache — grows as items enter the viewport
  final Map<int, double> _heights = {};

  // Wired by _ScrollablePositionedListState
  VoidCallback? onFadeOut;
  VoidCallback? onFadeIn;

  // ── Internal registration ──────────────────────────────────────────────────

  /// Called by [PositionedListItem] when it enters the tree.
  void register(int index, BuildContext ctx) {
    _registry[index] = ctx;

    // Capture the RenderBox immediately — it is already attached by the time
    // didChangeDependencies runs. We avoid postFrameCallback entirely so there
    // is no window where the element can go DEFUNCT before we read it.
    final box = ctx.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      _heights[index] = box.size.height;
    }
  }

  /// Called by [PositionedListItem] when it leaves the tree.
  void unregister(int index) => _registry.remove(index);

  // ── Offset helpers ─────────────────────────────────────────────────────────

  double get _averageHeight {
    if (_heights.isEmpty) return 80.0;
    return _heights.values.reduce((a, b) => a + b) / _heights.length;
  }

  /// Precise offset derived from the live [RenderObject].
  /// Returns `null` if the item has not been built yet or is no longer active.
  double? liveOffsetOf(int index) {
    final ctx = _registry[index];
    if (ctx == null) return null;

    // Guard against defunct elements (e.g. item recycled by a lazy list).
    if (!ctx.mounted) {
      _registry.remove(index);
      return null;
    }

    final scrollable = Scrollable.of(ctx);
    final scrollBox = scrollable.context.findRenderObject() as RenderBox?;
    final itemBox = ctx.findRenderObject() as RenderBox?;
    if (scrollBox == null || itemBox == null || !itemBox.attached) return null;

    final transform = itemBox.getTransformTo(scrollBox);
    final origin = MatrixUtils.transformPoint(transform, Offset.zero);
    final axis = scrollable.widget.axis;

    return (axis == Axis.vertical ? origin.dy : origin.dx) +
        scrollController.offset;
  }

  /// Estimated offset computed by summing known + average heights.
  double estimatedOffsetOf(int index) {
    double offset = 0;
    for (int i = 0; i < index; i++) {
      offset += _heights[i] ?? _averageHeight;
    }
    return offset;
  }

  double _applyAlignment(double rawOffset, int index, double alignment) {
    if (alignment == IndexAlignment.start) return rawOffset;
    final itemHeight = _heights[index] ?? _averageHeight;
    final viewportSize = scrollController.position.viewportDimension;
    return rawOffset - (viewportSize - itemHeight) * alignment;
  }

  double _clamp(double offset) => offset.clamp(
        scrollController.position.minScrollExtent,
        scrollController.position.maxScrollExtent,
      );

  // ── Public navigation API ──────────────────────────────────────────────────

  /// Smoothly scrolls to [index].
  ///
  /// - If the item is already built → single animated scroll.
  /// - If not yet built → fades out, jumps to estimated position, waits for
  ///   the item to build, corrects to exact position, then fades back in.
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
    assert(
      scrollController.hasClients,
      'scrollController has no clients. '
      'Did you attach it to a ScrollView via controller.scrollController?',
    );

    if (highlight) highlightedIndex.value = index;

    final live = liveOffsetOf(index);

    // Fast path — item is already in the render tree
    if (live != null) {
      await scrollController.animateTo(
        _clamp(_applyAlignment(live, index, alignment)),
        duration: scrollDuration,
        curve: scrollCurve,
      );
      return;
    }

    // Slow path — item not yet built; hide the two-phase jump with a fade
    onFadeOut?.call();
    await Future<void>.delayed(fadeDuration);

    // Phase 1: rough instant jump to estimated position
    scrollController.jumpTo(_clamp(estimatedOffsetOf(index)));

    // Phase 2: poll until the item builds and registers itself
    final deadline = DateTime.now().add(buildTimeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
      final precise = liveOffsetOf(index);
      if (precise != null) {
        scrollController
            .jumpTo(_clamp(_applyAlignment(precise, index, alignment)));
        break;
      }
    }

    onFadeIn?.call();
  }

  /// Immediately jumps to [index] without animation or fade.
  ///
  /// [highlight] — set to `false` to jump without changing the highlight.
  void jumpToIndex(
    int index, {
    double alignment = IndexAlignment.start,
    bool highlight = true,
  }) {
    assert(
      scrollController.hasClients,
      'scrollController has no clients. '
      'Did you attach it to a ScrollView via controller.scrollController?',
    );
    if (highlight) highlightedIndex.value = index;
    final raw = liveOffsetOf(index) ?? estimatedOffsetOf(index);
    scrollController.jumpTo(_clamp(_applyAlignment(raw, index, alignment)));
  }

  /// Clears the current highlight without scrolling.
  void clearHighlight() => highlightedIndex.value = null;

  /// Releases the internal [ScrollController] and [ValueNotifier].
  /// Always call this in your widget's [State.dispose].
  void dispose() {
    scrollController.dispose();
    highlightedIndex.dispose();
    onFadeOut = null;
    onFadeIn = null;
  }
}
