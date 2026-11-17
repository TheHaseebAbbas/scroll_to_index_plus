import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_to_index_plus/scroll_to_index_plus.dart';

import 'harness.dart';

void main() {
  late ScrollablePositionedController controller;

  setUp(() => controller = ScrollablePositionedController());
  tearDown(() => controller.dispose());

  group('isIndexBuilt / extentOf', () {
    testWidgets('item nested in a Card is built and measured', (tester) async {
      await tester.pumpWidget(buildHarness(controller: controller));

      expect(controller.isIndexBuilt(0), isTrue);
      expect(controller.extentOf(0), 100);
      expect(controller.isIndexBuilt(50), isFalse);
      expect(controller.extentOf(50), isNull);
    });

    testWidgets('reports the new size after the item grows', (tester) async {
      final extra = {2: ValueNotifier<double>(0)};
      await tester.pumpWidget(
        buildHarness(controller: controller, extraHeight: extra),
      );
      expect(controller.extentOf(2), 100);

      extra[2]!.value = 60;
      await tester.pump();

      expect(controller.extentOf(2), 160);
    });

    testWidgets('horizontal lists report the width', (tester) async {
      await tester.pumpWidget(buildHarness(
        controller: controller,
        axis: Axis.horizontal,
        heightOf: (_) => 150,
      ));

      expect(controller.extentOf(0), 150);
    });

    testWidgets('item nested in an unrelated scroller uses the list axis',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: ScrollablePositionedList(
              controller: controller,
              child: ListView.builder(
                controller: controller.scrollController,
                itemCount: 20,
                itemBuilder: (_, i) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: PositionedListItem(
                    index: i,
                    child: const SizedBox(width: 900, height: 100),
                  ),
                ),
              ),
            ),
          ),
        ),
      ));

      expect(controller.extentOf(1), 100);
      expect(controller.liveOffsetOf(1), 100);
      expect(controller.isIndexVisible(1), isTrue);
    });

    testWidgets('queries are safe before the controller is attached',
        (tester) async {
      expect(controller.isIndexBuilt(0), isFalse);
      expect(controller.extentOf(0), isNull);
      expect(controller.isIndexVisible(0), isFalse);
    });
  });

  group('isIndexVisible', () {
    testWidgets('fully visible item', (tester) async {
      await tester.pumpWidget(buildHarness(controller: controller));

      expect(controller.isIndexVisible(0), isTrue);
      expect(controller.isIndexVisible(5), isTrue); // 500..600, flush edge
    });

    testWidgets('partially visible item honours minVisible', (tester) async {
      await tester.pumpWidget(buildHarness(controller: controller));
      controller.scrollController.jumpTo(60); // item 0: 40% visible
      await tester.pump();

      expect(controller.isIndexVisible(0, minVisible: 0.3), isTrue);
      expect(controller.isIndexVisible(0, minVisible: 0.5), isFalse);
      expect(controller.isIndexVisible(0), isFalse);
    });

    testWidgets('built because of the cache extent but outside the viewport',
        (tester) async {
      await tester.pumpWidget(
        buildHarness(controller: controller, cacheExtent: 2000),
      );

      expect(controller.isIndexBuilt(10), isTrue);
      expect(controller.isIndexVisible(10), isFalse);
    });

    testWidgets('not built is not visible', (tester) async {
      await tester.pumpWidget(buildHarness(controller: controller));

      expect(controller.isIndexVisible(50, minVisible: 0), isFalse);
    });
  });
}
