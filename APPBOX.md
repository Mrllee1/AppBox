# AppBox

AppBox is a SwiftUI application-center shell built on LiveContainer. The catalog UI is intentionally independent from LiveContainer's IPA import and runtime internals.

## Module boundaries

- `AppBoxCatalog`: hardcoded catalog data and deterministic search/grouping.
- `AppBoxStore`: UI state, install coordination, persistence, and idempotency guards.
- `AppBoxContainerBridging`: the runtime boundary injected into the store for isolated tests.
- `AppBoxContainerBridge`: the production adapter from catalog IDs to LiveContainer models.
- `AppBoxPINService`: Keychain-backed PIN storage behind `AppBoxPINProviding`.
- Views and components: presentation only; they do not parse IPAs or write Keychain data.

## Icons

AppBox UI glyphs use exact SVG exports from the IconaMoon 1.1 Figma Community file. `AppBoxIcon` is the single typed icon registry and `AppBoxGlyph` is the only rendering entry point, so feature views do not depend on SF Symbols. Source nodes and asset names are recorded in `ICONAMOON.md`.

## Visual system

`AppBoxPalette` owns semantic colors for light and dark appearances while `AppBoxLayout` owns shared spacing, control height, and the 8-point corner radius. Reusable surface, header, search, icon button, section heading, and app-cell components keep feature screens free of duplicated styling. Skin changes affect the accent color without tinting the entire interface, preserving contrast and a neutral professional hierarchy.

On iOS 26 and later, functional controls use SwiftUI's native `glassEffect` API. App content remains on neutral opaque surfaces so the hierarchy stays readable. iOS 15 through iOS 25 use an `ultraThinMaterial` fallback through the same `appBoxGlassControl` modifier, including a solid-surface path when Reduce Transparency is enabled.

The share experience is an in-place overlay rather than a full-screen presentation. This preserves the visible app center behind a light dimming layer while keeping the poster, close action, and share actions independent and reusable.

## Install behavior

Simulator catalog installs are deterministic mock installs because iOS Simulator cannot execute device IPA binaries. The result persists in `UserDefaults` and appears in the installed section only after the first successful install.

On a signed physical device, `downloadURL` values in `AppBoxCatalog.swift` are forwarded to LiveContainer's installer. The Settings screen also exposes the original file and URL IPA import flow.

`AppBoxStore.install(_:)` is idempotent: an installed app, an in-progress app, or an active install request is rejected before any state mutation. Persisted sets are written only when the value changes. Keychain writes are skipped when the stored PIN hash already matches.

## Real-device requirements

AppBox inherits LiveContainer's signing, entitlement, JIT, and iOS-version requirements. Installing AppBox does not remove Apple's code-signing restrictions, and catalog IPA files still need to be compatible with the selected LiveContainer setup.
