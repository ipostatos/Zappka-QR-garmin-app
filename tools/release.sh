#!/bin/sh
# Reproducible release build with provenance (audit ZG-04). Refuses a dirty tree.
# usage: tools/release.sh <developer_key.der> [device ...]   (default: all products in manifest.xml)
set -e
KEY=$1; shift; ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
S="${CIQ_SDK_BIN:-$(ls -d "$APPDATA"/Garmin/ConnectIQ/Sdks/*/bin | tail -1)}"
[ -z "$(git status --porcelain)" ] || { echo "dirty tree: commit first"; exit 1; }
DEVS=${*:-$(grep -o 'product id="[^"]*"' manifest.xml | cut -d'"' -f2)}
SHA=$(git rev-parse --short HEAD); DESC=$(git describe --tags --always)
SDKV=$(basename "$(dirname "$S")")
PY=$(command -v python3 || command -v python)
# Before building: settings defaults in the sources must be empty (no account baked in).
"$PY" -I tools/check-build.py --properties || { echo "abort: properties.xml carries a default value"; exit 1; }
OUT=bin/release/$DESC; rm -rf "$OUT"; mkdir -p "$OUT"
{ echo; echo "## $DESC ($(date -u +%Y-%m-%dT%H:%MZ))"; echo; echo "commit \`$SHA\`, SDK \`$SDKV\`"; echo; echo "| device | sha256 | bytes |"; echo "|---|---|---|"; } > "$OUT/RELEASE.md"
for D in $DEVS; do
  "$S/monkeyc.bat" -f monkey.jungle -d "$D" -o "$OUT/zappka-$D.prg" -y "$KEY" -r >/dev/null
  # After building: the compiler's settings.json must exist with empty defaults, and the binary
  # itself must hold no 64+ hex run. A missing file fails; nothing passes silently.
  "$PY" -I tools/check-build.py "$OUT/zappka-$D.prg" || { echo "abort: $D build failed the secret check"; exit 1; }
  H=$(sha256sum "$OUT/zappka-$D.prg" | cut -c1-64); B=$(wc -c < "$OUT/zappka-$D.prg")
  echo "| $D | \`$H\` | $B |" >> "$OUT/RELEASE.md"
done
cat "$OUT/RELEASE.md"
echo; echo "Append the block above to docs/RELEASES.md and commit it."
