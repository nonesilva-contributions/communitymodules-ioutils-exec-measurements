#!/usr/bin/env bash
# Runs in the pinned eclipse-temurin image. Builds the pinned CommunityModules
# from its committed tree, measures the exec finding and the gate, and runs the
# project's own test suite with the patched build.
set -euo pipefail
PIN=4c6c79bf6f3124dfa3a4fd3cfa9a92fe34c20763
export DEBIAN_FRONTEND=noninteractive
echo ">> Installing build tools in the container (quiet, ~1 min)..."
apt-get update -qq >/dev/null && apt-get install -y -qq ant patch git >/dev/null

git config --global --add safe.directory /cm-src
mkdir -p /cm && git -C /cm-src archive "$PIN" | tar -x -C /cm
cd /cm
echo "CommunityModules committed tree at $PIN"

CP="/cm/tlc/tla2tools.jar:/cm/dist/CommunityModules-deps.jar"

runtlc() {
  # $1 label | $2 dir | $3 spec base in /m | $4 marker file | $5 extra -D
  rm -rf "$2"; mkdir -p "$2"; cp "/m/$3.tla" "/m/$3.cfg" "$2"/
  ( cd "$2"
    set +e
    java $5 -cp "$CP" tlc2.TLC -config "$3.cfg" "$3.tla" >tlc.out 2>&1
    echo "[$1] tlc exit=$?"
    if [ -f "$4" ]; then echo "[$1] marker PRESENT -> command ran"
    else echo "[$1] marker ABSENT -> command blocked"; fi )
}

echo "== Build shipped (no gate) -- compiling, quiet, ~1 min =="
ant -q -Dtimestamp=fixed dist >/tmp/b1.log 2>&1 || { echo "shipped build failed"; tail -40 /tmp/b1.log; exit 1; }

echo "== shipped: spec uses PrintT =="
runtlc shipped /work/c1 ExecFinding ioexec-ran.marker ""

echo "== shipped: spec has NO PrintT; full TLC console follows =="
runtlc silent /work/cs ExecSilent exec-silent.marker ""
echo "---- begin full TLC console (silent spec, shipped): no line announces a command ----"
cat /work/cs/tlc.out
echo "---- end full TLC console ----"

echo "== Apply ioutils-exec-gate.patch =="
patch -p1 < /m/ioutils-exec-gate.patch
rm -rf build dist

echo "== project 'ant test' on the patched build -- their full suite, quiet, ~1-2 min =="
set +e
ant -q -Dtimestamp=fixed -Dskip.download=true test >/tmp/b2.log 2>&1
TESTCODE=$?
set -e
echo "[ant test] exit=$TESTCODE  (0 means the fix keeps their suite green)"
[ "$TESTCODE" -eq 0 ] || { echo "ant test FAILED:"; tail -80 /tmp/b2.log; }

echo "== gated: default, no opt-in =="
runtlc gated-default /work/c2 ExecFinding ioexec-ran.marker ""
if grep -q "disabled by default" /work/c2/tlc.out && [ ! -f /work/c2/ioexec-ran.marker ]; then
  echo "[gated-default] GATE fired: message present AND marker absent"
else
  echo "[gated-default] UNEXPECTED gate state"
fi
grep -i "disabled by default" /work/c2/tlc.out | head -1 || true

echo "== gated: explicit opt-in =="
runtlc gated-optin /work/c3 ExecFinding ioexec-ran.marker "-Dtlc2.overrides.IOUtils.enableExec=true"

echo
echo "== DONE: measurement complete =="
