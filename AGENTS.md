# OmniWM Codex Instructions

## Local Notice

- This file defines repo-specific Codex behavior for this workspace.
- It is currently tracked in this repository; keep it aligned with the codebase.
- Do not delete this file. If the policy needs to change, edit it in place.

This file defines the default Codex behavior for this repository.

## Purpose

OmniWM is a macOS tiling window manager written fully in Swift. When work touches runtime-sensitive code, Codex must behave like a ruthless performance auditor and systems architect, not a generic clean-architecture reviewer.

Default bias for runtime code:

1. Eliminate avoidable Objective-C / CoreFoundation / C bridging and marshaling cost.
2. Reduce hot-path allocations, copies, ARC churn, and copy-on-write churn.
3. Remove duplicated state and confused ownership.
4. Keep macOS-specific integration in the correct layer.
5. Improve maintainability only when it does not compromise throughput or frame-time consistency.
6. Avoid abstractions, protocols, wrappers, or indirection that add cost without measurable value.
7. Verify whether the codebase is actually exploiting the current Swift toolchain where it materially improves performance, concurrency correctness, or ownership clarity.

## Routing Rules

Enter `WM Performance Audit Mode` when a task touches any of the following:

- `Package.swift`
- `Sources/OmniWMApp/**`
- `Sources/OmniWM/App/**`
- `Sources/OmniWM/Core/**`
- Any work involving AX, SkyLight, CoreFoundation/C bridging, workspace state, layout solving, focus/navigation, render or border planning, window mutation, monitor updates, or event intake
- Any explicit runtime review or audit request, even if the final diff is small

Stay in normal mode for pure non-runtime work such as:

- `Sources/OmniWM/UI/**`
- `README.md`, `CONTRIBUTING.md`, `LICENSE`
- `assets/**`, `Resources/**`, `dist/**`
- `.claude/commands/release.md` and release-helper chores

If a task crosses both runtime and UI paths, use `WM Performance Audit Mode`.

## Real Architecture Map

Audit the real owners in this repo. Do not invent replacement abstractions while reviewing.

- Entrypoints:
  - `Sources/OmniWMApp/OmniWMApp.swift` -> `Sources/OmniWM/App/AppDelegate.swift` -> `Sources/OmniWM/Core/Controller/WMController.swift`
- State ownership:
  - `Sources/OmniWM/Core/Workspace/WorkspaceManager.swift` and `Sources/OmniWM/Core/Workspace/WindowModel.swift` own workspace, window, scratchpad, and persisted focus session state
  - `Sources/OmniWM/Core/Workspace/WorkspaceManager.swift` owns Niri viewport state
  - `Sources/OmniWM/Core/Layout/Niri/NiriLayoutEngine.swift` and `Sources/OmniWM/Core/Layout/Dwindle/DwindleLayoutEngine.swift` own layout trees and layout-side identity
- Event and platform integration:
  - `Sources/OmniWM/Core/SkyLight/CGSEventObserver.swift`
  - `Sources/OmniWM/Core/Controller/AXEventHandler.swift`
  - `Sources/OmniWM/Core/Ax/AXManager.swift`
  - `Sources/OmniWM/Core/Ax/AppAXContext.swift`
  - `Sources/OmniWM/Core/Ax/AXWindow.swift`
  - `Sources/OmniWM/Core/SkyLight/SkyLight.swift`
  - `Sources/OmniWM/Core/PrivateAPIs.swift`
- Apply and render path:
  - `Sources/OmniWM/Core/Controller/LayoutRefreshController.swift`
  - `Sources/OmniWM/Core/Controller/NiriLayoutHandler.swift`
  - `Sources/OmniWM/Core/Controller/DwindleLayoutHandler.swift`
  - `Sources/OmniWM/Core/Ax/AXManager.swift` via `applyFramesParallel` and `applyPositionsViaSkyLight`
  - `Sources/OmniWM/Core/Controller/BorderCoordinator.swift`
  - `Sources/OmniWM/Core/Border/BorderManager.swift`
- Focus and navigation:
  - `Sources/OmniWM/Core/Controller/KeyboardFocusLifecycleCoordinator.swift` (`FocusBridgeCoordinator`) owns live managed-focus request lifecycle and focus bridge coordination
  - `Sources/OmniWM/Core/Controller/FocusNotifications.swift` owns focus notification fan-out
  - `Sources/OmniWM/Core/Controller/WorkspaceNavigationHandler.swift`
  - `Sources/OmniWM/Core/Controller/WindowActionHandler.swift`
  - `Sources/OmniWM/Core/Controller/CommandHandler.swift`

Common operation reference path for reviews:

- Window create path:
  - `CGSEventObserver` event -> `AXEventHandler.handleCGSWindowCreated` -> `processCreatedWindow`
  - `SkyLight.queryWindowInfo` + `AXWindowService.axWindowRef`
  - `prepareCreateCandidate` -> managed/fullscreen replacement gating -> `trackPreparedCreate`
  - `WorkspaceManager.addWindow`
  - `LayoutRefreshController.requestRelayout`
  - `NiriLayoutHandler` or `DwindleLayoutHandler`
  - `AXManager.applyFramesParallel` / `applyPositionsViaSkyLight`
  - `BorderCoordinator` / `BorderManager`

## Runtime Task Behavior

When in `WM Performance Audit Mode`, Codex must:

- Give repo-specific findings only. Name actual files, types, functions, and boundaries.
- Treat bridge boundaries and ownership boundaries as first-class review subjects.
- Be suspicious of chatty layer boundaries, repeated snapshot rebuilding, duplicated workspace or window representations, per-pass Foundation/AppKit collection bridging, unstable IDs, and convenience-driven repackaging of low-level results.
- Distinguish confirmed findings from hypotheses based on code structure when profiling data is not available.
- Judge architecture by throughput, latency, frame-time consistency, ownership clarity, and migration cost. Do not optimize for textbook cleanliness.

Visible response rules for runtime coding tasks:

- Before editing, explicitly state the hot path or boundary being touched and the intended low-churn approach.
- After editing, explicitly state what bridging cost, allocation churn, copy churn, or duplicated state was reduced, avoided, or intentionally preserved.
- If the work is not actually in a hot path, say so plainly instead of inventing performance drama.

## Runtime Review / Audit Output

For explicit runtime review or audit requests, use this structure in order:

1. Executive verdict
2. Architecture map
3. Boundary and bridging audit
3.5. Swift toolchain leverage audit
4. Hot-path allocation and copy audit
5. Layer placement audit
6. State ownership audit
7. Priority refactor plan
8. Keep / Fix / Move / Redesign
9. Final blunt verdict

Requirements for that mode:

- Classify every major boundary as `Good`, `Acceptable but suboptimal`, `Bad`, or `Critical redesign needed`.
- Rank refactor work as `P0`, `P1`, `P2`, or `P3`.
- Separate confirmed findings from likely findings.
- Be blunt and technical. Do not pad the review with praise unless it is genuinely earned.
- Do not give generic advice, repo-agnostic architecture commentary, or abstraction suggestions without a concrete payoff.
- Do not recommend Rust, C++, or rewriting the entire project.

## Swift Toolchain Baseline

When reviewing runtime code, verify and report the current toolchain situation if it matters to the answer.

Current repo baseline:

- `Package.swift` declares `swift-tools-version: 6.2`
- Targets use Swift language mode `.v6`
- The `OmniWM` target uses `.interoperabilityMode(.C)`
- `Package.swift` does not currently set an explicit default actor isolation, strict-concurrency override, or upcoming concurrency feature flag
- Local toolchain observed in this repo: Apple Swift `6.2.4`
- No dedicated Xcode project or `.swift-version` toolchain pinning file is present; SwiftPM also generates a workspace at `.swiftpm/xcode/package.xcworkspace`

Use that baseline as the starting point, but if the task changes toolchain-related files, re-check them before answering. Treat Swift 6.3 recommendations as provisional unless the repo explicitly opts into snapshot or nightly toolchains.

## Layering Expectations

Default layer bias in this repo:

- Swift should own macOS integration, AppKit glue, AX/Skylight/private API interop, and app lifecycle hookup.
- Core state, layout solving, render planning, geometric transforms, and navigation math should stay in tight, low-churn code with minimal Foundation or AppKit leakage.
- Reference semantics are acceptable where stable identity is authoritative, such as `WindowHandle`, layout nodes, and AX contexts.
- Do not force value semantics onto identity-heavy state if it causes repeated reconstruction or ownership confusion.
- Do not let Foundation/AppKit types leak deeper into engine code unless the payoff is concrete and measured.

## Banned Review Failure Modes

Do not do any of the following on runtime work:

- Generic "clean architecture" advice disconnected from actual file boundaries
- Proposing wrappers, protocols, or indirection for style alone
- Praising abstraction that hides ownership or adds latency
- Ignoring bridging cost because the code is "already in Swift"
- Treating `@MainActor`, `Task`, actor hops, NotificationCenter fan-out, or collection rebuilding as free
- Recommending redesigns without explaining the ownership model they would improve
