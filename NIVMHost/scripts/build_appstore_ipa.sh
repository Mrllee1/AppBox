#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APPBOX_ARTIFACT_ROOT="${APPBOX_ARTIFACT_ROOT:-/Users/king/Documents/AppBox}"
APPBOX_CLIENT_IOS_ROOT="${APPBOX_CLIENT_IOS_ROOT:-${PROJECT_ROOT}/../../pornhub/pornhub_client/ios}"
APPBOX_CATALOG_BASE_URL="${APPBOX_CATALOG_BASE_URL:-https://3601.help}"
APPBOX_VERIFICATION_BASE_URL="${APPBOX_VERIFICATION_BASE_URL:-$APPBOX_CATALOG_BASE_URL}"
APPBOX_CLIENT_AES_KEY="${APPBOX_CLIENT_AES_KEY:-}"
APPBOX_ASSET_AES_KEY="${APPBOX_ASSET_AES_KEY:-}"
APPBOX_ASSET_AES_IV="${APPBOX_ASSET_AES_IV:-}"
APPBOX_GUEST_URL="${APPBOX_GUEST_URL:-}"
APPBOX_PORNHUB_GUEST_URL="${APPBOX_PORNHUB_GUEST_URL:-}"
APPBOX_PLAYBOX_GUEST_URL="${APPBOX_PLAYBOX_GUEST_URL:-}"
APPBOX_DYZB_GQ_GUEST_URL="${APPBOX_DYZB_GQ_GUEST_URL:-}"
APPBOX_DYZB_TF_GUEST_URL="${APPBOX_DYZB_TF_GUEST_URL:-}"
APPBOX_CHUNGONG_GUEST_URL="${APPBOX_CHUNGONG_GUEST_URL:-}"
APPBOX_IG_XIONGMAO_GUEST_URL="${APPBOX_IG_XIONGMAO_GUEST_URL:-}"
APPBOX_TIANYA_348_GUEST_URL="${APPBOX_TIANYA_348_GUEST_URL:-}"
PORNHUB_GUEST_IPA="${PORNHUB_GUEST_IPA:-/Users/king/Documents/GitHub/pornhub/pornhub_client/dist/ios/non_tf/天涯-非TF-20.0.0+357.ipa}"
# The stock release-mode engine currently crashes source-built Flutter guests
# during DartVM::GetVMData. Keep the previously verified custom debug-unopt
# engine and strip its debug/local symbols below for a safe size reduction.
CUSTOM_FLUTTER_FRAMEWORK="${CUSTOM_FLUTTER_FRAMEWORK:-/Users/king/flutter/engine/src/out/ios_debug_unopt/Flutter.framework}"
TEAM_ID="${TEAM_ID:-6TQJ3XWC45}"
BUILD_STAMP="${BUILD_STAMP:-$(date '+%Y%m%d-%H%M%S')}"
OUTPUT_ROOT="${OUTPUT_ROOT:-${PROJECT_ROOT}/dist/Quietform-appstore-optimized-${BUILD_STAMP}}"
ARCHIVE_PATH="${OUTPUT_ROOT}/Quietform.xcarchive"
EXPORT_PATH="${OUTPUT_ROOT}/export"
DERIVED_DATA="${OUTPUT_ROOT}/DerivedData"
ZIPFOUNDATION_DERIVED_DATA="${OUTPUT_ROOT}/ZIPFoundationDerivedData"
RUNTIME_ROOT="${OUTPUT_ROOT}/Runtime"
RUNTIME_FRAMEWORKS="${RUNTIME_ROOT}/Frameworks"
PLUGIN_ROOT="${OUTPUT_ROOT}/PornhubPlugins"
EXPORT_OPTIONS="${OUTPUT_ROOT}/ExportOptions-AppStore.plist"
ARCHIVE_ENTITLEMENTS="${OUTPUT_ROOT}/archive-entitlements.plist"
LEGACY_IPAD_ICON_SOURCE="${PROJECT_ROOT}/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png"
LEGACY_IPAD_ICON_NAME="AppIcon83.5x83.5"
LEGACY_IPAD_ICON_FILE="${LEGACY_IPAD_ICON_NAME}@2x~ipad.png"

fail() {
  printf 'App Store build failed: %s\n' "$*" >&2
  exit 1
}

validate_appstore_bundle() {
  local app_path="$1"
  local info_plist="${app_path}/Info.plist"
  local key value

  for key in \
    NSContactsUsageDescription \
    NSSpeechRecognitionUsageDescription \
    NSCalendarsUsageDescription \
    NSCalendarsFullAccessUsageDescription \
    NSCalendarsWriteOnlyAccessUsageDescription; do
    value="$(plutil -extract "${key}" raw -o - "${info_plist}" 2>/dev/null || true)"
    [[ -n "${value}" ]] || fail "missing or empty privacy purpose string: ${key}"
  done

  if rg -a -l -F '_cfBundle' "${app_path}" >/dev/null; then
    fail "non-public selector remains in the built application: _cfBundle"
  fi

  if rg -a -l -F '/api/v1/appbox/internal-unlock/redeem' "${app_path}" >/dev/null; then
    fail "internal unlock support leaked into the App Store application"
  fi
}

[[ -d "${APPBOX_CLIENT_IOS_ROOT}/.symlinks/plugins" ]] \
  || fail "Flutter plugin links were not found at ${APPBOX_CLIENT_IOS_ROOT}"
[[ -f "${PORNHUB_GUEST_IPA}" ]] || fail "pornhub_client IPA is missing: ${PORNHUB_GUEST_IPA}"
[[ -f "${CUSTOM_FLUTTER_FRAMEWORK}/Flutter" ]] \
  || fail "release Flutter runtime is missing: ${CUSTOM_FLUTTER_FRAMEWORK}"
[[ -f "${LEGACY_IPAD_ICON_SOURCE}" ]] \
  || fail "167x167 iPad Pro icon is missing: ${LEGACY_IPAD_ICON_SOURCE}"

mkdir -p "${OUTPUT_ROOT}" "${RUNTIME_FRAMEWORKS}" "${PLUGIN_ROOT}"
mkdir -p "${PROJECT_ROOT}/.symlinks"
ln -sfn "${APPBOX_CLIENT_IOS_ROOT}/.symlinks/plugins" "${PROJECT_ROOT}/.symlinks/plugins"

"${SCRIPT_DIR}/validate_app_icons.sh"

xcodebuild \
  -quiet \
  -project "${PROJECT_ROOT}/Pods/Pods.xcodeproj" \
  -scheme ZIPFoundation \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "${ZIPFOUNDATION_DERIVED_DATA}" \
  build

"${SCRIPT_DIR}/prepare_playbox_runtime.sh" "${RUNTIME_FRAMEWORKS}"

ZIPFOUNDATION_FRAMEWORK="${PROJECT_ROOT}/build/Release-iphoneos/ZIPFoundation/ZIPFoundation.framework"
[[ -f "${ZIPFOUNDATION_FRAMEWORK}/ZIPFoundation" ]] \
  || fail "ZIPFoundation runtime was not built: ${ZIPFOUNDATION_FRAMEWORK}"
ditto "${ZIPFOUNDATION_FRAMEWORK}" "${RUNTIME_FRAMEWORKS}/ZIPFoundation.framework"
ditto "${CUSTOM_FLUTTER_FRAMEWORK}" "${RUNTIME_FRAMEWORKS}/Flutter.framework"

ditto -x -k "${PORNHUB_GUEST_IPA}" "${PLUGIN_ROOT}"
PORNHUB_PLUGIN_APP="$(find "${PLUGIN_ROOT}/Payload" -maxdepth 1 -type d -name '*.app' -print -quit)"
[[ -n "${PORNHUB_PLUGIN_APP}" ]] || fail "pornhub_client app bundle was not found in the IPA"
for framework_name in \
  JNKeychain \
  connectivity_plus \
  device_info_plus \
  flutter_secure_storage \
  mobile_device_identifier \
  package_info_plus \
  path_provider_foundation \
  shared_preferences_foundation; do
  source_framework="${PORNHUB_PLUGIN_APP}/Frameworks/${framework_name}.framework"
  [[ -f "${source_framework}/${framework_name}" ]] \
    || fail "required pornhub_client plugin is missing: ${framework_name}"
  ditto "${source_framework}" "${RUNTIME_FRAMEWORKS}/${framework_name}.framework"
done

if [[ "${APPBOX_STRIP_RUNTIME:-1}" == "1" ]]; then
  for binary in \
    "${RUNTIME_FRAMEWORKS}/Flutter.framework/Flutter" \
    "${RUNTIME_FRAMEWORKS}/PBPlayerKit.framework/PBPlayerKit" \
    "${RUNTIME_FRAMEWORKS}/VLCKit.framework/VLCKit"; do
    [[ -f "${binary}" ]] || fail "runtime binary is missing: ${binary}"
    xcrun strip -S -x "${binary}"
  done
fi

xcodebuild \
  -quiet \
  -workspace "${PROJECT_ROOT}/Runner.xcworkspace" \
  -scheme Runner \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "${DERIVED_DATA}" \
  -archivePath "${ARCHIVE_PATH}" \
  -allowProvisioningUpdates \
  "FRAMEWORK_SEARCH_PATHS=\$(inherited) ${RUNTIME_FRAMEWORKS}" \
  SWIFT_ENABLE_EXPLICIT_MODULES=NO \
  APPBOX_CATALOG_BASE_URL="${APPBOX_CATALOG_BASE_URL}" \
  APPBOX_VERIFICATION_BASE_URL="${APPBOX_VERIFICATION_BASE_URL}" \
  APPBOX_CLIENT_AES_KEY="${APPBOX_CLIENT_AES_KEY}" \
  APPBOX_ASSET_AES_KEY="${APPBOX_ASSET_AES_KEY}" \
  APPBOX_ASSET_AES_IV="${APPBOX_ASSET_AES_IV}" \
  APPBOX_GUEST_URL="${APPBOX_GUEST_URL}" \
  APPBOX_PORNHUB_GUEST_URL="${APPBOX_PORNHUB_GUEST_URL}" \
  APPBOX_PLAYBOX_GUEST_URL="${APPBOX_PLAYBOX_GUEST_URL}" \
  APPBOX_DYZB_GQ_GUEST_URL="${APPBOX_DYZB_GQ_GUEST_URL}" \
  APPBOX_DYZB_TF_GUEST_URL="${APPBOX_DYZB_TF_GUEST_URL}" \
  APPBOX_CHUNGONG_GUEST_URL="${APPBOX_CHUNGONG_GUEST_URL}" \
  APPBOX_IG_XIONGMAO_GUEST_URL="${APPBOX_IG_XIONGMAO_GUEST_URL}" \
  APPBOX_TIANYA_348_GUEST_URL="${APPBOX_TIANYA_348_GUEST_URL}" \
  archive

HOST_APP="${ARCHIVE_PATH}/Products/Applications/Runner.app"
[[ -d "${HOST_APP}" ]] || fail "archived application was not found: ${HOST_APP}"

# Xcode keeps the 167x167 rendition in Assets.car, but App Store validation can
# also require the legacy standalone iPad Pro icon referenced by Info.plist.
# Keep both representations so the bundle is accepted by modern and older
# validation paths.
ditto "${LEGACY_IPAD_ICON_SOURCE}" "${HOST_APP}/${LEGACY_IPAD_ICON_FILE}"

INFO_PLIST="${HOST_APP}/Info.plist"
/usr/libexec/PlistBuddy -c 'Delete :CFBundleIconFiles~ipad' "${INFO_PLIST}" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c 'Add :CFBundleIconFiles~ipad array' "${INFO_PLIST}"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIconFiles~ipad:0 string AppIcon60x60' "${INFO_PLIST}"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIconFiles~ipad:1 string AppIcon76x76' "${INFO_PLIST}"
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFiles~ipad:2 string ${LEGACY_IPAD_ICON_NAME}" "${INFO_PLIST}"
/usr/libexec/PlistBuddy -c 'Delete :CFBundleIcons~ipad:CFBundlePrimaryIcon:CFBundleIconFiles' "${INFO_PLIST}" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c 'Add :CFBundleIcons~ipad:CFBundlePrimaryIcon:CFBundleIconFiles array' "${INFO_PLIST}"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIcons~ipad:CFBundlePrimaryIcon:CFBundleIconFiles:0 string AppIcon60x60' "${INFO_PLIST}"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIcons~ipad:CFBundlePrimaryIcon:CFBundleIconFiles:1 string AppIcon76x76' "${INFO_PLIST}"
/usr/libexec/PlistBuddy -c "Add :CFBundleIcons~ipad:CFBundlePrimaryIcon:CFBundleIconFiles:2 string ${LEGACY_IPAD_ICON_NAME}" "${INFO_PLIST}"

SIGNING_AUTHORITY="$(codesign -d --verbose=4 "${HOST_APP}" 2>&1 \
  | sed -n 's/^Authority=//p' \
  | head -1)"
SIGNING_IDENTITY="$(security find-identity -v -p codesigning \
  | grep -F "\"${SIGNING_AUTHORITY}\"" \
  | awk 'NR == 1 { print $2 }')"
[[ -n "${SIGNING_IDENTITY}" ]] || fail "archive signing identity could not be resolved"

codesign -d --entitlements :- "${HOST_APP}" > "${ARCHIVE_ENTITLEMENTS}" 2>/dev/null
plutil -lint "${ARCHIVE_ENTITLEMENTS}" >/dev/null

mkdir -p "${HOST_APP}/Frameworks"
while IFS= read -r framework; do
  ditto "${framework}" "${HOST_APP}/Frameworks/$(basename "${framework}")"
done < <(find "${RUNTIME_FRAMEWORKS}" -maxdepth 1 -type d -name '*.framework' -print | sort)

while IFS= read -r framework; do
  codesign --force --sign "${SIGNING_IDENTITY}" --timestamp=none "${framework}"
done < <(find "${HOST_APP}/Frameworks" -maxdepth 1 -type d -name '*.framework' -print | sort)
codesign --force --sign "${SIGNING_IDENTITY}" --timestamp=none \
  --entitlements "${ARCHIVE_ENTITLEMENTS}" "${HOST_APP}"
codesign --verify --deep --strict --verbose=2 "${HOST_APP}"
"${SCRIPT_DIR}/validate_app_icons.sh" "${HOST_APP}"
validate_appstore_bundle "${HOST_APP}"

plutil -create xml1 "${EXPORT_OPTIONS}"
plutil -insert destination -string export "${EXPORT_OPTIONS}"
plutil -insert manageAppVersionAndBuildNumber -bool NO "${EXPORT_OPTIONS}"
plutil -insert method -string app-store-connect "${EXPORT_OPTIONS}"
plutil -insert signingStyle -string automatic "${EXPORT_OPTIONS}"
plutil -insert stripSwiftSymbols -bool YES "${EXPORT_OPTIONS}"
plutil -insert teamID -string "${TEAM_ID}" "${EXPORT_OPTIONS}"
plutil -insert uploadSymbols -bool NO "${EXPORT_OPTIONS}"

xcodebuild \
  -quiet \
  -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${EXPORT_PATH}" \
  -exportOptionsPlist "${EXPORT_OPTIONS}" \
  -allowProvisioningUpdates

IPA_PATH="$(find "${EXPORT_PATH}" -maxdepth 1 -type f -name '*.ipa' -print -quit)"
[[ -n "${IPA_PATH}" ]] || fail "export did not produce an IPA"
unzip -tq "${IPA_PATH}"

VALIDATION_ROOT="${OUTPUT_ROOT}/validation"
mkdir -p "${VALIDATION_ROOT}"
ditto -x -k "${IPA_PATH}" "${VALIDATION_ROOT}"
VALIDATION_APP="$(find "${VALIDATION_ROOT}/Payload" -maxdepth 1 -type d -name '*.app' -print -quit)"
[[ -n "${VALIDATION_APP}" ]] || fail "exported app bundle was not found"
codesign --verify --deep --strict --verbose=2 "${VALIDATION_APP}"
"${SCRIPT_DIR}/validate_app_icons.sh" "${VALIDATION_APP}"
validate_appstore_bundle "${VALIDATION_APP}"

printf 'APPSTORE_IPA_OK\n'
printf 'ipa=%s\n' "${IPA_PATH}"
printf 'bytes=%s\n' "$(stat -f '%z' "${IPA_PATH}")"
printf 'sha256=%s\n' "$(shasum -a 256 "${IPA_PATH}" | awk '{print $1}')"
