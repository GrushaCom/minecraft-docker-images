#!/usr/bin/env bash

set -euo pipefail

dir=${1:?usage: $0 <dir> [prefix]}
dir=${dir%/}
prefix=${2:-$(basename "$(dirname "$dir")")}

resolve_image() {
  if [[ -n "${IMAGE:-}" ]]; then
    echo "$IMAGE"
  elif [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
    echo "ghcr.io/$GITHUB_REPOSITORY"
  else
    local remote
    remote=$(git remote get-url origin 2>/dev/null) || {
      echo "Set IMAGE or add a git remote 'origin'" >&2
      return 1
    }
    remote=${remote%.git}
    echo "ghcr.io/${remote#*github.com[:/]}"
  fi
}

image=$(resolve_image)
image=${image,,}

labels=()
if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
  labels+=(--label "org.opencontainers.image.source=${GITHUB_SERVER_URL:-https://github.com}/$GITHUB_REPOSITORY")
fi

local_tag="$prefix:$(basename "$dir")"
docker build "${labels[@]}" -t "$local_tag" "$dir"

java_version=$(docker run --rm "$local_tag" java -version 2>&1 | awk -F '"' 'NR == 1 {print $2}')
if [[ -z "$java_version" ]]; then
  echo "Could not detect the Java version in $local_tag" >&2
  exit 1
fi

# 1.8.0_392 -> 8, 25.0.5.1 -> 25
major_version=${java_version%%.*}
if [[ "$major_version" == 1 ]]; then
  major_version=$(cut -d . -f 2 <<<"$java_version")
fi

tags=("$image:$prefix-$java_version" "$image:$prefix-$major_version")
for tag in "${tags[@]}"; do
  docker tag "$local_tag" "$tag"
done

if [[ "${PUSH:-1}" == 0 ]]; then
  echo "PUSH=0, not pushing: ${tags[*]}"
  exit 0
fi

for tag in "${tags[@]}"; do
  docker push "$tag"
done
