# scroll_to_index

Programmatic scroll-to-index for any Flutter `ScrollView` — `ListView`,
`GridView`, `CustomScrollView`, `SingleChildScrollView`, and more.

Supports **variable / unknown item heights** via a two-phase scroll hidden
behind a seamless fade transition. Includes optional built-in highlight
with fully customizable decoration.

---

## Features

- Drop-in widgets: `ScrollToIndexListView`, `ScrollToIndexGridView`, `ScrollToIndexCustomScrollView`, `ScrollToIndexSingleChildScrollView`
- Lower-level API via `ScrollablePositionedList` + `PositionedListItem` for full control
- **Controller is optional** — widgets create and own one internally when none is supplied
- Variable and unknown item heights — no `extentOf` callback required
- Off-screen items reached via estimated offset → auto-corrected once built
- Two-phase jump hidden behind a configurable fade transition
- Optional built-in highlight with animated `BoxDecoration`
- Fully customizable highlight via `PositionedItemHighlight`
- Jump to an index on first render via `initialScrollIndex`
- Alignment control: `start`, `center`, or `end` of the viewport
- Zero `GlobalKey` overhead — uses `BuildContext` + `RenderObject` transforms
- Zero rebuild overhead when highlight is disabled

---

## Installation

```yaml
dependencies:
  scroll_to_index: latest
```

---

## Two APIs

Every drop-in widget supports both a **simple** and a **flexible** API.

### Simple API — no controller needed

The widget creates and manages its own controller internally. Use this when
you only need `initialScrollIndex`, highlight, and do not need to trigger
navigation from outside:

```dart
ScrollToIndexListView(
  itemCount: items.length,
  initialScrollIndex: 10,
  enableHighlight: true,
  itemBuilder: (context, index) => MyTile(items[index]),
)
```

### Flexible API — supply your own controller

Create and own a `ScrollablePositionedController` in your `State`. Pass it
to the widget so you can call `scrollToIndex` from anywhere:

```dart
class _MyState extends State<MyWidget> {
  final _controller = ScrollablePositionedController();

  @override
  void dispose() {
    _controller.dispose(); // always dispose external controllers
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () => _controller.scrollToIndex(
            42,
            alignment: IndexAlignment.center,
          ),
          child: const Text('Go to 42'),
        ),
        Expanded(
          child: ScrollToIndexListView(
            controller: _controller,
            itemCount: items.length,
            enableHighlight: true,
            itemBuilder: (context, index) => MyTile(items[index]),
          ),
        ),
      ],
    );
  }
}
```

---

## Widgets

### `ScrollToIndexListView`

Drop-in replacement for `ListView.builder`. `PositionedListItem` is wrapped
around each item automatically — your `itemBuilder` stays clean.

```dart
// Simple
ScrollToIndexListView(
  itemCount: items.length,
  initialScrollIndex: 10,
  enableHighlight: true,
  itemBuilder: (context, index) => MyTile(items[index]),
)

// Flexible
ScrollToIndexListView(
  controller: _controller,
  itemCount: items.length,
  enableHighlight: true,
  itemBuilder: (context, index) => MyTile(items[index]),
)
```

---

### `ScrollToIndexGridView`

Drop-in replacement for `GridView.builder`.

```dart
// Simple
ScrollToIndexGridView(
  itemCount: items.length,
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
  initialScrollIndex: 10,
  enableHighlight: true,
  itemBuilder: (context, index) => MyCell(items[index]),
)

// Flexible
ScrollToIndexGridView(
  controller: _controller,
  itemCount: items.length,
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
  itemBuilder: (context, index) => MyCell(items[index]),
)
```

---

### `ScrollToIndexCustomScrollView`

Drop-in replacement for `CustomScrollView`. Wrap items inside your slivers
with `PositionedListItem` manually.

When mixing multiple slivers, use **unique offsets per sliver** so indices
do not clash across sections:

```dart
const listCount = 20;
const gridCount = 20;

// Simple
ScrollToIndexCustomScrollView(
  enableHighlight: true,
  slivers: [
    SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => PositionedListItem(
          index: index,              // 0 … listCount-1
          child: MyTile(list[index]),
        ),
        childCount: listCount,
      ),
    ),
    SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
      delegate: SliverChildBuilderDelegate(
        (context, index) => PositionedListItem(
          index: listCount + index,  // listCount … listCount+gridCount-1
          child: MyCell(grid[index]),
        ),
        childCount: gridCount,
      ),
    ),
  ],
)

// Flexible — navigate to a grid cell:
_controller.scrollToIndex(listCount + 5);
```

---

### `ScrollToIndexSingleChildScrollView`

Drop-in replacement for `SingleChildScrollView`. Build children manually
and wrap each navigable item with `PositionedListItem`.

```dart
// Simple
ScrollToIndexSingleChildScrollView(
  initialScrollIndex: 5,
  enableHighlight: true,
  child: Column(
    children: [
      for (int i = 0; i < items.length; i++)
        PositionedListItem(
          index: i,
          child: MyTile(items[i]),
        ),
    ],
  ),
)

// Flexible
ScrollToIndexSingleChildScrollView(
  controller: _controller,
  child: Column(...),
)
```

---

### Lower-level API — `ScrollablePositionedList` + `PositionedListItem`

Use this when you need full control: custom durations, multiple controllers,
or a scroll view type not covered by the drop-in widgets.

```dart
final _controller = ScrollablePositionedController(
  fadeDuration: Duration(milliseconds: 200),
  scrollDuration: Duration(milliseconds: 500),
  scrollCurve: Curves.easeInOutCubic,
);

ScrollablePositionedList(
  controller: _controller,
  initialScrollIndex: 10,
  enableHighlight: true,
  highlightDecoration: PositionedItemHighlight(
    borderRadius: BorderRadius.zero,
    animationDuration: Duration(milliseconds: 400),
  ),
  child: ListView.builder(
    controller: _controller.scrollController,
    itemBuilder: (context, index) => PositionedListItem(
      index: index,
      child: MyTile(items[index]),
    ),
  ),
)
```

---

## Highlight

Enable the built-in highlight by setting `enableHighlight: true`.
The navigated item animates in and out of a `BoxDecoration` automatically —
your item widget needs no knowledge of selection state.

The default style uses the theme's `ColorScheme.primary`:
12% opacity background + 2px solid border. Override with `highlightDecoration`:

```dart
ScrollToIndexListView(
  controller: _controller,
  enableHighlight: true,
  highlightDecoration: PositionedItemHighlight(
    color: Colors.amber.withOpacity(0.15),
    border: Border.all(color: Colors.amber, width: 2),
    borderRadius: BorderRadius.circular(16),
    animationDuration: Duration(milliseconds: 300),
    animationCurve: Curves.easeOutBack,
  ),
  itemBuilder: (context, index) => MyTile(items[index]),
)
```

You can also highlight without scrolling, or clear the highlight:

```dart
_controller.highlightedIndex.value = 5; // highlight only
_controller.clearHighlight();           // remove highlight
_controller.scrollToIndex(5, highlight: false); // scroll without highlight
```

When `enableHighlight` is `false` (default), `PositionedListItem.build`
returns its child directly — zero extra widgets in the tree.

---

## API

### `ScrollablePositionedController`

**Constructor parameters**

| Parameter        | Default     | Description                                             |
| ---------------- | ----------- | ------------------------------------------------------- |
| `fadeDuration`   | `150ms`     | Fade-out / fade-in duration for off-screen navigation   |
| `scrollDuration` | `380ms`     | Animated scroll duration when target is already visible |
| `scrollCurve`    | `easeInOut` | Scroll animation curve                                  |
| `buildTimeout`   | `600ms`     | Max wait time for an off-screen item to build           |

**Properties**

| Property           | Type                  | Description                                                              |
| ------------------ | --------------------- | ------------------------------------------------------------------------ |
| `scrollController` | `ScrollController`    | Attach to your `ScrollView`'s `controller:` parameter                    |
| `highlightedIndex` | `ValueNotifier<int?>` | Currently highlighted index; set directly to highlight without scrolling |

**Methods**

| Method                                         | Description                                         |
| ---------------------------------------------- | --------------------------------------------------- |
| `scrollToIndex(index, {alignment, highlight})` | Animated scroll; fades for off-screen items         |
| `jumpToIndex(index, {alignment, highlight})`   | Instant jump, no animation or fade                  |
| `clearHighlight()`                             | Clears the current highlight without scrolling      |
| `dispose()`                                    | Releases resources — always call in `State.dispose` |

---

### Common parameters (all four drop-in widgets)

| Parameter                | Default                | Description                                                          |
| ------------------------ | ---------------------- | -------------------------------------------------------------------- |
| `controller`             | `null`                 | Optional external controller; widget owns one internally when `null` |
| `initialScrollIndex`     | `null`                 | Jump to this index on the first frame                                |
| `initialScrollAlignment` | `IndexAlignment.start` | Alignment for the initial jump                                       |
| `enableHighlight`        | `false`                | Enable the built-in item highlight                                   |
| `highlightDecoration`    | `null`                 | Custom highlight style; uses theme default when `null`               |

All other parameters mirror the standard Flutter widget each one wraps.

---

### `ScrollablePositionedList` (lower-level)

| Parameter                | Default                | Description                           |
| ------------------------ | ---------------------- | ------------------------------------- |
| `controller`             | required               | Your `ScrollablePositionedController` |
| `child`                  | required               | Your `ScrollView` widget              |
| `initialScrollIndex`     | `null`                 | Jump to this index on the first frame |
| `initialScrollAlignment` | `IndexAlignment.start` | Alignment for the initial jump        |
| `enableHighlight`        | `false`                | Enable the built-in item highlight    |
| `highlightDecoration`    | `null`                 | Custom highlight style                |

---

### `PositionedListItem`

| Parameter | Description                                                  |
| --------- | ------------------------------------------------------------ |
| `index`   | Item position — must match the index used in `scrollToIndex` |
| `child`   | Your item widget                                             |

Must be a descendant of `ScrollablePositionedList` (or any drop-in widget).

---

### `PositionedItemHighlight`

| Parameter           | Default                    | Description                      |
| ------------------- | -------------------------- | -------------------------------- |
| `color`             | `primary @ 12%`            | Background tint when highlighted |
| `border`            | `2px solid primary`        | Border when highlighted          |
| `borderRadius`      | `BorderRadius.circular(8)` | Corner radius                    |
| `animationDuration` | `250ms`                    | Transition in/out duration       |
| `animationCurve`    | `easeInOut`                | Transition curve                 |

---

### `IndexAlignment`

```dart
IndexAlignment.start   // 0.0 — item's leading edge at viewport top / left
IndexAlignment.center  // 0.5 — item centred in the viewport
IndexAlignment.end     // 1.0 — item's trailing edge at viewport bottom / right
```

---

## How it works

**Items already in the viewport** → single smooth `animateTo`.

**Off-screen items** (not yet built by the lazy list):

```
scrollToIndex(42)
  │
  ├─ fade out                            (150ms)
  ├─ jumpTo(estimated offset)            instant — brings item into build window
  ├─ poll every frame until item builds  ~1–3 frames (16ms each)
  ├─ jumpTo(exact RenderObject offset)   precise correction
  └─ fade in                             (150ms)
```

Height estimates improve over time — items that have already been scrolled
past contribute their real measured height to the average, making subsequent
far-jumps increasingly accurate.

**Why no `GlobalKey`?**

Each `PositionedListItem` stores only a `BuildContext` reference in the
controller's registry. At scroll time, `RenderBox.getTransformTo()` computes
the item's offset relative to the scroll view — a single matrix multiply
with no widget-tree side effects.
