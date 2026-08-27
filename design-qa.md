# AppBox PlayBox Alignment - Design QA

## Evidence

- Source visual: `/var/folders/bv/dxb0_wm90mn_wnkjstp9_4540000gn/T/codex-clipboard-0dc4b0fe-4288-408f-939d-19e4b3dde7a9.png`
- Implementation capture: `NIVMHost/QA/implementation-iphone15.png`
- Shared comparison input: `NIVMHost/QA/playbox-comparison.png`
- In-process runtime capture: `NIVMHost/QA/inprocess-guest-adult-douyin-315.png`
- Device: connected iPhone 15, portrait, 393 x 852 points at 3x
- Implementation pixels: 1179 x 2556
- Source pixels: 668 x 576, cropped catalog component; source point density is unknown
- Tested state: offline catalog fallback, six supported applications grouped
  into `看片` and `直播`, two installed/launchable guests, remaining install
  controls visible

The comparison uses the supplied PlayBox catalog component and a focused crop
of the same catalog region from the physical-device capture. The source is not
a full-screen reference, so full-view parity is assessed only for the shared
catalog surface.

## Fidelity review

- Typography: bold white section titles, compact semibold app labels, and
  readable capsule actions follow the reference hierarchy without clipping.
- Layout: rounded category cards, five equal columns, square icons, two-line
  labels, and one action per tile match the PlayBox structure.
- Color: the dark page, blue/teal grouped cards, restrained borders, and muted
  action pills reproduce the visible source palette and contrast.
- Images: fallback entries use real icons extracted from their corresponding
  IPA packages. Remote catalog icons are downloaded and AES-256-CBC decrypted
  using the same key/IV contract as the backend.
- Copy and state: group titles and app names are real data. `安装` changes to
  `启动` only after strict package verification and persisted installation.
- Interaction: install downloads the selected package; launch enters an NIVM
  guest in the current AppBox process without requiring a manual reopen.
- Compatibility boundary: the known Flutter Debug package
  `tianya-348-playbox.ipa` is intentionally excluded from the supported catalog;
  its device run requires Flutter tooling and is not a valid standalone guest.

## Iterations

1. The first implementation used generic symbols and a separate single-item
   recommendation card. The result had visibly different density and hierarchy.
2. Real IPA icons were extracted, the source-built guest was merged into the
   first five-column group, and section/card geometry was tightened.
3. Remote encrypted icons were added to the same rendering path so the online
   server state remains visually identical to the verified fallback state.
4. The final physical-device run installed Adult Douyin 3.1.5, launched it
   in-process, and reached the application's login screen after its resource
   bootstrap. The source-built Tianya 20.0.0+357 guest was also reinstalled so
   both applications coexist with `启动` state. The resulting screens are
   preserved in the captures above.

## Findings

- P0: none.
- P1: none.
- P2: none.
- P3: the supplied source contains five applications in each group, while the
  verified fallback currently contains four video applications and two
  live-streaming applications; this is data-driven and does not change the
  five-column grid geometry.

final result: passed
