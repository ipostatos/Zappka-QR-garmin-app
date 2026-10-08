#!/bin/sh
# Simulator end-to-end check (Windows + Git Bash). Builds with the PUBLIC EXAMPLE account as
# property defaults (restored afterwards), runs it, screenshots the simulator, decodes the QR.
# usage: tools/sim-e2e.sh <device> <developer_key.der>     needs: simulator running, python opencv-python
set -e
DEV=$1; KEY=$2; ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
S="${CIQ_SDK_BIN:-$(ls -d "$APPDATA"/Garmin/ConnectIQ/Sdks/*/bin | tail -1)}"
P=resources/settings/properties.xml; cp $P /tmp/props.bak
cat > $P <<'E'
<properties>
    <property id="userId" type="string">123456789012</property>
    <property id="secret" type="string">2db76449a55d59f1f9420b809edb1beb19dfa434ddb5dbf331f01aec35956e35</property>
</properties>
E
"$S/monkeyc.bat" -f monkey.jungle -d "$DEV" -o bin/e2e.prg -y "$KEY" -w || true
cp /tmp/props.bak $P
"$S/monkeydo.bat" bin/e2e.prg "$DEV" >/dev/null 2>&1 &
sleep 15
T=$(pwsh -NoProfile -File tools/sim-shot.ps1 "$TEMP/e2e.png" | tail -1)
python tools/verify_qr.py "$TEMP/e2e.png" "$T"
