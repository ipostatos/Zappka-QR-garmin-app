#!/bin/sh
# Reproducible release build with provenance (audit ZG-04). Refuses a dirty tree.
# usage: tools/release.sh <developer_key.der> [device ...]   (default: all products in manifest.xml)
set -e
[ "$#" -ge 1 ] || { echo "usage: $0 <developer_key.der> [device ...]" >&2; exit 2; }
KEY=$1; shift; ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
if [ -n "${CIQ_SDK_BIN:-}" ]; then
  S=$CIQ_SDK_BIN
elif [ -n "${CONNECT_IQ_HOME:-}" ]; then
  S=$CONNECT_IQ_HOME/bin
elif command -v monkeyc >/dev/null 2>&1; then
  S=$(dirname "$(command -v monkeyc)")
elif [ -n "${APPDATA:-}" ]; then
  S=$(ls -d "$APPDATA"/Garmin/ConnectIQ/Sdks/*/bin | tail -1)
else
  echo "Set CIQ_SDK_BIN or CONNECT_IQ_HOME to the Garmin SDK" >&2; exit 1
fi
if [ -f "$S/monkeyc" ]; then
  COMPILER=$S/monkeyc
elif [ -f "$S/monkeyc.bat" ]; then
  COMPILER=$S/monkeyc.bat
else
  echo "No Monkey C compiler in $S" >&2; exit 1
fi
[ -f "$KEY" ] || { echo "Signing key file not found" >&2; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "dirty tree: commit first"; exit 1; }
DEVS=${*:-$(grep -o 'product id="[^"]*"' manifest.xml | cut -d'"' -f2)}
SHA=$(git rev-parse --short HEAD); DESC=$(git describe --tags --always)
SDKV=$("$COMPILER" --version)
PY=$(command -v python3 || command -v python)
# Before building: settings defaults in the sources must be empty (no account baked in).
"$PY" -I tools/check-build.py --properties || { echo "abort: properties.xml carries a default value"; exit 1; }
OUT=bin/release/$DESC; rm -rf "$OUT"; mkdir -p "$OUT"
{ echo; echo "## $DESC ($(date -u +%Y-%m-%dT%H:%MZ))"; echo; echo "commit \`$SHA\`, SDK \`$SDKV\`"; echo; echo "| device | sha256 | bytes |"; echo "|---|---|---|"; } > "$OUT/RELEASE.md"
for D in $DEVS; do
  "$COMPILER" -f monkey.jungle -d "$D" -o "$OUT/zappka-$D.prg" -y "$KEY" -r >/dev/null
  # After building: the compiler's settings.json must exist with empty defaults, and the binary
  # itself must hold no 64+ hex run. A missing file fails; nothing passes silently.
  "$PY" -I tools/check-build.py "$OUT/zappka-$D.prg" || { echo "abort: $D build failed the secret check"; exit 1; }
  H=$(sha256sum "$OUT/zappka-$D.prg" | cut -c1-64); B=$(wc -c < "$OUT/zappka-$D.prg")
  echo "| $D | \`$H\` | $B |" >> "$OUT/RELEASE.md"
done
cat "$OUT/RELEASE.md"
echo; echo "Append the block above to docs/RELEASES.md and commit it."
