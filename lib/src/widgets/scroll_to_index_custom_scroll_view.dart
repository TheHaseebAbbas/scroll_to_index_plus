import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../index_alignment.dart';
import '../positioned_item_highlight.dart';
import '../scrollable_positioned_controller.dart';
import '../scrollable_positioned_list.dart';

/// A drop-in `CustomScrollView` with built-in scroll-to-index support.
///
/// ## Simple API — no controller needed
///
/// ```dart
/// ScrollToIndexCustomScrollView(
///   enableHighlight: true,
///   slivers: [
///     SliverList(
///       delegate: SliverChildBuilderDelegate(
///         (context, index) => PositionedListItem(
///           index: index,
///           child: MyTile(items[index]),
///         ),
///         childCount: items.length,
///       ),
///     ),
///   ],
/// )
/// ```
///
/// ## Flexible API — supply your own controller
///
/// ```dart
/// final _controller = ScrollablePositionedController();
///
/// ScrollToIndexCustomScrollView(
///   controller: _controller,
///   slivers: [...],
/// )
///
/// _controller.scrollToIndex(42, alignment: IndexAlignment.center);
/// ```
///
/// When mixing multiple slivers, offset indices per sliver to avoid clashes:
///
/// ```dart
/// // List items: 0 … listCount-1
/// // Grid items: listCount … listCount+gridCount-1
/// _controller.scrollToIndex(listCount + gridIndex);
/// ```
class ScrollToIndexCustomScrollView extends StatefulWidget {
  const ScrollToIndexCustomScrollView({
    super.key,
    this.controller,
    required this.slivers,
    // ── scroll-to-index params ──────────────────────────────────────────────
    this.initialScrollIndex,
    this.initialScrollAlignment = IndexAlignment.start,
    this.enableHighlight = false,
    this.highlightDecoration,
    // ── standard CustomScrollView params ────────────────────────────────────
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.primary,
    this.physics,
    this.scrollBehavior,
    this.shrinkWrap = false,
    this.center,
    this.anchor = 0.0,
    this.cacheExtent,
    this.semanticChildCount,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
  });

  /// Optional external controller.
  ///
  /// When `null`, the widget creates and owns an internal controller.
  final ScrollablePositionedController? controller;

  /// Your sliver widgets. Wrap items with [PositionedListItem] to register
  /// them for navigation.
  final List<Widget> slivers;

  // ── scroll-to-index ────────────────────────────────────────────────────────
  final int? initialScrollIndex;
  final double initialScrollAlignment;
  final bool enableHighlight;
  final PositionedItemHighlight? highlightDecoration;

  // ── CustomScrollView passthrough ───────────────────────────────────────────
  final Axis scrollDirection;
  final bool reverse;
  final bool? primary;
  final ScrollPhysics? physics;
  final ScrollBehavior? scrollBehavior;
  final bool shrinkWrap;
  final Key? center;
  final double anchor;
  final double? cacheExtent;
  final int? semanticChildCount;
  final DragStartBehavior dragStartBehavior;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final String? restorationId;
  final Clip clipBehavior;

  @override
  State<ScrollToIndexCustomScrollView> createState() =>
      _ScrollToIndexCustomScrollViewState();
}

class _ScrollToIndexCustomScrollViewState
    extends State<ScrollToIndexCustomScrollView> {
  ScrollablePositionedController? _internal;

  ScrollablePositionedController get _ctrl => widget.controller ?? _internal!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internal = ScrollablePositionedController();
    }
  }

  @override
  void didUpdateWidget(ScrollToIndexCustomScrollView old) {
    super.didUpdateWidget(old);
    if (old.controller == null && widget.controller != null) {
      _internal?.dispose();
      _internal = null;
    } else if (old.controller != null && widget.controller == null) {
      _internal = ScrollablePositionedController();
    }
  }

  @override
  void dispose() {
    _internal?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScrollablePositionedList(
      controller: _ctrl,
      initialScrollIndex: widget.initialScrollIndex,
      initialScrollAlignment: widget.initialScrollAlignment,
      enableHighlight: widget.enableHighlight,
      highlightDecoration: widget.highlightDecoration,
      child: CustomScrollView(
        controller: _ctrl.scrollController,
        scrollDirection: widget.scrollDirection,
        reverse: widget.reverse,
        primary: widget.primary,
        physics: widget.physics,
        scrollBehavior: widget.scrollBehavior,
        shrinkWrap: widget.shrinkWrap,
        center: widget.center,
        anchor: widget.anchor,
        cacheExtent: widget.cacheExtent,
        semanticChildCount: widget.semanticChildCount,
        dragStartBehavior: widget.dragStartBehavior,
        keyboardDismissBehavior: widget.keyboardDismissBehavior,
        restorationId: widget.restorationId,
        clipBehavior: widget.clipBehavior,
        slivers: widget.slivers,
      ),
    );
  }
}
