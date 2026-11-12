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
OUT=bin/release/$DESC; mkdir -p "$OUT"
{ echo; echo "## $DESC ($(date -u +%Y-%m-%dT%H:%MZ))"; echo; echo "commit \`$SHA\`, SDK \`$SDKV\`"; echo; echo "| device | sha256 | bytes |"; echo "|---|---|---|"; } > "$OUT/RELEASE.md"
for D in $DEVS; do
  "$S/monkeyc.bat" -f monkey.jungle -d "$D" -o "$OUT/zappka-$D.prg" -y "$KEY" -r >/dev/null
  if grep -q -E '[0-9a-f]{64}' "$OUT/zappka-$D-settings.json"; then echo "secret-like default in $D settings: abort"; exit 1; fi
  H=$(sha256sum "$OUT/zappka-$D.prg" | cut -c1-64); B=$(wc -c < "$OUT/zappka-$D.prg")
  echo "| $D | \`$H\` | $B |" >> "$OUT/RELEASE.md"
done
cat "$OUT/RELEASE.md"
echo; echo "Append the block above to docs/RELEASES.md and commit it."
