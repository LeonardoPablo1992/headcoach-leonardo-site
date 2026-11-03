-- =========================================================
-- ProTrainerPlus · CALIFICACIONES DE COACHES (1 a 5 estrellas)
-- El cliente califica a su coach en 5 aspectos: compromiso, resultados, seguimiento,
-- puntualidad y conocimiento (+ comentario opcional). Una calificación por cliente y coach,
-- que puede actualizar cuando quiera. El catálogo muestra el promedio y cuántas personas calificaron.
-- Ejecutar en Supabase → SQL Editor. Se puede volver a correr.
-- =========================================================

create table if not exists public.pt_coach_ratings (
  athlete_email text not null,
  coach_email   text not null,
  compromiso    smallint not null check (compromiso between 1 and 5),
  resultados    smallint not null check (resultados between 1 and 5),
  seguimiento   smallint not null check (seguimiento between 1 and 5),
  puntualidad   smallint not null check (puntualidad between 1 and 5),
  conocimiento  smallint not null check (conocimiento between 1 and 5),
  comment       text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  primary key (athlete_email, coach_email)
);
create index if not exists pt_coach_ratings_coach_idx on public.pt_coach_ratings (coach_email);
alter table public.pt_coach_ratings enable row level security;
drop policy if exists "pt_ratings_own" on public.pt_coach_ratings;
create policy "pt_ratings_own" on public.pt_coach_ratings for select to authenticated
  using (athlete_email = public.pt_me() or public.pt_is_admin());

-- Calificar (solo a tu coach actual)
create or replace function public.pt_rate_coach(p_coach text, p_compromiso int, p_resultados int, p_seguimiento int,
                                                p_puntualidad int, p_conocimiento int, p_comment text default null) returns json
language plpgsql security definer set search_path = public as $$
declare em text := public.pt_me(); co text := lower(trim(coalesce(p_coach, '')));
begin
  if auth.uid() is null or em = '' then raise exception 'not_authenticated'; end if;
  if em = co then raise exception 'cannot_rate_self'; end if;
  if not exists (select 1 from public.pt_links where athlete_email = em and coach_email = co and status = 'active') then
    raise exception 'not_your_coach';
  end if;
  insert into public.pt_coach_ratings(athlete_email, coach_email, compromiso, resultados, seguimiento, puntualidad, conocimiento, comment)
  values (em, co, p_compromiso, p_resultados, p_seguimiento, p_puntualidad, p_conocimiento, nullif(left(trim(coalesce(p_comment, '')), 600), ''))
  on conflict (athlete_email, coach_email) do update set
    compromiso = excluded.compromiso, resultados = excluded.resultados, seguimiento = excluded.seguimiento,
    puntualidad = excluded.puntualidad, conocimiento = excluded.conocimiento, comment = excluded.comment, updated_at = now();
  return json_build_object('ok', true);
end $$;

-- Promedios por coach (sin datos de quién calificó)
create or replace function public.pt_coach_rating_summary()
returns table(coach_email text, n int, avg numeric, compromiso numeric, resultados numeric, seguimiento numeric, puntualidad numeric, conocimiento numeric)
language sql stable security definer set search_path = public as $$
  select coach_email, count(*)::int,
         round(avg((compromiso + resultados + seguimiento + puntualidad + conocimiento) / 5.0), 2),
         round(avg(compromiso), 2), round(avg(resultados), 2), round(avg(seguimiento), 2),
         round(avg(puntualidad), 2), round(avg(conocimiento), 2)
  from public.pt_coach_ratings group by coach_email;
$$;

-- Comentarios para el propio coach (anónimos) y para el administrador
create or replace function public.pt_my_coach_reviews()
returns table(score numeric, comment text, updated_at timestamptz)
language sql stable security definer set search_path = public as $$
  select round((compromiso + resultados + seguimiento + puntualidad + conocimiento) / 5.0, 1), comment, updated_at
  from public.pt_coach_ratings
  where coach_email = public.pt_me() and comment is not null
  order by updated_at desc limit 50;
$$;

do $$
declare f text;
begin
  foreach f in array array['pt_rate_coach(text,int,int,int,int,int,text)','pt_coach_rating_summary()','pt_my_coach_reviews()'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- Al dar de baja a una persona se borran sus calificaciones (como clienta o como coach)
create or replace function public._pt_purge_ratings() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  delete from public.pt_coach_ratings where athlete_email = lower(old.email) or coach_email = lower(old.email);
  return old;
end $$;
drop trigger if exists pt_purge_ratings on auth.users;
create trigger pt_purge_ratings after delete on auth.users for each row execute function public._pt_purge_ratings();
