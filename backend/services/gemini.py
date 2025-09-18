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
    Return a normalized itinerary skeleton we’ll enrich with Maps.
    """
    model = GenerativeModel("gemini-1.5-pro")
    mood_label = prefs.get("moodLabel", "balanced")
    prompt = f"""
    You are an expert travel planner.

    Create a daily itinerary for a trip to {prefs['destination']} from {prefs['startDate']} through {prefs['endDate']} for {prefs['pax']} people with an approximate budget of INR {prefs['budget']}.
    The travelers prefer a {mood_label} vibe.

    Requirements:
    - Include every day from the start date through the end date (inclusive).
    - Provide exactly three activities per day.
    - Use realistic times between 08:00 and 22:00 in chronological order.
    - Tailor activity choices to the requested mood.

    Return strict JSON with the structure:
    {{
      "city": "...",
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
      ]
    }}
    """

    try:
        resp = model.generate_content(prompt)
        text = (resp.text or "").strip().strip("`")
        if "{" not in text or "}" not in text:
            raise ValueError("Gemini response did not contain JSON")
        payload = text[text.find("{") : text.rfind("}") + 1]
        raw = json.loads(payload)
        normalized = _normalize_response(raw, prefs)
        if not normalized.get("days"):
            raise ValueError("Gemini response missing days")
        return normalized
    except Exception as exc:
        print(f"[gemini] fallback activated: {exc}")
        return _fallback_itinerary(prefs)


def _normalize_response(raw: Dict, prefs: Dict) -> Dict:
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

    if not normalized_days and isinstance(raw.get("blocks"), list):
        normalized_days.append(
            {
                "date": raw.get("date") or prefs.get("startDate"),
                "blocks": raw.get("blocks", []),
            }
        )

    return {"city": city, "days": normalized_days}


def _fallback_itinerary(prefs: Dict) -> Dict:
    destination = prefs.get("destination", "City")
    return {
        "city": destination,
        "days": _fallback_days(prefs, destination),
    }


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
