#!/usr/bin/env bash
# Builds the pinned CommunityModules with and without the exec gate, measures the
# finding and the gate, and runs the project's own test suite, all in the
# container. Host is read-only. Usage: ./run-docker.sh  (override with CM=path)
set -euo pipefail
cd "$(dirname "$0")"
CM=${CM:-/home/data/oss/CommunityModules}
IMG=eclipse-temurin:11-jdk-jammy@sha256:0ab919c546b23b2da000376778ce947596d1f92d18a32fd69342743bd0e1e431
mkdir -p results
docker run --rm \
  -v "$PWD:/m:ro" -v "$CM:/cm-src:ro" \
  "$IMG" \
  bash /m/in-container.sh 2>&1 | tee results/communitymodules-exec-gate.txt
