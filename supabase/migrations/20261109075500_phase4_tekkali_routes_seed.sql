-- =============================================================================
-- Migration: 20261109075500_phase4_tekkali_routes_seed.sql
-- Description: Phase 4 Tekkali Campus Routes & Stops Seed Migration
-- =============================================================================

DO $$
DECLARE
    v_route1_id UUID;
    v_route2_id UUID;
    v_bus1_id UUID;
    v_bus2_id UUID;
BEGIN
    -- 1. Insert Tekkali Campus Routes if not existing
    INSERT INTO public.routes (name, code, description, created_at, updated_at)
    VALUES 
        ('Tekkali - Srikakulam Express', 'R-TK-SKLM', 'Main arterial route connecting Tekkali campus to Srikakulam RTC Complex', now(), now())
    ON CONFLICT (code) DO UPDATE 
        SET name = EXCLUDED.name, description = EXCLUDED.description
    RETURNING id INTO v_route1_id;

    INSERT INTO public.routes (name, code, description, created_at, updated_at)
    VALUES 
        ('Tekkali - Palasa Shuttle', 'R-TK-PLS', 'Campus express route connecting Tekkali to Palasa Junction & Station', now(), now())
    ON CONFLICT (code) DO UPDATE 
        SET name = EXCLUDED.name, description = EXCLUDED.description
    RETURNING id INTO v_route2_id;

    -- If existing routes didn't return id (on conflict do update returns id in modern PG, but fallback lookup just in case)
    IF v_route1_id IS NULL THEN
        SELECT id INTO v_route1_id FROM public.routes WHERE code = 'R-TK-SKLM';
    END IF;
    IF v_route2_id IS NULL THEN
        SELECT id INTO v_route2_id FROM public.routes WHERE code = 'R-TK-PLS';
    END IF;

    -- 2. Clean out old Bangalore demo stops for these routes if present
    DELETE FROM public.stops WHERE route_id IN (v_route1_id, v_route2_id);

    -- 3. Insert real Tekkali Campus Stops
    -- Route 1: Tekkali - Srikakulam
    INSERT INTO public.stops (route_id, name, sequence_no, latitude, longitude, scheduled_morning)
    VALUES 
        (v_route1_id, 'Tekkali Campus Main Gate', 1, 18.5702, 84.1853, '07:30:00'),
        (v_route1_id, 'Tekkali Old Bus Stand', 2, 18.5760, 84.1890, '07:38:00'),
        (v_route1_id, 'Kotabommali Junction', 3, 18.5300, 84.1500, '07:55:00'),
        (v_route1_id, 'Narasannapeta Bypass', 4, 18.4200, 84.0500, '08:20:00'),
        (v_route1_id, 'Srikakulam RTC Complex', 5, 18.2969, 83.8967, '08:50:00');

    -- Route 2: Tekkali - Palasa
    INSERT INTO public.stops (route_id, name, sequence_no, latitude, longitude, scheduled_morning)
    VALUES 
        (v_route2_id, 'Tekkali Engineering Block', 1, 18.5710, 84.1860, '07:45:00'),
        (v_route2_id, 'Nandigam Cross', 2, 18.6500, 84.2800, '08:05:00'),
        (v_route2_id, 'Palasa Railway Station', 3, 18.7700, 84.4100, '08:35:00');

    -- 4. Ensure demo fleet buses are registered with genuine college codes
    INSERT INTO public.buses (code, label, is_active)
    VALUES 
        ('BUS-01', 'AP 30 TC 1001', true),
        ('BUS-02', 'AP 30 TC 1002', true)
    ON CONFLICT (code) DO NOTHING;

END $$;
