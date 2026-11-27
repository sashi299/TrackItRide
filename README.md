# 🚌 TrackItRide — Smart College Bus Tracking System

A scalable, battery-optimized, and secure real-time campus transit tracking system engineered with **Flutter** and **Supabase (PostgreSQL)**.

---

## 📌 Architecture Overview

TrackItRide eliminates guesswork for campus commuters by streaming live bus telemetry directly from driver devices to students and dispatch administrators.

```
+-------------------------------------------------------------------------------+
|                             FLUTTER MOBILE CLIENTS                            |
|                                                                               |
|   [Student Portal]                  [Driver Console]         [Admin Console]  |
|   - Scoped Realtime Stream          - Foreground Service     - Route Setup    |
|   - Freshness & Signal Badge        - Sticky Notification    - Fleet Ops      |
|   - Tekkali Campus Geo              - Dead-Zone FIFO Buffer  - User Roles     |
+-------------------------------------------------------------------------------+
                                      ▲
                                      │ Supabase Realtime & PostgREST RPC
                                      ▼
+-------------------------------------------------------------------------------+
|                            SUPABASE CLOUD BACKEND                             |
|                                                                               |
|   - PostgreSQL with Row Level Security (RLS) on all tables                    |
|   - Atomic Telemetry RPC: record_driver_telemetry()                           |
|   - Batch Sync RPC: batch_sync_offline_telemetry()                            |
|   - Realtime Postgres Change Feeds (Filter: trip_id = eq.selected)            |
|   - Strict Role-Based Authentication & Session Management                     |
+-------------------------------------------------------------------------------+
```

---

## 🚀 Key Technical Features

### 1. Real-World Driver GPS Telemetry (Phase 3)
* **Android Foreground Service:** Runs with `FOREGROUND_SERVICE_LOCATION` and persistent sticky notifications so live broadcasting never halts when the driver's screen is locked or the app is minimized.
* **Telemetry Throttling & Cost Optimization:** Eliminates aggressive sub-second DB spam. Telemetry is throttled to **20 meters distance filter** and **8–10 seconds interval**, reducing database write costs by over 80%.
* **Atomic RPC:** Both location breadcrumbs (`trip_locations`) and active trip state (`trips`) are updated in a single atomic database RPC (`record_driver_telemetry`).
* **Offline Resiliency (Dead-Zone Buffering):** When a bus drives through areas with zero cellular reception, telemetry points are buffered locally into a persistent FIFO queue in `SharedPreferences`. The moment connectivity resumes, all buffered points sync atomically via `batch_sync_offline_telemetry`.

### 2. Student UX & Scoped Subscriptions (Phase 4)
* **Localized Campus Geo:** Default map coordinates centered on **Tekkali Campus (`18.5702, 84.1853`)**.
* **Scoped Real-Time Streaming:** Rather than flooding student devices with updates from every bus across the institution, students subscribe strictly to the bus/route they are actively tracking via `SupabaseService.streamTrip(tripId)`.
* **Telemetry Freshness & GPS Loss Warning:** Real-time visual status badges:
  * 🟢 **Live (<= 25s):** Displays speed and live updates (`Updated 4s ago`).
  * 🟡 **Signal Delay (26s - 60s):** Alerts student to network lag.
  * 🔴 **GPS Lost (> 60s):** Highlights signal loss (`⚠️ GPS Signal Lost - Last seen 2m ago`).
* **Strict Trip Lifecycle:** No fake dummy buses (`BUS-12`) or phantom markers. If a driver has not started the trip, the app displays: *"🚍 Bus has not started yet. Waiting for driver."*

### 3. Enterprise Security & Hardening (Phase 1 & 2)
* **Row Level Security (RLS):** Enabled across all database tables. Read-only for public student schedules; write access restricted strictly to verified drivers (`auth.uid() = driver_id`) and admins.
* **Keystore & Secret Isolation:** Keystores, signing passwords, and environment credentials are separated into `.gitignore` and `key.properties`.
* **Production R8/ProGuard:** Release builds are minified, obfuscated, and resource-shrunk for Play Store distribution.

---

## 🛠️ Tech Stack

* **Frontend:** Flutter 3.x, Dart 3.x
* **State & Networking:** `supabase_flutter: ^2.8.0`, `provider: ^6.1.1`
* **Maps & Geolocation:** `google_maps_flutter: ^2.5.3`, `geolocator: ^10.1.0`, `location: ^5.0.3`
* **Local Storage:** `shared_preferences: ^2.2.0`
* **Backend:** Supabase (PostgreSQL 15+, PostgREST, Supabase Auth, Supabase Realtime)
* **Package ID:** `com.cbts.transport`

---

## ⚙️ Setup & Installation

### 1. Prerequisites
* Flutter SDK (3.22.0 or higher)
* JDK 17
* Android Studio / Android SDK (Platform 34+)
* Supabase project with PostgREST and Realtime enabled

### 2. Configure Credentials
Create `android/key.properties` with your release signing keystore:
```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=cbts_release_key
storeFile=release.keystore
```

### 3. Build Production APK
```bash
flutter clean
flutter pub get
flutter build apk --release
```

The optimized, signed production APK will be generated at:
`build/app/outputs/flutter-apk/app-release.apk`

---

## 📜 Privacy & Compliance
TrackItRide handles real-time driver location data strictly during active assigned trips. For details on location permissions, background access, and data retention, see [PRIVACY_POLICY.md](PRIVACY_POLICY.md).
