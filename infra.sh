# Set project/region
export PROJECT_ID=plangenie-
export REGION=asia-south1
gcloud config set project $PROJECT_ID

# Enable just these
gcloud services enable run.googleapis.com firestore.googleapis.com aiplatform.googleapis.com secretmanager.googleapis.com

# Firestore (Native)
gcloud firestore databases create --location=$REGION

# Service Account
gcloud iam service-accounts create planner-sa --display-name="Planner API SA"

# Roles (least-privilege)
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:planner-sa@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/datastore.user"
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:planner-sa@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/aiplatform.user"

# Secrets (store your keys)
gcloud secrets create MAPS_API_KEY --replication-policy=automatic
echo -n "<your-maps-key>" | gcloud secrets versions add MAPS_API_KEY --data-file=-

# (Optional later) BigQuery
# bq mk -d --location=$REGION trips

# 1) Create a Docker repo (one-time)
gcloud artifacts repositories create containers \
  --repository-format=docker \
  --location=$REGION \
  --description="Container images"

# 2) Build & push your image to that repo
gcloud builds submit \
  --tag $REGION-docker.pkg.dev/$PROJECT_ID/containers/planner-api:latest

# 3) Deploy from that image
gcloud run deploy planner-api \
  --image=$REGION-docker.pkg.dev/$PROJECT_ID/containers/planner-api:latest \
  --region=$REGION \
  --service-account=planner-sa@$PROJECT_ID.iam.gserviceaccount.com \
  --allow-unauthenticated \
  --set-env-vars=FIRESTORE_PROJECT=$PROJECT_ID,VERTEX_REGION=$REGION,MAPS_API_KEY_2="" \
  --set-env-vars='PLANGENIE_CORS_REGEX=^https?://localhost(:[0-9]+)?$' \
  --set-env-vars=PLANGENIE_CORS_ORIGINS=https://plan-genie-hackathon.web.app
  #,https://your-custom-domain.com

# list docker images currently running
gcloud artifacts docker images list \
  $REGION-docker.pkg.dev/$PROJECT_ID/containers \
  --include-tags

# OR delete tag only (digest remains if used elsewhere)
gcloud artifacts docker tags delete \
  asia-south1-docker.pkg.dev/plangenie-472417/containers/planner-api:latest
# delete specific images
gcloud artifacts docker images delete \
  $REGION-docker.pkg.dev/$PROJECT_ID/containers/planner-api@sha256:<digest> \
  --quiet

# you can delete the repo
gcloud artifacts repositories delete containers --location=$REGION

# get the access keys
gcloud secrets versions access latest \
  --secret=MAPS_API_KEY \
  --project=$PROJECT_ID

# Log Queries
resource.type="cloud_run_revision"
resource.labels.service_name="planner-api"
resource.labels.location="asia-south1"
(textPayload:"Traceback" OR textPayload:"SyntaxError" OR textPayload:"Exception" OR textPayload:"ERROR")
