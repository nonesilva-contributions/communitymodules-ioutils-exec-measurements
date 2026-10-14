#!/usr/bin/env bash
# Runs in eclipse-temurin:11-jdk-jammy. Builds the pinned CommunityModules
# twice (shipped, then gated) and model-checks the spec in each case.
set -euo pipefail
PIN=4c6c79bf6f3124dfa3a4fd3cfa9a92fe34c20763
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null && apt-get install -y -qq ant patch git >/dev/null

cp -r /cm-src /cm
cd /cm
test "$(git rev-parse HEAD)" = "$PIN" || { echo "FAIL: source not at pinned $PIN"; exit 1; }
echo "CommunityModules at $(git rev-parse HEAD)"

runtlc() {
  # $1 label, $2 run dir, $3 extra JVM -D (may be empty)
  rm -rf "$2"; mkdir -p "$2"; cp /m/ExecFinding.tla /m/ExecFinding.cfg "$2"/
  ( cd "$2"
    set +e
    java $3 -cp /cm/tlc/tla2tools.jar:/cm/dist/CommunityModules-deps.jar \
      tlc2.TLC -config ExecFinding.cfg ExecFinding.tla >tlc.out 2>&1
    echo "[$1] tlc exit=$?"
    if [ -f ioexec-ran.marker ]; then echo "[$1] marker PRESENT -> command ran"
    else echo "[$1] marker ABSENT -> command blocked"; fi
    grep -iE "disabled by default|Set -D" tlc.out | head -1 || true )
}

echo "== Case 1: shipped CommunityModules, no gate =="
ant -q -Dtimestamp=fixed dist >/tmp/ant1.log 2>&1 || { echo "build 1 failed"; tail -40 /tmp/ant1.log; exit 1; }
runtlc shipped /work/case1 ""

echo "== Apply ioutils-exec-gate.patch and rebuild =="
patch -p1 < /m/ioutils-exec-gate.patch
rm -rf build dist
ant -q -Dtimestamp=fixed -Dskip.download=true dist >/tmp/ant2.log 2>&1 || { echo "build 2 failed"; tail -40 /tmp/ant2.log; exit 1; }

echo "== Case 2: gated build, default (no opt-in) =="
runtlc gated-default /work/case2 ""

echo "== Case 3: gated build, explicit opt-in =="
runtlc gated-optin /work/case3 "-Dtlc2.overrides.IOUtils.enableExec=true"
