import 'package:flutter/material.dart';

import 'index_alignment.dart';
import 'positioned_item_highlight.dart';
import 'scrollable_positioned_controller.dart';

/// Wraps your [ScrollView] to enable scroll-to-index navigation.
///
/// Place this directly above your list widget:
///
/// ```dart
/// ScrollablePositionedList(
///   controller: _controller,
///   initialScrollIndex: 15,
///   initialScrollAlignment: IndexAlignment.center,
///   enableHighlight: true,                          // optional
///   highlightDecoration: PositionedItemHighlight(   // optional
///     color: Colors.amber.withOpacity(0.15),
///     border: Border.all(color: Colors.amber, width: 2),
///   ),
///   child: ListView.builder(
///     controller: _controller.scrollController,
///     itemBuilder: (context, index) => PositionedListItem(
///       index: index,
///       child: MyTile(index),
///     ),
///   ),
/// )
/// ```
class ScrollablePositionedList extends StatefulWidget {
  const ScrollablePositionedList({
    super.key,
    required this.controller,
    required this.child,
    this.initialScrollIndex,
    this.initialScrollAlignment = IndexAlignment.center,
    this.enableHighlight = false,
    this.highlightDecoration,
  });

  final ScrollablePositionedController controller;
  final Widget child;

  /// If provided, the list jumps to this index on the very first frame.
  ///
  /// No fade is triggered — the jump happens before the user sees anything.
  final int? initialScrollIndex;

  /// Alignment used when jumping to [initialScrollIndex].
  /// Defaults to [IndexAlignment.start].
  final double initialScrollAlignment;

  /// Whether [PositionedListItem] widgets should animate a highlight decoration
  /// on the currently navigated item.
  ///
  /// When `false` (default), no extra widget is added to the tree — zero
  /// overhead for lists that do not need highlighting.
  final bool enableHighlight;

  /// Custom highlight appearance.
  ///
  /// Only used when [enableHighlight] is `true`. When `null`, a default
  /// decoration is derived from the theme's [ColorScheme.primary]:
  /// 12% opacity background + 2px solid border.
  ///
  /// See [PositionedItemHighlight] for all customization options.
  final PositionedItemHighlight? highlightDecoration;

  @override
  State<ScrollablePositionedList> createState() =>
      _ScrollablePositionedListState();
}

class _ScrollablePositionedListState extends State<ScrollablePositionedList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: widget.controller.fadeDuration,
      value: 1.0, // start fully visible
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);

    _wireCallbacks(widget.controller);

    if (widget.initialScrollIndex != null) {
      // Defer until after the first frame so the ScrollController has clients
      // and the first batch of items has been laid out.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.controller.jumpToIndex(
            widget.initialScrollIndex!,
            alignment: widget.initialScrollAlignment,
          );
        }
      });
    }
  }

  void _wireCallbacks(ScrollablePositionedController ctrl) {
    ctrl.onFadeOut = () {
      if (mounted) _fadeCtrl.reverse();
    };
    ctrl.onFadeIn = () {
      if (mounted) _fadeCtrl.forward();
    };
  }

  @override
  void didUpdateWidget(ScrollablePositionedList old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.onFadeOut = null;
      old.controller.onFadeIn = null;
      _wireCallbacks(widget.controller);
    }
  }

  @override
  void dispose() {
    widget.controller.onFadeOut = null;
    widget.controller.onFadeIn = null;
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScrollablePositionedInherited(
      controller: widget.controller,
      enableHighlight: widget.enableHighlight,
      highlightDecoration: widget.highlightDecoration,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: widget.child,
      ),
    );
  }
}

// ── Internal inherited widget ─────────────────────────────────────────────────
// Not part of the public API. Used for O(1) lookup of controller + highlight
// config from any PositionedListItem descendant.

class ScrollablePositionedInherited extends InheritedWidget {
  const ScrollablePositionedInherited({
    super.key,
    required this.controller,
    required this.enableHighlight,
    required this.highlightDecoration,
    required super.child,
  });

  final ScrollablePositionedController controller;
  final bool enableHighlight;
  final PositionedItemHighlight? highlightDecoration;

  static ScrollablePositionedInherited of(BuildContext context) {
    final result = context
        .dependOnInheritedWidgetOfExactType<ScrollablePositionedInherited>();
    assert(
      result != null,
      'No ScrollablePositionedList found in the widget tree.\n'
      'Make sure ScrollablePositionedList wraps your ScrollView.',
    );
    return result!;
  }

  @override
  bool updateShouldNotify(ScrollablePositionedInherited old) =>
      controller != old.controller ||
      enableHighlight != old.enableHighlight ||
      highlightDecoration != old.highlightDecoration;
}
