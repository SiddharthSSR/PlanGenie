import os
import asyncio
from typing import Literal, Any, Optional

from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from google.cloud import secretmanager

from services.gemini import draft_itinerary_with_gemini
from services.maps import get_destination_hero_image, get_destination_photo_reference, enrich_itinerary_async, get_destination_photo_reference_async
from services.store import save_itinerary

# Proxy imports
from fastapi.responses import StreamingResponse
from urllib.parse import quote
import httpx

DEFAULT_REFERER = os.getenv("MAPS_API_REFERER")  # optional
DEFAULT_UA = os.getenv(
    "PLANGENIE_UPSTREAM_UA",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/126.0 Safari/537.36",
)

PROJECT_ID = os.environ.get("FIRESTORE_PROJECT")

MOOD_LABELS = {1: "chill", 2: "balanced", 3: "adventurous", 4: "party"}


def access_secret(name: str) -> str:
    client = secretmanager.SecretManagerServiceClient()
    if PROJECT_ID is None:
        raise RuntimeError("FIRESTORE_PROJECT env var is required")
    path = client.secret_version_path(PROJECT_ID, name, "latest")
    return client.access_secret_version(request={"name": path}).payload.data.decode()


# Use the NEW key everywhere
MAPS_API_KEY_2: Optional[str] = None

app = FastAPI(title="Planner API")

raw_origins = os.getenv("PLANGENIE_CORS_ORIGINS", "")
origin_regex = os.getenv("PLANGENIE_CORS_REGEX", r"^https?://localhost(:\d+)?$")
allowed_origins = [o.strip() for o in raw_origins.split(",") if o.strip()]

cors_kwargs: dict[str, Any] = {
    "allow_methods": ["*"],
    "allow_headers": ["*"],
    "expose_headers": ["*"],
    "allow_credentials": True,
    "max_age": 86400,
}
if origin_regex:
    cors_kwargs["allow_origin_regex"] = origin_regex
if allowed_origins:
    cors_kwargs["allow_origins"] = allowed_origins

app.add_middleware(CORSMiddleware, **cors_kwargs)


class PlanRequest(BaseModel):
    origin: str = Field(..., examples=["DEL"])
    destination: str = Field(..., examples=["JAI"])
    startDate: str
    endDate: str
    pax: int = 2
    budget: int = 25000
    mood: Literal[1, 2, 3, 4] = Field(
        2, examples=[2], description="1=chill, 2=balanced, 3=adventurous, 4=party"
    )
    model: str = Field(
        "gemini-2.5-flash-lite",
        examples=["gemini-2.5-flash-lite", "gemini-2.5-flash"],
        description="Gemini model to use for generating itinerary"
    )


@app.get("/")
def root():
    return {"ok": True, "msg": "Planner API up. Use POST /plan"}


@app.on_event("startup")
def boot():
    global MAPS_API_KEY_2

    # Check for Gemini authentication
    gemini_api_key = os.getenv("GEMINI_API_KEY")
    print("[boot] Environment variables check:")
    print(f"[boot] GEMINI_API_KEY: {'Set' if gemini_api_key else 'Not set'}")
    print(f"[boot] FIRESTORE_PROJECT: {PROJECT_ID}")
    print(f"[boot] GOOGLE_GENAI_USE_VERTEXAI: {os.getenv('GOOGLE_GENAI_USE_VERTEXAI')}")

    if gemini_api_key:
        print(f"[boot] GEMINI_API_KEY found (ends with: ...{gemini_api_key[-6:]}) - will use direct API authentication")
        # Test the Gemini connection during startup
        try:
            from services.gemini import init_gemini
            client = init_gemini()
            test_resp = client.models.generate_content(
                model="gemini-2.5-flash-lite",
                contents="Say 'OK' if you can read this."
            )
            print(f"[boot] Gemini API test successful: {(test_resp.text or '').strip()}")
        except Exception as e:
            print(f"[boot] WARNING: Gemini API test failed: {e}")
    elif PROJECT_ID:
        print("[boot] GEMINI_API_KEY not found - will use Vertex AI authentication")
    else:
        raise RuntimeError("Either GEMINI_API_KEY or FIRESTORE_PROJECT env var is required for Gemini")

    # Project ID is still needed for Firestore
    if not PROJECT_ID:
        print("[boot] Warning: FIRESTORE_PROJECT not set - Firestore operations will fail")

    # Prefer env var (for local/dev), else Secret Manager
    MAPS_API_KEY_2 = os.getenv("MAPS_API_KEY_2")
    if not MAPS_API_KEY_2:
        try:
            MAPS_API_KEY_2 = access_secret("MAPS_API_KEY_2")
        except Exception as e:
            print(f"[secret] MAPS_API_KEY_2 not available: {e}")
            MAPS_API_KEY_2 = None

    # Optional: fallback to old MAPS_API_KEY if you still have that secret around
    if not MAPS_API_KEY_2:
        try:
            fallback = os.getenv("MAPS_API_KEY") or access_secret("MAPS_API_KEY")
            if fallback:
                MAPS_API_KEY_2 = fallback
                print("[boot] FELL BACK to MAPS_API_KEY")
        except Exception:
            pass

    if MAPS_API_KEY_2:
        print("[boot] MAPS_API_KEY_2 loaded")
    else:
        print("[boot] MAPS_API_KEY_2 is not configured")


@app.post("/plan")
async def plan(req: PlanRequest, request: Request):
    prefs = req.model_dump()
    prefs["moodLabel"] = MOOD_LABELS.get(req.mood, "balanced")

    # 1) Ask Gemini for a multi-day plan
    draft = draft_itinerary_with_gemini(prefs, req.model)

    city = draft.get("city") or req.destination
    days = draft.get("days") if isinstance(draft.get("days"), list) else []

    if not days and draft.get("blocks"):
        days = [{"date": draft.get("date") or req.startDate, "blocks": draft.get("blocks", [])}]
    if not days:
        days = [{"date": req.startDate, "blocks": []}]

    itinerary_draft = {"city": city, "days": days}

    total_budget = draft.get("total_budget")
    if total_budget is not None:
        itinerary_draft["total_budget"] = total_budget

    blurb = draft.get("destination_blurb") or draft.get("destinationBlurb")
    if blurb:
        itinerary_draft["destinationBlurb"] = str(blurb).strip()[:140]

    itinerary = {"prefs": prefs, "itineraryDraft": itinerary_draft, "status": "DRAFT"}

    # Check if Firestore is available for saving
    save_to_firestore = bool(PROJECT_ID)

    # 2) Run Maps enrichment and photo check concurrently with Firestore save
    tasks = []

    # Task 1: Enrich itinerary with Maps data (if API key available)
    if MAPS_API_KEY_2:
        tasks.append(enrich_itinerary_async(city, itinerary["itineraryDraft"]["days"], MAPS_API_KEY_2))
        tasks.append(get_destination_photo_reference_async(city, MAPS_API_KEY_2))
    else:
        # Create dummy async functions that return None/original data
        async def no_enrichment():
            return itinerary["itineraryDraft"]["days"]
        async def no_photo():
            return None
        tasks.append(no_enrichment())
        tasks.append(no_photo())

    # Task 3: Store in Firestore (run in thread pool since it's not async)
    if save_to_firestore and PROJECT_ID:
        loop = asyncio.get_event_loop()
        tasks.append(loop.run_in_executor(None, save_itinerary, PROJECT_ID, itinerary))
    else:
        # Create dummy async function that returns a local trip ID
        async def no_save():
            return "local_draft"
        tasks.append(no_save())

    # Execute all tasks concurrently
    results = await asyncio.gather(*tasks, return_exceptions=True)

    # Process results
    enriched_days, photo_ref, trip_id = results

    # Handle enriched days
    if isinstance(enriched_days, Exception):
        print(f"[maps_enrich_async] warning: {enriched_days}")
    elif enriched_days is not None and isinstance(enriched_days, list):
        itinerary["itineraryDraft"]["days"] = enriched_days
        print(f"[maps_enrich_async] successfully enriched {len(enriched_days)} days")

    # Handle photo reference
    if isinstance(photo_ref, Exception):
        print(f"[hero_image_async] photo lookup failed: {photo_ref}")
    elif photo_ref is not None:
        itinerary_draft["imageUrl"] = f"/media/destination?q={quote(city)}"
        print(f"[hero_image_async] Google Places photo available for {city}")
    elif MAPS_API_KEY_2:
        print(f"[hero_image_async] No Google Places photo found for {city}, frontend should use fallback")
    else:
        print("[hero_image_async] MAPS_API_KEY_2 is not configured, no destination images available")

    # Handle trip_id
    if isinstance(trip_id, Exception):
        raise RuntimeError(f"Failed to save itinerary: {trip_id}")

    if not save_to_firestore:
        print("[plan] Itinerary created without Firestore save (using local draft ID)")

    return {"tripId": trip_id, "draft": itinerary["itineraryDraft"]}

# testsearch debugging
from services.maps import textsearch_raw

@app.get("/debug/textsearch")
def debug_textsearch(q: str):
    # Prefer the secret-loaded key you already fetched at startup
    maps_key = MAPS_API_KEY_2 or os.getenv("MAPS_API_KEY_2") or os.getenv("MAPS_API_KEY")
    if not maps_key:
        raise HTTPException(status_code=500, detail="Maps API key not configured")
    return textsearch_raw(q, maps_key)

@app.get("/debug/photoref")
def debug_photoref(q: str, maxwidth: int = 1200):
    maps_key = MAPS_API_KEY_2 or os.getenv("MAPS_API_KEY_2") or os.getenv("MAPS_API_KEY")
    if not maps_key:
        raise HTTPException(status_code=500, detail="Maps API key not configured")

    ref = get_destination_photo_reference(q, maps_key)
    return {
        "query": q,
        "ok": bool(ref),
        "photo_reference": ref,
        "proxy_url": f"/media/places-photo?ref={quote(ref)}&mw={maxwidth}" if ref else None,
    }

# --- Proxy route: Places Photo only (uses MAPS_API_KEY_2) ---
@app.get("/media/destination")
async def destination_image(q: str):
    if not MAPS_API_KEY_2:
        raise HTTPException(status_code=503, detail="Maps API key not configured")

    # Build a Places Photo URL server-side (legacy flow) so the key never hits the browser
    url = get_destination_hero_image(q, MAPS_API_KEY_2)
    if not url:
        # No Places Photo found — return 404 so frontend can use fallback
        print(f"[media_proxy] No image found for destination: {q}")
        raise HTTPException(status_code=404, detail="No image found for destination")

    upstream_headers = {
        "User-Agent": DEFAULT_UA,
        "Accept": "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
    }
    if DEFAULT_REFERER:
        upstream_headers["Referer"] = DEFAULT_REFERER

    try:
        async with httpx.AsyncClient(
            timeout=20.0, follow_redirects=True, headers=upstream_headers
        ) as client:
            r = await client.get(url)
            if r.status_code != 200:
                snippet = r.text[:300] if r.text else str(r.content[:300])
                print(f"[media_proxy] upstream status={r.status_code} body={snippet}")
                raise HTTPException(status_code=404, detail=f"Upstream returned {r.status_code}")

            content_type = r.headers.get("content-type", "image/jpeg")

            # Validate that we actually got an image
            if not content_type.startswith("image/"):
                print(f"[media_proxy] unexpected content-type: {content_type}")
                raise HTTPException(status_code=502, detail="Invalid image response")

            return StreamingResponse(
                iter([r.content]),
                media_type=content_type,
                headers={
                    "Cache-Control": "public, max-age=86400",
                    "X-Image-Source": "google-places"
                },
            )
    except HTTPException:
        raise
    except Exception as e:
        print(f"[media_proxy] error for destination {q}: {e}")
        raise HTTPException(status_code=502, detail="Image proxy error")

@app.get("/media/places-photo")
async def places_photo(ref: str, mw: int = 1200):
    if not MAPS_API_KEY_2:
        raise HTTPException(status_code=404, detail="Maps key not configured")

    # New Places API endpoint format
    # ref should be in format: places/{place_id}/photos/{photo_reference}
    if "/photos/" in ref:
        url = f"https://places.googleapis.com/v1/{ref}/media"
    else:
        # Fallback: assume ref is just the photo reference part
        url = f"https://places.googleapis.com/v1/{ref}/media"

    params = {"maxWidthPx": str(mw), "key": MAPS_API_KEY_2}

    headers = {
        "User-Agent": DEFAULT_UA,
        "Accept": "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
    }
    if DEFAULT_REFERER:
        headers["Referer"] = DEFAULT_REFERER  # only if your key requires it

    try:
        async with httpx.AsyncClient(timeout=20.0, follow_redirects=True, headers=headers) as client:
            r = await client.get(url, params=params)
            if r.status_code != 200:
                snippet = r.text[:300] if r.text else str(r.content[:300])
                print(f"[places_photo_proxy] status={r.status_code} body={snippet}")
                raise HTTPException(status_code=404, detail=f"Upstream {r.status_code}")

            return StreamingResponse(
                iter([r.content]),
                media_type=r.headers.get("content-type", "image/jpeg"),
                headers={"Cache-Control": "public, max-age=86400"},
            )
    except HTTPException:
        raise
    except Exception as e:
        print(f"[places_photo_proxy] error: {e}")
        raise HTTPException(status_code=502, detail="Image proxy error")
