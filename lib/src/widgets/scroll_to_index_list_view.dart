import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../index_alignment.dart';
import '../positioned_item_highlight.dart';
import '../positioned_list_item.dart';
import '../scrollable_positioned_controller.dart';
import '../scrollable_positioned_list.dart';

/// A drop-in `ListView.builder` with built-in scroll-to-index support.
///
/// ## Simple API — no controller needed
///
/// Use [ScrollToIndexListView.withKey] to get a [GlobalKey] that exposes
/// the internal controller, or simply omit the controller when you only
/// need `initialScrollIndex` and highlight:
///
/// ```dart
/// ScrollToIndexListView(
///   itemCount: items.length,
///   initialScrollIndex: 10,
///   enableHighlight: true,
///   itemBuilder: (context, index) => MyTile(items[index]),
/// )
/// ```
///
/// ## Flexible API — supply your own controller
///
/// ```dart
/// final _controller = ScrollablePositionedController();
///
/// ScrollToIndexListView(
///   controller: _controller,
///   itemCount: items.length,
///   enableHighlight: true,
///   itemBuilder: (context, index) => MyTile(items[index]),
/// )
///
/// // Navigate from anywhere:
/// _controller.scrollToIndex(42, alignment: IndexAlignment.center);
/// ```
class ScrollToIndexListView extends StatefulWidget {
  const ScrollToIndexListView({
    super.key,
    this.controller,
    required this.itemBuilder,
    this.itemCount,
    // ── scroll-to-index params ──────────────────────────────────────────────
    this.initialScrollIndex,
    this.initialScrollAlignment = IndexAlignment.start,
    this.enableHighlight = false,
    this.highlightDecoration,
    // ── standard ListView.builder params ────────────────────────────────────
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.primary,
    this.physics,
    this.shrinkWrap = false,
    this.padding,
    this.itemExtent,
    this.prototypeItem,
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
  /// Use this when you need to call [ScrollablePositionedController.scrollToIndex]
  /// from outside the widget tree.
  final ScrollablePositionedController? controller;

  /// Called to build children. [PositionedListItem] is wrapped automatically.
  final Widget Function(BuildContext context, int index) itemBuilder;
  final int? itemCount;

  // ── scroll-to-index ────────────────────────────────────────────────────────
  final int? initialScrollIndex;
  final double initialScrollAlignment;
  final bool enableHighlight;
  final PositionedItemHighlight? highlightDecoration;

  // ── ListView.builder passthrough ───────────────────────────────────────────
  final Axis scrollDirection;
  final bool reverse;
  final bool? primary;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final EdgeInsetsGeometry? padding;
  final double? itemExtent;
  final Widget? prototypeItem;
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
  State<ScrollToIndexListView> createState() => _ScrollToIndexListViewState();
}

class _ScrollToIndexListViewState extends State<ScrollToIndexListView> {
  // Owned only when no external controller was supplied.
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
  void didUpdateWidget(ScrollToIndexListView old) {
    super.didUpdateWidget(old);
    // External controller swapped in or out.
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
      child: ListView.builder(
        controller: _ctrl.scrollController,
        scrollDirection: widget.scrollDirection,
        reverse: widget.reverse,
        primary: widget.primary,
        physics: widget.physics,
        shrinkWrap: widget.shrinkWrap,
        padding: widget.padding,
        itemExtent: widget.itemExtent,
        prototypeItem: widget.prototypeItem,
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
