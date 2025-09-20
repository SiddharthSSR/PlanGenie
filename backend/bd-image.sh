#!/usr/bin/env bash
set -euo pipefail

: "${REGION:?Need to set REGION}"
: "${PROJECT_ID:?Need to set PROJECT_ID}"

IMAGE_URI="$REGION-docker.pkg.dev/$PROJECT_ID/containers/planner-api:latest"

# Build container image and push to Artifact Registry
 gcloud builds submit \
  --tag "$IMAGE_URI"

# Deploy container image to Cloud Run
 gcloud run deploy planner-api \
  --image="$IMAGE_URI" \
  --region="$REGION" \
  --service-account="planner-sa@$PROJECT_ID.iam.gserviceaccount.com" \
  --allow-unauthenticated \
  --set-env-vars="FIRESTORE_PROJECT=$PROJECT_ID,VERTEX_REGION=$REGION" \
  --set-env-vars="PLANGENIE_CORS_REGEX=^https?://localhost(:[0-9]+)?$"
