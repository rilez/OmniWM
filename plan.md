# OmniWM  Niri Parity Analysis

## Executive Summary

This analysis compares OmniWM's Swift implementation against Niri's Rust reference for viewport, scrolling, resizing, moving, swapping, closing, opening, layout, and animations. The goal is to identify algorithm mismatches and potential race conditions affecting UX parity.

---

## CRITICAL ISSUES (Priority 1)

### 1.1 Spring Animation Model Mismatch

**Impact**: Different animation curves produce visibly different scrolling/movement feel

| Aspect | OmniWM | Niri |
|--------|--------|------|
| File | `SpringAnimation.swift:24-111` | `animation/spring.rs:38-177` |
| Parameters | `duration`, `bounce` | `damping_ratio`, `stiffness`, `epsilon` |
| Implementation | Apple's `SwiftUI.Spring` | Custom libadwaita/RBBAnimation physics |
| Damping modes | Implicit via bounce | Explicit: critically/under/over-damped |

**OmniWM** (lines 55-56, 66-70):
```swift
spring = config.appleSpring  // Spring(duration:bounce:)
let springValue = spring.value(target:initialVelocity:time:)
```

**Niri** (lines 141-177):
```rust
fn oscillate(&self, t: f64) -> f64 {
    // Explicit damping calculation: beta, omega0
    // Handles critically damped, underdamped, overdamped cases
}
```

**Fix Required**: Map Niri's `(damping_ratio, stiffness)` to Apple Spring's `(duration, bounce)` or implement custom spring physics.

---

### 1.2 SwipeTracker Timestamp Validation Missing

**Impact**: Out-of-order events could corrupt velocity calculations

| Aspect | OmniWM | Niri |
|--------|--------|------|
| File | `SwipeTracker.swift:15-19` | `swipe_tracker.rs:29-46` |
| Validation | None | Ignores events with earlier timestamps |

**Niri** (lines 32-40):
```rust
if let Some(last) = self.history.back() {
    if timestamp < last.timestamp {
        trace!("ignoring event with timestamp earlier than last");
        return;  // CRITICAL: Prevents corruption
    }
}
```

**OmniWM** (lines 15-19):
```swift
func push(delta: Double, timestamp: TimeInterval) {
    position += delta  // No validation!
    history.append(SwipeEvent(delta: delta, timestamp: timestamp))
    trimHistory(currentTime: timestamp)
}
```

**Fix Required**: Add timestamp monotonicity check in `SwipeTracker.push()`.

---

### 1.3 SwipeTracker Velocity Threshold Difference

**Impact**: Edge case behavior differs at gesture end

| Aspect | OmniWM | Niri |
|--------|--------|------|
| Zero-time check | `totalTime > 0.001` | `total_time == 0.` |

**OmniWM** (line 28): Returns 0 if `totalTime <= 0.001`
**Niri** (line 60-61): Returns 0 only if `total_time == 0.`

**Fix Required**: Change OmniWM threshold to match Niri's exact-zero check, OR document intentional difference.

---

### 1.4 Scroll Wheel Gestures Never End

**Impact**: Viewport can remain stuck in `.gesture` state; snapping/recentering never happens

**OmniWM** (`Core/Controller/MouseEventHandler.swift:311`):
- Scroll wheel path calls `beginGesture()` + `updateGesture()` but never `endGesture()`
- `LayoutRefreshController` skips `ensureSelectionVisible` when `viewOffsetPixels.isGesture` is true

**Niri** (`layout/scrolling.rs:3159`):
- Gestures always end and snap to the closest column

**Fix Required**: Call `endGesture()` on wheel gesture completion (idle timeout or phase-based), then start scroll animation.

---

### 1.5 Fullscreen Toggling Bypasses Viewport Restore

**Impact**: Viewport offset is wrong after exiting fullscreen

**OmniWM** (`CommandHandler.swift:480`, `NiriLayoutEngine.swift:2059`):
- `toggleNiriFullscreen` mutates `windowNode.sizingMode` directly
- `viewOffsetToRestore` is never saved/restored via `setWindowSizingMode`

**Niri** (`scrolling.rs:1365`):
- Fullscreen flow preserves and restores view offset

**Fix Required**: Use `setWindowSizingMode` path or manually save/restore `viewOffsetToRestore`.

---

### 1.6 Window Ordering Is Nondeterministic

**Impact**: Multiple window opens/closes can reorder columns unpredictably (looks like a race)

**OmniWM** (`WindowModel.swift:70`, `LayoutRefreshController.swift:427`):
- `WindowModel.windows(in:)` iterates a `Set`
- `layoutWithNiriEngine` uses that order for `syncWindows`
- Set iteration order is undefined

**Niri**:
- Uses stable add order for columns

**Fix Required**: Use ordered collection (Array) or sort by insertion order/window ID.

---

### 1.7 Swap Across Columns Doesn't Match Niri

**Impact**: Can swap the "wrong" target and keep widths attached to the old column

**OmniWM** (`NiriLayoutEngine.swift:1031`):
- Swaps by source index and keeps column widths/active tiles

**Niri** (`scrolling.rs:2031`):
- Swaps active tiles
- When both columns have single tile, moves the column (preserving width with the column)

**Fix Required**: Swap active tiles, not by index. Handle single-tile column case as column move.

---

## HIGH PRIORITY ISSUES (Priority 2)

### 2.1 Focus Cache Staleness Risk

**Impact**: Deferred focus can target a closed window

**File**: `AXEventHandler.swift:281-338`

**Issue**: `deferredFocusHandle` is queued and reused without revalidation in the async Task. If the window is closed during the pending focus, the handle becomes stale.

**Fix Required**: Revalidate `entry(for:)` inside the Task before focusing, and clear deferred handles that no longer exist.

---

### 2.2 ViewGesture Reference Semantics in ViewportState Copies

**Impact**: Copying `ViewportState` can alias the same `ViewGesture` instance

**File**: `ViewportState.swift:6-56`

**Issue**: `ViewGesture` is a class; copying `ViewportState` shares the same gesture object. This can cause unexpected state coupling between refresh passes (not necessarily multi-threaded, but aliasing across copies).

**Fix Required**: Make `ViewGesture` a struct or ensure copies deep-clone the gesture state.

---

### 2.3 Empty Column Creation on Last Window Close

**Impact**: Different behavior when workspace becomes empty

| Aspect | OmniWM | Niri |
|--------|--------|------|
| Behavior | Creates empty placeholder column | Leaves workspace empty |
| Location | `NiriLayoutEngine.swift:517-531` | `scrolling.rs:1203-1204` |

**OmniWM**:
```swift
if column.children.isEmpty {
    column.remove()
    if let root, root.columns.isEmpty {
        let emptyColumn = NiriContainer()
        root.appendChild(emptyColumn)  // Creates placeholder!
    }
}
```

**Fix Required**: Match Niri behavior - do not create an empty placeholder column.

---

### 2.4 Viewport Centering / Working Area Mismatch

**Impact**: Centering and snapping differs with struts, fullscreen/maximized, and single-column modes

**OmniWM**:
- `ViewportState.computeNewViewOffsetFit()` ignores working area offsets and sizing modes
- `alwaysCenterSingleColumn` is only applied in `targetFrameForWindow`, not in ViewportState
- `ViewportState.animateToOffset` uses a fixed `scale = 2.0` pixel threshold

**Niri**:
- `compute_new_view_offset` uses working_area/parent_area and sizing mode (fullscreen/maximized)
- `always_center_single_column` participates in centering decisions

**Fix Required**: Port working-area-aware offset logic and always-center-single-column behavior into `ViewportState`.

---

### 2.5 Interactive Resize Semantics Mismatch

**Impact**: Resize behavior feels different and can violate Niri UX constraints

**OmniWM** (`NiriLayoutEngine.swift:1758`):
- Vertical resize adjusts weight (`windowNode.size`), not fixed pixels
- No guard against resizing top edge on topmost tile
- No centering adjustment for horizontal resize

**Niri** (`scrolling.rs:3528`):
- Uses fixed pixel height
- Blocks top-edge resize on topmost tile
- Doubles horizontal delta when centering

**Fix Required**: Align resize semantics with Niri, including top-edge guard and centering adjustments.

---

### 2.6 Interactive Move Drop Targets Missing

**Impact**: Drag/move UX is limited to swap-only behavior

**OmniWM**:
- `interactiveMoveEnd` only supports swap-on-window targets
- `columnGap` / `workspaceEdge` targets never implemented

**Niri**:
- Supports drop to column gaps, workspace edges, and DnD scroll behavior

**Fix Required**: Implement column-gap/workspace-edge drop handling and DnD scrolling parity.

---

### 2.7 Open/Close Animation Pipeline Missing

**Impact**: Window open/close UX differs; no shader snapshots or transaction-synced animations

**OmniWM**:
- `closingHandles` is unused; windows are removed immediately

**Niri**:
- `OpenAnimation` and `ClosingWindow` use render snapshots + transactions for open/close effects

**Fix Required**: Implement open/close animation pipeline or explicitly disable them to match Niri config.

---

## MEDIUM PRIORITY ISSUES (Priority 3)

### 3.1 activatePrevColumnOnRemoval Animation Sequence

**Location**:
- OmniWM: `NiriLayoutEngine.swift:598-606`
- Niri: `scrolling.rs:1214-1236`

**Issue**: OmniWM restores the offset but does not animate in the same sequence as Niri.

---

### 3.2 Gesture endGesture Uses .never CenterMode

**Impact**: `centerFocusedColumn` setting is ignored during gesture snap

**OmniWM** (`ViewportState.swift:545`, `MouseEventHandler.swift:449`):
- `endGesture()` defaults to `centerMode: .never`
- Selection changes during gesture updates, not at gesture end

**Niri** (`scrolling.rs:3057`, `scrolling.rs:3184`):
- Updates active column at gesture end
- Uses `center_focused_column` config for snap points

**Fix Required**: Pass actual `centerFocusedColumn` setting to `endGesture()`.

---

### 3.3 Tabbed Toggle Doesn't Clear Fullscreen

**Impact**: Fullscreen tile can overlap others when leaving tabbed mode

**OmniWM** (`NiriLayoutEngine.swift:2176`):
- Just flips `displayMode`

**Niri** (`scrolling.rs:2173`):
- Explicitly unfullscreens on non-tabbed columns with multiple tiles

**Fix Required**: Clear fullscreen when toggling to non-tabbed with multiple tiles.

---

### 3.4 Opening Window Defaults Differ

**Impact**: New windows don't respect preset sizes or open rules

**OmniWM** (`NiriLayoutEngine.swift:441`):
- Always creates new column with width `1/maxVisibleColumns`
- Doesn't apply default column width/height or open-floating/fullscreen rules

**Niri** (`layout/mod.rs:885`):
- Resolves preset sizes and rules on open

**Fix Required**: Apply window rules and preset sizes when opening windows.

---

### 3.5 Floating Window Mode Not Implemented (Optional)

**Impact**: Layout parity gap for mixed floating + scrolling workflows

**Note**: This may be out-of-scope for the current parity pass but is a structural mismatch.

---

## VERIFIED MATCHING ALGORITHMS 

### Column Position Calculation
- `columnX(at:columns:gap:)` matches Niri's `column_x()` accumulation of widths and gaps

### Viewport Offset Fit Calculation
- `computeNewViewOffsetFit()` (lines 470-497) matches `compute_new_view_offset()` (lines 5447-5479)

### Snap Point Finding
- `findSnapPointsAndTarget()` (lines 666-751) follows same logic as Niri's gesture end

### Center Mode Logic
- `CenterFocusedColumn` enum and behavior matches Niri's implementation

---

## FILES TO MODIFY

| File | Changes |
|------|---------|
| `Core/Animation/SwipeTracker.swift` | Add timestamp validation, adjust velocity threshold |
| `Core/Animation/SpringAnimation.swift` | Consider custom spring physics OR parameter mapping |
| `Core/Controller/MouseEventHandler.swift` | Ensure wheel gestures call `endGesture()`, pass centerMode |
| `Core/Controller/AXEventHandler.swift` | Revalidate deferred focus handles |
| `Core/Controller/CommandHandler.swift` | Fix fullscreen toggle to use setWindowSizingMode path |
| `Core/Controller/LayoutRefreshController.swift` | Refresh ordering and multi-removal handling |
| `Core/Workspace/WindowModel.swift` | Use ordered collection instead of Set for windows |
| `Core/Layout/Niri/ViewportState.swift` | Working-area-aware centering, gesture struct, pass centerMode to endGesture |
| `Core/Layout/Niri/NiriLayoutEngine.swift` | Resize/move/swap parity, open/close pipeline, fullscreen restore, tabbed+fullscreen, opening defaults |
| `Core/Layout/Niri/InteractiveResize.swift` | Track top-edge guard and centering adjustments |
| `Core/Layout/Niri/InteractiveMove.swift` | Implement column-gap/workspace-edge drops |

---

## VERIFICATION TEST CASES

1. **Scroll wheel gesture end** - Ensure snapping and recentering occurs
2. **Out-of-order scroll events** - Verify timestamp handling
3. **Rapid window open/close** - Confirm focus and animation stability
4. **Close last window in workspace** - Verify empty state handling
5. **Interactive resize edge cases** - Top-edge guard + centering delta
6. **Single-window swap** - Ensure column-move semantics
7. **Full refresh during AX events** - Check for missed windows/invalid states
8. **Fullscreen toggle cycle** - Verify viewport offset restored after exit
9. **Window ordering stability** - Open 5 windows rapidly, verify column order is stable
10. **Swap across columns** - Verify active tiles swap, not by index
11. **Tabbed + fullscreen** - Toggle tabbed on column with fullscreen tile
12. **centerFocusedColumn during gesture** - Verify snap respects setting

---

## RACE CONDITION HOTSPOTS

1. **Full refresh enumeration is async** (`LayoutRefreshController.swift:251`, `:318`) - windows created/closed during async wait can be missed; AX event handling is paused during refresh
2. **Full refresh vs AX events** (`LayoutRefreshController.executeFullRefresh`) - snapshot may miss live changes
3. **Deferred focus handle reuse** (`AXEventHandler.focusWindow`) - stale handles possible
4. **Multiple column removals in one refresh** (`LayoutRefreshController.layoutWithNiriEngine`) - only first gets special handling
5. **Animation deltas from stale frames** (`AXEventHandler.handleRemoved` + `NiriLayoutEngine.triggerMoveAnimations`) - jumps during active scroll/column animations
6. **Immediate refresh does not cancel pending tasks** (`LayoutRefreshController.executeLayoutRefreshImmediate`) - later refresh can overwrite in-progress state

---

## IMPLEMENTATION ORDER

### Phase 1: Critical Data Structure Fixes
1. Fix window ordering - use Array instead of Set in `WindowModel.swift`
2. Fix swap across columns - swap active tiles, handle single-tile column move
3. Fix fullscreen toggle - use `setWindowSizingMode` path for viewport restore

### Phase 2: Gesture Input Parity
4. End wheel gestures and snap to column
5. Pass `centerFocusedColumn` to `endGesture()`
6. Add SwipeTracker timestamp monotonicity validation
7. Align SwipeTracker velocity threshold

### Phase 3: Viewport Centering Parity
8. Port working-area and sizing-mode aware centering
9. Apply always-center-single-column in ViewportState
10. Convert ViewGesture from class to struct

### Phase 4: Resize/Move/Swap Parity
11. Align interactive resize semantics (fixed pixels, top-edge guard, centering delta)
12. Implement column-gap/workspace-edge drops + DnD scroll

### Phase 5: Window Lifecycle Parity
13. Fix tabbed toggle to clear fullscreen when needed
14. Apply opening window defaults and rules
15. Implement open/close animation pipeline (or disable to match config)

### Phase 6: Spring Animation Parity
16. Implement custom spring physics or parameter mapping

### Phase 7: Race/Refresh Safety
17. Revalidate deferred focus handles
18. Handle multi-removal + refresh ordering
19. Remove empty column creation on last window close
