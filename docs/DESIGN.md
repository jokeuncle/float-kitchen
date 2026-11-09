---
name: Float Kitchen
description: A warm miniature bistro for local AI activity, drawn in native AppKit.
colors:
  background: "#211d19"
  surface: "#2c2620"
  cream: "#f9edda"
  secondary: "#c7b9a6"
  muted: "#aa9d8b"
  copper: "#f1ad73"
  sage: "#b2c8a1"
  gold: "#e4c174"
  error: "#f39c89"
  rule: "#514438"
  paper: "#f7e8cd"
  ink: "#413126"
typography:
  display:
    fontFamily: "macOS system serif, macOS system fallback"
    fontSize: "28pt"
    fontWeight: 500
  compact-title:
    fontFamily: "macOS system serif, macOS system fallback"
    fontSize: "23pt"
    fontWeight: 500
  headline:
    fontFamily: "macOS system serif, macOS system fallback"
    fontSize: "20pt"
    fontWeight: 500
  title:
    fontFamily: "macOS system"
    fontSize: "15pt"
    fontWeight: 600
  body:
    fontFamily: "macOS system"
    fontSize: "12pt"
    fontWeight: 400
  button:
    fontFamily: "macOS system"
    fontSize: "12pt"
    fontWeight: 500
  label:
    fontFamily: "macOS system"
    fontSize: "11pt"
    fontWeight: 400
  footnote:
    fontFamily: "macOS system"
    fontSize: "10pt"
    fontWeight: 400
  sign-title:
    fontFamily: "macOS system"
    fontSize: "9pt"
    fontWeight: 600
  sign-detail:
    fontFamily: "macOS system"
    fontSize: "8pt"
    fontWeight: 400
  compact-sign-title:
    fontFamily: "macOS system"
    fontSize: "7.5pt"
    fontWeight: 600
  compact-sign-detail:
    fontFamily: "macOS system"
    fontSize: "7pt"
    fontWeight: 400
rounded:
  shell: "24pt"
  stage: "16pt"
  button: "9pt"
  focus: "8pt"
  sign: "5pt"
spacing:
  stage-inset: "12pt"
  control-inset: "24pt"
  reading-inset: "28pt"
  symbol-text-inset: "8pt 2pt"
  sign-horizontal-inset: "5pt"
  receipt-inset: "24pt 28pt"
components:
  expanded-panel:
    backgroundColor: "{colors.background}"
    textColor: "{colors.cream}"
    rounded: "{rounded.shell}"
    width: "680pt"
    height: "764pt"
  compact-panel:
    backgroundColor: "{colors.background}"
    textColor: "{colors.cream}"
    rounded: "{rounded.shell}"
    width: "440pt"
    height: "400pt"
  button:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.secondary}"
    typography: "{typography.button}"
    rounded: "{rounded.button}"
    height: "30pt"
  button-active:
    backgroundColor: "{colors.copper}"
    textColor: "{colors.ink}"
    typography: "{typography.button}"
    rounded: "{rounded.button}"
    height: "30pt"
  button-hover:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.cream}"
    rounded: "{rounded.button}"
  button-disabled:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.muted}"
    rounded: "{rounded.button}"
  workstation-sign:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    rounded: "{rounded.sign}"
  receipt:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    padding: "{spacing.receipt-inset}"
    width: "480pt"
    height: "490pt"
---

# Design System: Float Kitchen

## Overview

**Creative North Star: "深夜小馆 / The Warm Miniature Bistro"**

Float Kitchen makes waiting feel like watching a small late-night restaurant at work. Ceramic robot chefs, ivory tile, copper cookware, cherrywood and forest green carry the warmth; an espresso shell gives the authored scene a quiet desktop setting. This language comes from the approved kitchen brief and existing implementation.

The artwork is expressive while information stays still. Native controls, source labels and paper receipts make the performance understandable without turning an event into a claim about the model's thoughts. This document belongs to the independent Float Kitchen app; Orbit's visual system remains separate.

**Key Characteristics:**
- Authored miniature kitchen art with eight distinct chef poses.
- Espresso surroundings, cream reading text and copper selection.
- Steady paper signs and selectable native receipts.
- State-specific compositor motion with accessibility and visibility gates.

## Colors

The frontmatter preserves `Bistro`'s actual sRGB hex values. The art has its own baked palette; these tokens govern the native shell and information.

### Primary
- **Copper:** selected mode, client and pin controls; general activity emphasis.

### Secondary
- **Sage:** reading and served states, plus the keyboard focus stroke.
- **Gold:** testing and waiting states, including the bell ring.
- **Soft Error Coral:** explicit failure state, paired with named text and a distinct pose.

### Neutral
- **Espresso / Warm Surface:** outer shell and button grounds.
- **Cream / Secondary / Muted:** reading text, supporting labels and quiet annotations.
- **Brown Rule:** perimeter and horizontal separators.
- **Receipt Paper / Ink:** workstation signs and the selectable receipt.

**The Named State Rule.** Color supports the activity name and pose; color alone must not identify a state.

## Typography

Use `NSFont.systemFont`; the brand and main activity caption request its native serif design with a system fallback. Guide labels, tool names and controls use system sans. Font metrics determine height; no global custom line height is imposed.

The frontmatter records recurring roles. The receipt uses a semibold serif brand, semibold event rows (14pt) and regular detail text; its paragraphs have spacing after (12pt) and line spacing (4pt). Guide explanations use regular system text (11pt) with line spacing (3pt). Connection examples use the native monospace font (12pt).

**The Shared Baseline Rule.** Symbols beside text use one `NSTextAttachment` run, with vertical offset `(font.capHeight - iconHeight) / 2`; do not position an unrelated icon by eye. Button symbols are 14pt, standalone controls 15pt, and the brand symbol 24pt.

**The Measured Sign Rule.** Fit each sign line using the actual native font width and a measured trailing ellipsis before drawing. Keep the source/activity line and detail line independent and single-line.

## Layout

All native geometry is in AppKit points. Expanded and compact are discrete window modes, preserving the upper-right anchor and constrained to the screen. Expanded composition is brand, mode controls, scene, activity caption, client selection, two recent events and footer. Compact keeps brand, scene, three signs, caption, mode label and pin/fold/hide controls; other controls remain available through the menu bar.

The scene sits at x=12 with width `windowWidth - 24` and height `sceneWidth / 1.5`; its top is y=122 expanded or y=66 compact. Three chef anchors sit at 31%, 53% and 75% of scene width. Chef bounds are 23.5% of scene width by 47% of scene height, anchored at 50%/90%. The foreground counter reuses the bottom 32% of the environment, covering the lower chef bodies.

Signs share the stage frame in a separate, noninteractive sibling view. Each is 20.4% of scene width, centered on its chef at 84% scene height, with height `max(30pt, sceneHeight × 0.085)`. Text has the frontmatter horizontal inset, with two separately measured lines at y+4 and y+18. Sign typography switches to compact roles when the stage width is below 500pt; this is a native sign threshold, not a web breakpoint.

The guide is a vertically scrolling 580×640pt native window with a 580×1110pt document and eight 120pt rows. Its thumbnails, explanation and demonstration action share a stable grid. The resizable receipt is a native text view with wrapping, vertical scrolling and selection; do not replace it with clipped custom drawing.

## Elevation & Depth

Depth comes primarily from the authored scene and its layered occlusion: environment, three independent chefs, reused counter foreground, small emitters and waiting rings. The main panel uses AppKit's native window shadow; its parameters are system-owned. The scene clips to its rounded bounds and never asks AppKit to paint partial backing updates over the animated subtree. Paper signs are drawn by a static sibling, above that scene.

**The Stable Reading Plane Rule.** Keep signs and surrounding information outside the animated layer-hosting subtree. Only the state artwork and local effects move.

## Shapes

The shell, stage, controls and signs step down through the frontmatter's rounded vocabulary. The shell has a fine 1pt perimeter; ordinary separators use a 0.7pt stroke. Buttons draw within a 1pt inset. Keyboard focus uses a 2pt sage stroke inside a 2pt inset, alongside the native exterior focus-ring setting. Paper signs remain compact rectangles, visually related to receipts rather than floating bubbles.

## Components

### Native buttons

`BistroButton` is a native `NSButton` with custom drawing and native keyboard/action semantics. Copper active fill uses ink text; ordinary controls use warm surface with secondary text. Fill alpha is 0.85 at rest, 1 on hover and 0.65 when pressed. Hover raises ordinary text to cream; disabled text is muted. Quiet icon controls omit their background until hover or active state. Do not add web-only control states to the app.

### Animated kitchen

The two runtime scene images are loaded from the packaged resources, decoded once and cached. Crop all eight atlas cells to independent CGImages before assigning layer contents; never animate a shared atlas subrectangle. Props are already part of each chef pose. No extra foreground props sheet is composited.

A changed pose crossfades over 360ms with `easeInEaseOut` and settles from its presentation transform over 280ms with `easeOut`; its activity loop begins after settling. An unchanged client keeps its existing loop. The reading sway lasts 2.8s; search excursion 4.2s; cooking tilt and vertical toss 1.2s; testing tremor 0.45s; waiting sway/ring 1.7s; failed sway 2s; served lift 3.6s. Idle is still. All activity loops return to rest and use `easeInEaseOut`. Steam accompanies cooking/testing; darker smoke accompanies failure; waiting has a gold expanding/fading ring.

**The Independent Motion Rule.** A client event changes that client's pose and motion without restarting the others. Pause, Reduce Motion, hiding/occlusion and sleep remove continuous effects; static poses and signs retain meaning. A one-second model timer and background polling remain separate from compositor animation; there is no Swift frame redraw timer.

### Workstation signs and event details

Signs show client plus activity, then safe detail or tool name; idle reads “等待新任务”. They never intercept chef selection. Long Chinese, English and filenames use measured ellipsis rather than shrinking indefinitely, wrapping or disappearing. Expanded recent rows include source time; the paper receipt preserves the latest six events in selectable native text.

### Guide and packaging

The built-in guide reuses the eight pose crops and explains motion, source evidence and limitations. “看此动作” selects an explicitly labeled isolated demo; continuous demo and live activity remain separate modes. The bundled Chinese guide describes the same mapping.

Implementation authority: `Sources/FloatKitchen/Theme.swift`, `Controls.swift`, `KitchenView.swift`, `KitchenStage.swift`, `KitchenSigns.swift`, `KitchenGuide.swift` and `KitchenController.swift`. `kitchen.png` and `chef-states.png` are runtime scene art; `chefs.png` supplies the build-time icon. Exact prompt files and embedded provenance remain intact, including the abandoned activity-props prompt. Performance observations and limits are recorded in `PERFORMANCE.md`; the sidecar's HTML is a documentation preview of native primitives, not app source or native rendering evidence.

## Do's and Don'ts

### Do:
- **Do** preserve the authored warm bistro world and native system typography.
- **Do** keep client, activity and safe detail readable on a steady paper sign.
- **Do** use shared cap-height symbol alignment and measured single-line ellipsis.
- **Do** preserve independent client motion, Reduce Motion and menu-bar recovery.
- **Do** distinguish fictional demo, observed live activity and unknown or stale state.

### Don't:
- **Don't** reintroduce separate foreground props or shared-atlas sampling that bleeds neighboring poses.
- **Don't** move signs into the animated scene or let motion cover information.
- **Don't** infer private reasoning, approval, failure or task quality from decorative motion.
- **Don't** equate display callback cadence with guaranteed GPU frame presentation.
