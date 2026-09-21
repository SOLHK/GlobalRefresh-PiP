# STRA Refresh · UI design contract (2.0 series)

The visual identity and information hierarchy in this file are product requirements for future STRA Refresh iterations, not temporary styling.

## Brand and layout
- Installed app name **STRA Refresh**, independent GitHub destination `SOLHK/GlobalRefresh-PiP`.
- Distinctive control-room dashboard, not the original upstream vertical stack: light aqua/blue visual accent, restrained static gradients, generous spacing, rounded shapes and a consistent grid. Support light/dark mode and smaller iPhones.
- Main **Start / Stop Floating Window** control is the first large full-width button; quick **Minimize** and **Window Height** actions live in a two-column grid beneath it. Do not restore the removed Switch Style or Guide tiles to Home. The compact session status card follows the controls.
- Prefer Xcode 27 and native iOS 26/27 SwiftUI Liquid Glass (glassEffect), with a system ultrathin-material fallback for older iOS. Do not approximate glass with opaque white cards.
- About Preferences must always offer a visible X close button and tap-outside dismissal; panels must not trap touches under a full-screen invisible GeometryReader.
- Keep labels aligned within tiles, touch targets large, and allow vertical scrolling rather than using fixed offsets that break on compact displays. Avoid horizontal clipping and unnecessary animated backgrounds / timers.

## Interaction and popup policy
- Do not show a blocking dialog after a routine successful Minimize or basic settings toggle. Reflect success in the visible card/status instead.
- No automatic per-version changelog popup and no notification permission request just from opening Home. Changelog and notifications remain opt-in from their respective controls.
- Retain meaningful confirmations for destructive actions and explicitly opt-in risky features; retain actionable failure and interrupted-session warnings.
- Do not mislabel physical height: default VideoCall route's current minimum is **0.1 pt**, not 0.01 pt; PlayerLayer route's minimum is **1 pt**. Changing to 0.01 pt requires independent real-device validation and fallback behavior.
- Preserve existing PiP session logic, background/lock power saving, thermal safety and independent-app GitHub links during visual iterations.
