import asyncio
import httpx
import requests
from typing import Dict, List, Optional
# from urllib.parse import urlencode

# --- New Places API endpoints ---
# Migration completed from legacy Places API to new Places API
# Key changes:
# - GET requests changed to POST with JSON body
# - Added required field masks for all requests
# - Photo references now use 'name' field instead of 'photo_reference'
# - Response format changed from 'results' to 'places' array
PLACES_API_BASE = "https://places.googleapis.com/v1"
TEXTSEARCH_URL = f"{PLACES_API_BASE}/places:searchText"
PHOTO_URL = f"{PLACES_API_BASE}/places"  # Will be used as base for photo URLs


# ---------------------------
# Raw Text Search helper (for debugging/verification)
# ---------------------------
def textsearch_raw(query: str, maps_key: str) -> Dict:
    """
    Calls the new Places Text Search endpoint and returns the JSON as-is.
    Example: textsearch_raw("Bali, Indonesia", KEY)
    """
    if not maps_key:
        return {"status": "CONFIG_ERROR", "error": "Maps API key missing"}
    try:
        headers = {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': maps_key,
            'X-Goog-FieldMask': 'places.id,places.displayName,places.formattedAddress,places.location,places.photos'
        }
        data = {"textQuery": query}
        r = requests.post(TEXTSEARCH_URL, json=data, headers=headers, timeout=10)
        r.raise_for_status()
        j = r.json()

        # Convert new API response format to legacy-like format for compatibility
        places = j.get("places", [])
        if places:
            print(f"[textsearch_raw] query={query!r} found {len(places)} places")
            # Convert to legacy format
            results = []
            for place in places:
                legacy_place = {
                    "place_id": place.get("id"),
                    "geometry": {
                        "location": place.get("location", {})
                    },
                    "photos": place.get("photos", [])
                }
                # Add display name as name for compatibility
                if "displayName" in place:
                    legacy_place["name"] = place["displayName"].get("text", "") if isinstance(place["displayName"], dict) else str(place["displayName"])
                if "formattedAddress" in place:
                    legacy_place["formatted_address"] = place["formattedAddress"]
                results.append(legacy_place)

            return {"status": "OK", "results": results}
        else:
            print(f"[textsearch_raw] query={query!r} no places found")
            return {"status": "ZERO_RESULTS", "results": []}
    except Exception as e:
        print(f"[textsearch_raw] HTTP error for {query!r}: {e}")
        return {"status": "HTTP_ERROR", "error": str(e)}


# ---------------------------
# Day blocks enrichment (unchanged public API)
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
            headers = {
                'Content-Type': 'application/json',
                'X-Goog-Api-Key': maps_key,
                'X-Goog-FieldMask': 'places.id,places.location'
            }
            data = {"textQuery": q}
            r = requests.post(TEXTSEARCH_URL, json=data, headers=headers, timeout=8)
            r.raise_for_status()
            places = r.json().get("places", [])
            place = places[0] if places else None

            # Convert to legacy format for compatibility
            if place:
                place = {
                    "place_id": place.get("id"),
                    "geometry": {
                        "location": place.get("location", {})
                    }
                }
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
# Photo-reference (destination-only) helpers
# ---------------------------
def get_destination_photo_reference(destination: str, maps_key: str) -> Optional[str]:
    """
    Enhanced photo reference search with multiple query strategies and fallbacks.
    Tries different search patterns to improve photo discovery success rate.
    """
    if not maps_key:
        print("[places_photo] no API key configured")
        return None

    # Multiple search strategies to improve success rate
    search_queries = [
        destination,  # Original query
        f"{destination} tourist attraction",  # More specific for tourist destinations
        f"{destination} landmark",  # Focus on landmarks
        f"{destination} city",  # Focus on city if it's a place name
        destination.split(',')[0].strip() if ',' in destination else None,  # Just the city part if comma-separated
    ]

    # Remove None values and duplicates
    search_queries = list(dict.fromkeys([q for q in search_queries if q]))

    for query in search_queries:
        try:
            print(f"[places_photo] trying query: {query!r}")
            headers = {
                'Content-Type': 'application/json',
                'X-Goog-Api-Key': maps_key,
                'X-Goog-FieldMask': 'places.photos'
            }
            data = {"textQuery": query}
            r = requests.post(TEXTSEARCH_URL, json=data, headers=headers, timeout=10)
            r.raise_for_status()
            j = r.json()

            places = j.get("places", [])
            if not places:
                print(f"[places_photo] no places found for query={query!r}")
                continue

            # Convert to legacy-like format for compatibility
            results = []
            for place in places:
                legacy_place = {
                    "photos": place.get("photos", [])
                }
                results.append(legacy_place)

            # Try multiple results, not just the first one
            for i, result in enumerate(results[:3]):  # Check first 3 results
                photos = result.get("photos") or []
                if not photos:
                    continue

                # Look for the best photo (prefer larger photos)
                best_photo = None
                max_width = 0

                for photo in photos[1:5]:  # Check first 5 photos
                    # New API uses 'name' field instead of 'photo_reference'
                    photo_name = photo.get("name")
                    width = photo.get("widthPx", 0)  # New API uses widthPx
                    if photo_name and width > max_width:
                        best_photo = photo_name
                        max_width = width

                if best_photo:
                    print(f"[places_photo] found photo name for {destination!r} using query={query!r} (result #{i+1}, width={max_width})")
                    return best_photo

            print(f"[places_photo] no photos found in results for query={query!r}")

        except Exception as e:
            print(f"[places_photo] textsearch error for query={query!r}: {e}")
            continue

    print(f"[places_photo] exhausted all search strategies for destination={destination!r}")
    return None


def _build_photo_url_new(photo_name: str, maps_key: str, maxwidth: int = 1600) -> str:
    """
    Build a Places Photo URL using the photo name (new Places API).
    """
    # Extract place_id and photo_id from the photo name
    # New API photo names are in format: places/{place_id}/photos/{photo_reference}
    if "/photos/" in photo_name:
        return f"{PLACES_API_BASE}/{photo_name}/media?maxWidthPx={maxwidth}&key={maps_key}"
    else:
        # If photo_name doesn't contain the full path, construct it
        return f"{PLACES_API_BASE}/{photo_name}/media?maxWidthPx={maxwidth}&key={maps_key}"


def get_destination_hero_image(destination: str, maps_key: str, maxwidth: int = 1600) -> Optional[str]:
    """
    Enhanced destination image retrieval with fallback options:
    - First tries Google Places Photo API
    - If that fails, can be extended with other image services
    - Returns the best available image URL or None
    """
    photo_name = get_destination_photo_reference(destination, maps_key)
    if photo_name:
        return _build_photo_url_new(photo_name, maps_key, maxwidth)

    print(f"[destination_hero] no Google Places photo found for {destination!r}")
    return None


def get_fallback_destination_image(destination: str) -> Optional[str]:
    """
    Fallback image service for when Google Places Photos are not available.
    Can be extended to use services like Unsplash, Pexels, or other image APIs.
    """
    # For now, return None - can be extended with other services
    # Example extensions:
    # - Unsplash API: f"https://source.unsplash.com/1600x900/?{destination.replace(' ', ',')}"
    # - Placeholder service: f"https://via.placeholder.com/1600x900/cccccc/666666?text={destination}"

    print(f"[fallback_image] no fallback image service configured for {destination!r}")
    return None


# ---------------------------
# ASYNC VERSIONS OF ALL FUNCTIONS
# ---------------------------

async def textsearch_raw_async(query: str, maps_key: str, client: httpx.AsyncClient) -> Dict:
    """
    Async version of textsearch_raw using httpx.AsyncClient
    """
    if not maps_key:
        return {"status": "CONFIG_ERROR", "error": "Maps API key missing"}

    try:
        headers = {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': maps_key,
            'X-Goog-FieldMask': 'places.id,places.displayName,places.formattedAddress,places.location,places.photos'
        }
        data = {"textQuery": query}

        r = await client.post(TEXTSEARCH_URL, json=data, headers=headers, timeout=8.0)
        r.raise_for_status()
        j = r.json()

        # Convert new API response format to legacy-like format for compatibility
        places = j.get("places", [])
        if places:
            print(f"[textsearch_async] query={query!r} found {len(places)} places")
            results = []
            for place in places:
                legacy_place = {
                    "place_id": place.get("id"),
                    "geometry": {
                        "location": place.get("location", {})
                    },
                    "photos": place.get("photos", [])
                }
                if "displayName" in place:
                    legacy_place["name"] = place["displayName"].get("text", "") if isinstance(place["displayName"], dict) else str(place["displayName"])
                if "formattedAddress" in place:
                    legacy_place["formatted_address"] = place["formattedAddress"]
                results.append(legacy_place)

            return {"status": "OK", "results": results}
        else:
            print(f"[textsearch_async] query={query!r} no places found")
            return {"status": "ZERO_RESULTS", "results": []}

    except Exception as e:
        print(f"[textsearch_async] HTTP error for {query!r}: {e}")
        return {"status": "HTTP_ERROR", "error": str(e)}


async def enrich_block_async(block: Dict, city: str, maps_key: str, client: httpx.AsyncClient) -> Dict:
    """
    Async enrichment of a single block with place_id and lat/lng
    """
    title = block.get("title", "")
    if not title:
        return block

    q = f"{title} in {city}"
    try:
        headers = {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': maps_key,
            'X-Goog-FieldMask': 'places.id,places.location'
        }
        data = {"textQuery": q}

        r = await client.post(TEXTSEARCH_URL, json=data, headers=headers, timeout=6.0)
        r.raise_for_status()
        places = r.json().get("places", [])
        place = places[0] if places else None

        # Convert to legacy format for compatibility
        if place:
            place = {
                "place_id": place.get("id"),
                "geometry": {
                    "location": place.get("location", {})
                }
            }

            block["place_id"] = place.get("place_id")
            loc = place.get("geometry", {}).get("location", {})
            block["lat"] = loc.get("latitude")
            block["lng"] = loc.get("longitude")

    except Exception as e:
        print(f"[maps_enrich_async] warning for {q}: {e}")

    return block


async def enrich_day_async(day: Dict, city: str, maps_key: str, client: httpx.AsyncClient) -> Dict:
    """
    Async enrichment of all blocks in a day using concurrent requests
    """
    blocks = day.get("blocks", [])
    if not blocks:
        return day

    # Process all blocks concurrently
    enriched_blocks = await asyncio.gather(
        *[enrich_block_async(block.copy(), city, maps_key, client) for block in blocks],
        return_exceptions=True
    )

    # Handle any exceptions and fall back to original blocks
    final_blocks = []
    for i, result in enumerate(enriched_blocks):
        if isinstance(result, Exception):
            print(f"[enrich_day_async] block {i} failed: {result}")
            final_blocks.append(blocks[i])  # Use original block
        else:
            final_blocks.append(result)

    day["blocks"] = final_blocks
    return day


async def enrich_itinerary_async(city: str, days: List[Dict], maps_key: str) -> List[Dict]:
    """
    Async enrichment of all days in an itinerary using concurrent requests
    """
    if not maps_key or not days:
        return days

    async with httpx.AsyncClient(
        timeout=httpx.Timeout(20.0, connect=5.0),
        limits=httpx.Limits(max_connections=10, max_keepalive_connections=5)
    ) as client:

        # Process all days concurrently
        enriched_days = await asyncio.gather(
            *[enrich_day_async(day.copy(), city, maps_key, client) for day in days],
            return_exceptions=True
        )

        # Handle any exceptions and fall back to original days
        final_days = []
        for i, result in enumerate(enriched_days):
            if isinstance(result, Exception):
                print(f"[enrich_itinerary_async] day {i} failed: {result}")
                final_days.append(days[i])  # Use original day
            else:
                final_days.append(result)

        return final_days


async def get_destination_photo_reference_async(destination: str, maps_key: str) -> Optional[str]:
    """
    Async version of photo reference search with multiple query strategies
    """
    if not maps_key:
        print("[places_photo_async] no API key configured")
        return None

    search_queries = [
        destination,
        f"{destination} tourist attraction",
        f"{destination} landmark",
        f"{destination} city",
        destination.split(',')[0].strip() if ',' in destination else None,
    ]

    # Remove None values and duplicates
    search_queries = list(dict.fromkeys([q for q in search_queries if q]))

    async with httpx.AsyncClient(
        timeout=httpx.Timeout(15.0, connect=5.0)
    ) as client:

        for query in search_queries:
            try:
                print(f"[places_photo_async] trying query: {query!r}")
                headers = {
                    'Content-Type': 'application/json',
                    'X-Goog-Api-Key': maps_key,
                    'X-Goog-FieldMask': 'places.photos'
                }
                data = {"textQuery": query}

                r = await client.post(TEXTSEARCH_URL, json=data, headers=headers, timeout=8.0)
                r.raise_for_status()
                j = r.json()

                places = j.get("places", [])
                if not places:
                    print(f"[places_photo_async] no places found for query={query!r}")
                    continue

                # Try multiple results, not just the first one
                for i, place in enumerate(places[:3]):
                    photos = place.get("photos", [])
                    if not photos:
                        continue

                    # Look for the best photo (prefer larger photos)
                    best_photo = None
                    max_width = 0

                    for photo in photos[:5]:
                        photo_name = photo.get("name")
                        width = photo.get("widthPx", 0)
                        if photo_name and width > max_width:
                            best_photo = photo_name
                            max_width = width

                    if best_photo:
                        print(f"[places_photo_async] found photo name for {destination!r} using query={query!r} (result #{i+1}, width={max_width})")
                        return best_photo

                print(f"[places_photo_async] no photos found in results for query={query!r}")

            except Exception as e:
                print(f"[places_photo_async] textsearch error for query={query!r}: {e}")
                continue

    print(f"[places_photo_async] exhausted all search strategies for destination={destination!r}")
    return None


async def get_destination_hero_image_async(destination: str, maps_key: str, maxwidth: int = 1600) -> Optional[str]:
    """
    Async version of destination image retrieval
    """
    photo_name = await get_destination_photo_reference_async(destination, maps_key)
    if photo_name:
        return _build_photo_url_new(photo_name, maps_key, maxwidth)

    print(f"[destination_hero_async] no Google Places photo found for {destination!r}")
    return None
