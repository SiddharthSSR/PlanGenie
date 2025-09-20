import json
from datetime import datetime, timedelta, date
from typing import Dict, List, Optional

import vertexai
from vertexai.generative_models import GenerativeModel


def init_vertex(project_id: str, region: str):
    vertexai.init(project=project_id, location=region)


def draft_itinerary_with_gemini(prefs: Dict) -> Dict:
    """
    Ask Gemini for a multi-day itinerary with three activities per day.
    Return a normalized itinerary skeleton. Ensures a computed total_budget
    that is derived from the itinerary (not just echoing user input), and
    includes a one-line destination_blurb.
    """
    model = GenerativeModel("gemini-1.5-flash")
    mood_label = prefs.get("moodLabel", "balanced")

    # Prompt keeps your existing structure, adds clear budgeting + blurb instruction.
    prompt = f"""
    You are an expert travel planner.

    Create a daily itinerary for a trip to {prefs['destination']} from {prefs['startDate']} through {prefs['endDate']} for {prefs['pax']} people with an approximate budget of INR {prefs['budget']}.
    The travelers prefer a {mood_label} vibe.

    Requirements:
    - Include every day from the start date through the end date (inclusive).
    - Provide exactly three activities per day.
    - Use realistic times between 08:00 and 22:00 in chronological order.
    - Tailor activity choices to the requested mood.
    - Also include a numeric field 'total_budget' (INR) for the full trip, computed from your proposed plan.
      Do NOT simply repeat the user's provided budget; calculate based on the itinerary (it may be higher or lower).
      Prefer keeping total_budget ≤ the provided budget where possible.
    - Include a single-sentence 'destination_blurb' (≤140 chars) that describes {prefs['destination']} in a punchy, traveler-friendly way.

    Return strict JSON with the structure:
    {{
      "city": "...",
      "destination_blurb": "...",
      "days": [
        {{
          "date": "YYYY-MM-DD",
          "blocks": [
            {{
              "time": "HH:MM",
              "title": "...",
              "tag": "heritage|food|activity|nightlife|adventure|relax"
            }}
          ]
        }}
      ],
      "total_budget": 0
    }}
    """

    try:
        resp = model.generate_content(prompt)
        text = (resp.text or "").strip().strip("`")
        if "{" not in text or "}" not in text:
            raise ValueError("Gemini response did not contain JSON")
        payload = text[text.find("{"): text.rfind("}") + 1]
        raw = json.loads(payload)

        normalized = _normalize_response(raw, prefs)
        if not normalized.get("days"):
            raise ValueError("Gemini response missing days")

        # Compute itinerary-based estimate from blocks/tags & pax (does NOT echo user budget)
        computed = _estimate_total_budget_from_blocks(normalized, prefs)

        # If model omitted/zeroed budget OR echoed user budget, use computed
        if (
            "total_budget" not in normalized
            or normalized.get("total_budget") in (None, "", 0, 0.0)
            or _is_same_number(normalized.get("total_budget"), prefs.get("budget"))
        ):
            normalized["total_budget"] = computed
        else:
            normalized["total_budget"] = round(_coerce_number(normalized["total_budget"]), 2)

        # Guardrail: if model's total exceeds user budget by >2%, switch to computed
        user_budget = prefs.get("budget")
        if user_budget is not None:
            try:
                cap = float(user_budget)
                if normalized["total_budget"] > cap * 1.02:
                    normalized["total_budget"] = computed
            except Exception:
                pass

        # Ensure a destination_blurb exists (fallback if model missed it)
        if not normalized.get("destination_blurb"):
            city = normalized.get("city") or prefs.get("destination", "the destination")
            normalized["destination_blurb"] = f"Discover {city}'s top sights, local flavors, and vibrant culture in a balanced, time-smart trip."

        return normalized

    except Exception as exc:
        print(f"[gemini] fallback activated: {exc}")
        return _fallback_itinerary(prefs)


def _normalize_response(raw: Dict, prefs: Dict) -> Dict:
    """
    Preserve city, days (with blocks), and keep total_budget + destination_blurb if supplied.
    """
    city = raw.get("city") or prefs.get("destination")
    normalized_days: List[Dict] = []

    raw_days = raw.get("days")
    if isinstance(raw_days, list):
        for day in raw_days:
            if not isinstance(day, dict):
                continue
            blocks = day.get("blocks") if isinstance(day.get("blocks"), list) else []
            normalized_days.append(
                {
                    "date": day.get("date") or prefs.get("startDate"),
                    "blocks": blocks,
                }
            )

    # Some models flatten to top-level date/blocks
    if not normalized_days and isinstance(raw.get("blocks"), list):
        normalized_days.append(
            {
                "date": raw.get("date") or prefs.get("startDate"),
                "blocks": raw.get("blocks", []),
            }
        )

    out = {"city": city, "days": normalized_days}

    # Preserve total_budget if present (we may still override later)
    if "total_budget" in raw:
        out["total_budget"] = raw.get("total_budget")

    # Preserve a one-line destination blurb if present (accept both snake/camel)
    blurb = raw.get("destination_blurb") or raw.get("destinationBlurb")
    if blurb:
        # hard-trim to 140 chars just in case
        out["destination_blurb"] = str(blurb).strip()[:140]

    return out


def _coerce_number(x, default=0.0) -> float:
    try:
        if x is None:
            return default
        if isinstance(x, (int, float)):
            return float(x)
        s = str(x).replace(",", "").strip()
        return float(s)
    except Exception:
        return default


def _is_same_number(a, b, tol_ratio: float = 0.01) -> bool:
    """
    True if a and b are numerically equal within a relative tolerance (default 1%).
    If either is None, returns False.
    """
    try:
        if a is None or b is None:
            return False
        fa = _coerce_number(a)
        fb = _coerce_number(b)
        if fb == 0:
            return abs(fa - fb) < 1e-9
        return abs(fa - fb) / abs(fb) <= tol_ratio
    except Exception:
        return False


def _estimate_total_budget_from_blocks(itin: dict, prefs: Dict) -> float:
    """
    Estimate budget from itinerary content:
    - Tag-based per-activity rough costs (per person)
    - Multiplied by pax
    - Plus a simple BLR→destination flight baseline per pax
    """
    pax = int(prefs.get("pax", 1) or 1)

    # Rough per-person activity costs (INR) by tag
    TAG_PRICE_TABLE = {
        "heritage": 800,
        "food": 600,
        "activity": 1200,
        "nightlife": 1500,
        "adventure": 2000,
        "relax": 700,
    }

    total = 0.0
    for day in itin.get("days", []):
        for block in day.get("blocks", []):
            tag = (block.get("tag") or "").strip().lower()
            total += TAG_PRICE_TABLE.get(tag, 800) * pax

    # Add a rough flight baseline per person from origin
    total += 15000 * pax

    return round(total, 2)


def _fallback_itinerary(prefs: Dict) -> Dict:
    destination = prefs.get("destination", "City")
    itin = {
        "city": destination,
        "days": _fallback_days(prefs, destination),
        "destination_blurb": f"Discover {destination}'s highlights with a smart mix of sights, food, and local culture.",
    }
    itin["total_budget"] = _estimate_total_budget_from_blocks(itin, prefs)
    return itin


def _fallback_days(prefs: Dict, destination: str) -> List[Dict]:
    start = _parse_date(prefs.get("startDate")) or datetime.utcnow().date()
    end = _parse_date(prefs.get("endDate")) or start

    if end < start:
        end = start

    days: List[Dict] = []
    current = start
    while current <= end:
        days.append(
            {
                "date": current.isoformat(),
                "blocks": _fallback_blocks(destination),
            }
        )
        current += timedelta(days=1)
    return days


def _parse_date(value: object) -> Optional[date]:
    if isinstance(value, str):
        try:
            return datetime.strptime(value, "%Y-%m-%d").date()
        except ValueError:
            return None
    return None


def _fallback_blocks(destination: str) -> List[Dict]:
    return [
        {"time": "10:00", "title": f"{destination} Highlights Walk", "tag": "heritage"},
        {"time": "13:00", "title": "Local Lunch Spot", "tag": "food"},
        {"time": "18:00", "title": "Evening Cultural Experience", "tag": "activity"},
    ]
