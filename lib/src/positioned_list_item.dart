import 'package:flutter/material.dart';

import '/src/positioned_item_highlight.dart';
import 'scrollable_positioned_controller.dart';
import 'scrollable_positioned_list.dart';

/// Wraps a single list item to make it navigable via
/// [ScrollablePositionedController.scrollToIndex].
///
/// Place this at the top level of your `itemBuilder`:
///
/// ```dart
/// itemBuilder: (context, index) => PositionedListItem(
///   index: index,
///   child: MyTile(data[index]),
/// )
/// ```
///
/// **Highlight behavior**
///
/// When [ScrollablePositionedList.enableHighlight] is `true`, this widget
/// listens to [ScrollablePositionedController.highlightedIndex] and wraps
/// the child in an [AnimatedContainer] that transitions between the idle and
/// highlighted [BoxDecoration]s defined by
/// [ScrollablePositionedList.highlightDecoration] (or the built-in default).
///
/// When highlight is disabled, [build] returns [child] directly — zero
/// extra widget overhead.
class PositionedListItem extends StatefulWidget {
  const PositionedListItem({
    super.key,
    required this.index,
    required this.child,
  });

  /// The item's position in the list.
  ///
  /// Must match the index passed to
  /// [ScrollablePositionedController.scrollToIndex].
  final int index;

  final Widget child;

  @override
  State<PositionedListItem> createState() => _PositionedListItemState();
}

class _PositionedListItemState extends State<PositionedListItem> {
  ScrollablePositionedController? _controller;
  bool _enableHighlight = false;
  PositionedItemHighlight? _highlightDecoration;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final inherited = ScrollablePositionedInherited.of(context);

    _controller?.unregister(widget.index);
    _controller = inherited.controller;
    _enableHighlight = inherited.enableHighlight;
    _highlightDecoration = inherited.highlightDecoration;

    _controller!.register(widget.index, context);
  }

  @override
  void dispose() {
    _controller?.unregister(widget.index);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fast path — highlight is disabled, no extra widget in the tree.
    if (!_enableHighlight) return widget.child;

    final theme = Theme.of(context);
    final decoration = _highlightDecoration ?? const PositionedItemHighlight();

    return ValueListenableBuilder<int?>(
      valueListenable: _controller!.highlightedIndex,
      builder: (context, highlightedIndex, child) {
        final isHighlighted = highlightedIndex == widget.index;
        return AnimatedContainer(
          duration: decoration.animationDuration,
          curve: decoration.animationCurve,
          decoration: isHighlighted
              ? decoration.resolve(theme)
              : decoration.resolveIdle(theme),
          child: child,
        );
      },
      // Stable child subtree — not rebuilt when highlight changes,
      // only the decoration animates.
      child: widget.child,
    );
  }
}
