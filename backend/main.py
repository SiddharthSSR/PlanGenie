import os
from fastapi import FastAPI
from pydantic import BaseModel, Field
from google.cloud import secretmanager

from services.gemini import init_vertex, draft_itinerary_with_gemini
from services.maps import enrich_with_maps
from services.store import save_itinerary

PROJECT_ID = os.environ.get("FIRESTORE_PROJECT")
REGION = os.environ.get("VERTEX_REGION", "asia-south1")

# Lazy secrets fetch
def access_secret(name: str) -> str:
    client = secretmanager.SecretManagerServiceClient()
    if PROJECT_ID is None:
        raise RuntimeError("FIRESTORE_PROJECT env var is required")
    path = client.secret_version_path(PROJECT_ID, name, "latest")
    return client.access_secret_version(request={"name": path}).payload.data.decode()

MAPS_API_KEY = None

app = FastAPI(title="Planner API")

class PlanRequest(BaseModel):
    origin: str = Field(..., examples=["DEL"])
    destination: str = Field(..., examples=["JAI"])
    startDate: str  # "YYYY-MM-DD"
    endDate: str
    pax: int = 2
    budget: int = 25000
    themes: list[str] = []
    mood: float = 0.5

@app.get("/")
def root():
    return {"ok": True, "msg": "Planner API up. Use POST /plan"}

@app.on_event("startup")
def boot():
    global MAPS_API_KEY
    if not PROJECT_ID:
        raise RuntimeError("FIRESTORE_PROJECT env var is required")

    init_vertex(PROJECT_ID, REGION)

    # Prefer env var if injected via --set-secrets or --set-env-vars
    MAPS_API_KEY = os.getenv("MAPS_API_KEY")
    if not MAPS_API_KEY:
        try:
            MAPS_API_KEY = access_secret("MAPS_API_KEY")
        except Exception as e:
            print(f"[secret] MAPS_API_KEY not available: {e}")
            MAPS_API_KEY = None


@app.post("/plan")
def plan(req: PlanRequest):
    # 1) Ask Gemini for a minimal day plan
    draft = draft_itinerary_with_gemini(req.model_dump())

    city = draft.get("city") or req.destination
    day = {
        "date": draft.get("date") or req.startDate,
        "blocks": draft.get("blocks", []),
    }

    itinerary = {
        "prefs": req.model_dump(),
        "itineraryDraft": {"city": city, "days": [day]},
        "status": "DRAFT",
    }

    # 2) Enrich with Maps (guarded try/except so we never 500)
    if MAPS_API_KEY:
        try:
            itinerary["itineraryDraft"]["days"][0] = enrich_with_maps(
                city, itinerary["itineraryDraft"]["days"][0], MAPS_API_KEY
            )
        except Exception as e:
            # Optional: log error, but continue with the draft
            print(f"[maps_enrich] warning: {e}")
    if not PROJECT_ID:
        raise RuntimeError("FIRESTORE_PROJECT env var is required")
    # 3) Store in Firestore
    trip_id = save_itinerary(PROJECT_ID, itinerary)

    return {"tripId": trip_id, "draft": itinerary["itineraryDraft"]}
