import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_to_index_plus/scroll_to_index_plus.dart';

import 'harness.dart';

/// Labels as an app would define them: an enum, with unused values and
/// cards/spacers in between, so the labels are not contiguous.
enum Field { name, email, phone, address, notes, bio, website }

void main() {
  late ScrollablePositionedController controller;

  setUp(() => controller = ScrollablePositionedController());
  tearDown(() => controller.dispose());

  group('already visible', () {
    testWidgets('does not move and completes', (tester) async {
      await tester.pumpWidget(buildHarness(controller: controller));

      final done = controller.ensureIndexVisible(2);
      await tester.pump();
      await done;

      expect(controller.scrollController.offset, 0);
      expect(controller.highlightedIndex.value, isNull);
    });

    testWidgets('afterFrame: false completes without a frame', (tester) async {
      await tester.pumpWidget(buildHarness(controller: controller));

      await controller.ensureIndexVisible(2, afterFrame: false);

      expect(controller.scrollController.offset, 0);
    });

    testWidgets('still highlights without moving', (tester) async {
      await tester.pumpWidget(buildHarness(controller: controller));

      final done = controller.ensureIndexVisible(2, highlight: true);
      await tester.pump();
      await done;

      expect(controller.scrollController.offset, 0);
      expect(controller.highlightedIndex.value, 2);
    });

    testWidgets('cancels an older scroll and restores the fade',
        (tester) async {
      await tester.pumpWidget(buildHarness(controller: controller));

      final older = controller.scrollToIndex(80);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(listOpacity(tester), lessThan(1.0));

      final newer = controller.ensureIndexVisible(2);
      await tester.pumpAndSettle();
      await older;
      await newer;

      expect(controller.scrollController.offset, 0);
      expect(listOpacity(tester), 1.0);
    });
  });

  group('not sufficiently visible', () {
    testWidgets('built but off-screen item scrolls to the alignment',
        (tester) async {
      await tester.pumpWidget(
        buildHarness(controller: controller, cacheExtent: 2000),
      );
      expect(controller.isIndexBuilt(7), isTrue);
      expect(controller.isIndexVisible(7), isFalse);

      final done = controller.ensureIndexVisible(7, alignment: 0.1);
      await tester.pumpAndSettle();
      await done;

      expect(controller.isIndexVisible(7), isTrue);
      // item top at 700, minus (600 - 100) * 0.1
      expect(controller.scrollController.offset, 650);
      expect(controller.highlightedIndex.value, isNull); // default false
    });

    testWidgets('a repeated call scrolls again', (tester) async {
      await tester.pumpWidget(
        buildHarness(controller: controller, cacheExtent: 2000),
      );

      var done = controller.ensureIndexVisible(7);
      await tester.pumpAndSettle();
      await done;
      expect(controller.isIndexVisible(7), isTrue);

      controller.scrollController.jumpTo(0);
      await tester.pump();
      expect(controller.isIndexVisible(7), isFalse);

      done = controller.ensureIndexVisible(7);
      await tester.pumpAndSettle();
      await done;
      expect(controller.isIndexVisible(7), isTrue);
    });

    testWidgets('un-built item takes the slow path', (tester) async {
      await tester.pumpWidget(buildHarness(controller: controller));

      final done = controller.ensureIndexVisible(80, highlight: true);
      await tester.pumpAndSettle();
      await done;

      expect(controller.isIndexVisible(80), isTrue);
      expect(controller.highlightedIndex.value, 80);
      expect(listOpacity(tester), 1.0);
    });

    testWidgets('minVisible fraction decides whether to scroll',
        (tester) async {
      await tester.pumpWidget(buildHarness(controller: controller));
      controller.scrollController.jumpTo(60); // item 0 is 40% visible
      await tester.pump();

      var done = controller.ensureIndexVisible(0, minVisible: 0.3);
      await tester.pumpAndSettle();
      await done;
      expect(controller.scrollController.offset, 60);

      done = controller.ensureIndexVisible(0, minVisible: 0.5);
      await tester.pumpAndSettle();
      await done;
      expect(controller.scrollController.offset, 0);
    });
  });

  group('afterFrame', () {
    testWidgets('measures after layout changes of the same frame',
        (tester) async {
      final extra = {0: ValueNotifier<double>(0)};
      await tester.pumpWidget(
        buildHarness(controller: controller, extraHeight: extra),
      );
      expect(controller.isIndexVisible(5), isTrue); // 500..600

      // Error text appears above the target in the same frame as the call.
      extra[0]!.value = 200;
      final done = controller.ensureIndexVisible(5);
      await tester.pumpAndSettle();
      await done;

      expect(controller.isIndexVisible(5), isTrue);
      expect(controller.scrollController.offset, greaterThan(0));
    });

    testWidgets('afterFrame: false measures before the layout change',
        (tester) async {
      final extra = {0: ValueNotifier<double>(0)};
      await tester.pumpWidget(
        buildHarness(controller: controller, extraHeight: extra),
      );

      extra[0]!.value = 200;
      await controller.ensureIndexVisible(5, afterFrame: false);
      await tester.pumpAndSettle();

      expect(controller.scrollController.offset, 0);
      expect(controller.isIndexVisible(5), isFalse);
    });

    testWidgets('a newer call during the frame wait wins', (tester) async {
      await tester.pumpWidget(
        buildHarness(controller: controller, cacheExtent: 2000),
      );

      final ensure = controller.ensureIndexVisible(7);
      final newer = controller.scrollToIndex(1);
      await tester.pumpAndSettle();
      await ensure;
      await newer;

      expect(controller.scrollController.offset, 100);
    });
  });

  testWidgets('scroll to the first invalid form field', (tester) async {
    // Rendered fields; others (email, address, notes) are not on this form.
    const shown = [Field.name, Field.phone, Field.bio, Field.website];
    final extra = {
      for (final f in shown) f.index: ValueNotifier<double>(0),
    };
    await tester.pumpWidget(buildHarness(
      controller: controller,
      labels: [for (final f in shown) f.index],
      heightOf: (_) => 400,
      cacheExtent: 5000, // all fields stay built
      extraHeight: extra,
    ));
    for (final f in shown) {
      expect(controller.isIndexBuilt(f.index), isTrue);
    }

    // The save failed: error text appears under name and phone, and the
    // first invalid field (bio) is off-screen.
    extra[Field.name.index]!.value = 24;
    extra[Field.phone.index]!.value = 24;
    final done =
        controller.ensureIndexVisible(Field.bio.index, alignment: 0.1);
    await tester.pumpAndSettle();
    await done;

    expect(controller.isIndexVisible(Field.bio.index), isTrue);
    // Fields above it are not re-scrolled to when already visible.
    final offset = controller.scrollController.offset;
    final again = controller.ensureIndexVisible(Field.bio.index, alignment: 0.1);
    await tester.pumpAndSettle();
    await again;
    expect(controller.scrollController.offset, offset);
  });
}
