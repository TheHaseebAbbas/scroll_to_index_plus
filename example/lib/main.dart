import 'package:flutter/material.dart';
import 'package:scroll_to_index_plus/scroll_to_index_plus.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'scroll_to_index example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00BFA5),
          brightness: Brightness.dark,
        ),
      ),
      home: const RootScreen(),
    );
  }
}

// ── Shared fake data ────────────────────────────────────────────────────────

const _descriptions = [
  'Short.',
  'A bit longer description that wraps to two lines on a narrow screen.',
  'Medium length text.',
  'This is a much longer description that will definitely cause the tile to '
      'grow taller because it contains a lot of words and will wrap across '
      'several lines when rendered inside a constrained list item.',
  'Tiny.',
  'Another moderately sized piece of text that might wrap once.',
  'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod '
      'tempor incididunt ut labore et dolore magna aliqua.',
  'Just a sentence.',
  'Two sentences here. This is the second one.',
  'A very short item.',
];

String descFor(int i) => '${_descriptions[i % _descriptions.length]} (item $i)';

// ── Root screen ─────────────────────────────────────────────────────────────

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('scroll_to_index'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'ListView'),
            Tab(text: 'GridView'),
            Tab(text: 'CustomScrollView'),
            Tab(text: 'SingleChildScrollView'),
            Tab(text: 'Manual (lower-level)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _ListViewExample(),
          _GridViewExample(),
          _CustomScrollViewExample(),
          _SingleChildScrollViewExample(),
          _ManualExample(),
        ],
      ),
    );
  }
}

// ── 1. ScrollToIndexListView ─────────────────────────────────────────────────
// Demonstrates the simple API: controller is created internally by the widget.
// We still keep a reference via an external controller for the NavBar.

class _ListViewExample extends StatefulWidget {
  const _ListViewExample();

  @override
  State<_ListViewExample> createState() => _ListViewExampleState();
}

class _ListViewExampleState extends State<_ListViewExample> with AutomaticKeepAliveClientMixin {
  static const _count = 80;

  final _controller = ScrollablePositionedController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _NavBar(
          itemCount: _count,
          onNavigate: (i) => _controller.scrollToIndex(i, alignment: IndexAlignment.center),
        ),
        Expanded(
          child: ScrollToIndexListView(
            controller: _controller,
            itemCount: _count,
            initialScrollIndex: 12,
            initialScrollAlignment: IndexAlignment.center,
            enableHighlight: true,
            itemBuilder: (context, index) => ListTile(
              leading: CircleAvatar(child: Text('$index')),
              title: Text(descFor(index)),
            ),
          ),
        ),
      ],
    );
  }
}

// ── 2. ScrollToIndexGridView — flexible API (external controller) ───────────

class _GridViewExample extends StatefulWidget {
  const _GridViewExample();

  @override
  State<_GridViewExample> createState() => _GridViewExampleState();
}

class _GridViewExampleState extends State<_GridViewExample> with AutomaticKeepAliveClientMixin {
  static const _count = 80;

  // Flexible API: own the controller to drive navigation from a button.
  final _controller = ScrollablePositionedController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _NavBar(
          itemCount: _count,
          onNavigate: (i) => _controller.scrollToIndex(i, alignment: IndexAlignment.center),
        ),
        Expanded(
          child: ScrollToIndexGridView(
            controller: _controller, // pass external controller
            itemCount: _count,
            initialScrollIndex: 12,
            initialScrollAlignment: IndexAlignment.center,
            enableHighlight: true,
            highlightDecoration: PositionedItemHighlight(
              color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.2),
              border: Border.all(
                color: Theme.of(context).colorScheme.tertiary,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
              animationDuration: const Duration(milliseconds: 300),
              animationCurve: Curves.easeOutBack,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemBuilder: (context, index) => Card(
              margin: EdgeInsets.zero,
              child: Center(
                child: Text(
                  '$index',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── 3. ScrollToIndexCustomScrollView — flexible API, mixed slivers ──────────

class _CustomScrollViewExample extends StatefulWidget {
  const _CustomScrollViewExample();

  @override
  State<_CustomScrollViewExample> createState() => _CustomScrollViewExampleState();
}

class _CustomScrollViewExampleState extends State<_CustomScrollViewExample> with AutomaticKeepAliveClientMixin {
  static const _listCount = 20;
  static const _gridCount = 20;

  // Grid items are offset by _listCount so indices don't clash.
  static int gridIndex(int i) => _listCount + i;

  final _controller = ScrollablePositionedController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _NavBar(
                label: 'List',
                itemCount: _listCount,
                onNavigate: (i) => _controller.scrollToIndex(
                  i,
                  alignment: IndexAlignment.center,
                ),
              ),
            ),
            Expanded(
              child: _NavBar(
                label: 'Grid',
                itemCount: _gridCount,
                onNavigate: (i) => _controller.scrollToIndex(
                  gridIndex(i),
                  alignment: IndexAlignment.center,
                ),
              ),
            ),
          ],
        ),
        Expanded(
          child: ScrollToIndexCustomScrollView(
            controller: _controller,
            enableHighlight: true,
            slivers: [
              const SliverToBoxAdapter(
                child: _SectionHeader('List section (indices 0–19)'),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => PositionedListItem(
                    index: index, // 0 … _listCount-1
                    child: ListTile(
                      leading: CircleAvatar(child: Text('$index')),
                      title: Text(descFor(index)),
                    ),
                  ),
                  childCount: _listCount,
                ),
              ),
              const SliverToBoxAdapter(
                child: _SectionHeader('Grid section (indices 20–39)'),
              ),
              SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => PositionedListItem(
                    index: gridIndex(index), // _listCount … _listCount+_gridCount-1
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Center(
                        child: Text(
                          '$index',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  childCount: _gridCount,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 4. ScrollToIndexSingleChildScrollView ────────────────────────────────────

class _SingleChildScrollViewExample extends StatefulWidget {
  const _SingleChildScrollViewExample();

  @override
  State<_SingleChildScrollViewExample> createState() => _SingleChildScrollViewExampleState();
}

class _SingleChildScrollViewExampleState extends State<_SingleChildScrollViewExample>
    with AutomaticKeepAliveClientMixin {
  static const _count = 30;

  final _controller = ScrollablePositionedController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _NavBar(
          itemCount: _count,
          onNavigate: (i) => _controller.scrollToIndex(i, alignment: IndexAlignment.center),
        ),
        Expanded(
          child: ScrollToIndexSingleChildScrollView(
            controller: _controller,
            initialScrollIndex: 5,
            initialScrollAlignment: IndexAlignment.center,
            enableHighlight: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < _count; i++)
                  PositionedListItem(
                    index: i,
                    child: ListTile(
                      leading: CircleAvatar(child: Text('$i')),
                      title: Text(descFor(i)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── 5. Manual (lower-level) — ScrollablePositionedList + PositionedListItem ──
//
// Use this when you need full control over the ScrollView setup,
// want to reuse the same controller across multiple lists, or need
// to access the controller outside the widget tree.

class _ManualExample extends StatefulWidget {
  const _ManualExample();

  @override
  State<_ManualExample> createState() => _ManualExampleState();
}

class _ManualExampleState extends State<_ManualExample> with AutomaticKeepAliveClientMixin {
  static const _count = 80;

  final _controller = ScrollablePositionedController(
    fadeDuration: const Duration(milliseconds: 200),
    scrollDuration: const Duration(milliseconds: 500),
    scrollCurve: Curves.easeInOutCubic,
    buildTimeout: const Duration(milliseconds: 800),
  );

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _NavBar(
          itemCount: _count,
          onNavigate: (i) => _controller.scrollToIndex(i, alignment: IndexAlignment.center),
        ),
        // Extra actions row to demo highlight-only and clearHighlight
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              const Text(
                'Highlight only:',
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
              const SizedBox(width: 8),
              for (final i in [0, 10, 20, 40])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: OutlinedButton(
                    onPressed: () => _controller.highlightedIndex.value = i,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('$i'),
                  ),
                ),
              const Spacer(),
              TextButton(
                onPressed: _controller.clearHighlight,
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
        Expanded(
          // ScrollablePositionedList wraps the ScrollView once.
          child: ScrollablePositionedList(
            controller: _controller,
            initialScrollIndex: 12,
            initialScrollAlignment: IndexAlignment.center,
            enableHighlight: true,
            highlightDecoration: const PositionedItemHighlight(
              borderRadius: BorderRadius.all(Radius.circular(0)),
              animationDuration: Duration(milliseconds: 400),
            ),
            // Use the controller's scrollController on your ScrollView.
            child: ListView.builder(
              controller: _controller.scrollController,
              itemCount: _count,
              itemBuilder: (context, index) => PositionedListItem(
                // PositionedListItem wraps each navigable item.
                index: index,
                child: ListTile(
                  leading: CircleAvatar(child: Text('$index')),
                  title: Text(descFor(index)),
                  subtitle: Text(
                    'index: $index',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shared UI helpers ───────────────────────────────────────────────────────

class _NavBar extends StatefulWidget {
  const _NavBar({
    required this.itemCount,
    required this.onNavigate,
    this.label = 'Item',
  });

  final int itemCount;
  final void Function(int index) onNavigate;
  final String label;

  @override
  State<_NavBar> createState() => _NavBarState();
}

class _NavBarState extends State<_NavBar> {
  final _textController = TextEditingController();

  void _submit() {
    final value = int.tryParse(_textController.text.trim()) ?? -1;
    if (value >= 0 && value < widget.itemCount) widget.onNavigate(value);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text(
            '${widget.label} #',
            style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _textController,
              keyboardType: TextInputType.number,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                hintText: '0–${widget.itemCount - 1}',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: _submit, child: const Text('Go')),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
