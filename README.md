<p align="center">
  <img src="assets/PlanGenie.png" alt="PlanGenie screenshot" width="600" />
</p>

# PlanGenie - AI-Powered Travel Planning Platform

**PlanGenie** is an intelligent travel planning platform that leverages AI to create personalized, multi-day itineraries with real-time pricing, location intelligence, and seamless booking experiences. Built for modern travelers who want smart, comprehensive trip planning without the hassle.

## ✨ Key Features

### 🤖 **AI-Powered Itinerary Generation**
- **Multi-day Planning**: Comprehensive day-by-day itineraries covering your entire travel period
- **Mood-based Customization**: Tailored experiences based on travel style (Chill, Balanced, Adventurous, Party)
- **Smart Activity Selection**: AI-curated activities with optimal timing and logical flow
- **Budget Intelligence**: Dynamic cost calculation and optimization within your budget

### 🗺️ **Location Intelligence & Maps Integration**
- **Google Places Integration**: Real place IDs, coordinates, and location data for every activity
- **Destination Photos**: High-quality images for destinations and activities
- **Interactive Maps**: Visual representation of your itinerary with precise locations
- **Route Optimization**: Smart sequencing of activities for efficient travel

### 🔐 **Authentication & User Management**
- **Firebase Authentication**: Secure sign-in/sign-up with email and social providers
- **User Profiles**: Personalized travel preferences and history
- **Trip Storage**: Persistent storage of generated itineraries in Firestore

### 💰 **Advanced Budget Management**
- **Real-time Cost Calculation**: AI computes realistic trip costs based on actual itinerary
- **Activity-based Pricing**: Tag-based pricing models for accurate estimation
- **Flight Cost Integration**: Includes transportation costs in total budget
- **Budget Optimization**: Maximizes experience while staying within limits

### 🏗️ **Production-Ready Architecture**
- **Scalable Backend**: FastAPI with Google Cloud integration (Vertex AI, Firestore, Secret Manager)
- **Cross-Platform Client**: Flutter app supporting iOS, Android, and Web
- **Secure Media Proxy**: Image delivery without API key exposure
- **Cloud Deployment**: Ready for Google Cloud Run with automated scaling

## 📁 Repository Structure

| Directory | Description | Technology Stack |
|-----------|-------------|------------------|
| **`backend/`** | Production FastAPI service | Python, FastAPI, Vertex AI, Firestore |
| **`flutter-app/`** | Cross-platform mobile & web client | Flutter, Dart, Firebase Auth |
| **`mockup/`** | Interactive React prototype | React, Vite, Tailwind CSS |
| **`mockup-next/`** | Production-ready Next.js prototype | Next.js 14, TypeScript, Tailwind |
| **`assets/`** | Visual assets and architecture diagrams | PNG, Documentation |

## 🚀 Quick Start

### Prerequisites
- **Node.js 18+** (for web prototypes)
- **Flutter 3.16+** (for mobile app)
- **Python 3.11+** (for backend)
- **Google Cloud Account** (for deployment)

### 1. Interactive Mockups (Fastest Start)

**React + Vite Mockup:**
```bash
cd mockup
npm install
npm run dev
# Open http://localhost:5173
```

**Next.js Prototype:**
```bash
cd mockup-next
npm install
npm run dev
# Open http://localhost:3000
```

### 2. Full-Stack Development

**Backend Setup:**
```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export FIRESTORE_PROJECT=<your-project-id>
export MAPS_API_KEY_2=<your-maps-key>
uvicorn main:app --reload --port 8080
```

**Flutter App:**
```bash
cd flutter-app
flutter pub get
flutter run --dart-define=PLANGENIE_API_BASE_URL=http://127.0.0.1:8080
```

## 🏗️ System Architecture

PlanGenie follows a modern, cloud-native architecture:

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Flutter App   │    │   FastAPI        │    │  Google Cloud   │
│   (iOS/Android/ │◄──►│   Backend        │◄──►│   Services      │
│    Web)         │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
│                      │                       │
│ • Firebase Auth      │ • AI Itinerary Gen    │ • Vertex AI
│ • Trip Display       │ • Maps Integration    │ • Firestore
│ • User Interface     │ • Media Proxy         │ • Secret Manager
│ • State Management   │ • CORS Handling       │ • Cloud Run
└──────────────────────┴───────────────────────┴─────────────────┘
```

## 📚 Detailed Documentation

### Core Components
- **[Backend API Documentation](./backend/README.md)** - Complete FastAPI service setup, endpoints, and deployment
- **[Flutter App Guide](./flutter-app/README.md)** - Mobile/web client setup, Firebase integration, and development
- **[React Mockup](./mockup/README.md)** - Interactive prototype for rapid UI iteration
- **[Next.js Prototype](./mockup-next/README.md)** - Production-ready app structure exploration

### Setup & Configuration
- **[Firebase Setup Guide](./FIREBASE_SETUP.md)** - Step-by-step Firebase configuration for new developers
- **[Contributing Guidelines](./CONTRIBUTING.md)** - Code standards, review process, and development workflow

### Infrastructure
- **[Deployment Script](./infra.sh)** - Google Cloud infrastructure setup and deployment automation

## 🎨 Visual Assets & Design

The `assets/` directory contains high-fidelity visuals showcasing the complete user experience:

| Asset | Description |
|-------|-------------|
| `AI Trip Planner Mockup (AI).png` | Landing screen with AI-powered destination discovery |
| `AI Trip Planner Mockup (Cart).png` | Booking cart with pricing and upgrade options |
| `AI Trip Planner Mockup (Itinerary).png` | Day-by-day itinerary view |
| `Basic_FlowChart.png` | High-level user journey and decision points |
| `Core-Booking-Flow.png` | Detailed reservation funnel from search to checkout |
| `System_Architecture(High-Level).png` | Complete architecture with data sources and AI components |

## 🔧 API Capabilities

### Core Endpoints
- **`POST /plan`** - Generate comprehensive multi-day itineraries with budget optimization
- **`GET /media/destination`** - Secure destination image proxy
- **`GET /media/places-photo`** - Places API photo proxy
- **Debug endpoints** for development and testing

### Sample API Response
```json
{
  "tripId": "abc123def456",
  "draft": {
    "city": "Jaipur",
    "destinationBlurb": "Pink City's royal palaces, vibrant bazaars, and rich culture.",
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
          }
        ]
      }
    ]
  }
}
```

## 🔒 Security & Best Practices

- **Secret Management**: API keys stored in Google Cloud Secret Manager
- **CORS Protection**: Configurable origin policies for browser security
- **Media Proxy**: Secure image delivery without API key exposure
- **Firebase Rules**: Secure data access with authentication
- **Environment Isolation**: Separate configs for development, staging, and production

## 🚀 Deployment Options

### Development
- Local development servers with hot reload
- Docker containers for isolated testing
- Firebase emulators for offline development

### Production
- **Google Cloud Run**: Serverless, auto-scaling backend deployment
- **Firebase Hosting**: Static web app hosting with CDN
- **Google Play Store / App Store**: Native mobile app distribution

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](./CONTRIBUTING.md) for:
- Code standards and formatting requirements
- Pull request process and review criteria
- Development workflow and branching strategy
- Quality assurance and testing requirements

## 📄 License

This project was created for educational and demonstration purposes. Please ensure you have proper API keys and permissions for Google Cloud services when deploying.

## 🔗 Quick Links

- [🔧 Backend Setup Guide](./backend/README.md)
- [📱 Flutter App Setup](./flutter-app/README.md)
- [🔥 Firebase Configuration](./FIREBASE_SETUP.md)
- [🤝 Contributing Guide](./CONTRIBUTING.md)
- [🎨 Interactive React Demo](./mockup/README.md)
- [⚡ Next.js Prototype](./mockup-next/README.md)

---

**Ready to start planning your next adventure with AI? Choose your path above and get started in minutes!** ✈️
