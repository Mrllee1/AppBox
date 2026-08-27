# Quietform (AppBox NIVM Host)

`Quietform` is the App Store-facing English product name. This repository is
the active iPhone host for the PlayBox-style AppBox flow.

## A/B surfaces

AppBox now keeps the original privacy surface as its A face and the NIVM app
catalog as its B face:

- A face (`Quietform`) uses Apple's `FamilyControls`, `ManagedSettings`, and
  the system `FamilyActivityPicker`. The user grants Screen Time access,
  chooses apps/categories in the iOS-owned picker, and can hide or restore the
  selected items. Only Apple's opaque selection tokens are persisted.
- B face (`天涯盒子`) is the existing encrypted catalog, download,
  installation, NIVM/QEMU runtime, and guest-return flow described below.
- A fresh install starts on A. Opening `appbox://box` (or the existing
  `appbox://open`, `appbox://install`, and `appbox://native` entry commands)
  activates B and persists it across normal launches.
- Opening `appbox://privacy` returns to A and persists that choice. The internal
  `appbox://playbox.guestapp.relaunch` callback deliberately preserves B so the
  guest floating menu continues to return to the box instead of exposing A.

The host target and its provisioning profile must both contain
`com.apple.developer.family-controls`. App Store distribution also requires the
corresponding Apple-approved Family Controls distribution entitlement; a local
development profile alone is not sufficient for release submission.

## User flow

1. The activated B face restores its last verified catalog from Application Support so a
   return/relaunch can render immediately, then refreshes the encrypted catalog
   from `AppBoxCatalogBaseURL` in the background.
2. The launcher renders server categories as five-column cards with real app
   icons and per-app `安装` / `启动` state.
3. `安装` downloads the converted IPA, verifies its SHA-256, bundle ID,
   version, build, `rocketship.nivm`/Flutter sidecar, and NIVM SHA-256.
4. The validated application is kept under AppBox's Documents container.
5. `启动` enters the selected NIVM/QEMU guest in the current AppBox process;
   the user does not need to reopen AppBox manually.
6. The guest window keeps a draggable PlayBox-style floating control. Tap it
   once to open PlayBox's full-screen pass-through menu and its separate
   `返回沙盒` action, then tap that action to relaunch the AppBox launcher
   automatically.

Every visible tile, including the source-built `pornhub_client`/天涯 package,
comes from the encrypted server catalog. A `.nivm.zip` URL selects the
source-built Flutter sidecar package format; converted applications use the
generic IPA-with-embedded-`rocketship.nivm` format. There is no hard-coded
launcher tile or server `runtime` selector.

The production catalog at `https://3601.help` currently contains five verified
entries in two groups:

- 看片: 天涯、成人抖音、成人抖音 3188.tv
- 直播: DYZB 官签、DYZB TF

## PlayBox-aligned launcher UI

- The launcher uses five-column app grids, compact rounded icon tiles, and
  separate group-card colors instead of one shared blue background.
- Installed packages show `启动`; packages absent from the local sandbox show
  `安装`. Downloaded applications also appear in a dedicated `已安装` card at
  the top of the catalog, matching PlayBox's icon-grid presentation; tapping an
  installed icon starts it directly.
- During installation, the selected tile shows the current stage or percentage,
  unrelated tiles are temporarily disabled, and a compact progress card shows
  the full download/verification message.
- During startup, the selected app is shown in a modal launch card with the
  PlayBox-aligned title, blue phase progress, green shield status, and a dimmed
  catalog backdrop. The overlay is rendered before entering the blocking NIVM
  bootstrap, preventing a visually blank or unresponsive transition.
- On the first run without a catalog cache, the launcher shows a dedicated
  loading card instead of an empty page. Network failure exposes an inline
  retry action, and pull-to-refresh is available after the launcher appears.
- The guest floating control is installed for the source-built Flutter runtime,
  normal in-process NIVM guests, and the special native-window guest path. It
  can be dragged vertically and snaps to the nearest screen edge.
- The floating control loads the original icon, highlighted icon, return icon,
  and localized title from `PBPlayerKit.framework/Floating.bundle`; a built-in
  AppBox symbol remains as the runtime fallback. Its expanded return action uses
  a compact black translucent card so it does not visually compete with guest
  content.

Real-device QA artifacts for this implementation are under
`Build/DeviceQA/playbox-ui-alignment/`, including the final launcher, loading
state, and Flutter guest screenshots. The revised PlayBox floating-menu proof
is under `Build/DeviceQA/playbox-floating-v2/`: `guest-floating-collapsed.png`,
`guest-floating-menu.png`, and `launcher-after-return.png` cover the collapsed
state, expanded return action, and automatic launcher recovery respectively.
The cache/startup revision is captured under
`Build/DeviceQA/playbox-launch-progress-cache/`: `launcher-cached.png`,
`launch-progress.png`, and `launcher-after-return.png` verify immediate catalog
restoration, the phase overlay, and recovery after the floating return action.
The A/B implementation is captured under `Build/DeviceQA/appbox-ab-surfaces/`:
`privacy-screen.png` and `box-screen.png` are real-device renders of the two
surfaces.

## Prerequisites

- Xcode and CocoaPods
- a connected, trusted iPhone included in the development profile
- `pornhub_client` at `../pornhub/pornhub_client`, or set
  `APPBOX_CLIENT_IOS_ROOT`
- the local converted artifacts under `/Users/king/Documents/AppBox`, or set
  `APPBOX_ARTIFACT_ROOT`
- an installed `/Applications/PlayBox.app`; the build stages the required
  private runtime frameworks from that local application

The runtime frameworks are intentionally not committed to this repository.

## Build, install, and launch

```bash
cd /Users/king/Documents/GitHub/AppBox/NIVMHost
pod install
./scripts/build_and_install.sh 003F06EE-CAF3-553A-8035-CDD0276F9ED1
```

Successful completion prints `APPBOX_HOST_OK`, installs
`com.tianya.appbox`, and launches it on the selected device.

## App Store IPA

Use the App Store build script instead of wrapping a device-specific build by
hand:

```bash
cd /Users/king/Documents/GitHub/AppBox/NIVMHost
./scripts/build_appstore_ipa.sh
```

The script creates a `generic/platform=iOS` archive, stages and signs the NIVM
runtime, preserves the required standalone 167x167 iPad Pro icon and its
`Info.plist` references, exports with App Store Connect signing, and then
verifies the ZIP, nested code signatures, source icon sets, and exported app
icon bundle. A successful run ends with `APPSTORE_IPA_OK` and prints the final
IPA path, byte size, and SHA-256.

The final bundle validation also rejects the non-public `-[NSBundle _cfBundle]`
selector and requires non-empty Contacts, Speech Recognition, and Calendar
purpose strings. Guest identity redirection creates its Core Foundation bundle
with the public `CFBundleCreate` API instead of calling the private selector.

The verified custom `ios_debug_unopt` Flutter engine remains the distribution
default because the smaller pure release engine currently crashes the
source-built Flutter guest during VM initialization. Debug and local symbols
are stripped from the staged copy, leaving the original engine build untouched.

Useful A/B QA launches are:

```bash
# Reset to and capture A.
xcrun devicectl device process launch --device <device-identifier> \
  --terminate-existing com.tianya.appbox --appbox-capture-privacy

# Force and capture B.
xcrun devicectl device process launch --device <device-identifier> \
  --terminate-existing com.tianya.appbox --appbox-capture-launcher
```

For repeatable device QA of a server-provided catalog app, launch AppBox with
its catalog id:

```bash
xcrun devicectl device process launch --device <device-identifier> \
  --terminate-existing --console com.tianya.appbox \
  --appbox-force-surface \
  --appbox-install-and-start-catalog-id=<catalog-app-id>
```

This waits for the encrypted remote catalog, downloads and validates the
selected package, and starts it in-process after installation succeeds.

Production catalog and encrypted-image settings can be supplied without
editing source:

```bash
APPBOX_CATALOG_BASE_URL=https://3601.help \
APPBOX_CLIENT_AES_KEY='<base64-32-byte-key>' \
APPBOX_ASSET_AES_KEY='<base64-or-hex-key>' \
APPBOX_ASSET_AES_IV='<base64-or-hex-iv>' \
./scripts/build_and_install.sh <device-identifier>
```

If the image key and IV are empty, both client and backend use the documented
SHA-256 fallback material. Never commit production secrets.

## Adding another application

Convert and validate the exact IPA first. Then create the entry in AppBox
Admin with all of the following fields:

- display name, icon, category, and group
- converted IPA URL and exact SHA-256
- bundle ID, version, and build from the converted package
- authoritative NIVM URL and exact SHA-256

No launcher code or new tile is required for a normal server-provided app.
Package-specific runtime compatibility work may still be necessary when a new
native framework, syscall, entitlement assumption, or guest ABI is encountered.

## Distribution boundary

The target uses QEMU/TCI, NIVM guest artifacts, patched private runtime
frameworks, and behavior reconstructed from PlayBox. It is suitable for the
current controlled-device research workflow, but it should not be represented
as App-Store-safe or expected to pass App Review in this form.
