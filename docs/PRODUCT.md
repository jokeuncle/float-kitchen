# Float Kitchen · AI 后厨
<!-- impeccable:product-schema 1 -->

## Platform
macOS native desktop, rendered with AppKit and Core Animation. This is an independent Swift package and macOS application. Impeccable's current platform enum does not represent AppKit, so web guidance must not override the native implementation.

## Stack
Swift 5.9 package, macOS 14 minimum deployment target, AppKit, QuartzCore and local Foundation file reading. No external runtime or network dependency. `FloatKitchen` depends on `KitchenCore` and packages authored raster resources.

## Users
The Mac owner working with local Codex, Claude or a custom client, who wants a pleasant peripheral view of activity and a readable account of recent events.

## Product Purpose
Turn waiting on AI into a warm miniature kitchen performance while making the client's explicitly observable activity understandable. Each of three workstations represents one client; a selectable receipt explains recent events.

## Operating Context
A floating desktop companion with expanded and compact modes, optional pinning, saved window position, hide and menu-bar recovery. The initial mode is explicitly labeled fictional demo. Switching to real activity clears demo events and reads local sources. A guide explains every pose and can isolate a demonstration.

## Capabilities and Constraints
- Eight states: reading, searching, cooking, testing, waiting, failed, served and idle. Multiple sessions from one client aggregate to one chef. No accurate per-session percentage is claimed.
- Local read-only adapters for recent Codex and Claude logs, plus an explicitly supplied JSONL bridge. Missing, unknown or stale activity stays idle; two minutes without new activity does not prove completion. Waiting requires an explicit event; completion does not verify task quality.
- Receipts preserve source time, client, activity, tool and bounded safe details. Automatic sources retain file basenames and executable categories, excluding prompt text, reasoning, tool output, full paths and command arguments. Custom labels are explicitly client-supplied and limited to 90 characters.
- Background incremental reads are bounded: up to four recent files per client and 512 KiB per source per poll, source discovery every twenty seconds, polling every two seconds. Buffers, event history and deduplication are bounded. Partial lines wait; truncation and rotation reset cursors.
- Continuous motion uses cached CGImages and Core Animation, without a Swift frame redraw timer. Reduce Motion, hidden/occluded windows and sleep stop continuous effects. Unchanged clients keep their existing animation when another client changes state.
- No log editing, network service, process control, startup registration or client configuration changes. The bridge remains local.
- Runtime scene art is `kitchen.png` and `chef-states.png`; `chefs.png` is build-time icon source. Preserve exact prompt and provenance files, including the abandoned activity-props experiment.

## Brand Commitments
The user approved an exquisite AI kitchen: authored ceramic robot chefs, warm ivory tile, copper cookware, cherrywood, forest green and espresso surroundings. Motion should feel playful and smooth with low overhead. Activity details, clear guide mapping, overflow protection and properly aligned symbols and text are part of the experience.

## Product Principles
- Let the art delight and the native information remain steady and legible.
- Explain observed events without suggesting access to private reasoning.
- Make demo, live, unknown and stale states unambiguous.
- Keep controls reversible and the hidden window recoverable.
- Respect accessibility settings and separate monitoring from animation.

Verification evidence and its limits belong to [PERFORMANCE.md](PERFORMANCE.md); this product record does not imply cross-machine acceptance, Apple notarization or guaranteed frame delivery.
