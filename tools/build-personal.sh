#!/bin/sh
# Builds a PERSONAL .prg with your ployId/secret as property defaults (sideload without phone settings).
# Account data comes from the DPAPI vault (tools/vault.ps1) via a pipe; no plaintext file is written.
# The resulting .prg CONTAINS THE SECRET: copy it to the watch and delete it (the script reminds you).
# usage: tools/build-personal.sh <device> <developer_key.der>
set -e
DEV=$1; KEY=$2; ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
S="${CIQ_SDK_BIN:-$(ls -d "$APPDATA"/Garmin/ConnectIQ/Sdks/*/bin | tail -1)}"
P=resources/settings/properties.xml; BAK=$(mktemp); cp "$P" "$BAK"
trap 'cp "$BAK" "$P"; rm -f "$BAK"' EXIT INT TERM
pwsh -NoProfile -File tools/vault.ps1 get | python -I -c '
import json,sys
d=json.load(sys.stdin)
open(sys.argv[1],"w").write("<properties>\n    <property id=\"userId\" type=\"string\">%s</property>\n    <property id=\"secret\" type=\"string\">%s</property>\n</properties>\n"%(str(d["ployId"]).strip(),d["secret"].strip()))
print("secret_present=true secret_length=%d"%len(d["secret"].strip()))
' "$P"
"$S/monkeyc.bat" -f monkey.jungle -d "$DEV" -o "bin/personal-$DEV.prg" -y "$KEY" -r
echo "-> bin/personal-$DEV.prg contains your secret. Copy it to GARMIN/APPS, then run:"
echo "   rm -f bin/personal-$DEV*"
