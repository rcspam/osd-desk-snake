#!/usr/bin/env bash
# Runs the unit tests, then renders the style previews into $OUT (default: tests/preview-out).
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
runner=/usr/lib/qt6/bin/qmltestrunner
out="${OUT:-$here/preview-out}"

export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}"
export QT_QPA_PLATFORMTHEME="${QT_QPA_PLATFORMTHEME:-kde}"

"$runner" -input "$here/tst_logic.qml"
"$runner" -input "$here/tst_fields.qml"
"$runner" -input "$here/tst_wheel.qml"

mkdir -p "$out"
cd "$(dirname "$out")"
[ "$(basename "$out")" = preview-out ] || { echo "OUT must end with preview-out" >&2; exit 1; }
"$runner" -input "$here/tst_preview.qml"
"$runner" -input "$here/tst_showcase.qml"
# The presets test reads tests/presets/*.osdsnake through XMLHttpRequest.
mkdir -p "$out/presets"
QML_XHR_ALLOW_FILE_READ=1 "$runner" -input "$here/tst_presets.qml"
echo "Previews written to $out"
