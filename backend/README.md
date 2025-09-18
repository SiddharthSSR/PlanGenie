# PlanGenie Backend

FastAPI service that drafts multi-day travel itineraries using Google Vertex AI’s Gemini models, enriches stops with Google Maps data, and persists results to Firestore.

## Stack & Architecture

- **FastAPI** application (`main.py`) exposing `GET /` and `POST /plan`.
- **Vertex AI Gemini** (`services/gemini.py`) generates a draft itinerary spanning the requested travel window.
- **Google Maps Text Search API** (`services/maps.py`) adds `place_id` and coordinates for each activity.
- **Cloud Firestore** (`services/store.py`) stores each generated trip in a `trip` collection.
- **Secret Manager** fetches `MAPS_API_KEY` when it is not provided via environment.

## Prerequisites

- Python 3.11+
- Google Cloud project with Vertex AI, Firestore, and Secret Manager enabled.
- Google Maps Places API key.
- Service account key with permissions for the above services (use `GOOGLE_APPLICATION_CREDENTIALS`).

## Configuration

Environment variables (can be set locally or via Cloud Run/App Engine deployment):

| Variable | Purpose |
| --- | --- |
| `FIRESTORE_PROJECT` | GCP project ID used for Firestore and secrets (required). |
| `VERTEX_REGION` | Vertex AI region (defaults to `asia-south1`). |
| `MAPS_API_KEY` | Google Maps API key (optional if stored in Secret Manager). |
| `GOOGLE_APPLICATION_CREDENTIALS` | Path to service-account JSON (local development). |

Secrets:
- Optional Secret Manager secret `MAPS_API_KEY` in the project; fetched on startup if the env var is absent.

Traveler mood values accepted by the API:

| Value | Description |
| --- | --- |
| `1` | chill |
| `2` | balanced |
| `3` | adventurous |
| `4` | party |

## Local Development

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export FIRESTORE_PROJECT=<your-project-id>
export MAPS_API_KEY=<maps-key>  # or rely on Secret Manager
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json
uvicorn main:app --reload --port 8080
```

## Docker

```bash
docker build -t plangenie-backend .
docker run --rm -p 8080:8080 \
  -e FIRESTORE_PROJECT=<your-project-id> \
  -e MAPS_API_KEY=<maps-key> \
  -v /path/to/key.json:/app/key.json \
  -e GOOGLE_APPLICATION_CREDENTIALS=/app/key.json \
  plangenie-backend
```

## API

### `GET /`
Health check — returns `{"ok": true, "msg": "Planner API up. Use POST /plan"}`.

### `POST /plan`
Generates and stores an itinerary covering every day in the requested travel window.

Request body:
```json
{
  "origin": "DEL",
  "destination": "JAI",
  "startDate": "2024-08-01",
  "endDate": "2024-08-03",
  "pax": 2,
  "budget": 25000,
  "mood": 3
}
```

Successful response:
```json
{
  "tripId": "abcdef123456",
  "draft": {
    "city": "Jaipur",
    "days": [
      {
        "date": "2024-08-01",
        "blocks": [
          {"time": "10:00", "title": "City Palace Walk", "tag": "heritage", "place_id": "...", "lat": 26.925, "lng": 75.823},
          {"time": "13:00", "title": "Lunch at LMB", "tag": "food"},
          {"time": "18:00", "title": "Sound & Light at Amber Fort", "tag": "activity"}
        ]
      },
      {
        "date": "2024-08-02",
        "blocks": [
          {"time": "09:30", "title": "Nahargarh Sunrise Ride", "tag": "adventure"},
          {"time": "13:00", "title": "Street Food Crawl", "tag": "food"},
          {"time": "19:00", "title": "Bar Hopping in MI Road", "tag": "nightlife"}
        ]
      },
      {
        "date": "2024-08-03",
        "blocks": [
          {"time": "10:00", "title": "Shopping at Johri Bazaar", "tag": "activity"},
          {"time": "13:30", "title": "Thali at Chokhi Dhani", "tag": "food"},
          {"time": "20:00", "title": "Party at Club Trove", "tag": "nightlife"}
        ]
      }
    ]
  }
}
```

Firestore will receive the itinerary along with the original preferences (including the derived mood label) and a `createdAt` timestamp.

## Testing & Monitoring

- No automated tests are present yet; add FastAPI route tests (e.g., pytest + httpx) when extending the service.
- Consider configuring structured logging and Google Cloud Logging sinks for production use.

## Deployment Notes

- Ensure the deploy environment has access to the service-account credentials.
- Configure Secret Manager and Firestore indexes ahead of time.
- For Cloud Run, set `--set-env-vars FIRESTORE_PROJECT=...` and optionally `--set-secrets MAPS_API_KEY=MAPS_API_KEY:latest`.
