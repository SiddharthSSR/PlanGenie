import requests
from typing import Dict, List, Optional, Tuple
from urllib.parse import urlencode

GOOGLE_MAPS_BASE = "https://maps.googleapis.com/maps/api"
TEXTSEARCH_URL = f"{GOOGLE_MAPS_BASE}/place/textsearch/json"
FINDPLACE_URL = f"{GOOGLE_MAPS_BASE}/place/findplacefromtext/json"
PHOTO_URL = f"{GOOGLE_MAPS_BASE}/place/photo"
STATICMAP_URL = f"{GOOGLE_MAPS_BASE}/staticmap"
STREETVIEW_URL = f"{GOOGLE_MAPS_BASE}/streetview"


# ---------------------------
# Day blocks enrichment (unchanged API)
# ---------------------------
def enrich_with_maps(city: str, day: Dict, maps_key: str) -> Dict:
    """
    Enrich a single day's blocks with place_id and lat/lng using Places Text Search.
    """
    enriched_blocks: List[Dict] = []
    for b in day.get("blocks", []):
        title = b.get("title", "")
        if not title:
            enriched_blocks.append(b)
            continue

        q = f"{title} in {city}"
        try:
            r = requests.get(
                TEXTSEARCH_URL,
                params={"query": q, "key": maps_key, "region": "id"},
                timeout=8,
            )
            r.raise_for_status()
            place = (r.json().get("results") or [None])[0]
        except Exception as e:
            print(f"[maps_enrich] warning: {e}")
            place = None

        if place:
            b["place_id"] = place.get("place_id")
            loc = place.get("geometry", {}).get("location", {})
            b["lat"] = loc.get("lat")
            b["lng"] = loc.get("lng")
        enriched_blocks.append(b)

    day["blocks"] = enriched_blocks
    return day


# ---------------------------
# Hero image helpers
# ---------------------------
def _build_photo_url(photo_ref: str, maps_key: str, maxwidth: int) -> str:
    """
    Build a Places Photo URL. IMPORTANT: parameter is 'photoreference' (no underscore).
    """
    q = urlencode({"maxwidth": maxwidth, "photoreference": photo_ref, "key": maps_key})
    return f"{PHOTO_URL}?{q}"


def _static_map(destination: str, maps_key: str) -> str:
    """
    Always-works fallback: Static Map centered on the destination.
    """
    q = urlencode({
        "center": destination,
        "zoom": 11,
        "size": "1280x720",
        "scale": 2,
        "key": maps_key
    })
    return f"{STATICMAP_URL}?{q}"


def _street_view_url(lat: float, lng: float, maps_key: str, size: str = "1280x720") -> str:
    q = urlencode({
        "size": size,
        "location": f"{lat},{lng}",
        "fov": 90,
        "key": maps_key
    })
    return f"{STREETVIEW_URL}?{q}"


def _first_result_with_geometry(results: List[Dict]) -> Optional[Tuple[float, float]]:
    for res in results:
        loc = res.get("geometry", {}).get("location", {})
        lat, lng = loc.get("lat"), loc.get("lng")
        if isinstance(lat, (int, float)) and isinstance(lng, (int, float)):
            return float(lat), float(lng)
    return None


def get_destination_hero_image(destination: str, maps_key: str, maxwidth: int = 1600) -> Optional[str]:
    """
    Returns an image URL for the destination:
      1) Try Find Place (often includes photos for cities/regions).
      2) Try Text Search (scan multiple results and query variants).
      3) Try Street View near the best result's geometry.
      4) Fallback to Static Map so UI always has an image.

    Returns None only if maps_key is missing or a truly unexpected error occurs.
    """
    if not maps_key:
        print("[places_photo] no MAPS_API_KEY configured")
        return None

    # --- 1) Find Place first (best hit rate for broad queries) ---
    try:
        fp = requests.get(
            FINDPLACE_URL,
            params={
                "input": destination,
                "inputtype": "textquery",
                "fields": "photos,place_id,geometry",
                "key": maps_key,
            },
            timeout=8,
        )
        if fp.status_code == 200:
            data = fp.json()
            for cand in data.get("candidates", []):
                photos = cand.get("photos") or []
                if photos:
                    ref = photos[0].get("photo_reference")
                    if ref:
                        url = _build_photo_url(ref, maps_key, maxwidth)
                        print(f"[places_photo] findplace hit: place_id={cand.get('place_id')}")
                        return url
        else:
            print(f"[places_photo] findplace status={fp.status_code} body={fp.text[:200]}")
    except Exception as e:
        print(f"[places_photo] findplace error: {e}")

    # --- 2) Text Search (variants) ---
    queries = [
        destination,
        f"{destination} Indonesia",
        f"{destination} tourism",
        f"{destination} island",
    ]
    last_results: List[Dict] = []
    try:
        for q in queries:
            r = requests.get(
                TEXTSEARCH_URL,
                params={"query": q, "key": maps_key, "region": "id"},
                timeout=8,
            )
            if r.status_code != 200:
                print(f"[places_photo] textsearch {q!r} status={r.status_code} body={r.text[:200]}")
                continue

            data = r.json()
            results = data.get("results") or []
            if results:
                last_results = results  # keep in case we need geometry for Street View
            for res in results[:10]:
                photos = res.get("photos") or []
                if not photos:
                    continue
                ref = photos[0].get("photo_reference")
                if not ref:
                    continue
                url = _build_photo_url(ref, maps_key, maxwidth)
                print(f"[places_photo] textsearch hit for {q!r}: place_id={res.get('place_id')}")
                return url

        print(f"[places_photo] no photos found for {destination!r} across queries")
    except Exception as e:
        print(f"[places_photo] textsearch error: {e}")

    # --- 3) Try Street View near the best known geometry (if any) ---
    try:
        if last_results:
            coords = _first_result_with_geometry(last_results)
            if coords:
                lat, lng = coords
                url = _street_view_url(lat, lng, maps_key)
                print(f"[places_photo] streetview fallback for {destination!r} at {lat},{lng}")
                return url
    except Exception as e:
        print(f"[places_photo] streetview error: {e}")

    # --- 4) Fallback: Static Map (ensures imageUrl exists) ---
    try:
        fallback = _static_map(destination, maps_key)
        print(f"[places_photo] using static map fallback for {destination!r}")
        return fallback
    except Exception as e:
        print(f"[places_photo] static map error: {e}")
        return None
