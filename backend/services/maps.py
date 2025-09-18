import requests
from typing import Dict, List

GOOGLE_MAPS_BASE = "https://maps.googleapis.com/maps/api"

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
        r = requests.get(
            "https://maps.googleapis.com/maps/api/place/textsearch/json",
            params={"query": q, "key": maps_key},
            timeout=8,
        )
        place = (r.json().get("results") or [None])[0]
        if place:
            b["place_id"] = place.get("place_id")
            loc = place.get("geometry", {}).get("location", {})
            b["lat"] = loc.get("lat")
            b["lng"] = loc.get("lng")
        enriched_blocks.append(b)

    day["blocks"] = enriched_blocks
    return day
