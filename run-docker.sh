#!/usr/bin/env bash
# Builds the pinned CommunityModules with and without the exec gate and
# model-checks ExecFinding.tla, all inside the container. Host is read-only.
# Usage: ./run-docker.sh   (override the source clone with CM=/path)
set -euo pipefail
cd "$(dirname "$0")"
CM=${CM:-/home/data/oss/CommunityModules}
mkdir -p results
docker run --rm \
  -v "$PWD:/m:ro" -v "$CM:/cm-src:ro" \
  eclipse-temurin:11-jdk-jammy \
  bash /m/in-container.sh 2>&1 | tee results/communitymodules-exec-gate.txt
