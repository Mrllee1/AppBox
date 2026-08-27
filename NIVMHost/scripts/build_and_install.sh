#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOST_DIR="$PROJECT_ROOT"
APPBOX_ARTIFACT_ROOT="${APPBOX_ARTIFACT_ROOT:-/Users/king/Documents/AppBox}"
APPBOX_CLIENT_IOS_ROOT="${APPBOX_CLIENT_IOS_ROOT:-$PROJECT_ROOT/../../pornhub/pornhub_client/ios}"
DEFAULT_DEVICE="003F06EE-CAF3-553A-8035-CDD0276F9ED1"
DEVICE_ID="${1:-$DEFAULT_DEVICE}"
DERIVED_DATA="$PROJECT_ROOT/Build/DerivedData"
ZIPFOUNDATION_DERIVED_DATA="$PROJECT_ROOT/Build/ZIPFoundationDerivedData"
APPBOX_GUEST_URL="${APPBOX_GUEST_URL:-}"
APPBOX_PORNHUB_GUEST_URL="${APPBOX_PORNHUB_GUEST_URL:-}"
APPBOX_PLAYBOX_GUEST_URL="${APPBOX_PLAYBOX_GUEST_URL:-}"
APPBOX_DYZB_GQ_GUEST_URL="${APPBOX_DYZB_GQ_GUEST_URL:-}"
APPBOX_DYZB_TF_GUEST_URL="${APPBOX_DYZB_TF_GUEST_URL:-}"
APPBOX_CHUNGONG_GUEST_URL="${APPBOX_CHUNGONG_GUEST_URL:-}"
APPBOX_IG_XIONGMAO_GUEST_URL="${APPBOX_IG_XIONGMAO_GUEST_URL:-}"
APPBOX_TIANYA_348_GUEST_URL="${APPBOX_TIANYA_348_GUEST_URL:-}"
APPBOX_CATALOG_BASE_URL="${APPBOX_CATALOG_BASE_URL:-https://3601.help}"
APPBOX_CLIENT_AES_KEY="${APPBOX_CLIENT_AES_KEY:-6btlrID18OytwUZ0s41atap+4WxlXr1xpebjrE04hnY=}"
APPBOX_ASSET_AES_KEY="${APPBOX_ASSET_AES_KEY:-}"
APPBOX_ASSET_AES_IV="${APPBOX_ASSET_AES_IV:-}"
PLAYBOX_RUNTIME_ROOT="$(mktemp -d /tmp/appbox-playbox-runtime.XXXXXX)"
PLAYBOX_RUNTIME_FRAMEWORKS="$PLAYBOX_RUNTIME_ROOT/Frameworks"
PLAYBOX_GUEST_IPA="${PLAYBOX_GUEST_IPA:-$APPBOX_ARTIFACT_ROOT/PlayBoxGuests/adult-douyin-3.1.5.ipa}"
PORNHUB_GUEST_IPA="/Users/king/Documents/GitHub/pornhub/pornhub_client/dist/ios/non_tf/天涯-非TF-20.0.0+357.ipa"
PORNHUB_GUEST_NIVM="${PORNHUB_GUEST_NIVM:-$APPBOX_ARTIFACT_ROOT/Artifacts/guest.nivm.zip}"
CUSTOM_FLUTTER_FRAMEWORK="/Users/king/flutter/engine/src/out/ios_debug_unopt/Flutter.framework"

if [[ ! -d "$APPBOX_CLIENT_IOS_ROOT/.symlinks/plugins" ]]; then
  echo "pornhub_client Flutter plugin links were not found: $APPBOX_CLIENT_IOS_ROOT" >&2
  exit 9
fi
mkdir -p "$HOST_DIR/.symlinks"
ln -sfn "$APPBOX_CLIENT_IOS_ROOT/.symlinks/plugins" "$HOST_DIR/.symlinks/plugins"

if [[ -z "$APPBOX_GUEST_URL" ]]; then
  DEVICE_TUNNEL_IP="$(xcrun devicectl device info details --device "$DEVICE_ID" \
    | sed -n 's/.*tunnelIPAddress: //p' \
    | head -1)"
  if [[ "$DEVICE_TUNNEL_IP" != *"::1" ]]; then
    echo "Could not derive the CoreDevice host tunnel address." >&2
    exit 10
  fi
  APPBOX_GUEST_URL="http://[${DEVICE_TUNNEL_IP%::1}::2]:8080/guest.ipa"
fi
if [[ -z "$APPBOX_PORNHUB_GUEST_URL" ]]; then
  APPBOX_PORNHUB_GUEST_URL="$APPBOX_GUEST_URL"
fi
if [[ -z "$APPBOX_PLAYBOX_GUEST_URL" ]]; then
  APPBOX_PLAYBOX_GUEST_URL="${APPBOX_GUEST_URL%guest.ipa}playbox-guest.ipa"
fi
if [[ -z "$APPBOX_DYZB_GQ_GUEST_URL" ]]; then
  APPBOX_DYZB_GQ_GUEST_URL="${APPBOX_GUEST_URL%guest.ipa}dyzb-gq-playbox.ipa"
fi
if [[ -z "$APPBOX_DYZB_TF_GUEST_URL" ]]; then
  APPBOX_DYZB_TF_GUEST_URL="${APPBOX_GUEST_URL%guest.ipa}dyzb-tf-playbox.ipa"
fi
if [[ -z "$APPBOX_CHUNGONG_GUEST_URL" ]]; then
  APPBOX_CHUNGONG_GUEST_URL="${APPBOX_GUEST_URL%guest.ipa}chungong-playbox.ipa"
fi
if [[ -z "$APPBOX_IG_XIONGMAO_GUEST_URL" ]]; then
  APPBOX_IG_XIONGMAO_GUEST_URL="${APPBOX_GUEST_URL%guest.ipa}ig-xiongmao-playbox.ipa"
fi
if [[ -z "$APPBOX_TIANYA_348_GUEST_URL" ]]; then
  APPBOX_TIANYA_348_GUEST_URL="${APPBOX_GUEST_URL%guest.ipa}tianya-348-playbox.ipa"
fi

xcodebuild \
  -project "$HOST_DIR/Pods/Pods.xcodeproj" \
  -scheme ZIPFoundation \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$ZIPFOUNDATION_DERIVED_DATA" \
  build

"$SCRIPT_DIR/prepare_playbox_runtime.sh" "$PLAYBOX_RUNTIME_FRAMEWORKS"
ZIPFOUNDATION_FRAMEWORK="$HOST_DIR/build/Release-iphoneos/ZIPFoundation/ZIPFoundation.framework"
if [[ ! -f "$ZIPFOUNDATION_FRAMEWORK/ZIPFoundation" ]]; then
  echo "ZIPFoundation runtime was not built: $ZIPFOUNDATION_FRAMEWORK" >&2
  exit 11
fi
rm -rf "$PLAYBOX_RUNTIME_FRAMEWORKS/ZIPFoundation.framework"
ditto "$ZIPFOUNDATION_FRAMEWORK" "$PLAYBOX_RUNTIME_FRAMEWORKS/ZIPFoundation.framework"
if [[ ! -f "$CUSTOM_FLUTTER_FRAMEWORK/Flutter" ]]; then
  echo "Custom Flutter runtime was not built: $CUSTOM_FLUTTER_FRAMEWORK" >&2
  exit 12
fi
ditto "$CUSTOM_FLUTTER_FRAMEWORK" "$PLAYBOX_RUNTIME_FRAMEWORKS/Flutter.framework"

# Core Flutter plugins are taken from the exact target IPA and re-signed as
# nested AppBox code. They are not linked into the launcher and are loaded only
# after the Flutter guest runtime has been selected.
PORNHUB_PLUGIN_ROOT="$(mktemp -d /tmp/appbox-pornhub-plugins.XXXXXX)"
ditto -x -k "$PORNHUB_GUEST_IPA" "$PORNHUB_PLUGIN_ROOT"
PORNHUB_PLUGIN_APP="$(find "$PORNHUB_PLUGIN_ROOT/Payload" -maxdepth 1 -type d -name '*.app' -print -quit)"
for framework_name in \
  JNKeychain \
  connectivity_plus \
  device_info_plus \
  flutter_secure_storage \
  mobile_device_identifier \
  package_info_plus \
  path_provider_foundation \
  shared_preferences_foundation; do
  source_framework="$PORNHUB_PLUGIN_APP/Frameworks/$framework_name.framework"
  if [[ ! -f "$source_framework/$framework_name" ]]; then
    echo "Required pornhub_client plugin is missing: $framework_name" >&2
    exit 13
  fi
  ditto "$source_framework" "$PLAYBOX_RUNTIME_FRAMEWORKS/$framework_name.framework"
done

xcodebuild \
  -workspace "$HOST_DIR/Runner.xcworkspace" \
  -scheme Runner \
  -configuration Release \
  -destination "id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA" \
  "FRAMEWORK_SEARCH_PATHS=\$(inherited) $PLAYBOX_RUNTIME_FRAMEWORKS" \
  APPBOX_GUEST_URL="$APPBOX_GUEST_URL" \
  APPBOX_PORNHUB_GUEST_URL="$APPBOX_PORNHUB_GUEST_URL" \
  APPBOX_PLAYBOX_GUEST_URL="$APPBOX_PLAYBOX_GUEST_URL" \
  APPBOX_DYZB_GQ_GUEST_URL="$APPBOX_DYZB_GQ_GUEST_URL" \
  APPBOX_DYZB_TF_GUEST_URL="$APPBOX_DYZB_TF_GUEST_URL" \
  APPBOX_CHUNGONG_GUEST_URL="$APPBOX_CHUNGONG_GUEST_URL" \
  APPBOX_IG_XIONGMAO_GUEST_URL="$APPBOX_IG_XIONGMAO_GUEST_URL" \
  APPBOX_TIANYA_348_GUEST_URL="$APPBOX_TIANYA_348_GUEST_URL" \
  APPBOX_CATALOG_BASE_URL="$APPBOX_CATALOG_BASE_URL" \
  APPBOX_CLIENT_AES_KEY="$APPBOX_CLIENT_AES_KEY" \
  APPBOX_ASSET_AES_KEY="$APPBOX_ASSET_AES_KEY" \
  APPBOX_ASSET_AES_IV="$APPBOX_ASSET_AES_IV" \
  clean build

HOST_APP="$DERIVED_DATA/Build/Products/Release-iphoneos/Runner.app"
if [[ ! -d "$HOST_APP" ]]; then
  echo "Built AppBox was not found: $HOST_APP" >&2
  exit 20
fi
SIGNING_AUTHORITY="$(codesign -d --verbose=4 "$HOST_APP" 2>&1 \
  | sed -n 's/^Authority=//p' \
  | head -1)"
SIGNING_IDENTITY="$(security find-identity -v -p codesigning \
  | grep -F "\"$SIGNING_AUTHORITY\"" \
  | awk 'NR == 1 { print $2 }')"
ENTITLEMENTS="$DERIVED_DATA/Build/Intermediates.noindex/Runner.build/Release-iphoneos/Runner.build/Runner.app.xcent"
if [[ -z "$SIGNING_IDENTITY" || ! -f "$ENTITLEMENTS" ]]; then
  echo "Could not resolve the development signing identity or entitlements." >&2
  exit 21
fi

mkdir -p "$HOST_APP/Frameworks"
while IFS= read -r framework; do
  ditto "$framework" "$HOST_APP/Frameworks/$(basename "$framework")"
done < <(find "$PLAYBOX_RUNTIME_FRAMEWORKS" -maxdepth 1 -type d -name '*.framework' -print | sort)
if [[ ! -f "$HOST_APP/Frameworks/PBPlayerKit.framework/Floating.bundle/cscb_floating_icon@2x.png" ]]; then
  echo "PBPlayerKit floating UI bundle was not staged into AppBox." >&2
  exit 24
fi

# CopySwiftLibs may strip the custom Flutter binary after the Xcode phase signed
# it. Seal the nested framework and outer app in their final on-disk form.
while IFS= read -r framework; do
  codesign --force --sign "$SIGNING_IDENTITY" --timestamp=none "$framework"
done < <(find "$HOST_APP/Frameworks" -maxdepth 1 -type d -name '*.framework' -print | sort)
codesign --force --sign "$SIGNING_IDENTITY" --timestamp=none \
  --entitlements "$ENTITLEMENTS" "$HOST_APP"
codesign --verify --deep --strict --verbose=2 "$HOST_APP"
xcrun devicectl device install app --device "$DEVICE_ID" "$HOST_APP"

LAUNCH_ARGUMENTS=()
if [[ "${APPBOX_FORCE_SURFACE:-0}" == "1" ]]; then
  LAUNCH_ARGUMENTS+=(--appbox-force-surface)
fi
INJECTION_ROOT=""
if [[ "${APPBOX_USE_INJECTED_GUEST:-0}" == "1" || "${APPBOX_USE_PLAYBOX_GUEST:-0}" == "1" ]]; then
  INJECTION_ROOT="$(mktemp -d /tmp/appbox-guest-injection.XXXXXX)"
  mkdir -p "$INJECTION_ROOT/AppBoxTest"
fi
if [[ "${APPBOX_USE_INJECTED_GUEST:-0}" == "1" ]]; then
  if [[ ! -f "$PORNHUB_GUEST_IPA" || ! -f "$PORNHUB_GUEST_NIVM" ]]; then
    echo "pornhub_client IPA or NIVM is missing." >&2
    exit 22
  fi
  ditto "$PORNHUB_GUEST_IPA" "$INJECTION_ROOT/AppBoxTest/guest.ipa"
  ditto "$PORNHUB_GUEST_NIVM" "$INJECTION_ROOT/AppBoxTest/guest.nivm.zip"
  LAUNCH_ARGUMENTS+=(--appbox-install-pornhub-guest)
fi
if [[ "${APPBOX_USE_PLAYBOX_GUEST:-0}" == "1" ]]; then
  if [[ ! -f "$PLAYBOX_GUEST_IPA" ]]; then
    echo "PlayBox guest IPA is missing: $PLAYBOX_GUEST_IPA" >&2
    exit 23
  fi
  ditto "$PLAYBOX_GUEST_IPA" "$INJECTION_ROOT/AppBoxTest/playbox-guest.ipa"
  LAUNCH_ARGUMENTS+=(--appbox-install-playbox-guest)
fi
if [[ -n "$INJECTION_ROOT" ]]; then
  xcrun devicectl device copy to --device "$DEVICE_ID" \
    --source "$INJECTION_ROOT/AppBoxTest" \
    --destination Documents/AppBoxTest \
    --remove-existing-content true \
    --domain-type appDataContainer \
    --domain-identifier com.tianya.appbox
fi
if (( ${#LAUNCH_ARGUMENTS[@]} )); then
  xcrun devicectl device process launch --device "$DEVICE_ID" \
    --terminate-existing com.tianya.appbox "${LAUNCH_ARGUMENTS[@]}"
else
  xcrun devicectl device process launch --device "$DEVICE_ID" \
    --terminate-existing com.tianya.appbox
fi

echo "APPBOX_HOST_OK"
echo "device=$DEVICE_ID"
echo "bundle=com.tianya.appbox"
echo "host_app=$HOST_APP"
echo "guest_url=$APPBOX_GUEST_URL"
