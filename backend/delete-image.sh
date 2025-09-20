#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-}"
if [[ -z "$PROJECT_ID" ]]; then
  PROJECT_ID="$(gcloud config get-value project 2>/dev/null || true)"
fi
if [[ -z "$PROJECT_ID" || "$PROJECT_ID" == "(unset)" ]]; then
  echo "PROJECT_ID must be provided via environment variable or gcloud config." >&2
  exit 1
fi

REGION="${REGION:-asia-south1}"
REPOSITORY="${REPOSITORY:-containers}"
IMAGE_NAME="${IMAGE_NAME:-planner-api}"

REGISTRY_PATH="$REGION-docker.pkg.dev/$PROJECT_ID/$REPOSITORY"
TAG_PATH="$REGISTRY_PATH/$IMAGE_NAME:latest"

printf 'Looking up digest for %s...\n' "$TAG_PATH"
DIGEST="$(gcloud artifacts docker images list "$REGISTRY_PATH" \
  --include-tags \
  --format='value(DIGEST)' \
  --filter="IMAGE='$REGISTRY_PATH/$IMAGE_NAME' AND TAGS:latest" \
  | head -n1)"

if [[ -z "$DIGEST" ]]; then
  echo "Could not find a digest with the latest tag for $IMAGE_NAME in $REGION." >&2
  exit 1
fi

IMAGE_PATH="$REGISTRY_PATH/$IMAGE_NAME@$DIGEST"
printf 'Found digest: %s\n' "$DIGEST"
printf 'Deleting tag %s...\n' "$TAG_PATH"
gcloud artifacts docker tags delete "$TAG_PATH" --quiet

printf 'Deleting image %s...\n' "$IMAGE_PATH"
gcloud artifacts docker images delete "$IMAGE_PATH" --quiet

echo "Done."
