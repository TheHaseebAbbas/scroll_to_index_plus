import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_to_index_plus/scroll_to_index_plus.dart';

import 'harness.dart';

void main() {
  late ScrollablePositionedController controller;

  setUp(() => controller = ScrollablePositionedController());
  tearDown(() => controller.dispose());

  group('detached and disposed controllers', () {
    testWidgets('never attached asserts in debug', (tester) async {
      await expectLater(controller.scrollToIndex(1), throwsAssertionError);
      expect(() => controller.jumpToIndex(1), throwsAssertionError);
    });

    testWidgets('detached after having been attached returns quietly',
        (tester) async {
      await tester.pumpWidget(buildHarness(controller: controller));
      await tester.pumpWidget(const SizedBox());
      expect(controller.scrollController.hasClients, isFalse);

      await controller.scrollToIndex(3);
      controller.jumpToIndex(3);
      await controller.ensureIndexVisible(3);

      expect(controller.highlightedIndex.value, isNull);
    });

    testWidgets('after dispose calls return quietly', (tester) async {
      await tester.pumpWidget(buildHarness(controller: controller));
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      controller.dispose(); // idempotent

      await controller.scrollToIndex(3);
      controller.jumpToIndex(3);
      await controller.ensureIndexVisible(3);
      controller.clearHighlight();
      expect(controller.isIndexBuilt(3), isFalse);
    });

    testWidgets('dispose during a slow-path scroll stops it', (tester) async {
      await tester.pumpWidget(buildHarness(controller: controller));

      final done = controller.scrollToIndex(80);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      controller.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await done;

      expect(tester.takeException(), isNull);
    });
  });

  group('frame-driven slow path', () {
    testWidgets('completes under pumpAndSettle without runAsync',
        (tester) async {
      await tester.pumpWidget(buildHarness(controller: controller));
      expect(controller.isIndexBuilt(80), isFalse);

      final done = controller.scrollToIndex(80);
      await tester.pumpAndSettle();
      await done;

      expect(controller.isIndexBuilt(80), isTrue);
      expect(controller.liveOffsetOf(80), 8000);
      expect(listOpacity(tester), 1.0);
    });

    testWidgets('gives up after buildTimeout and restores the fade',
        (tester) async {
      await tester.pumpWidget(
        buildHarness(controller: controller, count: 100),
      );

      // Label 500 does not exist, so the item never builds.
      final done = controller.scrollToIndex(500);
      await tester.pumpAndSettle();
      await done;

      expect(controller.isIndexBuilt(500), isFalse);
      expect(listOpacity(tester), 1.0);
    });
  });

  group('cancellation', () {
    testWidgets('newer call during the fade wait wins', (tester) async {
      await tester.pumpWidget(buildHarness(controller: controller));

      final first = controller.scrollToIndex(80);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final second = controller.scrollToIndex(3);
      await tester.pumpAndSettle();
      await first;
      await second;

      expect(controller.scrollController.offset, 300);
      expect(controller.highlightedIndex.value, 3);
      expect(listOpacity(tester), 1.0);
    });

    testWidgets('newer slow call during the build wait wins', (tester) async {
      await tester.pumpWidget(buildHarness(controller: controller));

      final first = controller.scrollToIndex(80);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final second = controller.scrollToIndex(5);
      await tester.pumpAndSettle();
      await first;
      await second;

      expect(controller.liveOffsetOf(5), 500);
      expect(controller.scrollController.offset, 500);
      expect(listOpacity(tester), 1.0);
    });

    testWidgets('jumpToIndex supersedes a scroll in flight', (tester) async {
      await tester.pumpWidget(buildHarness(controller: controller));

      final first = controller.scrollToIndex(80);
      await tester.pump();
      controller.jumpToIndex(2);
      await tester.pumpAndSettle();
      await first;

      expect(controller.scrollController.offset, 200);
      expect(listOpacity(tester), 1.0);
    });
  });

  group('1.0.0 behaviour', () {
    testWidgets('fast path animates and highlights', (tester) async {
      await tester.pumpWidget(buildHarness(
        controller: controller,
        cacheExtent: 2000,
        enableHighlight: true,
      ));

      final done = controller.scrollToIndex(10);
      await tester.pump();
      expect(listOpacity(tester), 1.0); // no fade on the fast path
      await tester.pumpAndSettle();
      await done;

      expect(controller.scrollController.offset,
          closeTo(controller.liveOffsetOf(10)!, 0.5)); // highlight adds a border
      expect(controller.highlightedIndex.value, 10);
    });

    testWidgets('highlight: false leaves the highlight alone', (tester) async {
      await tester.pumpWidget(buildHarness(controller: controller));

      final done = controller.scrollToIndex(3, highlight: false);
      await tester.pumpAndSettle();
      await done;

      expect(controller.highlightedIndex.value, isNull);
    });

    testWidgets('jumpToIndex jumps immediately', (tester) async {
      await tester.pumpWidget(buildHarness(controller: controller));

      controller.jumpToIndex(4);

      expect(controller.scrollController.offset, 400);
      expect(controller.highlightedIndex.value, 4);
    });

    test('default parameters are unchanged', () {
      final c = ScrollablePositionedController();
      addTearDown(c.dispose);

      expect(c.fadeDuration, const Duration(milliseconds: 150));
      expect(c.scrollDuration, const Duration(milliseconds: 380));
      expect(c.scrollCurve, Curves.easeInOut);
      expect(c.buildTimeout, const Duration(milliseconds: 600));
      expect(c.highlightDuration, isNull);
    });
  });
}
