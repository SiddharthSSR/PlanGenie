from google.cloud import firestore
from datetime import datetime
from typing import Dict

def save_itinerary(project_id: str, trip: Dict) -> str:
    db = firestore.Client(project=project_id)
    ref = db.collection("trip").document()
    trip["createdAt"] = datetime.utcnow().isoformat() + "Z"
    ref.set(trip)
    return ref.id
