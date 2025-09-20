# PlanGenie Backend

FastAPI service that drafts multi-day travel itineraries using Google Vertex AI's Gemini models, enriches stops with Google Maps data, and persists results to Firestore. Features destination photo integration, advanced budget estimation, and comprehensive media proxy functionality.

## Stack & Architecture

- **FastAPI** application (`main.py`) with comprehensive CORS support and media proxy endpoints
- **Vertex AI Gemini 1.5 Flash** (`services/gemini.py`) generates intelligent multi-day itineraries with budget estimation
- **Google Maps Places API (New)** (`services/maps.py`) enriches activities with location data and destination photos
- **Cloud Firestore** (`services/store.py`) stores generated trips with metadata in a `trip` collection
- **Secret Manager** integration for secure API key management
- **Media Proxy** for secure image delivery without exposing API keys to frontend

## Prerequisites

- Python 3.11+
- Google Cloud project with Vertex AI, Firestore, and Secret Manager enabled
- Google Maps Places API key (with Places API and Places Photo API enabled)
- Service account key with permissions for the above services (use `GOOGLE_APPLICATION_CREDENTIALS`)

## Configuration

Environment variables (can be set locally or via Cloud Run/App Engine deployment):

| Variable | Purpose |
| --- | --- |
| `FIRESTORE_PROJECT` | GCP project ID used for Firestore and secrets (required) |
| `VERTEX_REGION` | Vertex AI region (defaults to `asia-south1`) |
| `MAPS_API_KEY_2` | Google Maps API key for new Places API (primary) |
| `MAPS_API_KEY` | Legacy Google Maps API key (fallback) |
| `GOOGLE_APPLICATION_CREDENTIALS` | Path to service-account JSON (local development) |
| `PLANGENIE_CORS_ORIGINS` | Comma-separated list of allowed origins for CORS |
| `PLANGENIE_CORS_REGEX` | Regex pattern for allowed origins (defaults to localhost) |
| `MAPS_API_REFERER` | Optional referer header for Maps API requests |
| `PLANGENIE_UPSTREAM_UA` | User agent for upstream requests |

### Secret Manager Configuration

The application automatically fetches API keys from Secret Manager if not provided via environment variables:
- `MAPS_API_KEY_2` (primary key for new Places API)
- `MAPS_API_KEY` (fallback key)

### Traveler Mood Configuration

| Value | Description | Activity Focus |
| --- | --- | --- |
| `1` | chill | Relaxed pace, cultural sites, cafes |
| `2` | balanced | Mix of activities, moderate pace |
| `3` | adventurous | Active experiences, exploration |
| `4` | party | Nightlife, social experiences, entertainment |

## Local Development

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export FIRESTORE_PROJECT=<your-project-id>
export MAPS_API_KEY_2=<maps-key>  # Primary key for new Places API
# Optional: export MAPS_API_KEY=<legacy-key>  # Fallback key
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json
uvicorn main:app --reload --port 8080
```

## Docker

```bash
docker build -t plangenie-backend .
docker run --rm -p 8080:8080 \
  -e FIRESTORE_PROJECT=<your-project-id> \
  -e MAPS_API_KEY_2=<maps-key> \
  -v /path/to/key.json:/app/key.json \
  -e GOOGLE_APPLICATION_CREDENTIALS=/app/key.json \
  plangenie-backend
```

## API Endpoints

### Core Endpoints

#### `GET /`
Health check endpoint.

**Response:**
```json
{
  "ok": true,
  "msg": "Planner API up. Use POST /plan"
}
```

#### `POST /plan`
Generates and stores a comprehensive multi-day itinerary with intelligent budget estimation and destination photos.

**Request Body:**
```json
{
  "origin": "DEL",
  "destination": "JAI",
  "startDate": "2024-08-01",
  "endDate": "2024-08-03",
  "pax": 2,
  "budget": 25000,
  "mood": 3
}
```

**Request Fields:**
- `origin`: Origin airport/city code
- `destination`: Destination city or location
- `startDate`: Trip start date (YYYY-MM-DD)
- `endDate`: Trip end date (YYYY-MM-DD)
- `pax`: Number of travelers
- `budget`: Budget in INR
- `mood`: Travel style (1=chill, 2=balanced, 3=adventurous, 4=party)

**Response:**
```json
{
  "tripId": "abc123def456",
  "draft": {
    "city": "Jaipur",
    "destinationBlurb": "Pink City's royal palaces, vibrant bazaars, and rich Rajasthani culture await exploration.",
    "imageUrl": "/media/destination?q=Jaipur",
    "total_budget": 24500,
    "days": [
      {
        "date": "2024-08-01",
        "blocks": [
          {
            "time": "10:00",
            "title": "City Palace Walk",
            "tag": "heritage",
            "place_id": "ChIJA7lKZ1YDbTkRYbej3wuLEu8",
            "lat": 26.9255,
            "lng": 75.8243
          },
          {
            "time": "13:00",
            "title": "Lunch at LMB",
            "tag": "food"
          },
          {
            "time": "18:00",
            "title": "Sound & Light at Amber Fort",
            "tag": "activity",
            "place_id": "ChIJ5-kdP1f2bTkRzSprOCzWuFo",
            "lat": 26.9855,
            "lng": 75.8513
          }
        ]
      }
    ]
  }
}
```

**Response Fields:**
- `tripId`: Unique identifier for the generated trip
- `draft.city`: Destination city name
- `draft.destinationBlurb`: Short description of the destination (≤140 chars)
- `draft.imageUrl`: Proxy URL for destination hero image
- `draft.total_budget`: AI-calculated total budget for the trip
- `draft.days[]`: Array of daily itineraries
- `draft.days[].blocks[]`: Individual activities with timing and location data

### Media Proxy Endpoints

#### `GET /media/destination?q={destination}`
Serves destination hero images via secure proxy (no API key exposure).

**Parameters:**
- `q`: Destination name

**Response:** Image stream with caching headers, or 404 if no image found.

#### `GET /media/places-photo?ref={photo_reference}&mw={max_width}`
Serves place photos via secure proxy using new Places API.

**Parameters:**
- `ref`: Photo reference from Places API
- `mw`: Maximum width in pixels (default: 1200)

**Response:** Image stream with caching headers.

### Debug Endpoints

#### `GET /debug/textsearch?q={query}`
Debug endpoint for testing Places Text Search API.

#### `GET /debug/photoref?q={query}&maxwidth={width}`
Debug endpoint for testing photo reference retrieval.

### Data Storage

All generated itineraries are automatically stored in Firestore with:
- Original preferences (including resolved mood label)
- Generated itinerary data
- `createdAt` timestamp
- Trip status and metadata

## Key Features

### 🧠 Intelligent Itinerary Generation
- **Multi-day Planning**: Generates comprehensive day-by-day itineraries covering the entire travel period
- **Mood-based Customization**: Tailors activities to traveler preferences (chill, balanced, adventurous, party)
- **Smart Activity Selection**: AI-curated activities with optimal timing and logical flow
- **Activity Categorization**: Heritage, food, activity, nightlife, adventure, and relax tags

### 💰 Advanced Budget Management
- **Dynamic Budget Calculation**: AI computes realistic trip costs based on actual itinerary content
- **Activity-based Pricing**: Uses tag-based pricing models for accurate cost estimation
- **Budget Optimization**: Attempts to stay within user budget while maximizing experience
- **Flight Cost Integration**: Includes estimated flight costs in total budget calculation

### 📍 Location Intelligence
- **Google Places Integration**: Enriches activities with real place IDs, coordinates, and location data
- **New Places API**: Uses latest Google Places API for enhanced accuracy and photo support
- **Fallback Strategies**: Multiple search strategies to maximize place discovery success rate
- **Coordinate Mapping**: Provides latitude/longitude for mapping and navigation integration

### 🖼️ Media Management
- **Destination Photos**: Automatically fetches high-quality destination images
- **Secure Media Proxy**: Serves images without exposing API keys to frontend
- **Multiple Photo Sources**: Searches multiple photo repositories for best image quality
- **Caching Strategy**: Implements caching headers for optimal performance
- **Fallback Handling**: Graceful degradation when photos are unavailable

### 🔐 Security & Configuration
- **Secret Manager Integration**: Secure API key management via Google Cloud Secret Manager
- **Environment Flexibility**: Supports both environment variables and Secret Manager
- **CORS Configuration**: Flexible CORS policy with regex and origin list support
- **Key Rotation Support**: Easy switching between API keys without downtime

## Sample Request & Response

### Complete Trip Planning Example

**Request:**
```bash
curl -X POST "http://localhost:8080/plan" \
  -H "Content-Type: application/json" \
  -d '{
    "origin": "BOM",
    "destination": "Goa",
    "startDate": "2024-12-15",
    "endDate": "2024-12-17",
    "pax": 2,
    "budget": 35000,
    "mood": 2
  }'
```

**Complete Response:**
```json
{
  "tripId": "xyz789abc123",
  "draft": {
    "city": "Goa",
    "destinationBlurb": "Golden beaches, Portuguese heritage, and vibrant nightlife make Goa India's coastal paradise.",
    "imageUrl": "/media/destination?q=Goa",
    "total_budget": 32400,
    "days": [
      {
        "date": "2024-12-15",
        "blocks": [
          {
            "time": "11:00",
            "title": "Basilica of Bom Jesus Visit",
            "tag": "heritage",
            "place_id": "ChIJ8a1Q2NZQK68RTZmjKKH1H8",
            "lat": 15.5007,
            "lng": 73.9114
          },
          {
            "time": "14:00",
            "title": "Seafood Lunch at Beach Shack",
            "tag": "food",
            "place_id": "ChIJ9a2P3OYQk68R7ZnkLLI2I9",
            "lat": 15.5527,
            "lng": 73.7622
          },
          {
            "time": "18:30",
            "title": "Sunset at Anjuna Beach",
            "tag": "relax",
            "place_id": "ChIJ1a3R4PQQL68R8ZnmMMJ3J0",
            "lat": 15.5735,
            "lng": 73.7440
          }
        ]
      },
      {
        "date": "2024-12-16",
        "blocks": [
          {
            "time": "09:30",
            "title": "Spice Plantation Tour",
            "tag": "activity",
            "place_id": "ChIJ2b4S5QRQM68R9ZonNNK4K1",
            "lat": 15.3004,
            "lng": 74.1378
          },
          {
            "time": "13:30",
            "title": "Traditional Goan Thali",
            "tag": "food"
          },
          {
            "time": "20:00",
            "title": "Casino Night at Deltin Royale",
            "tag": "nightlife",
            "place_id": "ChIJ3c5T6SRQN68R0ZpoPPL5L2",
            "lat": 15.5183,
            "lng": 73.8223
          }
        ]
      },
      {
        "date": "2024-12-17",
        "blocks": [
          {
            "time": "10:00",
            "title": "Old Goa Heritage Walk",
            "tag": "heritage",
            "place_id": "ChIJ4d6U7TRQO68R1ZqpQQM6M3",
            "lat": 15.5005,
            "lng": 73.9115
          },
          {
            "time": "13:00",
            "title": "Beach Side Brunch",
            "tag": "food"
          },
          {
            "time": "16:00",
            "title": "Shopping at Mapusa Market",
            "tag": "activity",
            "place_id": "ChIJ5e7V8URQP68R2ZrqRRN7N4",
            "lat": 15.5947,
            "lng": 73.8097
          }
        ]
      }
    ]
  }
}
```

### Media Proxy Examples

**Destination Image:**
```bash
curl "http://localhost:8080/media/destination?q=Goa"
# Returns: High-quality destination image with caching headers
```

**Debug Text Search:**
```bash
curl "http://localhost:8080/debug/textsearch?q=Baga Beach Goa"
# Returns: Raw Places API search results for debugging
```

**Debug Photo Reference:**
```bash
curl "http://localhost:8080/debug/photoref?q=Anjuna Beach&maxwidth=800"
# Returns: Photo reference and proxy URL information
```

## Testing & Monitoring

### Local Testing
```bash
# Test health endpoint
curl http://localhost:8080/

# Test plan generation
curl -X POST http://localhost:8080/plan \
  -H "Content-Type: application/json" \
  -d '{"origin":"DEL","destination":"JAI","startDate":"2024-08-01","endDate":"2024-08-03","pax":2,"budget":25000,"mood":2}'

# Test media proxy
curl "http://localhost:8080/media/destination?q=Jaipur"
```

### Production Considerations
- Implement automated tests using pytest + httpx for route testing
- Configure structured logging and Google Cloud Logging for production monitoring
- Set up error tracking and performance monitoring
- Monitor API key usage and costs
- Implement rate limiting for production deployments

## Deployment Notes

### Cloud Run Deployment
```bash
# Set environment variables
gcloud run deploy plangenie-backend \
  --set-env-vars FIRESTORE_PROJECT=your-project-id \
  --set-env-vars VERTEX_REGION=asia-south1 \
  --set-secrets MAPS_API_KEY_2=MAPS_API_KEY_2:latest

# Optional CORS configuration
gcloud run services update plangenie-backend \
  --set-env-vars PLANGENIE_CORS_ORIGINS=https://your-frontend-domain.com
```

### Secret Manager Setup
```bash
# Create secrets in Google Cloud Secret Manager
gcloud secrets create MAPS_API_KEY_2 --data-file=maps-key.txt
gcloud secrets create MAPS_API_KEY --data-file=legacy-maps-key.txt

# Grant access to service account
gcloud secrets add-iam-policy-binding MAPS_API_KEY_2 \
  --member="serviceAccount:your-service-account@project.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

### Prerequisites Checklist
- ✅ Google Cloud project with billing enabled
- ✅ Vertex AI API enabled
- ✅ Firestore database created
- ✅ Secret Manager API enabled
- ✅ Places API (new) enabled
- ✅ Service account with required permissions
- ✅ Maps API key with Places API and Places Photo API access
