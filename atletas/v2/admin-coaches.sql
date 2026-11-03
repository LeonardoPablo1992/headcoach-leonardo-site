-- =========================================================
-- ProTrainerPlus · ADMINISTRACIÓN, APROBACIÓN DE COACHES, BAJA DE COACH Y LLAMADA INICIAL
-- Ejecutar en Supabase → SQL Editor (después de multi-coach.sql). Se puede volver a correr.
--
--  · Cuenta administradora: el coach principal (tabla coaches) + correos en pt_admins.
--  · Coaches nuevos quedan «pending» hasta que el administrador los acepte (inicia la prueba de 14 días)
--    o los rechace. Los coaches que ya estaban activos o en prueba no cambian.
--  · El administrador ve todos los coaches y los clientes de cada uno.
--  · El coach puede darse de baja: se borra su cuenta; sus clientes conservan su historial y quedan
--    libres para elegir otro coach (se les avisa).
--  · El cliente puede proponer una llamada inicial de 15 min al pedir coach (fecha y hora).
-- =========================================================

-- ---------- Columnas nuevas del vínculo (llamada inicial) ----------
alter table public.pt_links add column if not exists call_at timestamptz;
alter table public.pt_links add column if not exists note text;

-- ---------- Administradores ----------
create table if not exists public.pt_admins (email text primary key, created_at timestamptz not null default now());
alter table public.pt_admins enable row level security;
drop policy if exists "pt_admins_read" on public.pt_admins;
create policy "pt_admins_read" on public.pt_admins for select to authenticated using (email = public.pt_me());
insert into public.pt_admins(email) select lower(email) from public.coaches on conflict do nothing;

create or replace function public.pt_is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_coach() or exists (select 1 from public.pt_admins where email = public.pt_me());
$$;

-- ---------- Estados del coach: pending (en revisión) y rejected ----------
alter table public.pt_coaches drop constraint if exists pt_coaches_status_check;
alter table public.pt_coaches add constraint pt_coaches_status_check
  check (status in ('pending','trial','active','suspended','rejected'));
alter table public.pt_coaches add column if not exists reviewed_at timestamptz;
alter table public.pt_coaches add column if not exists reviewed_by text;

-- Solo es coach quien está en prueba o activo (o el coach principal)
create or replace function public.pt_is_coach() returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_coach()
      or exists (select 1 from public.pt_coaches where email = public.pt_me() and status in ('trial','active'));
$$;

drop policy if exists "pt_coaches_read" on public.pt_coaches;
create policy "pt_coaches_read" on public.pt_coaches for select to authenticated
  using (email = public.pt_me() or public.pt_is_admin());

create or replace function public.pt_my_role() returns json
language plpgsql stable security definer set search_path = public as $$
declare em text := public.pt_me(); c record; l record;
begin
  select * into c from public.pt_coaches where email = em;
  select * into l from public.pt_links where athlete_email = em and status = 'active' limit 1;
  return json_build_object(
    'coach',  public.pt_is_coach(),
    'admin',  public.pt_is_admin(),
    'main',   public.is_coach(),
    'status', coalesce(c.status, case when public.is_coach() then 'active' else null end),
    'trial_ends_at', c.trial_ends_at,
    'linked', l.id is not null,
    'coach_email', l.coach_email);
end $$;

-- Registro de coach: queda EN REVISIÓN y oculto del catálogo hasta que el administrador lo acepte
create or replace function public.pt_register_coach(p_name text) returns json
language plpgsql security definer set search_path = public, auth as $$
declare em text := public.pt_me();
begin
  if auth.uid() is null or em = '' then raise exception 'not_authenticated'; end if;
  if exists (select 1 from public.pt_links where athlete_email = em and status = 'active') then
    raise exception 'already_athlete';
  end if;
  insert into public.pt_coaches(email, user_id, name, status, trial_ends_at)
  values (em, auth.uid(), nullif(trim(p_name), ''), 'pending', null)
  on conflict (email) do nothing;
  insert into public.pt_coach_profiles(email, doc, public)
  values (em, jsonb_build_object('name', coalesce(nullif(trim(p_name), ''), split_part(em, '@', 1))), false)
  on conflict (email) do nothing;
  return public.pt_my_role();
end $$;

-- ---------- Panel del administrador ----------
create or replace function public.pt_admin_coaches()
returns table(email text, name text, status text, trial_ends_at timestamptz, created_at timestamptz,
              reviewed_at timestamptz, clients int, requests int, is_main boolean)
language sql stable security definer set search_path = public as $$
  select c.email, coalesce(nullif(p.doc->>'name',''), c.name, split_part(c.email,'@',1)), c.status, c.trial_ends_at, c.created_at,
         c.reviewed_at,
         (select count(*)::int from public.pt_links l where l.coach_email = c.email and l.status = 'active'),
         (select count(*)::int from public.pt_links l where l.coach_email = c.email and l.status = 'pending'),
         exists (select 1 from public.coaches k where lower(k.email) = c.email)
  from public.pt_coaches c left join public.pt_coach_profiles p on p.email = c.email
  where public.pt_is_admin()
  order by (c.status = 'pending') desc, c.created_at;
$$;

create or replace function public.pt_admin_clients()
returns table(coach_email text, athlete_email text, full_name text, status text, since timestamptz, call_at timestamptz)
language sql stable security definer set search_path = public as $$
  select l.coach_email, l.athlete_email, coalesce(p.full_name, ''), l.status, l.updated_at, l.call_at
  from public.pt_links l left join public.profiles p on lower(p.email) = l.athlete_email
  where public.pt_is_admin() and l.status in ('active','pending','invited')
  union all
  select null, lower(p.email), coalesce(p.full_name, ''), 'none', p.created_at, null
  from public.profiles p
  where public.pt_is_admin()
    and lower(p.email) not in (select athlete_email from public.pt_links where status in ('active','pending','invited'))
    and lower(p.email) not in (select email from public.pt_coaches)
    and lower(p.email) not in (select lower(email) from public.coaches);
$$;

create or replace function public.pt_admin_review_coach(p_email text, p_accept boolean) returns text
language plpgsql security definer set search_path = public as $$
declare em text := lower(trim(coalesce(p_email, ''))); n int;
begin
  if not public.pt_is_admin() then raise exception 'not_admin'; end if;
  if p_accept then
    update public.pt_coaches set status = 'trial', trial_ends_at = now() + interval '14 days',
           reviewed_at = now(), reviewed_by = public.pt_me()
    where email = em and status in ('pending','rejected');
    get diagnostics n = row_count;
    update public.pt_coach_profiles set public = true, updated_at = now() where email = em;
  else
    update public.pt_coaches set status = 'rejected', reviewed_at = now(), reviewed_by = public.pt_me()
    where email = em and status = 'pending';
    get diagnostics n = row_count;
    update public.pt_coach_profiles set public = false, updated_at = now() where email = em;
  end if;
  if n = 0 then raise exception 'coach_not_found'; end if;
  return case when p_accept then 'trial' else 'rejected' end;
end $$;

-- ---------- Llamada inicial de 15 minutos ----------

drop function if exists public.pt_request_coach(text);
create or replace function public.pt_request_coach(p_coach text, p_call timestamptz default null, p_note text default null) returns text
language plpgsql security definer set search_path = public as $$
declare em text := public.pt_me(); co text := lower(trim(coalesce(p_coach, '')));
begin
  if auth.uid() is null or em = '' then raise exception 'not_authenticated'; end if;
  if public.pt_is_coach() then raise exception 'coach_cannot_request'; end if;
  if not exists (select 1 from public.pt_coach_profiles where email = co and public) then raise exception 'coach_not_found'; end if;
  if exists (select 1 from public.pt_links where athlete_email = em and status = 'active') then raise exception 'already_linked'; end if;
  if p_call is not null and (p_call < now() or p_call > now() + interval '60 days') then raise exception 'bad_call_time'; end if;
  if p_call is not null and exists (select 1 from public.pt_links where coach_email = co and status in ('pending','active')
                                    and call_at = p_call and athlete_email <> em) then raise exception 'slot_taken'; end if;
  update public.pt_links set status = 'ended', updated_at = now() where athlete_email = em and status = 'pending';
  insert into public.pt_links(athlete_email, coach_email, status, call_at, note)
  values (em, co, 'pending', p_call, nullif(left(trim(coalesce(p_note, '')), 500), ''));
  return 'pending';
end $$;

-- Horarios ya apartados con un coach (solo fecha y hora, sin datos de nadie)
create or replace function public.pt_coach_busy(p_coach text) returns setof timestamptz
language sql stable security definer set search_path = public as $$
  select call_at from public.pt_links
  where coach_email = lower(trim(coalesce(p_coach, ''))) and status in ('pending','active')
    and call_at is not null and call_at > now();
$$;

-- Solicitudes del coach, ahora con la llamada propuesta
drop function if exists public.pt_coach_requests();
create or replace function public.pt_coach_requests()
returns table(athlete_email text, full_name text, status text, created_at timestamptz, call_at timestamptz, note text)
language sql stable security definer set search_path = public as $$
  select l.athlete_email, coalesce(p.full_name, ''), l.status, l.created_at, l.call_at, l.note
  from public.pt_links l left join public.profiles p on lower(p.email) = l.athlete_email
  where l.coach_email = public.pt_me() and l.status in ('pending','invited') and public.pt_is_coach()
  order by l.created_at desc;
$$;

-- El cliente puede leer su propio vínculo (con la hora de la llamada)
drop policy if exists "pt_links_read" on public.pt_links;
create policy "pt_links_read" on public.pt_links for select to authenticated
  using (athlete_email = public.pt_me() or coach_email = public.pt_me() or public.pt_is_admin());

-- ---------- Baja del coach (lo hace el propio coach) ----------
create or replace function public.delete_my_coach_account() returns json
language plpgsql security definer set search_path = public, auth, storage as $$
declare em text := lower(coalesce(auth.jwt() ->> 'email', '')); r record; n int := 0;
begin
  if auth.uid() is null or em = '' then raise exception 'not_authenticated'; end if;
  if public.is_coach() or exists (select 1 from public.pt_admins where email = em) then raise exception 'admin_cannot_delete'; end if;
  if not exists (select 1 from public.pt_coaches where email = em) then raise exception 'not_coach'; end if;
  -- avisar a sus clientes y liberarlos (conservan todo su historial)
  for r in select athlete_email from public.pt_links where coach_email = em and status = 'active' loop
    insert into public.pt_notifs(id, athlete_email, doc)
    values (gen_random_uuid()::text, r.athlete_email,
            jsonb_build_object('id', gen_random_uuid()::text, 'athleteId', r.athlete_email,
              'text', 'Tu coach dejó ProTrainerPlus. Tu historial sigue aquí: elige un nuevo coach cuando quieras 💪',
              'ts', (extract(epoch from now()) * 1000)::bigint, 'read', false));
    n := n + 1;
  end loop;
  update public.pt_links set status = 'ended', updated_at = now() where coach_email = em and status in ('active','pending','invited');
  delete from public.pt_templates where coach_email = em;
  delete from public.pt_coach_profiles where email = em;
  delete from public.pt_coaches where email = em;
  delete from public.pt_links where athlete_email = em;
  return (public._pt_purge_email(em)::jsonb || jsonb_build_object('clients_released', n))::json;
end $$;

-- ---------- Permisos ----------
do $$
declare f text;
begin
  foreach f in array array['pt_is_admin()','pt_admin_coaches()','pt_admin_clients()','pt_admin_review_coach(text,boolean)',
    'pt_request_coach(text,timestamptz,text)','pt_coach_busy(text)','pt_coach_requests()','delete_my_coach_account()',
    'pt_my_role()','pt_register_coach(text)','pt_is_coach()'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
