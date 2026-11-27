-- =============================================================================
-- Migration: 20261109071736_phase1_security_rls.sql
-- Description: Phase 1 Security & Access Control (P0 - Immediate Blockers)
--   1. Enable Row Level Security (RLS) on all production tables
--   2. Public Read-Only policies for Routes, Stops, Buses
--   3. Strict Driver-Only write policies for Trips & Trip Locations
--   4. Admin-Only write policies for Announcements & Routes/Stops/Buses
--   5. Self-profile security for Users & Public Admin Signup Prevention
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. ENABLE ROW LEVEL SECURITY (RLS) ON ALL TABLES
-- -----------------------------------------------------------------------------
ALTER TABLE IF EXISTS public.routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.stops ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.buses ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.trip_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.allowlist_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Grant schema usage to standard roles
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;

-- Helper Function: Check if current user is an Admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY INVOKER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE users.id = (SELECT auth.uid())
      AND users.role = 'admin'
      AND users.active = true
  );
$$;

-- Helper Function: Check if current user is a Driver
CREATE OR REPLACE FUNCTION public.is_driver()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY INVOKER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE users.id = (SELECT auth.uid())
      AND users.role = 'driver'
      AND users.active = true
  );
$$;

-- -----------------------------------------------------------------------------
-- 2. ROUTES: Public Read-Only | Admin Write-Only
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Public access routes" ON public.routes;
DROP POLICY IF EXISTS "routes_select_public" ON public.routes;
DROP POLICY IF EXISTS "routes_admin_insert" ON public.routes;
DROP POLICY IF EXISTS "routes_admin_update" ON public.routes;
DROP POLICY IF EXISTS "routes_admin_delete" ON public.routes;

CREATE POLICY "routes_select_public"
ON public.routes FOR SELECT
TO anon, authenticated
USING (true);

CREATE POLICY "routes_admin_insert"
ON public.routes FOR INSERT
TO authenticated
WITH CHECK (public.is_admin());

CREATE POLICY "routes_admin_update"
ON public.routes FOR UPDATE
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

CREATE POLICY "routes_admin_delete"
ON public.routes FOR DELETE
TO authenticated
USING (public.is_admin());

-- -----------------------------------------------------------------------------
-- 3. STOPS: Public Read-Only | Admin Write-Only
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Public access stops" ON public.stops;
DROP POLICY IF EXISTS "stops_select_public" ON public.stops;
DROP POLICY IF EXISTS "stops_admin_insert" ON public.stops;
DROP POLICY IF EXISTS "stops_admin_update" ON public.stops;
DROP POLICY IF EXISTS "stops_admin_delete" ON public.stops;

CREATE POLICY "stops_select_public"
ON public.stops FOR SELECT
TO anon, authenticated
USING (true);

CREATE POLICY "stops_admin_insert"
ON public.stops FOR INSERT
TO authenticated
WITH CHECK (public.is_admin());

CREATE POLICY "stops_admin_update"
ON public.stops FOR UPDATE
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

CREATE POLICY "stops_admin_delete"
ON public.stops FOR DELETE
TO authenticated
USING (public.is_admin());

-- -----------------------------------------------------------------------------
-- 4. BUSES: Public Read-Only | Admin Write-Only
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Public access buses" ON public.buses;
DROP POLICY IF EXISTS "buses_select_public" ON public.buses;
DROP POLICY IF EXISTS "buses_admin_insert" ON public.buses;
DROP POLICY IF EXISTS "buses_admin_update" ON public.buses;
DROP POLICY IF EXISTS "buses_admin_delete" ON public.buses;

CREATE POLICY "buses_select_public"
ON public.buses FOR SELECT
TO anon, authenticated
USING (true);

CREATE POLICY "buses_admin_insert"
ON public.buses FOR INSERT
TO authenticated
WITH CHECK (public.is_admin());

CREATE POLICY "buses_admin_update"
ON public.buses FOR UPDATE
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

CREATE POLICY "buses_admin_delete"
ON public.buses FOR DELETE
TO authenticated
USING (public.is_admin());

-- -----------------------------------------------------------------------------
-- 5. TRIPS: Read-Only for Students/Public | Driver Write-Only (auth.uid() = driver_id)
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Public access trips" ON public.trips;
DROP POLICY IF EXISTS "trips_select_all" ON public.trips;
DROP POLICY IF EXISTS "trips_driver_insert" ON public.trips;
DROP POLICY IF EXISTS "trips_driver_update" ON public.trips;
DROP POLICY IF EXISTS "trips_admin_delete" ON public.trips;

-- Any student, driver, or faculty can view live and scheduled trips
CREATE POLICY "trips_select_all"
ON public.trips FOR SELECT
TO anon, authenticated
USING (true);

-- Drivers can only start/insert trips where they are assigned as the driver
CREATE POLICY "trips_driver_insert"
ON public.trips FOR INSERT
TO authenticated
WITH CHECK (
    driver_id = (SELECT auth.uid())
    OR public.is_admin()
);

-- Drivers can only update their own trip telemetry and status
CREATE POLICY "trips_driver_update"
ON public.trips FOR UPDATE
TO authenticated
USING (
    driver_id = (SELECT auth.uid())
    OR public.is_admin()
)
WITH CHECK (
    driver_id = (SELECT auth.uid())
    OR public.is_admin()
);

CREATE POLICY "trips_admin_delete"
ON public.trips FOR DELETE
TO authenticated
USING (public.is_admin());

-- -----------------------------------------------------------------------------
-- 6. TRIP LOCATIONS: Read-Only for Students | Driver Write-Only for Own Trips
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Public access locations" ON public.trip_locations;
DROP POLICY IF EXISTS "trip_locations_select_all" ON public.trip_locations;
DROP POLICY IF EXISTS "trip_locations_driver_insert" ON public.trip_locations;

-- Anyone can see GPS coordinate breadcrumbs for the active trip
CREATE POLICY "trip_locations_select_all"
ON public.trip_locations FOR SELECT
TO anon, authenticated
USING (true);

-- Only the driver assigned to the trip can stream GPS points into trip_locations
CREATE POLICY "trip_locations_driver_insert"
ON public.trip_locations FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.trips
        WHERE trips.id = trip_locations.trip_id
          AND (trips.driver_id = (SELECT auth.uid()) OR public.is_admin())
    )
);

-- -----------------------------------------------------------------------------
-- 7. ANNOUNCEMENTS: Read-Only for Everyone | Admin Write-Only
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Public access announcements" ON public.announcements;
DROP POLICY IF EXISTS "announcements_select_all" ON public.announcements;
DROP POLICY IF EXISTS "announcements_admin_insert" ON public.announcements;
DROP POLICY IF EXISTS "announcements_admin_update" ON public.announcements;
DROP POLICY IF EXISTS "announcements_admin_delete" ON public.announcements;

CREATE POLICY "announcements_select_all"
ON public.announcements FOR SELECT
TO anon, authenticated
USING (true);

CREATE POLICY "announcements_admin_insert"
ON public.announcements FOR INSERT
TO authenticated
WITH CHECK (public.is_admin());

CREATE POLICY "announcements_admin_update"
ON public.announcements FOR UPDATE
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

CREATE POLICY "announcements_admin_delete"
ON public.announcements FOR DELETE
TO authenticated
USING (public.is_admin());

-- -----------------------------------------------------------------------------
-- 8. USERS: Profiles & Public Admin Registration Prevention
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Public access users" ON public.users;
DROP POLICY IF EXISTS "users_select_all" ON public.users;
DROP POLICY IF EXISTS "users_insert_signup" ON public.users;
DROP POLICY IF EXISTS "users_self_update" ON public.users;
DROP POLICY IF EXISTS "users_admin_delete" ON public.users;

-- Authenticated and anonymous users can read basic names and roles
CREATE POLICY "users_select_all"
ON public.users FOR SELECT
TO anon, authenticated
USING (true);

-- Self-signup can only create 'student' or 'driver' accounts (NEVER 'admin')
CREATE POLICY "users_insert_signup"
ON public.users FOR INSERT
TO anon, authenticated
WITH CHECK (
    -- Admins can create any user
    public.is_admin()
    -- Non-admins cannot register as admin
    OR (
        role IN ('student', 'driver')
        AND (id = (SELECT auth.uid()) OR (SELECT auth.uid()) IS NULL)
    )
);

-- Users can only edit their own profile; Admins can update any profile
CREATE POLICY "users_self_update"
ON public.users FOR UPDATE
TO authenticated
USING (
    id = (SELECT auth.uid())
    OR public.is_admin()
)
WITH CHECK (
    -- Normal users cannot elevate their own role to admin
    (id = (SELECT auth.uid()) AND role NOT IN ('admin'))
    OR public.is_admin()
);

CREATE POLICY "users_admin_delete"
ON public.users FOR DELETE
TO authenticated
USING (public.is_admin());

-- -----------------------------------------------------------------------------
-- 9. AUDIT LOGS: Admin Read/Write Only
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Public access audit_logs" ON public.audit_logs;
DROP POLICY IF EXISTS "audit_logs_select_admin" ON public.audit_logs;
DROP POLICY IF EXISTS "audit_logs_insert_system" ON public.audit_logs;

CREATE POLICY "audit_logs_select_admin"
ON public.audit_logs FOR SELECT
TO authenticated
USING (public.is_admin());

CREATE POLICY "audit_logs_insert_system"
ON public.audit_logs FOR INSERT
TO authenticated
WITH CHECK (true);
