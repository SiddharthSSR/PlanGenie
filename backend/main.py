import os
from typing import Literal, Any

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from google.cloud import secretmanager

from services.gemini import init_vertex, draft_itinerary_with_gemini
from services.maps import enrich_with_maps, get_destination_hero_image
from services.store import save_itinerary

# NEW: imports for proxy route
from fastapi import Response, HTTPException
from urllib.parse import quote
import httpx

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

raw_origins = os.getenv("PLANGENIE_CORS_ORIGINS", "")  # comma-separated
origin_regex = os.getenv(
    "PLANGENIE_CORS_REGEX",
    r"^https?://localhost(:\d+)?$"  # allow any localhost port by default
)

allowed_origins = [o.strip() for o in raw_origins.split(",") if o.strip()]

cors_kwargs: dict[str, Any] = {
    "allow_methods": ["*"],             # GET, POST, PUT, DELETE, OPTIONS, ...
    "allow_headers": ["*"],             # Authorization, Content-Type, custom headers
    "expose_headers": ["*"],            # if frontend reads custom response headers
    "allow_credentials": True,          # needed if you use cookies / withCredentials
    "max_age": 86400,                   # cache preflight for 24h
}

# Prefer regex for localhost dev; fall back to explicit list for prod
if origin_regex:
    cors_kwargs["allow_origin_regex"] = origin_regex
if allowed_origins:
    # You can combine regex + explicit allowlist: fastapi will honor both
    cors_kwargs["allow_origins"] = allowed_origins

app.add_middleware(CORSMiddleware, **cors_kwargs)


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
    # MAPS_API_KEY = os.getenv("MAPS_API_KEY")
    if not MAPS_API_KEY:
        try:
            MAPS_API_KEY = access_secret("MAPS_API_KEY")
        except Exception as e:
            print(f"[secret] MAPS_API_KEY not available: {e}")
            MAPS_API_KEY = None

    if MAPS_API_KEY:
        print("[boot] MAPS_API_KEY loaded")
    else:
        print("[boot] MAPS_API_KEY is not configured")


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

    # Keep total_budget, destination blurb
    itinerary_draft = {"city": city, "days": days}

    total_budget = draft.get("total_budget")
    if total_budget is not None:
        itinerary_draft["total_budget"] = total_budget

    # One-line destination description from Gemini
    blurb = draft.get("destination_blurb") or draft.get("destinationBlurb")
    if blurb:
        itinerary_draft["destinationBlurb"] = str(blurb).strip()[:140]

    # Destination hero image via PROXY (so the browser never sees the key)
    if MAPS_API_KEY:
        # Always point the client to our proxy route; proxy will fetch from Google server-side
        itinerary_draft["imageUrl"] = f"/media/destination?q={quote(city)}"
        print(f"[hero_image] proxied imageUrl set for {city}")
    else:
        print("[hero_image] MAPS_API_KEY is not configured")

    itinerary = {
        "prefs": prefs,
        "itineraryDraft": itinerary_draft,
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

    # Return draft with total_budget + destinationBlurb + imageUrl included
    return {"tripId": trip_id, "draft": itinerary["itineraryDraft"]}


# --- Proxy route: serves destination image from your API (hides Google key) ---
@app.get("/media/destination")
async def destination_image(q: str):
    if not MAPS_API_KEY:
        raise HTTPException(status_code=404, detail="Maps key not configured")

    # Build Google image URL server-side (includes the key) using your helper
    url = get_destination_hero_image(q, MAPS_API_KEY)
    if not url:
        raise HTTPException(status_code=404, detail="No image for destination")

    # Fetch bytes and stream back to the browser
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            r = await client.get(url)
            if r.status_code != 200:
                print(f"[media_proxy] upstream {r.status_code} for {q}: {url[:100]}...")
                raise HTTPException(status_code=502, detail=f"Upstream {r.status_code}")
            headers = {"Cache-Control": "public, max-age=86400"}
            return Response(
                content=r.content,
                media_type=r.headers.get("content-type", "image/jpeg"),
                headers=headers,
            )
    except HTTPException:
        raise
    except Exception as e:
        print(f"[media_proxy] error for {q}: {e}")
        raise HTTPException(status_code=502, detail="Image proxy error")
