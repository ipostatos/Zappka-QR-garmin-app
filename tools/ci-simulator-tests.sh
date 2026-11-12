#!/usr/bin/env bash
# Minimal SDK 9.2.0/Linux simulator harness. No application credentials.
set -euo pipefail
: "${CONNECT_IQ_HOME:?CONNECT_IQ_HOME is required}"
if (( $# != 2 )); then echo "Usage: $0 tests.prg device" >&2; exit 2; fi
[ -f "$1" ] || { echo "Missing compiled tests: $1" >&2; exit 1; }
exec timeout --signal=TERM --kill-after=10s 180s \
  xvfb-run -a -s "-screen 0 1280x1024x24" dbus-run-session -- \
  bash -euo pipefail -c '
  logfile="$(mktemp)"; simlog="$(mktemp)"; pid=""
  cleanup() { [ -z "$pid" ] || { kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; }; cat "$simlog" >&2; rm -f "$logfile" "$simlog"; }
  trap cleanup EXIT
  "$CONNECT_IQ_HOME/bin/simulator" >"$simlog" 2>&1 & pid=$!
  ready=no
  for (( i=0; i<60; i++ )); do
    kill -0 "$pid" 2>/dev/null || { echo "Simulator exited" >&2; exit 1; }
    if (: > /dev/tcp/127.0.0.1/1234) 2>/dev/null; then ready=yes; break; fi
    sleep 0.5
  done
  [ "$ready" = yes ] || { echo "Simulator not ready" >&2; exit 1; }
  set +e
  "$CONNECT_IQ_HOME/bin/monkeydo" "$1" "$2" -t 2>&1 | tee "$logfile"
  statuses=("${PIPESTATUS[@]}")
  set -e
  [ "${statuses[0]}" = 0 ] && [ "${statuses[1]}" = 0 ] || exit 1
  grep -Eq "^PASSED \(passed=[1-9][0-9]*, failed=0, errors=0\)[[:space:]]*$" "$logfile" || {
    echo "Simulator did not report successful tests" >&2; exit 1;
  }
  ' bash "$1" "$2"
