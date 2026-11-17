# Spec Delta

## Purpose

Lets the highlighted index clear itself after a configurable time, so callers do not have to clear it manually. The default behavior (highlight stays until cleared) is kept.

## ADDED Requirements

### Requirement: Optional highlight duration
`ScrollablePositionedController` SHALL accept an optional `highlightDuration`. When null (the default), a highlight remains until `clearHighlight` is called or the value is replaced, as in 1.0.0.

#### Scenario: Default
- **WHEN** the controller is created without `highlightDuration` and an index is highlighted
- **THEN** the highlight remains indefinitely

### Requirement: Highlight clears itself
When `highlightDuration` is set, `highlightedIndex` SHALL return to null that long after the highlight starts, if the value has not changed in the meantime. This SHALL apply to highlights set by scrolling and to values assigned directly.

#### Scenario: Timed clear
- **WHEN** `highlightDuration` is 2 seconds and index 4 is highlighted
- **THEN** after 2 seconds `highlightedIndex.value` is null

#### Scenario: Direct assignment
- **WHEN** `highlightedIndex.value = 4` is assigned directly
- **THEN** it clears after `highlightDuration`

#### Scenario: Replaced highlight
- **WHEN** index 4 is highlighted and index 6 is highlighted one second later with a 2-second duration
- **THEN** the highlight of 6 lasts 2 seconds from its own start
- **AND** the earlier timer does not clear it

### Requirement: Timing starts when the scroll completes
When a highlight is set by `scrollToIndex` or `ensureIndexVisible`, the duration SHALL be measured from when the scroll finishes, not from the start of the call, so a slow scroll does not consume it.

#### Scenario: Slow scroll
- **WHEN** a slow-path scroll takes about 1 second with a 2-second duration
- **THEN** the highlight is still visible about 1.9 seconds after the call
- **AND** it clears about 2 seconds after the scroll ends

### Requirement: Cancelled by clear, replacement and dispose
The pending expiry SHALL be cancelled by `clearHighlight`, by a newer highlight and by `dispose`. A disposed controller SHALL NOT change `highlightedIndex` later.

#### Scenario: Disposed with a pending expiry
- **WHEN** the controller is disposed before the duration elapses
- **THEN** no error occurs and no timer remains pending
