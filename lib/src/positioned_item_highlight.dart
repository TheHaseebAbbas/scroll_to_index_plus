import 'package:flutter/material.dart';

/// Defines the visual appearance of a highlighted [PositionedListItem].
///
/// Pass a custom instance to [ScrollablePositionedList.highlightDecoration]
/// to override the default theme-derived style.
///
/// ```dart
/// ScrollablePositionedList(
///   controller: _controller,
///   enableHighlight: true,
///   highlightDecoration: PositionedItemHighlight(
///     color: Colors.amber.withOpacity(0.15),
///     border: Border.all(color: Colors.amber, width: 2),
///     borderRadius: BorderRadius.circular(16),
///     animationDuration: Duration(milliseconds: 300),
///   ),
///   child: ListView.builder(...),
/// )
/// ```
class PositionedItemHighlight {
  const PositionedItemHighlight({
    this.color,
    this.border,
    this.borderRadius,
    this.animationDuration = const Duration(milliseconds: 250),
    this.animationCurve = Curves.easeInOut,
  });

  /// Background tint when highlighted.
  /// Defaults to the theme's [ColorScheme.primary] at 12% opacity.
  final Color? color;

  /// Border when highlighted.
  /// Defaults to a 2px solid line in the theme's [ColorScheme.primary].
  final BoxBorder? border;

  /// Corner radius of the highlight container.
  /// Defaults to [BorderRadius.circular(8)].
  final BorderRadius? borderRadius;

  /// Duration of the transition in and out of the highlighted state.
  final Duration animationDuration;

  /// Curve of the highlight transition.
  final Curve animationCurve;

  /// Resolves the highlighted [BoxDecoration] using [theme] for fallback values.
  BoxDecoration resolve(ThemeData theme) {
    final primary = theme.colorScheme.primary;
    return BoxDecoration(
      color: color ?? primary.withValues(alpha: 0.12),
      border: border ?? Border.all(color: primary, width: 2),
      borderRadius: borderRadius ?? BorderRadius.circular(8),
    );
  }

  /// Resolves the idle (non-highlighted) [BoxDecoration].
  ///
  /// Uses transparent colors but the same shape so [AnimatedContainer] can
  /// tween smoothly between the two states.
  BoxDecoration resolveIdle(ThemeData theme) {
    return BoxDecoration(
      color: Colors.transparent,
      border: Border.all(color: Colors.transparent, width: 2),
      borderRadius: borderRadius ?? BorderRadius.circular(8),
    );
  }
}
