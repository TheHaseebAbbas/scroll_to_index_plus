# index-visibility Specification

## Purpose

Lets callers ask whether an indexed item is built, how large it is, and how much of it is inside the viewport. It also lets them scroll to an item only when it is not already sufficiently visible, for example the first invalid form field.

## Requirements

### Requirement: Built query
The controller SHALL expose `isIndexBuilt(index)`, which returns true only while an item registered with that index is mounted and attached to the render tree.

#### Scenario: Built item
- **WHEN** an item with index 3 is currently built
- **THEN** `isIndexBuilt(3)` returns true

#### Scenario: Item not built or disposed
- **WHEN** no item with the index was ever built, or its item has been removed from the tree
- **THEN** `isIndexBuilt` returns false

### Requirement: Live extent query
The controller SHALL expose `extentOf(index)`, which returns the item's current main-axis size in logical pixels (height for vertical lists, width for horizontal lists), or null when the item is not built.

#### Scenario: Nested item
- **WHEN** a `PositionedListItem` is nested inside a Card rather than being a direct child of the list
- **THEN** `extentOf` returns the size of that item's own render box

#### Scenario: Size changes
- **WHEN** the item's content grows, for example when error text appears, and a frame has completed
- **THEN** `extentOf` returns the new size

#### Scenario: Horizontal list
- **WHEN** the list scrolls horizontally
- **THEN** `extentOf` returns the item's width

#### Scenario: Not built
- **WHEN** the item is not built
- **THEN** `extentOf` returns null

### Requirement: Visibility query
The controller SHALL expose `isIndexVisible(index, {minVisible = 1.0})`, which returns true when at least the fraction `minVisible` (0 to 1) of the item's main-axis extent lies inside the viewport, measured from live render objects. It SHALL return false when the item is not built.

#### Scenario: Fully visible
- **WHEN** the item lies entirely inside the viewport
- **THEN** `isIndexVisible` returns true for any `minVisible` up to 1.0

#### Scenario: Partially visible
- **WHEN** 40% of the item is inside the viewport
- **THEN** `isIndexVisible(index, minVisible: 0.3)` returns true
- **AND** `isIndexVisible(index, minVisible: 0.5)` returns false
- **AND** `isIndexVisible(index)` returns false

#### Scenario: Built but outside the viewport
- **WHEN** the item is built because of a large cache extent but lies fully outside the viewport
- **THEN** `isIndexVisible` returns false

#### Scenario: Not built
- **WHEN** the item is not built
- **THEN** `isIndexVisible` returns false

### Requirement: Ensure visible without moving when already visible
`ensureIndexVisible(index, {alignment, minVisible = 1.0, highlight = false, afterFrame = true})` SHALL leave the scroll position unchanged and complete normally when `isIndexVisible(index, minVisible: minVisible)` is true. It SHALL still apply the highlight when `highlight` is true, and it SHALL supersede any older in-flight scroll, like every other scrolling call.

#### Scenario: Already visible
- **WHEN** the item is fully visible and `ensureIndexVisible` is called
- **THEN** the scroll offset does not change
- **AND** the returned future completes

#### Scenario: Already visible with highlight
- **WHEN** the item is fully visible and `ensureIndexVisible(index, highlight: true)` is called
- **THEN** `highlightedIndex` is set to the index
- **AND** the scroll offset does not change

#### Scenario: Already visible cancels an older scroll
- **WHEN** a slow-path scroll to another index is in progress and `ensureIndexVisible` is called for an item that is already visible
- **THEN** the older scroll performs no further work
- **AND** the list is not left faded out

### Requirement: Ensure visible scrolls like scrollToIndex otherwise
When the item does not satisfy `minVisible`, `ensureIndexVisible` SHALL scroll exactly as `scrollToIndex` would for the same index, alignment and highlight values. Its `highlight` default SHALL be false. It SHALL scroll again on every call while the item is not sufficiently visible, including repeated calls for the same index.

#### Scenario: Off-screen built item
- **WHEN** the item is built but outside the viewport
- **THEN** `ensureIndexVisible(index, alignment: 0.1)` scrolls so the item lands at that alignment

#### Scenario: Repeat call
- **WHEN** the user scrolls the item out of view after an earlier `ensureIndexVisible` and the call is made again
- **THEN** the list scrolls to the item again

#### Scenario: Highlight opt-in
- **WHEN** `highlight` is omitted
- **THEN** `highlightedIndex` is not changed
- **AND** passing `highlight: true` sets it to the index

### Requirement: Measure after the next frame
When `afterFrame` is true, `ensureIndexVisible` SHALL wait for the end of the next frame, using the scheduler's end-of-frame signal and no timers, before evaluating visibility and extent. When false, it SHALL evaluate immediately.

#### Scenario: Layout settles first
- **WHEN** error text appears above the target in the same frame as the call
- **THEN** visibility and target offset are computed from the post-frame layout

#### Scenario: Immediate mode
- **WHEN** `afterFrame` is false
- **THEN** visibility is evaluated without waiting for a frame

#### Scenario: Newer call during the wait
- **WHEN** a newer scrolling call is made while an older `ensureIndexVisible` is waiting for the frame
- **THEN** the older call does not scroll

### Requirement: Safe on detached controllers
All visibility queries SHALL return their "not built" results (false or null) and `ensureIndexVisible` SHALL complete without throwing when the controller is not attached to a scroll view or has been disposed.

#### Scenario: Before attach
- **WHEN** the queries are called before the controller is attached
- **THEN** they return false or null and do not throw

#### Scenario: After dispose
- **WHEN** `ensureIndexVisible` is called after `dispose`
- **THEN** it completes without throwing and without scrolling
