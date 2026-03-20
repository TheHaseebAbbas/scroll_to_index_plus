/// Alignment of the target item within the viewport after scrolling.
///
/// Use with [ScrollablePositionedController.scrollToIndex] and
/// [ScrollablePositionedList.initialScrollAlignment].
///
/// ```dart
/// controller.scrollToIndex(20, alignment: IndexAlignment.center);
/// ```
abstract final class IndexAlignment {
  /// Item's leading edge aligns with the top / left of the viewport.
  static const double start = 0.0;

  /// Item is centred in the viewport.
  static const double center = 0.5;

  /// Item's trailing edge aligns with the bottom / right of the viewport.
  static const double end = 1.0;
}
