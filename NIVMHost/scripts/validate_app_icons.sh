#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ASSET_DIR="${IOS_DIR}/Runner/Assets.xcassets"
BUILT_APP="${1:-}"

PRIMARY_ICON_SET="AppIcon"
ALTERNATE_ICON_SETS=(
  AppIconWeChat
  AppIconQQ
  AppIconAlipay
  AppIconToutiao
  AppIconDouyin
  AppIconXiaohongshu
  AppIconTelegram
)
ICON_SETS=("${PRIMARY_ICON_SET}" "${ALTERNATE_ICON_SETS[@]}")

fail() {
  printf 'App icon validation failed: %s\n' "$*" >&2
  exit 1
}

command -v jq >/dev/null || fail "jq is required"
command -v sips >/dev/null || fail "sips is required"

for icon_name in "${ICON_SETS[@]}"; do
  icon_dir="${ASSET_DIR}/${icon_name}.appiconset"
  contents="${icon_dir}/Contents.json"
  [[ -d "${icon_dir}" ]] || fail "missing ${icon_name}.appiconset"
  jq -e . "${contents}" >/dev/null || fail "invalid ${contents}"

  while IFS=$'\t' read -r filename size scale; do
    [[ -n "${filename}" ]] || continue
    file="${icon_dir}/${filename}"
    [[ -f "${file}" ]] || fail "missing ${file}"

    points="${size%x*}"
    scale_number="${scale%x}"
    expected="$(awk -v points="${points}" -v scale="${scale_number}" \
      'BEGIN { printf "%d", points * scale }')"
    width="$(sips -g pixelWidth "${file}" | awk '/pixelWidth/ {print $2}')"
    height="$(sips -g pixelHeight "${file}" | awk '/pixelHeight/ {print $2}')"
    alpha="$(sips -g hasAlpha "${file}" | awk '/hasAlpha/ {print $2}')"

    [[ "${width}" == "${expected}" && "${height}" == "${expected}" ]] \
      || fail "${filename} is ${width}x${height}, expected ${expected}x${expected}"
    [[ "${alpha}" == "no" ]] || fail "${filename} must not contain alpha"
  done < <(
    jq -r '.images[] | select(.filename != null) |
      [.filename, .size, .scale] | @tsv' "${contents}"
  )
done

if [[ -n "${BUILT_APP}" ]]; then
  plist="${BUILT_APP}/Info.plist"
  [[ -f "${plist}" ]] || fail "missing built Info.plist at ${plist}"
  for icon_name in "${ALTERNATE_ICON_SETS[@]}"; do
    /usr/libexec/PlistBuddy \
      -c "Print :CFBundleIcons:CFBundleAlternateIcons:${icon_name}" \
      "${plist}" >/dev/null 2>&1 \
      || fail "built app did not register ${icon_name}"
  done

  ipad_pro_icon=""
  while IFS= read -r icon_file; do
    width="$(sips -g pixelWidth "${icon_file}" | awk '/pixelWidth/ {print $2}')"
    height="$(sips -g pixelHeight "${icon_file}" | awk '/pixelHeight/ {print $2}')"
    if [[ "${width}" == "167" && "${height}" == "167" ]]; then
      ipad_pro_icon="${icon_file}"
      break
    fi
  done < <(find "${BUILT_APP}" -maxdepth 1 -type f -name '*.png' -print)

  [[ -n "${ipad_pro_icon}" ]] \
    || fail "built app is missing the required 167x167 iPad Pro icon"
fi

if [[ -n "${BUILT_APP}" ]]; then
  printf 'Validated primary icon, %d alternate icon sets, and built 167x167 iPad icon.\n' \
    "${#ALTERNATE_ICON_SETS[@]}"
else
  printf 'Validated primary icon and %d alternate icon sets.\n' \
    "${#ALTERNATE_ICON_SETS[@]}"
fi
