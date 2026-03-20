import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../index_alignment.dart';
import '../positioned_item_highlight.dart';
import '../positioned_list_item.dart';
import '../scrollable_positioned_controller.dart';
import '../scrollable_positioned_list.dart';

/// A drop-in `GridView.builder` with built-in scroll-to-index support.
///
/// ## Simple API — no controller needed
///
/// ```dart
/// ScrollToIndexGridView(
///   itemCount: items.length,
///   initialScrollIndex: 10,
///   enableHighlight: true,
///   gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
///   itemBuilder: (context, index) => MyCell(items[index]),
/// )
/// ```
///
/// ## Flexible API — supply your own controller
///
/// ```dart
/// final _controller = ScrollablePositionedController();
///
/// ScrollToIndexGridView(
///   controller: _controller,
///   itemCount: items.length,
///   gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
///   itemBuilder: (context, index) => MyCell(items[index]),
/// )
///
/// _controller.scrollToIndex(42, alignment: IndexAlignment.center);
/// ```
class ScrollToIndexGridView extends StatefulWidget {
  const ScrollToIndexGridView({
    super.key,
    this.controller,
    required this.gridDelegate,
    required this.itemBuilder,
    this.itemCount,
    // ── scroll-to-index params ──────────────────────────────────────────────
    this.initialScrollIndex,
    this.initialScrollAlignment = IndexAlignment.start,
    this.enableHighlight = false,
    this.highlightDecoration,
    // ── standard GridView.builder params ────────────────────────────────────
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.primary,
    this.physics,
    this.shrinkWrap = false,
    this.padding,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
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
  final SliverGridDelegate gridDelegate;

  /// Called to build children. [PositionedListItem] is wrapped automatically.
  final Widget Function(BuildContext context, int index) itemBuilder;
  final int? itemCount;

  // ── scroll-to-index ────────────────────────────────────────────────────────
  final int? initialScrollIndex;
  final double initialScrollAlignment;
  final bool enableHighlight;
  final PositionedItemHighlight? highlightDecoration;

  // ── GridView.builder passthrough ───────────────────────────────────────────
  final Axis scrollDirection;
  final bool reverse;
  final bool? primary;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final EdgeInsetsGeometry? padding;
  final bool addAutomaticKeepAlives;
  final bool addRepaintBoundaries;
  final bool addSemanticIndexes;
  final double? cacheExtent;
  final int? semanticChildCount;
  final DragStartBehavior dragStartBehavior;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final String? restorationId;
  final Clip clipBehavior;

  @override
  State<ScrollToIndexGridView> createState() => _ScrollToIndexGridViewState();
}

class _ScrollToIndexGridViewState extends State<ScrollToIndexGridView> {
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
  void didUpdateWidget(ScrollToIndexGridView old) {
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
      child: GridView.builder(
        controller: _ctrl.scrollController,
        gridDelegate: widget.gridDelegate,
        scrollDirection: widget.scrollDirection,
        reverse: widget.reverse,
        primary: widget.primary,
        physics: widget.physics,
        shrinkWrap: widget.shrinkWrap,
        padding: widget.padding,
        addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
        addRepaintBoundaries: widget.addRepaintBoundaries,
        addSemanticIndexes: widget.addSemanticIndexes,
        cacheExtent: widget.cacheExtent,
        semanticChildCount: widget.semanticChildCount,
        dragStartBehavior: widget.dragStartBehavior,
        keyboardDismissBehavior: widget.keyboardDismissBehavior,
        restorationId: widget.restorationId,
        clipBehavior: widget.clipBehavior,
        itemCount: widget.itemCount,
        itemBuilder: (context, index) => PositionedListItem(
          index: index,
          child: widget.itemBuilder(context, index),
        ),
      ),
    );
  }
}
