# Phase 4 & 5: Student UX, Tekkali Scoping, Hygiene & Play Store Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Correct all campus coordinates to Tekkali (18.5702, 84.1853), scope real-time updates per selected trip with GPS recency badges, eliminate fake placeholder data, clean repo junk, rewrite documentation truthfully for Supabase + Flutter, update application ID to `com.cbts.transport`, and configure ProGuard/R8 release minification.

**Architecture:** Flutter frontend talking to Supabase PostgreSQL backend via real-time stream filters (`.eq('id', tripId)`). Android foreground location tracking service with R8/ProGuard obfuscation and resource shrinking. Tekkali geo-coordinates localized across map widgets and database seed migrations.

**Tech Stack:** Flutter 3.x, Dart 3.x, Supabase Flutter SDK (`supabase_flutter: ^2.8.0`), Google Maps Flutter (`google_maps_flutter: ^2.5.3`), Android Gradle Plugin with ProGuard/R8, PostgreSQL.

**Spec:** User Prompts for Phase 4 (Student UX, Location Correction & Fleet Scoping) and Phase 5 (Hygiene, Branding & Store Readiness).

## Global Constraints

- Backend must remain strictly Supabase.
- Mobile application package ID must be updated to `com.cbts.transport`.
- Preserves all UI and screen structures from the original TrackItRide GitHub design.
- ProGuard/R8 must retain all Flutter, Google Maps, Geolocator, and Supabase native interfaces without runtime crashing.
- Must verify release build with `flutter analyze` (0 errors) and `apksigner verify`.

## Review Focus

- App must not crash upon launch after R8 minification due to missing ProGuard reflection rules.
- Map camera must open centered on Tekkali (`18.5702, 84.1853`), never Bangalore.
- When bus trip has not been started by driver, student app must clearly show "Bus has not started yet" rather than an arbitrary marker.
- Signal loss warning must display accurately when `last_location_at` is older than 60 seconds.
- Single trip subscription must cancel prior subscriptions when student switches buses to prevent memory and network leaks.

---

### Task 1: College Geo-Coordinates Localization (Tekkali: 18.5702, 84.1853)

**Files:**
- Modify: `Smart_College_Bus_Tracking_System-TrackItRide-/lib/supabase_config.dart`
- Modify: `Smart_College_Bus_Tracking_System-TrackItRide-/lib/screens/student/student_location_screen.dart`
- Modify: `Smart_College_Bus_Tracking_System-TrackItRide-/lib/screens/driver/driver_dashboard_screen.dart`
- Modify: `Smart_College_Bus_Tracking_System-TrackItRide-/lib/screens/admin/admin_route_management_screen.dart`
- Create: `Smart_College_Bus_Tracking_System-TrackItRide-/supabase/migrations/20261109075500_phase4_tekkali_routes_seed.sql`

- [ ] Step 1: Add `defaultCampusLat = 18.5702` and `defaultCampusLng = 84.1853` to `lib/supabase_config.dart`.
- [ ] Step 2: Replace `LatLng(12.9716, 77.5946)` in `student_location_screen.dart` with Tekkali campus coordinates.
- [ ] Step 3: Replace Bangalore fallback in `driver_dashboard_screen.dart` with Tekkali coordinates.
- [ ] Step 4: Update hint placeholders in `admin_route_management_screen.dart` to `18.5702` and `84.1853`.
- [ ] Step 5: Author Supabase migration `20261109075500_phase4_tekkali_routes_seed.sql` with real campus stops (Tekkali Campus, Kotabommali, Palasa, Srikakulam).

---

### Task 2: Scoped Realtime Subscriptions & Freshness Indicator

**Files:**
- Modify: `Smart_College_Bus_Tracking_System-TrackItRide-/lib/services/supabase_service.dart`
- Modify: `Smart_College_Bus_Tracking_System-TrackItRide-/lib/screens/student/student_location_screen.dart`

- [ ] Step 1: Add `streamTrip(String tripId)` in `SupabaseService` scoped to `.eq('id', tripId)`.
- [ ] Step 2: Update `student_location_screen.dart` to cancel previous stream and subscribe only to selected trip.
- [ ] Step 3: Implement 1-second ticker calculating elapsed time from `last_location_at`.
- [ ] Step 4: Add UI badge displaying `Live • Updated Xs ago`, `Signal delay`, or `⚠️ GPS Signal Lost`.

---

### Task 3: Trip Lifecycle & Removing Fake Data

**Files:**
- Modify: `Smart_College_Bus_Tracking_System-TrackItRide-/lib/screens/student/student_location_screen.dart`
- Modify: `Smart_College_Bus_Tracking_System-TrackItRide-/lib/screens/driver/driver_login_screen.dart`
- Modify: `Smart_College_Bus_Tracking_System-TrackItRide-/lib/screens/driver/driver_dashboard_screen.dart`

- [ ] Step 1: Remove hardcoded `'BUS-12'` and placeholder assignments.
- [ ] Step 2: Guard bus marker rendering: only display moving bus pin if `trip['status'] == 'running'` and coordinates are valid.
- [ ] Step 3: When trip is not running, display "Bus has not started yet. Waiting for driver to start the trip."

---

### Task 4: Repo Bloat Cleanup & Honest Documentation (Phase 5.1 & 5.2)

**Files:**
- Delete: `Smart_College_Bus_Tracking_System-TrackItRide-/flutter_01.log`
- Delete: `Smart_College_Bus_Tracking_System-TrackItRide-/flutter_03.png`
- Delete: `Smart_College_Bus_Tracking_System-TrackItRide-/flutter_04.png`
- Rewrite: `Smart_College_Bus_Tracking_System-TrackItRide-/README.md`
- Create: `Smart_College_Bus_Tracking_System-TrackItRide-/PRIVACY_POLICY.md`

- [ ] Step 1: Delete `flutter_01.log`, 0-byte images, and verify no orphan build artifacts are tracked in git.
- [ ] Step 2: Rewrite `README.md` with true Supabase + Flutter architecture, background service details, and setup guide.
- [ ] Step 3: Create Play Store compliant `PRIVACY_POLICY.md` detailing background location disclosure for drivers and students.

---

### Task 5: Production Identity, ProGuard/R8 & Release Build (Phase 5.3)

**Files:**
- Modify: `Smart_College_Bus_Tracking_System-TrackItRide-/android/app/build.gradle`
- Create: `Smart_College_Bus_Tracking_System-TrackItRide-/android/app/proguard-rules.pro`

- [ ] Step 1: Change `applicationId` to `com.cbts.transport` in `android/app/build.gradle`.
- [ ] Step 2: Create `android/app/proguard-rules.pro` with keep rules for Flutter, Geolocator, Google Maps, and Supabase.
- [ ] Step 3: Configure `minifyEnabled true`, `shrinkResources true`, and `proguardFiles` in `build.gradle`.
- [ ] Step 4: Run `flutter analyze` and ensure 0 errors.
- [ ] Step 5: Build release APK and verify with `apksigner verify --print-certs`.
- [ ] Step 6: Deploy final production APK to `C:\Users\hp\Downloads\trackitride-production.apk`.
