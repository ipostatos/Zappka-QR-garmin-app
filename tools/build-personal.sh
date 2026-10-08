#!/bin/sh
# Builds a PERSONAL .prg with your ployId/secret as property defaults (sideload has no phone settings).
# Reads secrets.json ({"secret":"...","ployId":"..."}, git-ignored). Never prints the values.
# usage: tools/build-personal.sh <device> <developer_key.der>
set -e
DEV=$1; KEY=$2; ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
S="${CIQ_SDK_BIN:-$(ls -d "$APPDATA"/Garmin/ConnectIQ/Sdks/*/bin | tail -1)}"
P=resources/settings/properties.xml; cp $P /tmp/props.bak
trap 'cp /tmp/props.bak $P; rm -f /tmp/props.bak' EXIT
python - "$P" <<'E'
import json,sys
d=json.load(open('secrets.json'))
open(sys.argv[1],'w').write('<properties>\n    <property id="userId" type="string">%s</property>\n    <property id="secret" type="string">%s</property>\n</properties>\n'%(str(d['ployId']).strip(),d['secret'].strip()))
print("secret_present=true secret_length=%d"%len(d['secret'].strip()))
E
"$S/monkeyc.bat" -f monkey.jungle -d "$DEV" -o "bin/personal-$DEV.prg" -y "$KEY" -r
echo "-> bin/personal-$DEV.prg  (delete it after copying to the watch)"
