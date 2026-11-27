-- =============================================================================
-- Migration: 20261109073800_phase3_telemetry_rpc.sql
-- Description: Phase 3 Telemetry Optimization, Single-RPC writes & Batching
-- =============================================================================

-- 1. Single-Call Atomic Telemetry RPC (Replaces 2 separate DB roundtrips)
CREATE OR REPLACE FUNCTION public.record_driver_telemetry(
    p_trip_id UUID,
    p_latitude DOUBLE PRECISION,
    p_longitude DOUBLE PRECISION,
    p_speed_mps DOUBLE PRECISION DEFAULT 0.0,
    p_accuracy_meters DOUBLE PRECISION DEFAULT 0.0,
    p_captured_at TIMESTAMPTZ DEFAULT now()
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_driver_id UUID;
BEGIN
    -- Verify caller owns the trip or is admin (Security Enforcement)
    SELECT driver_id INTO v_driver_id
    FROM public.trips
    WHERE id = p_trip_id;

    IF v_driver_id IS NULL THEN
        RAISE EXCEPTION 'Trip with ID % not found', p_trip_id;
    END IF;

    IF (auth.uid() IS NOT NULL) AND (auth.uid() != v_driver_id) AND NOT public.is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Only the assigned driver can submit telemetry for this trip';
    END IF;

    -- 1. Insert point into trip_locations breadcrumbs
    INSERT INTO public.trip_locations (
        trip_id,
        latitude,
        longitude,
        speed_mps,
        accuracy_meters,
        captured_at
    ) VALUES (
        p_trip_id,
        p_latitude,
        p_longitude,
        p_speed_mps,
        p_accuracy_meters,
        p_captured_at
    );

    -- 2. Atomically update parent trip summary
    UPDATE public.trips
    SET last_latitude = p_latitude,
        last_longitude = p_longitude,
        last_speed_mps = p_speed_mps,
        last_location_at = p_captured_at,
        status = 'running',
        updated_at = now()
    WHERE id = p_trip_id;

    RETURN jsonb_build_object(
        'success', true,
        'trip_id', p_trip_id,
        'recorded_at', p_captured_at
    );
END;
$$;

-- Grant execute to authenticated users and service role
GRANT EXECUTE ON FUNCTION public.record_driver_telemetry TO authenticated, service_role;

-- 2. Batch Sync Offline Telemetry RPC (Syncs entire dead-zone buffer in 1 request)
CREATE OR REPLACE FUNCTION public.batch_sync_offline_telemetry(
    p_trip_id UUID,
    p_points JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_driver_id UUID;
    v_inserted_count INT := 0;
    v_latest RECORD;
BEGIN
    -- Verify caller owns the trip or is admin
    SELECT driver_id INTO v_driver_id
    FROM public.trips
    WHERE id = p_trip_id;

    IF v_driver_id IS NULL THEN
        RAISE EXCEPTION 'Trip with ID % not found', p_trip_id;
    END IF;

    IF (auth.uid() IS NOT NULL) AND (auth.uid() != v_driver_id) AND NOT public.is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Only the assigned driver can submit telemetry';
    END IF;

    -- Batch insert all buffered location points in 1 query
    INSERT INTO public.trip_locations (
        trip_id,
        latitude,
        longitude,
        speed_mps,
        accuracy_meters,
        captured_at
    )
    SELECT
        p_trip_id,
        (elem->>'latitude')::DOUBLE PRECISION,
        (elem->>'longitude')::DOUBLE PRECISION,
        COALESCE((elem->>'speed_mps')::DOUBLE PRECISION, 0.0),
        COALESCE((elem->>'accuracy_meters')::DOUBLE PRECISION, 0.0),
        (elem->>'captured_at')::TIMESTAMPTZ
    FROM jsonb_array_elements(p_points) AS elem;

    GET DIAGNOSTICS v_inserted_count = ROW_COUNT;

    -- Update trips table with latest point from batch
    SELECT 
        (elem->>'latitude')::DOUBLE PRECISION AS lat,
        (elem->>'longitude')::DOUBLE PRECISION AS lng,
        COALESCE((elem->>'speed_mps')::DOUBLE PRECISION, 0.0) AS spd,
        (elem->>'captured_at')::TIMESTAMPTZ AS ts
    INTO v_latest
    FROM jsonb_array_elements(p_points) AS elem
    ORDER BY (elem->>'captured_at')::TIMESTAMPTZ DESC
    LIMIT 1;

    IF v_latest.lat IS NOT NULL THEN
        UPDATE public.trips
        SET last_latitude = v_latest.lat,
            last_longitude = v_latest.lng,
            last_speed_mps = v_latest.spd,
            last_location_at = v_latest.ts,
            status = 'running',
            updated_at = now()
        WHERE id = p_trip_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'points_synced', v_inserted_count,
        'synced_at', now()
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.batch_sync_offline_telemetry TO authenticated, service_role;
