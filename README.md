# SpotShare

SpotShare is a mobile community discovery and map-sharing application for independent travelers to share beaches, scenic spots, viewpoints, cafes, and local food with practical travel tags (best time to visit, transport options, and estimated price range).

Built with **Flutter (Dart)**, **Riverpod**, **GoRouter**, **Material Design 3**, **Firebase** (Authentication, Cloud Firestore, Cloud Messaging), **Cloudinary**, **Flutter Map (OpenStreetMap)**, and **Google Gemini API**.

---

## 🏗️ Project Architecture (Feature-First)

```text
lib/
├── core/                  # App theme, router, main shell, shared services (Cloudinary, OSM), helpers
└── features/
    ├── auth/              # Sign in, sign up, password reset, session state
    ├── profile/           # User profile, unique @username handle, edit profile, follow, user spot grids
    ├── explore/           # Explore feed, trending/newest sorting, search spots & @username users
    ├── spots/             # Create, view detail, edit, delete spots & dynamic categories/quick tags
    ├── social/            # Likes, collections/saved spots, star ratings & reviews
    ├── map/               # Interactive map & category markers
    ├── ai/                # Gemini AI description & trip itinerary assistant
    └── notifications/     # Inbox & push notifications
```

---

## 📋 Prerequisites

Before cloning and running SpotShare, make sure your environment meets the following requirements:

1. **Git**: Installed and configured on your machine.
2. **Flutter SDK**: `3.24+` (Dart `3.5+`). Added to your system `PATH`.
   - Verify installation:
     ```bash
     flutter --version
     flutter doctor
     ```
3. **IDE & Target Device**:
   - **Android**: Android Studio or VS Code with Flutter & Dart extensions installed. Requires an Android emulator or a physical Android device (Android 8.0 / API 26+, 3GB+ RAM) with USB debugging enabled.
   - **Web (Fast UI Testing)**: Microsoft Edge or Google Chrome.
4. **Internet Connection**: Active network connection required for Firebase, Cloudinary image upload/CDN, OpenStreetMap tiles, and Gemini API.
5. **Environment & Firebase Config Files**:
   - `.env` file (copied from `.env.example`) containing API keys.
   - `android/app/google-services.json` required for Android Firebase integration.

---

## 🚀 Quick Start Guide

### 1. Clone the Repository
```bash
git clone https://github.com/Keywords2dr/spotshare.git
cd spotshare
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Setup Environment Variables & Configurations
1. Copy `.env.example` to `.env` in the project root:
   - **Windows (PowerShell):**
     ```powershell
     Copy-Item ".env.example" ".env"
     ```
   - **macOS / Linux / Git Bash:**
     ```bash
     cp .env.example .env
     ```
2. Open `.env` and fill in the required secret values provided by the team lead:
   ```env
   CLOUDINARY_CLOUD_NAME=your_cloud_name
   CLOUDINARY_UPLOAD_PRESET=your_unsigned_upload_preset
   GEMINI_API_KEY=your_gemini_api_key
   ```
3. Place `google-services.json` inside the `android/app/` directory.

### 4. Run the Application
- **Check connected devices:**
  ```bash
  flutter devices
  ```
- **Run on connected Android device or emulator:**
  ```bash
  flutter run
  ```
- **Run on Browser (Edge / Chrome) for fast UI testing:**
  ```bash
  flutter run -d edge
  ```

### 5. Code Quality Check
```bash
dart analyze
```

---

## 🔐 Environment Variables (.env)

| Variable | Description |
|---|---|
| `CLOUDINARY_CLOUD_NAME` | Cloudinary account cloud name for image media storage |
| `CLOUDINARY_UPLOAD_PRESET` | Unsigned upload preset for direct mobile image uploads |
| `GEMINI_API_KEY` | Google Gemini API Key for AI description & itinerary features |

---

## 🛠️ Tech Stack & Key Libraries

- **Framework:** Flutter 3.24+ (Dart 3.5+)
- **State Management & Routing:** Riverpod, GoRouter
- **Backend & Database:** Firebase Auth, Cloud Firestore, Firebase Cloud Messaging (FCM)
- **Image Processing & CDN:** Cloudinary API (Unsigned Uploads + WebP transformation)
- **Map & Geolocation:** Flutter Map (OpenStreetMap), Geolocator
- **AI Integration:** Google Gemini API (`gemini-2.5-flash`)