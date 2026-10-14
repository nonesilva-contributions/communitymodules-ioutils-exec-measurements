#!/usr/bin/env bash
# Builds the pinned CommunityModules with and without the exec gate, measures
# the finding and the gate, and runs the project's test suite in one container
# that is removed on exit, even on Ctrl-C. Usage: ./run-docker.sh (CM=path).
set -euo pipefail
cd "$(dirname "$0")"
CM=${CM:-/home/data/oss/CommunityModules}
IMG=eclipse-temurin:11-jdk-jammy@sha256:0ab919c546b23b2da000376778ce947596d1f92d18a32fd69342743bd0e1e431
out="results/communitymodules-exec-gate.txt"
name="cm-ioutils-exec-$$"
tmp="$(mktemp)"
cleanup() { docker rm -f "$name" >/dev/null 2>&1 || true; rm -f "$tmp" 2>/dev/null || true; }
trap cleanup EXIT INT TERM
mkdir -p results
echo "Running the measurement in Docker (~3-5 min). Output appears in bursts,"
echo "not line by line; the container is removed automatically at the end."
set +e
docker run --rm --name "$name" \
  -v "$PWD:/m:ro" -v "$CM:/cm-src:ro" \
  "$IMG" \
  bash /m/in-container.sh 2>&1 | tee "$tmp"
code=${PIPESTATUS[0]}
set -e
if [ "$code" -eq 0 ]; then cp "$tmp" "$out"; echo ">> Done. Result saved to $out"
else echo ">> Run stopped (exit $code); $out was left unchanged."; fi
