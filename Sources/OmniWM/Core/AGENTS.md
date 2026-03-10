# OmniWM Core Codex Instructions

## Local-only Notice

- This file is intentionally local and expected to be gitignored.
- Do not delete this file. It defines repo-specific Codex behavior for Core runtime work.
- If the policy needs to change, edit this file in place instead of removing it.

This file tightens the root `AGENTS.md` rules for everything under `Sources/OmniWM/Core/**`.

## Operating Mode

Inside `Sources/OmniWM/Core/**`, always behave as if `WM Performance Audit Mode` is active.

Before editing Core code, say which boundary or hot path is affected. Examples:

- `AX API -> WindowModel`
- `CGS event intake -> workspace mutation`
- `layout solve -> frame application`
- `frame application -> border update`
- `workspace/window snapshot materialization -> UI consumer`

After editing Core code, say whether the change reduced or preserved:

- bridging cost
- allocation or copy churn
- state duplication
- actor or task hopping
- layer boundary friction

## Hot Ownership Map

Treat these as the critical files and ownership boundaries in Core:

- Bridging boundaries:
  - `Ax/AXWindow.swift`
  - `Ax/AXManager.swift`
  - `Ax/AppAXContext.swift`
  - `SkyLight/SkyLight.swift`
  - `PrivateAPIs.swift`
- Authoritative state:
  - `Workspace/WorkspaceManager.swift`
  - `Workspace/WindowModel.swift`
  - `Controller/FocusManager.swift`
- Layout and frame application:
  - `Controller/LayoutRefreshController.swift`
  - `Controller/NiriLayoutHandler.swift`
  - `Layout/Niri/NiriLayoutEngine.swift` and `Layout/Niri/NiriLayoutEngine+*.swift`
  - `Layout/Dwindle/DwindleLayoutEngine.swift`
- Render and UI-adjacent runtime path:
  - `Controller/BorderCoordinator.swift`
  - `Border/BorderManager.swift`
  - `Sources/OmniWM/UI/WorkspaceBar/WorkspaceBarDataSource.swift`
  - `Controller/WindowActionHandler.swift`

## Repo-specific Suspicion Checklist

Be extremely suspicious of the following patterns in this repo:

- `UUID` churn and `WindowHandle` identity churn
  - `Layout/DNode.swift` defines `WindowHandle` as a class identity token
  - `Workspace/WindowModel.swift` creates UUID-backed handles in `upsert`
  - Any new wrapper, conversion, or alternate identity path around `WindowHandle` is suspect
- Snapshot materialization and rebuild loops
  - `Workspace/WindowModel.swift`: `allEntries()`, `windows(in:)`
  - `Workspace/WorkspaceManager.swift`: `entries(in:)`, `workspaces(on:)`, workspace sorting/filtering paths
  - `Controller/WindowActionHandler.swift` and `Sources/OmniWM/UI/WorkspaceBar/WorkspaceBarDataSource.swift` rebuild higher-level UI data from workspace/window snapshots
- Repeated CF/AppKit/Foundation bridging
  - `AXWindowService`
  - `AppAXContext.getWindowsAsync()`
  - `AXManager.currentWindowsAsync()`
  - `SkyLight.queryAllVisibleWindows()` and related query helpers
  - Any new `CFArray` / `CFTypeRef` / `AXUIElement` -> Swift array/dictionary/object conversion in hot loops
- `@MainActor` overreach and hop churn
  - `WMController`, `AXManager`, `AXEventHandler`, `LayoutRefreshController`, `NiriLayoutHandler`, and surrounding `Task { @MainActor in ... }` paths
  - Any new async hop in event intake, layout, focus, or frame application needs justification
- Per-pass collection rebuilding in layout and render paths
  - `NiriLayoutHandler.applyFramesOnDemand`
  - `LayoutRefreshController.applyLayoutForWorkspaces`
  - Niri and Dwindle frame calculation output shaping
  - Any new per-pass dictionaries, sets, arrays, sorts, or grouped maps need explicit payoff
- Duplicate authoritative state
  - Window presence split across `WorkspaceManager`, `WindowModel`, layout engines, focus memory, and UI consumers
  - Any change that introduces another persistent representation of workspace or window ordering is suspect unless ownership is crystal clear

## Boundary Rules

When auditing or changing Core code:

- Prefer coarse-grained boundaries over chatty ones.
- Do not repackage low-level AX or SkyLight results into short-lived higher-level objects if a stable handle or lightweight struct would do.
- Do not make AppKit/Foundation collection types the default currency of core layout or navigation logic.
- Do not move platform glue deeper into core state and geometry code.
- If compute-heavy logic currently lives in a platform integration file, move the computation out instead of dragging more platform types inward.
- If reference semantics already provide stable ownership, do not replace them with large copied structs without a measured reason.
- If value semantics are causing repeated reconstruction or copy-on-write churn, say so plainly and prefer an ownership model that matches update frequency.

## Review Expectations

For explicit Core audits and reviews:

- Trace at least one common end-to-end path through actual code.
- Rate each major boundary.
- Call out exact hotspots where arrays, dictionaries, sets, strings, UUIDs, or Swift model conversions are rebuilt.
- Audit Swift 6.2 usage and Swift 6.3 readiness only where it materially affects throughput, latency, concurrency correctness, or ownership clarity.
- Do not recommend modernization for fashion.
