# AppBox

AppBox is a SwiftUI application-center shell built on LiveContainer. The catalog UI is intentionally independent from LiveContainer's IPA import and runtime internals.

## Module boundaries

- `AppBoxCatalog`: hardcoded catalog data and deterministic search/grouping.
- `AppBoxStore`: unified IPA/H5 install coordination and idempotency guards.
- `AppBoxLocalInstallStore`: persistent local install records with legacy simulator-state migration.
- `AppBoxContainerBridging`: the runtime boundary injected into the store for isolated tests.
- `AppBoxContainerBridge`: the production adapter from catalog IDs to LiveContainer models.
- `AppBoxWebDataStore`: per-app WebKit data-store lifecycle and uninstall cleanup.
- `AppBoxWebAppView`: isolated full-screen H5 runtime with navigation and failure recovery.
- `AppBoxPINService`: Keychain-backed PIN storage behind `AppBoxPINProviding`.
- Views and components: presentation only; they do not parse IPAs or write Keychain data.

## Icons

AppBox UI glyphs use Apple SF Symbols through a typed `AppBoxIcon` registry. `AppBoxGlyph` is the single SwiftUI rendering entry point, while the injected sandbox control uses `UIImage systemImageNamed:` so host and guest interfaces stay visually consistent.

## Visual system

`AppBoxPalette` owns semantic colors for light and dark appearances while `AppBoxLayout` owns shared spacing, control height, and the 8-point corner radius. Reusable surface, header, search, icon button, section heading, and app-cell components keep feature screens free of duplicated styling. Skin changes affect the accent color without tinting the entire interface, preserving contrast and a neutral professional hierarchy.

On iOS 26 and later, functional controls use SwiftUI's native `glassEffect` API. App content remains on neutral opaque surfaces so the hierarchy stays readable. iOS 15 through iOS 25 use an `ultraThinMaterial` fallback through the same `appBoxGlassControl` modifier, including a solid-surface path when Reduce Transparency is enabled.

The share experience is an in-place overlay rather than a full-screen presentation. It keeps the underlying app center visible without a dark dimming layer and presents the poster, close action, and share actions in one focused dialog.

## Install behavior

Simulator catalog installs are deterministic mock installs because iOS Simulator cannot execute device IPA binaries. The result persists in `UserDefaults` and appears in the installed section only after the first successful install.

On a signed physical device, `.ipa(downloadURL:)` values in `AppBoxCatalog.swift` are forwarded to LiveContainer's installer. The Settings screen also exposes the original file and URL IPA import flow.

H5 catalog entries use the same install/open states as IPA entries. Install writes one local record, open presents an in-app `WKWebView`, and uninstall removes both the record and website data. iOS 17 and later use a persistent named `WKWebsiteDataStore` per catalog item. iOS 15 and 16 retain normal WebKit persistence and clear records for the app's host on uninstall because named stores are unavailable on those releases.

`AppBoxStore.install(_:)` is idempotent: an installed app, an in-progress app, or an active install request is rejected before any state mutation. Persisted sets are written only when the value changes. Keychain writes are skipped when the stored PIN hash already matches.

## Real-device requirements

AppBox inherits LiveContainer's signing, entitlement, JIT, and iOS-version requirements. Installing AppBox does not remove Apple's code-signing restrictions, and catalog IPA files still need to be compatible with the selected LiveContainer setup.
