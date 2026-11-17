# offset-estimation Specification

## Purpose

Defines how the controller estimates the scroll offset of items that are not yet built, so a two-phase scroll can land close to its target. This includes lists whose labels are sparse or non-contiguous, such as enum indices or ids.

## Requirements

### Requirement: Sparse labels are supported
Item labels (the `index` of `PositionedListItem`) SHALL NOT be required to be contiguous or start at zero. Offset estimation, scrolling and visibility queries SHALL work for labels such as 0, 10, 20, 30. Estimates for unbuilt items are best-effort.

#### Scenario: Sparse labels in a lazy list
- **WHEN** a lazy list has items labelled 0, 10, 20 and 30 of differing heights and the item labelled 30 is not built
- **THEN** the estimated offset of 30 counts only the known items labelled below 30
- **AND** it does not count 30 phantom items

#### Scenario: Scroll lands on a sparse target
- **WHEN** `scrollToIndex(30)` is called on that list
- **THEN** the list ends with item 30 built and positioned at the requested alignment

### Requirement: Known-label estimate when labels have gaps
When the set of known labels (currently registered labels plus labels measured earlier) contains at least one gap between its smallest and largest label, the estimate SHALL be the sum of the extents of the known labels strictly below the target. An unmeasured known label counts as the average measured extent.

#### Scenario: Gap in known labels
- **WHEN** the known labels are 0, 10 and 20, each 200 px tall, and the target is 30
- **THEN** the estimated offset is 600

#### Scenario: Target below the known labels
- **WHEN** the target is 10 and the known labels are 0, 10 and 20
- **THEN** only label 0 is counted as above the target

### Requirement: Contiguous lists keep the 1.0.0 estimate
When the known labels have no gaps (a contiguous run), the estimate SHALL extrapolate beyond the largest known label as if every label up to the target existed, as in 1.0.0. The estimate is the known extents below the target plus `(target - largestKnown)` average extents.

#### Scenario: Lazy contiguous list
- **WHEN** labels 0 to 9 have been built, each 100 px tall, in a 1000-item list and the target is 500
- **THEN** the estimated offset is about 50,000 and not about 1,000

#### Scenario: Single known label
- **WHEN** only one label is known
- **THEN** the estimate follows the contiguous rule

### Requirement: Heights come from live measurement and are retained
Item extents used for estimation SHALL be read from live render objects when a scroll or an estimate is requested, so the values are current. Measured extents SHALL be retained after an item leaves the tree. Extents SHALL be measured along the scroll axis, so horizontal lists use width. The default average extent with no measurements SHALL remain 80.

#### Scenario: Measured item scrolled away
- **WHEN** an item was measured and then scrolled out and disposed by a lazy list
- **THEN** its last measured extent is still used when estimating offsets below later targets

#### Scenario: Extent changes before scroll
- **WHEN** a built item grows before a scroll is requested
- **THEN** the estimate uses the new extent

#### Scenario: No measurements
- **WHEN** nothing has been measured
- **THEN** each unknown item counts as 80

### Requirement: Alignment uses the live extent
When the target is built, alignment SHALL be applied using its live extent. The retained measurement SHALL be used only when the target is not built.

#### Scenario: Centered target
- **WHEN** a built target is aligned to the center of the viewport
- **THEN** its midpoint ends at the viewport midpoint within one logical pixel
