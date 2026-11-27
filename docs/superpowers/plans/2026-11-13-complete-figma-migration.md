# TrackItRide – Complete Figma UI Migration Implementation Plan (System 1.0)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (or subagent-driven-development) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the 100% migration of all 32 Flutter application screens to match the user's original Figma design (**TrackItRide – System 1.0**, 116 artboard frames) as the single source of truth, preserving all existing Supabase integrations, authentication logic, database RPC calls, and responsive layouts before running Playwright Phase 2 E2E tests.

**Architecture:** Maintain the existing Flutter Web and Android framework, using the established System 1.0 design tokens (`AppTheme`, `AppColors`, `StatusChip`, `CustomButton`, `CustomTextField`). Replace legacy duplicate Material UI components in batches with exact Figma visual layouts, incorporating Figma loading, empty, error, and offline frames as contextual state variants.

**Tech Stack:** Flutter 3.44.0, Dart 3.10+, Supabase Cloud PostgreSQL, OpenStreetMap (`flutter_map` ^7.0.2 + `latlong2` ^0.9.1), Figma MCP.

**Spec:** Figma File Key `1wvgAh67xxtJxw27aV8w02` (*TrackItRide – System 1.0*).

## Global Constraints
- **Framework:** Preserve Flutter completely (do not migrate to React, Next.js, or HTML/JS).
- **Backend & DB:** Zero changes to production Supabase schemas, tables, RLS policies, or auth settings.
- **Design Source of Truth:** Original Figma file `1wvgAh67xxtJxw27aV8w02` is the only design reference.
- **Design Tokens:** Primary Maroon `#800000`, Subtle Maroon `#FFF1F2`, Live Marker Amber `#F59E0B`, Background `#F8FAFC`, Surface `#FFFFFF`, Border `#E2E8F0`, Text `#0F172A`, Muted Text `#475569`.
- **Geometry:** 12px control corner radius, 48px touch targets, 16px horizontal screen padding.
- **Code Quality:** Zero errors and zero warnings under `flutter analyze lib/`.
- **Execution Rule:** READ-ONLY VALIDATION ONLY until Phase C approval.

---

# Complete Verified 116 Figma Frame Inventory & Mapping

| # | Module | Exact Figma Frame Name | Figma ID | Dimensions | Target Flutter Screen | Type | Migration Status |
|---|---|---|---|---|---|---|---|
| 1 | Design Foundations | `00 · Start here` | `2:85` | 390x844 | `lib/shared/ (theme/tokens/atoms)` | Foundation Token Spec | Already migrated |
| 2 | Design Foundations | `01 · Light palette` | `2:89` | 390x844 | `lib/shared/ (theme/tokens/atoms)` | Foundation Token Spec | Already migrated |
| 3 | Design Foundations | `02 · Dark palette` | `2:93` | 390x844 | `lib/shared/ (theme/tokens/atoms)` | Foundation Token Spec | Already migrated |
| 4 | Design Foundations | `03 · Type & rhythm` | `2:97` | 390x844 | `lib/shared/ (theme/tokens/atoms)` | Foundation Token Spec | Already migrated |
| 5 | Design Foundations | `04 · Buttons` | `2:101` | 390x844 | `lib/shared/ (theme/tokens/atoms)` | Foundation Token Spec | Already migrated |
| 6 | Design Foundations | `05 · Fields & search` | `2:105` | 390x844 | `lib/shared/ (theme/tokens/atoms)` | Foundation Token Spec | Already migrated |
| 7 | Design Foundations | `06 · Transit patterns` | `2:109` | 390x844 | `lib/shared/ (theme/tokens/atoms)` | Foundation Token Spec | Already migrated |
| 8 | Design Foundations | `07 · Status language` | `2:113` | 390x844 | `lib/shared/ (theme/tokens/atoms)` | Foundation Token Spec | Already migrated |
| 9 | Design Foundations | `08 · Navigation` | `2:117` | 390x844 | `lib/shared/ (theme/tokens/atoms)` | Foundation Token Spec | Already migrated |
| 10 | Design Foundations | `09 · Sheets & dialogs` | `2:121` | 390x844 | `lib/shared/ (theme/tokens/atoms)` | Foundation Token Spec | Already migrated |
| 11 | Design Foundations | `10 · Feedback states` | `2:125` | 390x844 | `lib/shared/ (theme/tokens/atoms)` | Foundation Token Spec | Already migrated |
| 12 | Design Foundations | `11 · Icon library` | `2:129` | 390x844 | `lib/shared/ (theme/tokens/atoms)` | Foundation Token Spec | Already migrated |
| 13 | Design Specs | `12 · Student · Home` | `2:133` | 390x844 | `student_home_screen.dart` | Design Reference Showcase | Already migrated |
| 14 | Design Specs | `13 · Driver · Trip` | `2:134` | 390x844 | `driver_dashboard_screen.dart` | Design Reference Showcase | Already migrated |
| 15 | Design Specs | `14 · Admin · Overview` | `2:135` | 390x844 | `admin_dashboard_screen.dart` | Design Reference Showcase | Pending |
| 16 | Design Specs | `15 · Student · Dark` | `2:136` | 390x844 | `theme.dart (dark mode)` | Design Reference Showcase | Pending |
| 17 | Driver Console | `01 · Driver login` | `2:1668` | 390x844 | `driver_login_screen.dart` | Primary Screen | Already migrated |
| 18 | Driver Console | `02 · Driver sign up` | `2:1669` | 390x844 | `driver_signup_screen.dart` | Primary Screen | Pending |
| 19 | Driver Console | `03 · Email confirmation` | `2:1670` | 390x844 | `driver_forgot_password_screen.dart` | Primary Screen (Password Reset) | Pending |
| 20 | Driver Console | `04 · Pending approval` | `2:1671` | 390x844 | `driver_login_screen.dart` | UI State Variant (Approval pending banner) | Pending State |
| 21 | Driver Console | `05 · Select your bus` | `2:1672` | 390x844 | `driver_select_bus_screen.dart` | Primary Screen (Fleet selector) | Already migrated |
| 22 | Driver Console | `06 · Search focused` | `2:1673` | 390x844 | `driver_select_bus_screen.dart` | UI State Variant (Active bus search) | Already migrated |
| 23 | Driver Console | `07 · Buses loading` | `2:1674` | 390x844 | `driver_select_bus_screen.dart` | UI State Variant (Bus grid loading) | Pending State |
| 24 | Driver Console | `08 · No matching bus` | `2:1675` | 390x844 | `driver_select_bus_screen.dart` | UI State Variant (No matching buses) | Pending State |
| 25 | Driver Console | `09 · Bus list error` | `2:1676` | 390x844 | `driver_select_bus_screen.dart` | UI State Variant (Bus fetch error) | Pending State |
| 26 | Driver Console | `10 · Confirm bus 112` | `2:1677` | 390x844 | `driver_select_bus_screen.dart` | UI Modal / Sheet (Confirm bus claim) | Already migrated |
| 27 | Driver Console | `11 · Console ready` | `2:1678` | 390x844 | `driver_dashboard_screen.dart` | Primary Screen (Console ready / pre-trip) | Already migrated |
| 28 | Driver Console | `12 · Trip running` | `2:1679` | 390x844 | `driver_dashboard_screen.dart` | Primary Screen (Live trip running) | Already migrated |
| 29 | Driver Console | `13 · Network issue` | `2:1680` | 390x844 | `driver_dashboard_screen.dart` | UI State Variant (Network reconnect warning) | Pending State |
| 30 | Driver Console | `14 · Location permission` | `2:1681` | 390x844 | `driver_dashboard_screen.dart` | UI Modal / Dialog (Location permission prompt) | Pending State |
| 31 | Driver Console | `15 · Route schedule` | `2:1682` | 390x844 | `driver_route_overview_screen.dart` | Primary Screen (Route schedule & waypoints) | Pending |
| 32 | Driver Console | `16 · Driver profile` | `2:1683` | 390x844 | `driver_profile_screen.dart` | Primary Screen (Driver profile & vehicle) | Pending |
| 33 | Driver Console | `17 · Change bus` | `2:1684` | 390x844 | `driver_dashboard_screen.dart` | UI Modal / Sheet (Change bus dialog) | Already migrated |
| 34 | Driver Console | `18 · Driver feedback` | `2:1685` | 390x844 | `driver_view_feedback_screen.dart` | Primary Screen (Feedback view) | Pending |
| 35 | Student / Commuter | `S01 · Student login` | `7:1532` | 390x844 | `student_login_screen.dart` | Primary Screen | Already migrated |
| 36 | Student / Commuter | `S02 · Student sign up` | `7:1533` | 390x844 | `student_signup_screen.dart` | Primary Screen | Already migrated |
| 37 | Student / Commuter | `S03 · Confirm your email` | `7:1534` | 390x844 | `student_forgot_password_screen.dart` | Primary Screen (Password Reset) | Pending |
| 38 | Student / Commuter | `S04 · Home · LIVE` | `7:1535` | 390x844 | `student_home_screen.dart` | Primary Screen (Live Trip) | Already migrated |
| 39 | Student / Commuter | `S05 · Home · Not running` | `7:1536` | 390x844 | `student_home_screen.dart` | UI State Variant (Not running) | Pending State |
| 40 | Student / Commuter | `S06 · Home · Loading` | `7:1537` | 390x844 | `student_home_screen.dart` | UI State Variant (Loading skeleton) | Pending State |
| 41 | Student / Commuter | `S07 · Home · No favorite` | `7:1538` | 390x844 | `student_home_screen.dart` | UI State Variant (No bus assigned) | Pending State |
| 42 | Student / Commuter | `S08 · Home · Offline` | `7:1539` | 390x844 | `student_home_screen.dart` | UI State Variant (Offline network banner) | Pending State |
| 43 | Student / Commuter | `S09 · Home · Error` | `7:1540` | 390x844 | `student_home_screen.dart` | UI State Variant (Error banner) | Pending State |
| 44 | Student / Commuter | `S10 · Tracking · LIVE` | `7:1541` | 390x844 | `student_location_screen.dart` | Primary Screen (Live Map & Arrival) | Already migrated |
| 45 | Student / Commuter | `S11 · Tracking · Delayed` | `7:1542` | 390x844 | `student_location_screen.dart` | UI State Variant (Delayed badge) | Pending State |
| 46 | Student / Commuter | `S12 · Tracking · Signal lost` | `7:1543` | 390x844 | `student_location_screen.dart` | UI State Variant (Signal lost badge) | Pending State |
| 47 | Student / Commuter | `S13 · Tracking · Not running` | `7:1544` | 390x844 | `student_location_screen.dart` | UI State Variant (Trip inactive) | Pending State |
| 48 | Student / Commuter | `S14 · Tracking · Loading` | `7:1545` | 390x844 | `student_location_screen.dart` | UI State Variant (Map loading) | Pending State |
| 49 | Student / Commuter | `S15 · Tracking · No results` | `7:1546` | 390x844 | `student_search_screen.dart` | Primary Screen & State (No search results) | Pending |
| 50 | Student / Commuter | `S16 · Tracking · Offline` | `7:1547` | 390x844 | `student_location_screen.dart` | UI State Variant (Offline map cache) | Pending State |
| 51 | Student / Commuter | `S17 · Tracking · Error` | `7:1548` | 390x844 | `student_location_screen.dart` | UI State Variant (GPS error) | Pending State |
| 52 | Student / Commuter | `S18 · Routes · Expanded` | `7:1549` | 390x844 | `student_routes_screen.dart` | Primary Screen (Routes & Stops list) | Pending |
| 53 | Student / Commuter | `S19 · Routes · Loading stops` | `7:1550` | 390x844 | `student_routes_screen.dart` | UI State Variant (Stops loading) | Pending State |
| 54 | Student / Commuter | `S20 · Routes · No results` | `7:1551` | 390x844 | `student_routes_screen.dart` | UI State Variant (No routes found) | Pending State |
| 55 | Student / Commuter | `S21 · Routes · Offline` | `7:1552` | 390x844 | `student_routes_screen.dart` | UI State Variant (Offline routes cache) | Pending State |
| 56 | Student / Commuter | `S22 · Routes · Error` | `7:1553` | 390x844 | `student_routes_screen.dart` | UI State Variant (Route fetch error) | Pending State |
| 57 | Student / Commuter | `S23 · Notifications` | `7:1554` | 390x844 | `student_notifications_screen.dart` | Primary Screen (Announcements & Alerts) | Pending |
| 58 | Student / Commuter | `S24 · Notifications · Loading` | `7:1555` | 390x844 | `student_notifications_screen.dart` | UI State Variant (Notifications loading) | Pending State |
| 59 | Student / Commuter | `S25 · Notifications · Empty` | `7:1556` | 390x844 | `student_notifications_screen.dart` | UI State Variant (Empty notification inbox) | Pending State |
| 60 | Student / Commuter | `S26 · Notifications · Offline` | `7:1557` | 390x844 | `student_notifications_screen.dart` | UI State Variant (Offline notifications) | Pending State |
| 61 | Student / Commuter | `S27 · Notifications · Error` | `7:1558` | 390x844 | `student_notifications_screen.dart` | UI State Variant (Notifications error) | Pending State |
| 62 | Student / Commuter | `S28 · Feedback` | `7:1559` | 390x844 | `student_feedback_screen.dart` | Primary Screen (Student feedback form) | Pending |
| 63 | Student / Commuter | `S29 · Feedback · Sent` | `7:1560` | 390x844 | `student_feedback_screen.dart` | UI State Variant (Feedback submitted success) | Pending State |
| 64 | Student / Commuter | `S30 · Profile · English` | `7:1561` | 390x844 | `student_profile_screen.dart` | Primary Screen (Commuter profile) | Already migrated |
| 65 | Student / Commuter | `S31 · Profile · Telugu` | `7:1562` | 390x844 | `student_profile_screen.dart` | UI State Variant (Telugu language toggle) | Already migrated |
| 66 | Admin Desktop (1440x900) | `AD01 · Admin login` | `12:3350` | 1440x900 | `admin_login_screen.dart` | Desktop Responsive Variant | Already migrated |
| 67 | Admin Desktop (1440x900) | `AD02 · Dashboard` | `12:3351` | 1440x900 | `admin_dashboard_screen.dart` | Desktop Responsive Variant | Pending |
| 68 | Admin Desktop (1440x900) | `AD03 · Buses` | `12:3352` | 1440x900 | `admin_manage_buses_screen.dart` | Desktop Responsive Variant | Pending |
| 69 | Admin Desktop (1440x900) | `AD04 · Edit bus` | `12:3353` | 1440x900 | `admin_bus_edit_screen.dart` | Desktop Responsive Variant | Pending |
| 70 | Admin Desktop (1440x900) | `AD05 · Drivers` | `12:3354` | 1440x900 | `admin_manage_drivers_screen.dart` | Desktop Responsive Variant | Pending |
| 71 | Admin Desktop (1440x900) | `AD06 · Routes & Stops` | `12:3355` | 1440x900 | `admin_route_management_screen.dart` | Desktop Responsive Variant | Pending |
| 72 | Admin Desktop (1440x900) | `AD07 · Add stop` | `12:3356` | 1440x900 | `admin_route_management_screen.dart` | Desktop Responsive Variant | Pending |
| 73 | Admin Desktop (1440x900) | `AD08 · Assign bus override` | `12:3357` | 1440x900 | `assign_bus_route_screen.dart` | Desktop Responsive Variant | Pending |
| 74 | Admin Desktop (1440x900) | `AD09 · Announcements` | `12:3358` | 1440x900 | `admin_analytics_screen.dart` | Desktop Responsive Variant | Pending |
| 75 | Admin Desktop (1440x900) | `AD10 · Feedback inbox` | `12:3359` | 1440x900 | `admin_view_feedback_screen.dart` | Desktop Responsive Variant | Pending |
| 76 | Admin Desktop (1440x900) | `AD11 · Analytics` | `12:3360` | 1440x900 | `admin_analytics_screen.dart` | Desktop Responsive Variant | Pending |
| 77 | Admin Desktop (1440x900) | `AD12 · Import CSV preview` | `12:3361` | 1440x900 | `admin_manage_buses_screen.dart` | Desktop Responsive Variant | Pending |
| 78 | Admin Desktop (1440x900) | `AD13 · Delete bus confirmation` | `12:3362` | 1440x900 | `admin_manage_buses_screen.dart` | Desktop Responsive Variant | Pending |
| 79 | Admin Desktop (1440x900) | `AD14 · Release driver confirmation` | `12:3363` | 1440x900 | `admin_manage_drivers_screen.dart` | Desktop Responsive Variant | Pending |
| 80 | Admin Desktop (1440x900) | `AD15 · Reject driver confirmation` | `12:3364` | 1440x900 | `admin_manage_drivers_screen.dart` | Desktop Responsive Variant | Pending |
| 81 | Admin Desktop (1440x900) | `AD16 · Buses loading` | `12:3365` | 1440x900 | `admin_manage_buses_screen.dart` | Desktop Responsive Variant | Pending |
| 82 | Admin Desktop (1440x900) | `AD17 · Buses empty` | `12:3366` | 1440x900 | `admin_manage_buses_screen.dart` | Desktop Responsive Variant | Pending |
| 83 | Admin Desktop (1440x900) | `AD18 · Buses error` | `12:3367` | 1440x900 | `admin_manage_buses_screen.dart` | Desktop Responsive Variant | Pending |
| 84 | Admin Desktop (1440x900) | `AD19 · Add bus` | `12:3368` | 1440x900 | `admin_register_bus_screen.dart` | Desktop Responsive Variant | Pending |
| 85 | Admin Mobile | `AM01 · Admin login` | `12:3369` | 390x844 | `admin_login_screen.dart` | Primary Screen | Already migrated |
| 86 | Admin Mobile | `AM02 · Dashboard` | `12:3370` | 390x844 | `admin_dashboard_screen.dart` | Primary Screen (Operations console) | Pending |
| 87 | Admin Mobile | `AM03 · Buses` | `12:3371` | 390x844 | `admin_manage_buses_screen.dart` | Primary Screen (Bus fleet roster) | Pending |
| 88 | Admin Mobile | `AM04 · Edit bus` | `12:3372` | 390x844 | `admin_bus_edit_screen.dart` | Primary Screen (Edit bus details) | Pending |
| 89 | Admin Mobile | `AM05 · Drivers` | `12:3373` | 390x844 | `admin_manage_drivers_screen.dart` | Primary Screen (Driver roster & verification) | Pending |
| 90 | Admin Mobile | `AM06 · Routes & Stops` | `12:3374` | 390x844 | `admin_route_management_screen.dart` | Primary Screen (Routes & stops manager) | Pending |
| 91 | Admin Mobile | `AM07 · Add stop` | `12:3375` | 390x844 | `admin_route_management_screen.dart` | UI Modal (Add stop waypoint) | Pending |
| 92 | Admin Mobile | `AM08 · Assign bus override` | `12:3376` | 390x844 | `assign_bus_route_screen.dart` | Primary Screen (Assign bus override) | Pending |
| 93 | Admin Mobile | `AM09 · Announcements` | `12:3377` | 390x844 | `admin_analytics_screen.dart` | Primary Screen (Announcements broadcast) | Pending |
| 94 | Admin Mobile | `AM10 · Feedback inbox` | `12:3378` | 390x844 | `admin_view_feedback_screen.dart` | Primary Screen (Feedback inbox) | Pending |
| 95 | Admin Mobile | `AM11 · Analytics` | `12:3379` | 390x844 | `admin_analytics_screen.dart` | Primary Screen (Fleet analytics) | Pending |
| 96 | Admin Mobile | `AM12 · Import CSV preview` | `12:3380` | 390x844 | `admin_manage_buses_screen.dart` | UI Modal (Import CSV preview) | Pending |
| 97 | Admin Mobile | `AM13 · Delete bus confirmation` | `12:3381` | 390x844 | `admin_manage_buses_screen.dart` | UI Dialog (Delete bus confirmation) | Pending |
| 98 | Admin Mobile | `AM14 · Release driver confirmation` | `12:3382` | 390x844 | `admin_manage_drivers_screen.dart` | UI Dialog (Release driver confirmation) | Pending |
| 99 | Admin Mobile | `AM15 · Reject driver confirmation` | `12:3383` | 390x844 | `admin_manage_drivers_screen.dart` | UI Dialog (Reject driver confirmation) | Pending |
| 100 | Admin Mobile | `AM16 · Buses loading` | `12:3384` | 390x844 | `admin_manage_buses_screen.dart` | UI State Variant (Buses loading skeleton) | Pending State |
| 101 | Admin Mobile | `AM17 · Buses empty` | `12:3385` | 390x844 | `admin_manage_buses_screen.dart` | UI State Variant (Buses empty slate) | Pending State |
| 102 | Admin Mobile | `AM18 · Buses error` | `12:3386` | 390x844 | `admin_manage_buses_screen.dart` | UI State Variant (Buses error banner) | Pending State |
| 103 | Admin Mobile | `AM19 · Add bus` | `12:3387` | 390x844 | `admin_register_bus_screen.dart` | Primary Screen (Add bus) | Pending |
| 104 | Admin Mobile | `AM20 · Search route picker` | `12:3388` | 390x844 | `assign_bus_route_screen.dart` | UI Modal (Search route picker) | Pending |
| 105 | Admin Tablet (1024x900) | `AT01 · Dashboard` | `12:3389` | 1024x900 | `admin_dashboard_screen.dart` | Tablet Responsive Variant | Pending |
| 106 | Admin Tablet (1024x900) | `AT02 · Buses` | `12:3390` | 1024x900 | `admin_manage_buses_screen.dart` | Tablet Responsive Variant | Pending |
| 107 | Admin Mobile | `AM21 · Administration menu` | `12:9426` | 390x844 | `admin_dashboard_screen.dart` | UI Navigation Drawer (Administration menu) | Pending |
| 108 | System & Onboarding | `SYS01 · Splash` | `14:7058` | 390x844 | `main.dart / Native Splash` | System Splash Frame | Already configured |
| 109 | System & Onboarding | `SYS02 · Onboarding · Know where your bus is` | `14:7059` | 390x844 | `Onboarding walkthrough` | Onboarding Slide 1 | Already configured |
| 110 | System & Onboarding | `SYS03 · Onboarding · Never miss a stop` | `14:7060` | 390x844 | `Onboarding walkthrough` | Onboarding Slide 2 | Already configured |
| 111 | System & Onboarding | `SYS04 · Onboarding · Safe live sharing` | `14:7061` | 390x844 | `Onboarding walkthrough` | Onboarding Slide 3 | Already configured |
| 112 | System & Onboarding | `SYS05 · Driver location permission` | `14:7062` | 390x844 | `gps_tracking_service.dart` | System Permission Dialog | Already configured |
| 113 | System & Onboarding | `SYS06 · No internet` | `14:7063` | 390x844 | `BasePage.ts / AppTheme` | Offline Network State | Already configured |
| 114 | System & Onboarding | `SYS07 · Session expired` | `14:7064` | 390x844 | `role_guard.dart` | Session Expired Dialog | Already configured |
| 115 | System & Onboarding | `SYS08 · Driver access denied` | `14:7065` | 390x844 | `role_guard.dart` | Access Denied Screen | Already configured |
| 116 | System & Onboarding | `SYS09 · Update required` | `14:7066` | 390x844 | `Version Check System` | Update Required Modal | Already configured |

---

# Flutter Application Screens Inventory (32 Total)

### Migrated Screens (9 Screens)
1. `student_login_screen.dart` (Figma `S01 · Student login`, `7:1532`)
2. `student_signup_screen.dart` (Figma `S02 · Student sign up`, `7:1533`)
3. `student_home_screen.dart` (Figma `S04 · Home · LIVE`, `7:1535`)
4. `student_location_screen.dart` (Figma `S10 · Tracking · LIVE`, `7:1541`)
5. `student_profile_screen.dart` (Figma `S30 · Profile · English`, `7:1561`)
6. `driver_login_screen.dart` (Figma `01 · Driver login`, `2:1668`)
7. `driver_select_bus_screen.dart` (Figma `05 · Select your bus`, `2:1672`)
8. `driver_dashboard_screen.dart` (Figma `11 · Console ready` `2:1678` & `12 · Trip running` `2:1679`)
9. `admin_login_screen.dart` (Figma `AM01 · Admin login`, `12:3369`)

### Pending Screens (23 Screens grouped by Batch)
- **Batch 1 (Student Module - 5 screens):**
  - `student_search_screen.dart` (`05 · Fields & search` `2:105`, `06 · Search focused` `2:1673`, `S15` `7:1546`)
  - `student_routes_screen.dart` (`S18 · Routes · Expanded` `7:1549`, `S19`–`S22`)
  - `student_notifications_screen.dart` (`S23 · Notifications` `7:1554`, `S24`–`S27`)
  - `student_feedback_screen.dart` (`S28 · Feedback` `7:1559`, `S29` `7:1560`)
  - `student_forgot_password_screen.dart` (`S03 · Confirm your email` `7:1534`)
- **Batch 2 (Driver Module - 5 screens):**
  - `driver_signup_screen.dart` (`02 · Driver sign up` `2:1669`)
  - `driver_forgot_password_screen.dart` (`03 · Email confirmation` `2:1670`)
  - `driver_route_overview_screen.dart` (`15 · Route schedule` `2:1682`)
  - `driver_profile_screen.dart` (`16 · Driver profile` `2:1683`)
  - `driver_view_feedback_screen.dart` (`18 · Driver feedback` `2:1685`)
- **Batch 3 (Admin Fleet & Core - 4 screens):**
  - `admin_dashboard_screen.dart` (`AM02 · Dashboard` `12:3370`, `AD02`, `AT01`, `AM21`)
  - `admin_manage_buses_screen.dart` (`AM03 · Buses` `12:3371`, `AD03`, `AT02`, `AM12`–`AM18`)
  - `admin_bus_edit_screen.dart` (`AM04 · Edit bus` `12:3372`, `AD04`)
  - `admin_register_bus_screen.dart` (`AM19 · Add bus` `12:3387`, `AD19`)
- **Batch 4 (Admin Drivers & Routes - 5 screens):**
  - `admin_manage_drivers_screen.dart` (`AM05 · Drivers` `12:3373`, `AD05`, `AM14`–`AM15`)
  - `admin_register_driver_screen.dart` (`AM05` Add Driver Modal)
  - `admin_driver_edit_screen.dart` (`AM05` Edit Driver Drawer)
  - `admin_route_management_screen.dart` (`AM06 · Routes & Stops` `12:3374`, `AM07` `12:3375`, `AD06`–`AD07`)
  - `assign_bus_route_screen.dart` (`AM08 · Assign bus override` `12:3376`, `AM20`, `AD08`)
- **Batch 5 (Admin Communications, Analytics & Auth - 4 screens):**
  - `admin_analytics_screen.dart` (`AM09 · Announcements` `12:3377` & `AM11 · Analytics` `12:3379`, `AD09`, `AD11`)
  - `admin_view_feedback_screen.dart` (`AM10 · Feedback inbox` `12:3378`, `AD10`)
  - `admin_signup_screen.dart` (TrackItRide System 1.0 Auth layout derived from `AM01`)
  - `admin_forgot_password_screen.dart` (TrackItRide System 1.0 Password Recovery derived from `AM01`)
