import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../index_alignment.dart';
import '../positioned_item_highlight.dart';
import '../scrollable_positioned_controller.dart';
import '../scrollable_positioned_list.dart';

/// A drop-in `SingleChildScrollView` with built-in scroll-to-index support.
///
/// ## Simple API — no controller needed
///
/// ```dart
/// ScrollToIndexSingleChildScrollView(
///   initialScrollIndex: 5,
///   enableHighlight: true,
///   child: Column(
///     children: [
///       for (int i = 0; i < items.length; i++)
///         PositionedListItem(index: i, child: MyTile(items[i])),
///     ],
///   ),
/// )
/// ```
///
/// ## Flexible API — supply your own controller
///
/// ```dart
/// final _controller = ScrollablePositionedController();
///
/// ScrollToIndexSingleChildScrollView(
///   controller: _controller,
///   child: Column(...),
/// )
///
/// _controller.scrollToIndex(5, alignment: IndexAlignment.center);
/// ```
class ScrollToIndexSingleChildScrollView extends StatefulWidget {
  const ScrollToIndexSingleChildScrollView({
    super.key,
    this.controller,
    required this.child,
    // ── scroll-to-index params ──────────────────────────────────────────────
    this.initialScrollIndex,
    this.initialScrollAlignment = IndexAlignment.start,
    this.enableHighlight = false,
    this.highlightDecoration,
    // ── standard SingleChildScrollView params ───────────────────────────────
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.padding,
    this.primary,
    this.physics,
    this.dragStartBehavior = DragStartBehavior.start,
    this.clipBehavior = Clip.hardEdge,
    this.restorationId,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
  });

  /// Optional external controller.
  ///
  /// When `null`, the widget creates and owns an internal controller.
  final ScrollablePositionedController? controller;

  /// Your scrollable content. Wrap each navigable item with [PositionedListItem].
  final Widget child;

  // ── scroll-to-index ────────────────────────────────────────────────────────
  final int? initialScrollIndex;
  final double initialScrollAlignment;
  final bool enableHighlight;
  final PositionedItemHighlight? highlightDecoration;

  // ── SingleChildScrollView passthrough ─────────────────────────────────────
  final Axis scrollDirection;
  final bool reverse;
  final EdgeInsetsGeometry? padding;
  final bool? primary;
  final ScrollPhysics? physics;
  final DragStartBehavior dragStartBehavior;
  final Clip clipBehavior;
  final String? restorationId;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  @override
  State<ScrollToIndexSingleChildScrollView> createState() =>
      _ScrollToIndexSingleChildScrollViewState();
}

class _ScrollToIndexSingleChildScrollViewState
    extends State<ScrollToIndexSingleChildScrollView> {
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
  void didUpdateWidget(ScrollToIndexSingleChildScrollView old) {
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
      child: SingleChildScrollView(
        controller: _ctrl.scrollController,
        scrollDirection: widget.scrollDirection,
        reverse: widget.reverse,
        padding: widget.padding,
        primary: widget.primary,
        physics: widget.physics,
        dragStartBehavior: widget.dragStartBehavior,
        clipBehavior: widget.clipBehavior,
        restorationId: widget.restorationId,
        keyboardDismissBehavior: widget.keyboardDismissBehavior,
        child: widget.child,
      ),
    );
  }
}
