import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_to_index_plus/scroll_to_index_plus.dart';

import 'harness.dart';

void main() {
  late ScrollablePositionedController controller;

  setUp(() => controller = ScrollablePositionedController());
  tearDown(() => controller.dispose());

  testWidgets('with nothing measured every unknown item counts as 80',
      (tester) async {
    expect(controller.estimatedOffsetOf(5), 400);
  });

  testWidgets('estimate uses live measured heights, not the 80 fallback',
      (tester) async {
    // 1.0.0 never captured heights on first build, so this was 20 * 80.
    await tester.pumpWidget(buildHarness(controller: controller));

    expect(controller.estimatedOffsetOf(20), 2000);
  });

  testWidgets('contiguous lazy list keeps the 1.0.0 extrapolation',
      (tester) async {
    await tester.pumpWidget(
      buildHarness(controller: controller, count: 1000),
    );

    expect(controller.estimatedOffsetOf(500), closeTo(50000, 0.5));
  });

  group('sparse labels 0, 10, 20, 30 in a lazy list', () {
    Widget sparse() => buildHarness(
          controller: controller,
          labels: const [0, 10, 20, 30],
          heightOf: (p) => const [300.0, 400.0, 500.0, 700.0][p],
        );

    testWidgets('only labels below the target count as items above it',
        (tester) async {
      await tester.pumpWidget(sparse());

      expect(controller.isIndexBuilt(20), isTrue);
      expect(controller.isIndexBuilt(30), isFalse);
      expect(controller.estimatedOffsetOf(30), 1200); // 300 + 400 + 500
      expect(controller.estimatedOffsetOf(10), 300); // only label 0
      expect(controller.estimatedOffsetOf(0), 0);
    });

    testWidgets('scrollToIndex lands on a sparse target', (tester) async {
      await tester.pumpWidget(sparse());

      final done = controller.scrollToIndex(30);
      await tester.pumpAndSettle();
      await done;

      expect(controller.isIndexBuilt(30), isTrue);
      expect(controller.liveOffsetOf(30), 1200);
      expect(controller.scrollController.offset, 1200);
    });

    testWidgets('heights stay known after the items are scrolled away',
        (tester) async {
      await tester.pumpWidget(sparse());
      expect(controller.estimatedOffsetOf(30), 1200); // measures built items

      controller.scrollController.jumpTo(1300);
      await tester.pump();
      expect(controller.isIndexBuilt(0), isFalse);

      expect(controller.estimatedOffsetOf(10), 300);
    });
  });

  testWidgets('alignment uses the live extent of a built target',
      (tester) async {
    await tester.pumpWidget(buildHarness(
      controller: controller,
      cacheExtent: 2000,
      heightOf: (p) => p == 10 ? 200 : 100,
    ));

    final done = controller.scrollToIndex(10, alignment: IndexAlignment.center);
    await tester.pumpAndSettle();
    await done;

    final top =
        controller.liveOffsetOf(10)! - controller.scrollController.offset;
    expect(top + 100, closeTo(300, 1)); // item midpoint at viewport midpoint
  });
}
