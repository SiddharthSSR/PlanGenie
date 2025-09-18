import os
from typing import Literal

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from google.cloud import secretmanager

from services.gemini import init_vertex, draft_itinerary_with_gemini
from services.maps import enrich_with_maps
from services.store import save_itinerary

PROJECT_ID = os.environ.get("FIRESTORE_PROJECT")
REGION = os.environ.get("VERTEX_REGION", "asia-south1")

MOOD_LABELS = {
    1: "chill",
    2: "balanced",
    3: "adventurous",
    4: "party",
}


# Lazy secrets fetch
def access_secret(name: str) -> str:
    client = secretmanager.SecretManagerServiceClient()
    if PROJECT_ID is None:
        raise RuntimeError("FIRESTORE_PROJECT env var is required")
    path = client.secret_version_path(PROJECT_ID, name, "latest")
    return client.access_secret_version(request={"name": path}).payload.data.decode()


MAPS_API_KEY = None

app = FastAPI(title="Planner API")

raw_origins = os.getenv("PLANGENIE_CORS_ORIGINS")
allowed_origins = [o.strip() for o in raw_origins.split(",") if o.strip()] if raw_origins else ["*"]
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)



class PlanRequest(BaseModel):
    origin: str = Field(..., examples=["DEL"])
    destination: str = Field(..., examples=["JAI"])
    startDate: str  # "YYYY-MM-DD"
    endDate: str
    pax: int = 2
    budget: int = 25000
    mood: Literal[1, 2, 3, 4] = Field(
        2,
        examples=[2],
        description="1=chill, 2=balanced, 3=adventurous, 4=party",
    )


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
    prefs = req.model_dump()
    prefs["moodLabel"] = MOOD_LABELS.get(req.mood, "balanced")

    # 1) Ask Gemini for a multi-day plan
    draft = draft_itinerary_with_gemini(prefs)

    city = draft.get("city") or req.destination
    days = draft.get("days") if isinstance(draft.get("days"), list) else []

    if not days and draft.get("blocks"):
        days = [
            {
                "date": draft.get("date") or req.startDate,
                "blocks": draft.get("blocks", []),
            }
        ]
    if not days:
        days = [{"date": req.startDate, "blocks": []}]

    itinerary = {
        "prefs": prefs,
        "itineraryDraft": {"city": city, "days": days},
        "status": "DRAFT",
    }

    # 2) Enrich with Maps (guarded so we never 500)
    if MAPS_API_KEY:
        enriched_days = []
        for day in itinerary["itineraryDraft"]["days"]:
            try:
                enriched_days.append(
                    enrich_with_maps(city, day, MAPS_API_KEY)
                )
            except Exception as e:
                print(f"[maps_enrich] warning: {e}")
                enriched_days.append(day)
        itinerary["itineraryDraft"]["days"] = enriched_days

    if not PROJECT_ID:
        raise RuntimeError("FIRESTORE_PROJECT env var is required")
    # 3) Store in Firestore
    trip_id = save_itinerary(PROJECT_ID, itinerary)

    return {"tripId": trip_id, "draft": itinerary["itineraryDraft"]}
