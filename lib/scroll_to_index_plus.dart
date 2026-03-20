/// scroll_to_index_plus
///
/// Programmatic scroll-to-index for any Flutter ScrollView.
/// Supports variable / unknown item heights via a two-phase scroll
/// hidden behind a seamless fade transition. Optional built-in highlight
/// with fully customizable decoration.
///
/// ## Drop-in widgets (simplest API)
///
/// ```dart
/// import 'package:scroll_to_index_plus/scroll_to_index_plus.dart';
///
/// final controller = ScrollablePositionedController();
///
/// // ListView
/// ScrollToIndexListView(
///   controller: controller,
///   itemCount: items.length,
///   enableHighlight: true,
///   itemBuilder: (context, index) => MyTile(items[index]),
/// )
///
/// // GridView
/// ScrollToIndexGridView(
///   controller: controller,
///   itemCount: items.length,
///   gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
///   itemBuilder: (context, index) => MyCell(items[index]),
/// )
///
/// // CustomScrollView
/// ScrollToIndexCustomScrollView(
///   controller: controller,
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
///
/// // SingleChildScrollView
/// ScrollToIndexSingleChildScrollView(
///   controller: controller,
///   child: Column(
///     children: [
///       for (int i = 0; i < items.length; i++)
///         PositionedListItem(index: i, child: MyTile(items[i])),
///     ],
///   ),
/// )
///
/// // Navigate:
/// controller.scrollToIndex(42, alignment: IndexAlignment.center);
/// controller.highlightedIndex.value = 42; // highlight only
/// controller.clearHighlight();
/// ```
///
/// ## Lower-level API (any ScrollView)
///
/// Wrap your existing ScrollView with [ScrollablePositionedList] and each
/// item with [PositionedListItem] for full control.
library scroll_to_index_plus;

// Core
export 'src/index_alignment.dart';
export 'src/positioned_item_highlight.dart';
export 'src/positioned_list_item.dart';
export 'src/scrollable_positioned_controller.dart';
export 'src/scrollable_positioned_list.dart';
// Drop-in widgets
export 'src/widgets/scroll_to_index_custom_scroll_view.dart';
export 'src/widgets/scroll_to_index_grid_view.dart';
export 'src/widgets/scroll_to_index_list_view.dart';
export 'src/widgets/scroll_to_index_single_child_scroll_view.dart';
