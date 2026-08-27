#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLAYBOX_APP="${PLAYBOX_APP:-/Applications/PlayBox.app/Wrapper/PlayBox.app}"
DESTINATION="${1:?usage: prepare_playbox_runtime.sh /path/to/staging/Frameworks}"

if [[ ! -f "$PLAYBOX_APP/Frameworks/PBPlayerKit.framework/PBPlayerKit" ||
      ! -f "$PLAYBOX_APP/Frameworks/adversarys.framework/adversarys" ]]; then
  echo "PlayBox guest runtime was not found at: $PLAYBOX_APP" >&2
  exit 2
fi

mkdir -p "$DESTINATION"
ditto "$PLAYBOX_APP/Frameworks" "$DESTINATION"

# Add a small direct-threaded handler used by narrowly scoped guest fuel
# compatibility shims. The source PlayBox binary contains an authenticated,
# zero-filled executable cave at this offset; the patcher refuses any binary
# whose bytes do not match that expectation.
python3 "$PROJECT_ROOT/Tools/NIVMReverse/patch_adversarys_epilogue.py" \
  "$DESTINATION/adversarys.framework/adversarys"

# Diagnostic builds can preserve the module-index failure registers in an iOS
# crash report.  Normal AppBox builds keep the original PlayBox instruction.
if [[ "${APPBOX_RUNTIME_DIAGNOSTIC_TRAP:-0}" == "1" ]]; then
  python3 "$PROJECT_ROOT/Tools/NIVMReverse/patch_adversarys_abort.py" \
    "$DESTINATION/adversarys.framework/adversarys"
fi

# The App Store framework omits textual Swift module metadata. Keep a narrow
# interface for the public setup functions plus the host compatibility
# protocol that PBPlayerUIKitCore checks before presenting its developer UI.
PBPLAYER_MODULE="$DESTINATION/PBPlayerKit.framework/Modules/PBPlayerKit.swiftmodule"
mkdir -p "$PBPLAYER_MODULE"
ditto "$PROJECT_ROOT/Tools/PlayBoxRuntime/PBPlayerKit.swiftinterface" \
  "$PBPLAYER_MODULE/arm64-apple-ios.swiftinterface"

echo "PLAYBOX_RUNTIME_STAGED"
echo "frameworks=$DESTINATION"
