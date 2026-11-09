# Float Kitchen

User-approved direction: an AI kitchen as a delightful macOS floating desktop app; premium authored assets, playful event-driven animation, smooth movement and low resource use. The user subsequently requested meaningful activity information, not only visual effects.

## Delivery contract

Ship an independent Swift package. Files live in Sources/FloatKitchen, Sources/KitchenCore, Tests/KitchenCoreChecks, docs and app-specific scripts. No hook settings, network service, process control, startup registration, or existing client data is modified. Local logs are read-only. User-written bridge events remain on this Mac.

Acceptance: release app launches; generated art loads from its packaged resource bundle; native controls toggle pin/compact/hide and recover from menu bar; demo is explicitly labeled and cleared when switching live; Codex/Claude activity adapters and an incremental JSONL reader pass real fixture checks; a bridge event is observed through the running app; expanded/compact native renders have no overlaps; process CPU/RSS and display scheduling are measured. Unknown/stale data stays idle rather than being invented.

## Direction contract

Mode: Experience, with native Operate controls.
Thesis: waiting on AI becomes watching a tiny warm late-night bistro work.
Materials: authored clay/ceramic robot chefs, ivory tile, copper pots, cherrywood and forest-green counter against espresso surroundings. Three retained raster sources were generated with image_gen: kitchen environment, original icon characters, and eight state poses. The packaged runtime scene uses only kitchen.png and chef-states.png; chefs.png is build-time icon source. The abandoned activity-props prompt remains as provenance, but no separate props asset ships. Exact prompt files and embedded PNG metadata are preserved.
First viewport: one open-front kitchen, three independently composited characters behind its real foreground counter; typography and controls surround the scene rather than competing with it.
Signature: event-driven whole-pose sway, excursion, pan toss, tremor and serving lift, with compositor steam, smoke and waiting rings. Pose props move as part of the chef artwork. Continuous motion runs in Core Animation, without an app-side frame redraw timer. Distinct state trajectories carry activity; event receipts carry the actual information.
Risk: eight authored state-specific poses include their matching props; whole-pose transforms and small compositor effects communicate activity. This is image compositing, not a skeletal rig or independently articulated prop animation; information does not imply access to private model reasoning. Local event schemas can change and unknown records are ignored.

## State and information

reading / searching / cooking / testing / waiting / failed / served / idle. Three client identities: Codex, Claude, Local. First launch is clearly labeled demo. Live reads at most four recent files per client and 512 KiB per source per poll, scans at most 20k entries, polls every two seconds with 250ms leeway, discovers every twenty seconds. Parsing and filesystem work stay on a utility queue. Partial lines wait; truncation/rotation resets cursors. Read buffers, receipts, and deduplication are bounded. No prompt text, reasoning, tool output or raw command arguments are retained. File details are basenames; shell details are executable categories; optional bridge labels are provided explicitly by the client.

## Motion and performance

Core Animation composits cached CGImages and small particle systems at display cadence. No Swift frame timer. Respect Reduce Motion, stop animation on hiding/occlusion and sleep, keep sampling separate. No browser, Electron, external runtime, or network dependency. UI changes only on real events and mode/selection changes. Pause holds demo progression. Performance evidence reports process CPU and RSS separately from display-link scheduling; display callback cadence is not claimed as proof of every GPU frame.

User feedback acceptance extension: eight independently cropped state poses with state-specific compositor motion, per-workstation source/activity/detail signs, built-in state guide and one-click isolated demonstrations. Compact signs use two nonwrapping AppKit text lines with measured tail ellipsis and a minimum 30pt sign height. Long Chinese, English and file names have native stress captures, recorded in PERFORMANCE.md.

Rendering correction after user review: the animated kitchen uses a dedicated layer-hosting view; nameplates are static AppKit drawing in a separate sibling view, with explicit measured one-line ellipsis. Repeated foreground props were removed after user identified duplication and atlas bleed. Chef cells are cropped into independent cached CGImages before compositing. Pose changes crossfade over 360ms, settle over 280ms, and do not restart unchanged clients; Reduce Motion disables transitions.

## Documentation authority

PRODUCT.md and DESIGN.md in this directory describe Float Kitchen for this independent app. The token frontmatter reflects the current native Swift implementation; .impeccable/design.json extends it with motion, geometry, narrative and documentation-only HTML previews. PERFORMANCE.md records observed verification and its limits.
