import vertexai
from vertexai.generative_models import GenerativeModel
from typing import Dict

def init_vertex(project_id: str, region: str):
    vertexai.init(project=project_id, location=region)

def draft_itinerary_with_gemini(prefs: Dict) -> Dict:
    """
    Keep it simple: ask Gemini to outline 1 day with 3 POIs.
    Return a normalized itinerary skeleton we’ll enrich with Maps.
    """
    model = GenerativeModel("gemini-1.5-pro")
    prompt = f"""
    Create a one-day itinerary with 3 activities for {prefs['destination']}
    on {prefs['startDate']} for {prefs['pax']} people, budget INR {prefs['budget']}.
    Themes: {", ".join(prefs.get("themes", []))}. Keep times realistic (start at 10:00).
    Return strict JSON with fields:
    {{
      "city":"...", "date":"YYYY-MM-DD",
      "blocks":[{{"time":"HH:MM","title":"...", "tag":"heritage|food|activity"}}]
    }}
    """
    resp = model.generate_content(prompt)
    # vertex returns text; ensure it's JSON-ish
    import json
    text = resp.text.strip().strip("`")
    # Quick fallback in case model writes markdown fencing
    try:
        data = json.loads(text[text.find("{"): text.rfind("}")+1])
    except Exception:
        data = {
            "city": prefs["destination"],
            "date": prefs["startDate"],
            "blocks": [
                {"time":"10:00","title":"City Walk Old Town","tag":"heritage"},
                {"time":"13:00","title":"Popular Lunch Spot","tag":"food"},
                {"time":"16:00","title":"Top Museum Visit","tag":"activity"},
            ]
        }
    return data
