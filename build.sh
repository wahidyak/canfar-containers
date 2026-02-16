#!/bin/bash

# Exit on any error
set -e

# --- Configuration ---
REGISTRY="images.canfar.net/cadc"
TAG="26.02"
PLATFORM="linux/amd64"

# Dependency order: folder_name:image_name
IMAGES=(
    "base:base"
    "python:python"
    "terminal:terminal"
    "webterm:webterm"
    "opencode:webterm-opencode"
)

usage() {
    echo "Usage: $0 [all|base|python|terminal|webterm|opencode] [--push]"
    echo ""
    echo "This script builds the target layer and ALL subsequent dependent layers."
    echo "Example: './build.sh python' builds python, terminal, webterm, and opencode."
    exit 1
}

build_one() {
    local folder=$1
    local name=$2
    local push=$3
    local full_tag="${REGISTRY}/${name}:${TAG}"

    echo ">>> BUILDING: ${full_tag}"
    docker build --rm --platform "${PLATFORM}" -t "${full_tag}" "./dockerfiles/${folder}/"

    if [ "$push" == "true" ]; then
        echo ">>> PUSHING: ${full_tag}"
        docker push "${full_tag}"
    fi
}

# --- Parsing ---
TARGET=${1:-"usage"}
PUSH_FLAG="false"
[[ "$*" == *"--push"* ]] && PUSH_FLAG="true"

if [[ "$TARGET" == "usage" || "$TARGET" == "-h" ]]; then usage; fi

# --- Find Starting Point ---
START_INDEX=-1
if [ "$TARGET" == "all" ]; then
    START_INDEX=0
else
    for i in "${!IMAGES[@]}"; do
        if [[ "${IMAGES[$i]}" == "$TARGET"* ]]; then
            START_INDEX=$i
            break
        fi
    done
fi

if [ "$START_INDEX" -eq -1 ]; then
    echo "Error: Unknown target '$TARGET'"; usage
fi

# --- Cascading Build ---
echo "Starting cascading build from: ${TARGET}..."
for (( i=START_INDEX; i<${#IMAGES[@]}; i++ )); do
    folder="${IMAGES[$i]%%:*}"
    name="${IMAGES[$i]##*:}"
    build_one "$folder" "$name" "$PUSH_FLAG"
done

echo "Successfully completed build sequence."
