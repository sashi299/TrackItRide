-- =====================================================================
-- TrackItRide  |  001_schema_rls_rpc.sql
-- Run in: Supabase Dashboard -> SQL Editor.  Idempotent (safe to re-run).
--
-- ASSUMES these tables already exist (as used by the Flutter code):
--   users, buses, routes, stops, trips, trip_locations, announcements, audit_logs
-- ASSUMES primary keys are uuid. If yours are not, tell me and I'll adjust.
--
-- WHAT THIS DOES
--   1. Adds columns needed for self-service driver bus selection
--   2. Auth trigger: role comes from a trusted rule, NOT from the client
--   3. Row Level Security on every table (today: none verified)
--   4. RPC functions: search_buses, claim_bus, start_trip, post_location ...
--   5. bus_live table: ONE row per bus -> cheap realtime for 500+ buses
--   6. Indexes for 500+ buses / routes
--
-- !! BACK UP FIRST (Database -> Backups) -- step 3 DROPS all existing policies.
-- =====================================================================

create extension if not exists pg_trgm;

-- ---------------------------------------------------------------------
-- 1. Columns
-- ---------------------------------------------------------------------
alter table public.users add column if not exists auth_id uuid unique references auth.users(id) on delete cascade;
alter table public.users add column if not exists phone text;
alter table public.users add column if not exists license_number text;
alter table public.users add column if not exists approved boolean not null default false;

alter table public.buses add column if not exists default_route_id uuid references public.routes(id) on delete set null;
alter table public.trips add column if not exists last_history_at timestamptz;

-- Link existing rows to their auth account (by email)
update public.users u
   set auth_id = a.id
  from auth.users a
 where u.auth_id is null and lower(a.email) = lower(u.email);

-- Existing students/admins stay usable. Existing drivers: decide yourself:
update public.users set approved = true where role in ('student', 'admin');
-- update public.users set approved = true where role = 'driver';   -- uncomment for existing test drivers

-- ---------------------------------------------------------------------
-- 2. Auth trigger  (client can NEVER create an admin)
--    Requires: Auth -> Providers -> Email -> "Confirm email" = ON
-- ---------------------------------------------------------------------
create or replace function public.handle_new_auth_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_role text;
begin
  v_role := case when new.raw_user_meta_data->>'role' = 'driver' then 'driver' else 'student' end;
  insert into public.users (auth_id, email, name, role, external_id, active, phone, license_number, approved)
  values (
    new.id, lower(new.email),
    coalesce(nullif(new.raw_user_meta_data->>'name', ''), split_part(new.email, '@', 1)),
    v_role, lower(new.email), true,
    nullif(new.raw_user_meta_data->>'phone', ''),
    nullif(new.raw_user_meta_data->>'license', ''),
    (v_role = 'student')            -- drivers start UNAPPROVED
  )
  on conflict (email) do update set auth_id = excluded.auth_id;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_auth_user();

-- Helpers (SECURITY DEFINER => safe to call inside RLS policies, no recursion)
create or replace function public.me_id() returns uuid
  language sql stable security definer set search_path = public
  as $$ select id from public.users where auth_id = auth.uid() $$;
create or replace function public.me_role() returns text
  language sql stable security definer set search_path = public
  as $$ select role from public.users where auth_id = auth.uid() $$;
create or replace function public.me_approved() returns boolean
  language sql stable security definer set search_path = public
  as $$ select coalesce(approved, false) from public.users where auth_id = auth.uid() $$;

-- ---------------------------------------------------------------------
-- 3. bus_live: one row per bus (realtime-friendly) + indexes
-- ---------------------------------------------------------------------
create table if not exists public.bus_live (
  bus_id     uuid primary key references public.buses(id) on delete cascade,
  trip_id    uuid,
  latitude   double precision,
  longitude  double precision,
  speed_mps  real,
  heading    real,
  status     text not null default 'idle',
  updated_at timestamptz not null default now()
);

do $$ begin
  alter publication supabase_realtime add table public.bus_live;
exception when duplicate_object then null; when undefined_object then null; end $$;

-- If this fails, you have duplicate bus codes -> clean them first.
create unique index if not exists buses_code_lower_uq   on public.buses (lower(code));
create index        if not exists buses_code_prefix_idx on public.buses (lower(code) text_pattern_ops);
create index        if not exists buses_label_trgm_idx  on public.buses using gin (lower(label) gin_trgm_ops);
create index        if not exists buses_driver_idx      on public.buses (assigned_driver_id);
create index        if not exists routes_code_idx       on public.routes (lower(code));
create index        if not exists stops_route_seq_idx   on public.stops (route_id, sequence_no);
create index        if not exists stops_name_trgm_idx   on public.stops using gin (lower(name) gin_trgm_ops);
create index        if not exists trips_bus_idx         on public.trips (bus_id, status);
create index        if not exists trip_loc_idx          on public.trip_locations (trip_id, captured_at desc);
-- only ONE active trip per bus (fixes duplicate trips from the old upsert)
create unique index if not exists one_active_trip_per_bus on public.trips (bus_id)
  where status in ('scheduled', 'running', 'delayed');

-- ---------------------------------------------------------------------
-- 4. Row Level Security  (drops ALL existing policies on these tables!)
-- ---------------------------------------------------------------------
do $$ declare r record; begin
  for r in select schemaname, tablename, policyname from pg_policies
            where schemaname = 'public'
              and tablename in ('users','buses','routes','stops','trips','trip_locations','announcements','audit_logs','bus_live')
  loop
    execute format('drop policy %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;
end $$;

alter table public.users          enable row level security;
alter table public.buses          enable row level security;
alter table public.routes         enable row level security;
alter table public.stops          enable row level security;
alter table public.trips          enable row level security;
alter table public.trip_locations enable row level security;
alter table public.announcements  enable row level security;
alter table public.audit_logs     enable row level security;
alter table public.bus_live       enable row level security;

-- users: see own row; admin sees/edits all. No client INSERT (trigger does it).
create policy users_select on public.users for select to authenticated
  using (auth_id = auth.uid() or public.me_role() = 'admin');
create policy users_admin_update on public.users for update to authenticated
  using (public.me_role() = 'admin') with check (public.me_role() = 'admin');
create policy users_admin_delete on public.users for delete to authenticated
  using (public.me_role() = 'admin');

-- buses / routes / stops: everyone signed-in reads, only admin writes
create policy buses_read  on public.buses  for select to authenticated using (true);
create policy buses_admin on public.buses  for all    to authenticated
  using (public.me_role() = 'admin') with check (public.me_role() = 'admin');
create policy routes_read  on public.routes for select to authenticated using (true);
create policy routes_admin on public.routes for all    to authenticated
  using (public.me_role() = 'admin') with check (public.me_role() = 'admin');
create policy stops_read  on public.stops  for select to authenticated using (true);
create policy stops_admin on public.stops  for all    to authenticated
  using (public.me_role() = 'admin') with check (public.me_role() = 'admin');

-- trips / trip_locations / bus_live: read for all, writes ONLY via RPC (drivers) or admin
create policy trips_read  on public.trips for select to authenticated using (true);
create policy trips_admin on public.trips for all    to authenticated
  using (public.me_role() = 'admin') with check (public.me_role() = 'admin');
create policy triploc_read  on public.trip_locations for select to authenticated using (true);
create policy triploc_admin on public.trip_locations for delete to authenticated
  using (public.me_role() = 'admin');
create policy buslive_read on public.bus_live for select to authenticated using (true);

-- announcements: read what's meant for your role; admin writes
create policy ann_read on public.announcements for select to authenticated
  using (audience_role is null or audience_role = public.me_role() or public.me_role() = 'admin');
create policy ann_admin on public.announcements for all to authenticated
  using (public.me_role() = 'admin') with check (public.me_role() = 'admin');

-- audit_logs (feedback lives here today): anyone signed-in can add feedback, only admin reads
create policy audit_insert_feedback on public.audit_logs for insert to authenticated
  with check (action = 'FEEDBACK_SUBMITTED');
create policy audit_admin_read on public.audit_logs for select to authenticated
  using (public.me_role() = 'admin');

-- ---------------------------------------------------------------------
-- 5. RPC functions
-- ---------------------------------------------------------------------

-- Small JSON shape the Flutter app reads for "my bus"
create or replace function public._assignment_json(p_bus_id uuid)
returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'busId', b.id, 'busNumber', b.code, 'numberPlate', b.label,
    'routeId', coalesce(t.route_id, b.default_route_id),
    'routeName', r.name, 'routeCode', r.code,
    'tripId', t.id, 'tripStatus', coalesce(t.status, 'idle'))
  from buses b
  left join lateral (select * from trips x where x.bus_id = b.id
                      and x.status in ('scheduled','running','delayed')
                      order by x.updated_at desc nulls last limit 1) t on true
  left join routes r on r.id = coalesce(t.route_id, b.default_route_id)
  where b.id = p_bus_id
$$;

-- Server-side search: 500+ buses never travel to the phone
create or replace function public.search_buses(p_query text default '', p_limit int default 30, p_offset int default 0)
returns table(bus_id uuid, code text, label text, capacity int, route_id uuid, route_name text,
              route_code text, trip_id uuid, status text, driver_name text, is_taken boolean, is_mine boolean)
language sql stable security definer set search_path = public as $$
  select b.id, b.code, b.label, b.capacity,
         coalesce(t.route_id, b.default_route_id), r.name, r.code,
         t.id, coalesce(t.status, 'idle'),
         case when public.me_role() = 'admin' then d.name else split_part(coalesce(d.name, ''), ' ', 1) end,
         b.assigned_driver_id is not null,
         b.assigned_driver_id is not distinct from public.me_id()
    from buses b
    left join lateral (select * from trips x where x.bus_id = b.id
                        and x.status in ('scheduled','running','delayed')
                        order by x.updated_at desc nulls last limit 1) t on true
    left join routes r on r.id = coalesce(t.route_id, b.default_route_id)
    left join users  d on d.id = b.assigned_driver_id
   where b.active is not false
     and auth.uid() is not null
     and (trim(p_query) = ''
          or lower(b.code)  like lower(trim(p_query)) || '%'
          or lower(b.label) like '%' || lower(trim(p_query)) || '%')
   order by b.code
   limit least(greatest(p_limit, 1), 100) offset greatest(p_offset, 0)
$$;

-- DRIVER: pick my bus by number
create or replace function public.claim_bus(p_bus_code text)
returns json language plpgsql security definer set search_path = public as $$
declare v_me uuid := public.me_id(); v_bus public.buses%rowtype;
begin
  if v_me is null or public.me_role() <> 'driver' then
    raise exception 'Only driver accounts can select a bus';
  end if;
  if not public.me_approved() then
    raise exception 'Your driver account is waiting for admin approval';
  end if;

  select * into v_bus from public.buses
   where lower(code) = lower(trim(p_bus_code)) and active is not false
   for update;
  if not found then raise exception 'Bus "%" not found', p_bus_code; end if;

  if v_bus.assigned_driver_id is not null and v_bus.assigned_driver_id <> v_me then
    raise exception 'Bus % is already taken by another driver. Contact the transport admin.', v_bus.code;
  end if;
  if v_bus.default_route_id is null then
    raise exception 'Bus % has no route yet. Ask the admin to set its route.', v_bus.code;
  end if;

  -- a driver holds only one bus
  update public.buses set assigned_driver_id = null where assigned_driver_id = v_me and id <> v_bus.id;
  update public.buses set assigned_driver_id = v_me, updated_at = now() where id = v_bus.id;

  return public._assignment_json(v_bus.id);
end $$;

create or replace function public.release_bus()
returns void language plpgsql security definer set search_path = public as $$
declare v_me uuid := public.me_id(); v_bus uuid;
begin
  select id into v_bus from public.buses where assigned_driver_id = v_me;
  if v_bus is null then return; end if;
  update public.trips set status = 'completed', updated_at = now()
   where bus_id = v_bus and status in ('running','delayed','scheduled');
  update public.bus_live set status = 'idle', updated_at = now() where bus_id = v_bus;
  update public.buses set assigned_driver_id = null where id = v_bus;
end $$;

create or replace function public.my_assignment()
returns json language plpgsql stable security definer set search_path = public as $$
declare v_bus uuid;
begin
  select id into v_bus from public.buses where assigned_driver_id = public.me_id();
  if v_bus is null then return null; end if;
  return public._assignment_json(v_bus);
end $$;

-- DRIVER: start trip (creates today's trip if needed)
-- NOTE: if trips.status has a CHECK constraint, it must allow 'completed'.
create or replace function public.start_trip()
returns json language plpgsql security definer set search_path = public as $$
declare v_me uuid := public.me_id(); v_bus public.buses%rowtype; v_trip uuid;
begin
  select * into v_bus from public.buses where assigned_driver_id = v_me;
  if not found then raise exception 'Select your bus first'; end if;

  select id into v_trip from public.trips
   where bus_id = v_bus.id and status in ('scheduled','running','delayed') limit 1;
  if v_trip is null then
    insert into public.trips (bus_id, route_id, driver_id, status, direction)
    values (v_bus.id, v_bus.default_route_id, v_me, 'scheduled',
            case when extract(hour from (now() at time zone 'Asia/Kolkata')) < 13 then 'morning' else 'evening' end)
    returning id into v_trip;
  end if;
  update public.trips set status = 'running', driver_id = v_me, updated_at = now() where id = v_trip;

  insert into public.bus_live (bus_id, trip_id, status, updated_at)
  values (v_bus.id, v_trip, 'running', now())
  on conflict (bus_id) do update set trip_id = excluded.trip_id, status = 'running', updated_at = now();

  return public._assignment_json(v_bus.id);
end $$;

create or replace function public.end_trip()
returns void language plpgsql security definer set search_path = public as $$
declare v_bus uuid;
begin
  select id into v_bus from public.buses where assigned_driver_id = public.me_id();
  if v_bus is null then return; end if;
  update public.trips set status = 'completed', updated_at = now()
   where bus_id = v_bus and status in ('running','delayed');
  update public.bus_live set status = 'idle', updated_at = now() where bus_id = v_bus;
end $$;

-- DRIVER: ONE call per GPS ping. Live row every time; history row max every 30 s.
create or replace function public.post_location(p_lat double precision, p_lng double precision,
                                                p_speed real default 0, p_heading real default 0)
returns void language plpgsql security definer set search_path = public as $$
declare v_me uuid := public.me_id(); v_bus uuid; v_trip uuid; v_last timestamptz;
begin
  if p_lat not between -90 and 90 or p_lng not between -180 and 180 then
    raise exception 'Invalid coordinates';
  end if;
  select id into v_bus from public.buses where assigned_driver_id = v_me;
  if v_bus is null then raise exception 'No bus assigned'; end if;
  select id, last_history_at into v_trip, v_last from public.trips
   where bus_id = v_bus and status = 'running' limit 1;
  if v_trip is null then raise exception 'Trip not started'; end if;

  insert into public.bus_live (bus_id, trip_id, latitude, longitude, speed_mps, heading, status, updated_at)
  values (v_bus, v_trip, p_lat, p_lng, p_speed, p_heading, 'running', now())
  on conflict (bus_id) do update
     set trip_id = excluded.trip_id, latitude = excluded.latitude, longitude = excluded.longitude,
         speed_mps = excluded.speed_mps, heading = excluded.heading, status = 'running', updated_at = now();

  if v_last is null or now() - v_last >= interval '30 seconds' then
    insert into public.trip_locations (trip_id, latitude, longitude, speed_mps, captured_at)
    values (v_trip, p_lat, p_lng, p_speed, now());
    update public.trips
       set last_history_at = now(), last_latitude = p_lat, last_longitude = p_lng,
           last_speed_mps = p_speed, last_location_at = now()
     where id = v_trip;
  end if;
end $$;

-- ANY USER: edit own name/phone only (role/approved can't be touched)
create or replace function public.update_my_profile(p_name text, p_phone text)
returns void language sql security definer set search_path = public as $$
  update public.users set name = coalesce(nullif(trim(p_name), ''), name),
         phone = coalesce(nullif(trim(p_phone), ''), phone), updated_at = now()
   where auth_id = auth.uid()
$$;

-- ADMIN: assign bus -> driver + default route (replaces the old client-side upsert)
create or replace function public.admin_assign_bus(p_bus_id uuid, p_driver_id uuid, p_route_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if public.me_role() <> 'admin' then raise exception 'Admins only'; end if;
  update public.buses set assigned_driver_id = null where assigned_driver_id = p_driver_id and id <> p_bus_id;
  update public.buses set assigned_driver_id = p_driver_id, default_route_id = p_route_id, updated_at = now()
   where id = p_bus_id;
  update public.trips set route_id = p_route_id, driver_id = p_driver_id, updated_at = now()
   where bus_id = p_bus_id and status in ('scheduled','delayed');
end $$;

-- ADMIN: free a bus (driver left / phone lost)
create or replace function public.admin_release_bus(p_bus_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if public.me_role() <> 'admin' then raise exception 'Admins only'; end if;
  update public.trips set status = 'completed', updated_at = now()
   where bus_id = p_bus_id and status in ('running','delayed','scheduled');
  update public.bus_live set status = 'idle', updated_at = now() where bus_id = p_bus_id;
  update public.buses set assigned_driver_id = null where id = p_bus_id;
end $$;

-- Lock function access: signed-in users only
do $$ declare f text; begin
  foreach f in array array[
    'search_buses(text,int,int)', 'claim_bus(text)', 'release_bus()', 'my_assignment()',
    'start_trip()', 'end_trip()', 'post_location(double precision,double precision,real,real)',
    'update_my_profile(text,text)', 'admin_assign_bus(uuid,uuid,uuid)', 'admin_release_bus(uuid)'
  ] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 6. Housekeeping
-- ---------------------------------------------------------------------
-- First admin (run manually, after that admins are only created like this):
--   update public.users set role = 'admin', approved = true where email = 'YOUR_EMAIL';
--
-- Retention (enable pg_cron under Database -> Extensions first):
--   select cron.schedule('purge-trip-locations', '0 3 * * *',
--     $$ delete from public.trip_locations where captured_at < now() - interval '7 days' $$);
--
-- BULK IMPORT for 500+ buses/routes: Table Editor -> Import CSV into staging tables, e.g.
--   routes_stage(code, name)       stops_stage(route_code, sequence_no, name, latitude, longitude)
--   buses_stage(code, label, capacity, route_code)
-- then:
--   insert into routes(code, name, active) select code, name, true from routes_stage on conflict do nothing;
--   insert into stops(route_id, name, sequence_no, latitude, longitude, active)
--     select r.id, s.name, s.sequence_no, s.latitude, s.longitude, true
--       from stops_stage s join routes r on r.code = s.route_code;
--   insert into buses(code, label, capacity, active, default_route_id)
--     select b.code, b.label, b.capacity, true, r.id from buses_stage b left join routes r on r.code = b.route_code
--     on conflict do nothing;
