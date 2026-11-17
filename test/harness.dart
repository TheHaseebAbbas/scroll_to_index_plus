import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:scroll_to_index_plus/scroll_to_index_plus.dart';

/// Builds a [ScrollablePositionedList] around a lazy [ListView] whose items
/// are [PositionedListItem]s nested inside a [Card] (not direct children).
///
/// * [labels] — the label of each position; defaults to `0..count-1`.
/// * [heightOf] — the main-axis size of the item at a position.
/// * [extraHeight] — optional per-label notifier adding to an item's size.
Widget buildHarness({
  required ScrollablePositionedController controller,
  int count = 100,
  List<int>? labels,
  double Function(int position)? heightOf,
  double viewport = 600,
  double cacheExtent = 250,
  Axis axis = Axis.vertical,
  bool enableHighlight = false,
  Map<int, ValueNotifier<double>>? extraHeight,
}) {
  final itemCount = labels?.length ?? count;
  double sizeOf(int position) => heightOf?.call(position) ?? 100;

  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: axis == Axis.vertical ? 400 : viewport,
          height: axis == Axis.vertical ? viewport : 400,
          child: ScrollablePositionedList(
            controller: controller,
            enableHighlight: enableHighlight,
            child: ListView.builder(
              controller: controller.scrollController,
              scrollDirection: axis,
              scrollCacheExtent: ScrollCacheExtent.pixels(cacheExtent),
              itemCount: itemCount,
              itemBuilder: (context, position) {
                final label = labels?[position] ?? position;
                final extra = extraHeight?[label];
                Widget content(double size) => Card(
                      margin: EdgeInsets.zero,
                      child: SizedBox(
                        height: axis == Axis.vertical ? size : null,
                        width: axis == Axis.horizontal ? size : null,
                        child: Text('item $label'),
                      ),
                    );
                return PositionedListItem(
                  index: label,
                  child: extra == null
                      ? content(sizeOf(position))
                      : ValueListenableBuilder<double>(
                          valueListenable: extra,
                          builder: (_, value, __) =>
                              content(sizeOf(position) + value),
                        ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

/// Opacity of the fade wrapper around the list.
double listOpacity(WidgetTester tester) {
  final fade = tester.widget<FadeTransition>(
    find
        .descendant(
          of: find.byType(ScrollablePositionedList),
          matching: find.byType(FadeTransition),
        )
        .first,
  );
  return fade.opacity.value;
}
