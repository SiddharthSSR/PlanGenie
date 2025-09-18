# PlanGenie Flutter App

This app is the authenticated client for the Planner API. It uses Firebase Authentication for sign-in and talks to the FastAPI backend to draft itineraries.

## Prerequisites
- Flutter 3.16+ with web support enabled (`flutter config --enable-web`).
- Dart/Flutter dependencies fetched once after cloning (`flutter create .` followed by `flutter pub get`).
- Python 3.11+ for local backend development.
- Google Cloud SDK (`gcloud`) if you deploy to Cloud Run.

## Backend integration overview
- Requests are issued by the `PlannerApiClient` in `lib/src/features/home/data/planner_api.dart`.
- The client points to the URL provided through the `PLANGENIE_API_BASE_URL` Dart define (default `http://localhost:8080`).
- Riverpod manages request state via `planControllerProvider`, and the home screen renders the draft itinerary payload.

## Run the backend locally
1. `cd ../backend`
2. `python3 -m venv .venv && source .venv/bin/activate`
3. `pip install -r requirements.txt`
4. Export minimum env vars:
   ```bash
   export FIRESTORE_PROJECT=<gcp-project-id>
   export PLANGENIE_CORS_ORIGINS=http://localhost:64358  # adjust to your Flutter web dev server origin
   # optional during local dev
   export MAPS_API_KEY=<maps-key>
   export VERTEX_REGION=asia-south1
   export GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/service-account.json
   ```
   - `FIRESTORE_PROJECT` is required for Firestore, Secret Manager, and Vertex calls.
   - Provide `GOOGLE_APPLICATION_CREDENTIALS` or run `gcloud auth application-default login` so the Secret Manager lookup succeeds.
   - `PLANGENIE_CORS_ORIGINS` is a comma-separated list of allowed browser origins. Leave unset to allow all.
5. Start the API: `uvicorn main:app --reload --port 8080`
6. Optional smoke test: `curl http://127.0.0.1:8080/` or POST to `/plan` with sample JSON.

## Use the hosted Cloud Run backend
1. Make sure the Cloud Run service is deployed with the new image and env vars:
   ```bash
   gcloud run deploy planner-api \
     --image $REGION-docker.pkg.dev/$PROJECT_ID/containers/planner-api:latest \
     --region asia-south1 \
     --allow-unauthenticated \
     --set-env-vars FIRESTORE_PROJECT=$PROJECT_ID,VERTEX_REGION=asia-south1,PLANGENIE_CORS_ORIGINS=https://your-web-origin,http://localhost:64358 \
     --set-secrets MAPS_API_KEY=MAPS_API_KEY:latest
   ```
2. Record the service URL, e.g. `https://planner-api-12345.asia-south1.run.app`.
3. For browser clients, ensure every origin that will call the API is listed in `PLANGENIE_CORS_ORIGINS`.

## Run the Flutter app
1. `cd flutter-app`
2. Fetch dependencies: `flutter pub get`
3. Enable platforms (run once if not already):
   ```bash
   flutter config --enable-web
   flutter create .
   ```
4. Launch with the correct backend URL:
   - Local backend on desktop/web:
     ```bash
     flutter run --dart-define=PLANGENIE_API_BASE_URL=http://127.0.0.1:8080
     ```
   - Android emulator talking to local backend:
     ```bash
     flutter run -d android \
       --dart-define=PLANGENIE_API_BASE_URL=http://10.0.2.2:8080
     ```
   - iOS simulator with local backend:
     ```bash
     flutter run -d ios \
       --dart-define=PLANGENIE_API_BASE_URL=http://127.0.0.1:8080
     ```
   - Cloud Run backend (all platforms):
     ```bash
     flutter run --dart-define=PLANGENIE_API_BASE_URL=https://planner-api-12345.asia-south1.run.app
     ```

### Flutter web specifics
- When `flutter run -d chrome` starts it prints a URL such as `http://localhost:64358`. Add this origin to `PLANGENIE_CORS_ORIGINS` so preflight requests succeed.
- Chrome may block `http://localhost` vs `http://127.0.0.1` as different origins; include both if necessary.
- The web build expects Firebase web credentials (`flutterfire configure`) to be present for auth to work.

## Firebase configuration
Follow the existing instructions if you have not yet run the FlutterFire CLI:
1. Install: `dart pub global activate flutterfire_cli`
2. Generate configs: `flutterfire configure --project plan-genie-hackathon`
3. Copy the generated `google-services.json` and `GoogleService-Info.plist` into the platform folders.

## Troubleshooting
- **`FIRESTORE_PROJECT env var is required`**: export the variable before running uvicorn or set it on Cloud Run.
- **`MAPS_API_KEY not available: Your default credentials were not found`**: provide ADC via `GOOGLE_APPLICATION_CREDENTIALS` or `gcloud auth application-default login`.
- **405 on `OPTIONS /plan` in Flutter web**: confirm `PLANGENIE_CORS_ORIGINS` contains the dev server origin and redeploy/restart the backend.
- **Android cannot reach localhost backend**: use `http://10.0.2.2:<port>` instead of `http://127.0.0.1`.
- **TLS errors when pointing to Cloud Run**: ensure you pass an `https://` URL in `PLANGENIE_API_BASE_URL` and the device clock is accurate.

## Project layout
- `lib/src/app.dart` – top-level widget wiring theming and the auth gate.
- `lib/src/features/auth/…` – Firebase auth flows.
- `lib/src/features/home/home_screen.dart` – itinerary request UI wired to the backend.
- `lib/src/features/home/data/planner_api.dart` – REST client and models for `/plan`.
- `lib/src/features/home/providers/plan_controller.dart` – Riverpod notifier managing API state.
- `pubspec.yaml` – dependencies (`http`, `firebase_*`, `flutter_riverpod`, etc.).

Share this README with contributors so they can provision the backend URL and verify the round trip end to end.
