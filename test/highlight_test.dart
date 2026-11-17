import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_to_index_plus/scroll_to_index_plus.dart';

import 'harness.dart';

void main() {
  testWidgets('without highlightDuration the highlight stays', (tester) async {
    final controller = ScrollablePositionedController();
    addTearDown(controller.dispose);

    controller.highlightedIndex.value = 3;
    await tester.pump(const Duration(seconds: 30));

    expect(controller.highlightedIndex.value, 3);
    controller.clearHighlight();
    expect(controller.highlightedIndex.value, isNull);
  });

  group('with highlightDuration', () {
    late ScrollablePositionedController controller;

    setUp(() {
      controller = ScrollablePositionedController(
        highlightDuration: const Duration(seconds: 2),
      );
    });
    tearDown(() => controller.dispose());

    testWidgets('a direct assignment clears itself', (tester) async {
      controller.highlightedIndex.value = 4;

      await tester.pump(const Duration(milliseconds: 1900));
      expect(controller.highlightedIndex.value, 4);
      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.highlightedIndex.value, isNull);
    });

    testWidgets('a replaced highlight gets its own full duration',
        (tester) async {
      controller.highlightedIndex.value = 4;
      await tester.pump(const Duration(seconds: 1));
      controller.highlightedIndex.value = 6;

      await tester.pump(const Duration(milliseconds: 1500));
      expect(controller.highlightedIndex.value, 6);
      await tester.pump(const Duration(milliseconds: 600));
      expect(controller.highlightedIndex.value, isNull);
    });

    testWidgets('clearHighlight cancels the pending expiry', (tester) async {
      controller.highlightedIndex.value = 4;
      controller.clearHighlight();
      controller.highlightedIndex.value = 5;
      await tester.pump(const Duration(milliseconds: 1500));

      expect(controller.highlightedIndex.value, 5);
      await tester.pump(const Duration(seconds: 1));
      expect(controller.highlightedIndex.value, isNull);
    });

    testWidgets('time is measured from when a slow scroll finishes',
        (tester) async {
      await tester.pumpWidget(buildHarness(controller: controller));

      final done = controller.scrollToIndex(80);
      await tester.pumpAndSettle();
      await done;

      expect(controller.highlightedIndex.value, 80);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(controller.highlightedIndex.value, 80);
      await tester.pump(const Duration(milliseconds: 600));
      expect(controller.highlightedIndex.value, isNull);
    });

    testWidgets('a highlight shorter than the scroll survives the scroll',
        (tester) async {
      final quick = ScrollablePositionedController(
        highlightDuration: const Duration(milliseconds: 200),
      );
      addTearDown(quick.dispose);
      await tester.pumpWidget(
        buildHarness(controller: quick, cacheExtent: 2000),
      );

      final done = quick.scrollToIndex(10); // 380 ms animation
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(quick.highlightedIndex.value, 10);

      await tester.pumpAndSettle();
      await done;
      expect(quick.highlightedIndex.value, 10);
      await tester.pump(const Duration(milliseconds: 250));
      expect(quick.highlightedIndex.value, isNull);
    });

    testWidgets('dispose cancels a pending expiry', (tester) async {
      controller.highlightedIndex.value = 4;
      controller.dispose();

      // The test would fail on a pending timer or a write after dispose.
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
