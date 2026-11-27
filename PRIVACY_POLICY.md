# Privacy Policy for TrackItRide

**Last Updated:** November 9, 2026  
**Application Package ID:** `com.cbts.transport`

This Privacy Policy describes how the **TrackItRide** Smart College Bus Tracking System ("we", "our", or "us") collects, uses, and discloses information when you use our mobile application and related transit services.

---

## 1. Information We Collect

### A. Location Data (Foreground and Background)
* **Driver Location (Prominent Disclosure):**  
  TrackItRide collects precise real-time location data from registered bus drivers **only when an authorized transit trip is actively in progress**. This data collection operates in the background (`ACCESS_BACKGROUND_LOCATION` and `FOREGROUND_SERVICE_LOCATION`) via an active, persistent Android foreground service with a sticky status notification, ensuring students receive unbroken arrival estimates even when the driver's device is locked or minimized. Driver location tracking ceases immediately when the driver taps "Stop Trip" or terminates their active route.
* **Student Location:**  
  TrackItRide requests foreground location access from students solely to display their current position relative to nearby campus bus stops on the interactive Google Map. Student location data is processed locally on the device and is **never transmitted to or stored on our servers**.

### B. User Account & Identity Information
* Name, college email address, and phone number required for authentication and role assignment (Student, Driver, or Transport Administrator).
* Session authentication tokens managed through secure Supabase Authentication.

---

## 2. How We Use Information

* To provide live, real-time bus tracking and estimated arrival times to students and college staff.
* To maintain transit safety, optimize route schedules, and resolve student transportation inquiries.
* To authenticate authorized drivers and administrative personnel.

---

## 3. Data Sharing & Third-Party Services

We do not sell, rent, or trade your personal information. We only share necessary data with trusted service providers strictly to deliver core app functionality:
* **Supabase Cloud (PostgreSQL):** For secure real-time database streaming, user authentication, and encrypted data storage.
* **Google Maps Platform:** For rendering interactive maps and route polylines.

---

## 4. Data Security & Storage

* All communications between the mobile application and the Supabase backend are encrypted in transit via Transport Layer Security (TLS 1.3 / HTTPS / WSS).
* Database access is strictly governed by PostgreSQL Row Level Security (RLS) policies, preventing unauthorized read or write access across roles.
* Historical telemetry breadcrumbs are periodically archived and purged according to institutional transport policies.

---

## 5. User Choices & Data Deletion

* **Permissions:** You may withdraw location permissions at any time via your device's Android Settings (`Settings > Apps > TrackItRide > Permissions`). Disabling location permissions for drivers will prevent starting or broadcasting active transit trips.
* **Account Deletion:** Users may request the complete deletion of their account and associated profile information by contacting the College Transport Department or submitting a request to the system administrator.

---

## 6. Contact Us

If you have any questions or concerns regarding this Privacy Policy or data handling practices, please contact:
* **Department:** Campus Transport Administration
* **Email:** `transport@cbts.edu`
* **Address:** College Campus, Tekkali, Srikakulam District, Andhra Pradesh, India.
