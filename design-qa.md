# AppBox Design QA

## Sources

- Main reference: `/var/folders/bv/dxb0_wm90mn_wnkjstp9_4540000gn/T/codex-clipboard-8438e77d-1821-4166-861f-9acb6a17efc1.png`
- Settings reference: `/var/folders/bv/dxb0_wm90mn_wnkjstp9_4540000gn/T/codex-clipboard-de4dc4c6-d67c-4f8e-97d3-13cd53206ca1.png`
- Share reference: `/var/folders/bv/dxb0_wm90mn_wnkjstp9_4540000gn/T/codex-clipboard-6020b982-6a41-4c6d-8dea-27b74c7ba3d4.png`
- Share overlay refinement: `/var/folders/bv/dxb0_wm90mn_wnkjstp9_4540000gn/T/codex-clipboard-6e8e6f33-a124-4917-8c75-d1f2be061dea.png`
- PIN reference: `/var/folders/bv/dxb0_wm90mn_wnkjstp9_4540000gn/T/codex-clipboard-a08f2c3a-5415-4524-8658-bb64578ed4b0.png`
- Launch transition reference: `/var/folders/bv/dxb0_wm90mn_wnkjstp9_4540000gn/T/codex-clipboard-1e50aaf1-ae8c-4286-9938-8d5a2c3ed9d2.png`

## Implementation captures

- Main: `screenshots/appbox/home-installed.png`
- Settings: `screenshots/appbox/settings.png`
- Share: `screenshots/appbox/share.png`
- PIN: `screenshots/appbox/privacy-pin.png`
- Dark mode: `screenshots/appbox/dark.png`
- Dark settings: `screenshots/appbox/settings-dark.png`
- Dark theme picker: `screenshots/appbox/theme-dark.png`
- English layout: `screenshots/appbox/home-english.png`
- IPA import: `screenshots/appbox/ipa-import.png`
- Main side-by-side comparison: `screenshots/appbox/main-comparison.png`
- Share side-by-side comparison: `screenshots/appbox/share-comparison.png`
- Launch transition: `screenshots/appbox/launch-transition.png`
- Launch transition side-by-side comparison: `screenshots/appbox/launch-transition-comparison.png`

All implementation captures use an iPhone 16e simulator at 393 x 852 points. The main reference was center-cropped by 28 source pixels and scaled to the same implementation viewport before comparison.

## Comparison

- Typography: the refined version uses semibold headings, regular item labels, and restrained secondary text to create a clearer hierarchy without clipping.
- Layout: the reference structure remains recognizable through the header, search, conditional installed section, three series tabs, and five-column app grid. The implementation replaces heavy colored category bands with unframed sections and dividers for a quieter, more professional result.
- Color and surfaces: the page background is a neutral cool gray, while white or graphite surfaces, hairline borders, and accent-only selected states improve contrast. Native Liquid Glass is limited to controls on iOS 26; iOS 15-25 use a material fallback through the same component API. Sky, Mint, Coral, and dark appearances were checked.
- Controls: install actions use a stable 30-point control with a soft accent state; installed apps use the solid accent state. Segmented series and appearance controls share the same geometry and selected-state treatment.
- Assets and icons: AppBox uses a generated full-resolution bitmap app icon. All interface and catalog glyphs are exact SVG exports from the IconaMoon 1.1 Figma Community file's Light 24 x 24 style; semantic template colors were verified in light and dark modes.
- Interaction states: empty installed state, installing, installed, launch, search, language, appearance, skin, in-place share overlay, PIN entry, and IPA file/link import entry were exercised.
- Accessibility: all primary controls expose labels and selected traits; tap targets are at least 44 points; Chinese and English copy fit the tested viewport.
- Launch transition: the reference's centered app identity, title, progress bar, security status, and dimmed catalog context are preserved. The implementation uses the selected app's real catalog icon and localized name, and shows equivalent mid-launch progress at 48% versus the reference's 45%.

## Iterations

1. Added a simulator-only team identifier fallback after the unsigned simulator build exposed a missing entitlement value.
2. Kept signing and entitlement checks active on physical devices while bypassing them only for the simulator target.
3. Verified persisted install state after terminate/relaunch and ignored unrelated URL schemes instead of opening the importer.
4. Replaced every AppBox SF Symbol with a typed IconaMoon asset registry and hid decorative glyphs from the accessibility tree.
5. Consolidated semantic colors, spacing, surfaces, headings, headers, and control geometry into reusable AppBox presentation components.
6. Reworked catalog groups into neutral unframed sections, converted series and appearance choices into consistent segmented controls, and clarified install/open states.
7. Rebuilt settings, share, and PIN screens around the same typography, border, radius, and spacing rules.
8. Fixed appearance propagation so the active settings and theme sheets update immediately when switching between light and dark modes.
9. Removed decorative settings cards, catalog counts, heavy shadows, and filled install pills to produce a quieter content hierarchy.
10. Added native iOS 26 Liquid Glass for navigation and functional controls with an iOS 15-25 material fallback and Reduce Transparency handling.
11. Replaced the full-screen share presentation with an in-place overlay so the app center remains visible beneath a light 20% dimming layer.
12. Added one shared four-phase launch transition for installed IPA and H5 items: preparing, integrity verification, secure environment startup, and ready.
13. Refined the transition after side-by-side review by reducing the panel width, icon, and title scale, then replacing an over-blurred full-screen material with a restrained dim layer so the originating catalog remains legible.

## Launch Transition QA

- Reference: 1386 x 958 pixels. Implementation: 1170 x 2532 pixels, rendered at 390 x 844 points at 3x scale.
- Focus comparison: the implementation was cropped to the launch region and placed beside the full reference at a shared 958-pixel height. Both captures show the equivalent verification phase, at 45% and 48% respectively.
- Full-view review: the modal stays centered without clipping, preserves the installed and category context beneath it, and remains readable against varied catalog colors.
- Interaction review: the installed H5 item advances through 14%, 48%, 82%, and 100%, opens its web runtime, and returns to the catalog through the runtime close control. Duplicate launch taps are ignored while a transition is active.
- Accessibility review: each phase exposes a combined label containing the app name, phase description, and progress percentage.
- Native browser-console checks do not apply to this SwiftUI simulator flow; build diagnostics and runtime accessibility state were checked instead.

## Findings

- P0: none.
- P1: none.
- P2: the iOS 26.2 simulator share service renders an empty system activity sheet. `sharingd` reports `failed to update remote share sheet: no proxy object`; AppBox's QR/share poster and activity-controller invocation are valid, so this requires real-device confirmation rather than an application UI change.
- Launch transition P0/P1/P2: none after the final comparison pass.

final result: passed
