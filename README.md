# AppBox

AppBox is an iPhone application catalog and controlled NIVM/QEMU guest host.
It downloads only server-listed, pre-converted packages, verifies both the IPA
and `rocketship.nivm`, stores the validated application in its own sandbox, and
starts the selected guest inside the AppBox process.

## Active components

- [`NIVMHost`](./NIVMHost): active iPhone application and NIVM/QEMU launcher
- [`appbox-platform`](./appbox-platform): catalog API, admin console, encrypted
  icons, package metadata, and deployment configuration
- [`appbox-platform/deploy`](./appbox-platform/deploy): nginx/systemd deployment
  used by `https://3601.help`

## Runtime contract

Every IPA catalog record must contain:

- bundle ID, version, and build
- package URL and exact SHA-256
- NIVM URL and exact SHA-256

There is no selectable guest runtime. IPA records that do not satisfy this
contract are rejected by the API, and incomplete legacy records are disabled
during data-store migration.

The launcher is server-driven: adding, disabling, sorting, or regrouping a
validated application in AppBox Admin changes the iPhone catalog without a new
client build. The current production catalog contains five enabled entries;
normal converted packages require no per-app launcher code.

## Build and verification

Server:

```bash
cd /Users/king/Documents/GitHub/AppBox/appbox-platform
npm test
```

iPhone host:

```bash
cd /Users/king/Documents/GitHub/AppBox/NIVMHost
pod install
./scripts/build_and_install.sh 003F06EE-CAF3-553A-8035-CDD0276F9ED1
```

See [`NIVMHost/README.md`](./NIVMHost/README.md) for device launch and QA
commands, and [`appbox-platform/deploy/README.md`](./appbox-platform/deploy/README.md)
for server deployment.

## Boundary

This implementation supports explicitly converted and validated packages; it
is not an arbitrary-IPA runner. Its reverse-engineered private runtime is for
the current controlled-device workflow and must not be represented as
App-Store-safe.
