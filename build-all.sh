#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")"

for dockerfile in */*/Dockerfile; do
  bash ./build.sh "$(dirname "$dockerfile")"
done
