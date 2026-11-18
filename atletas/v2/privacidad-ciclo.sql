-- =====================================================================
-- ProTrainerPlus · Privacidad del ciclo menstrual (HU-02)
--
-- Qué hace:
--   1. La atleta decide si su coach ve su ciclo menstrual (fila pt_evo
--      id = 'cycpriv_<correo>', kind = 'cyclePriv', doc.share = true/false).
--   2. Si NO comparte, Supabase no le entrega al coach (ni a nadie más que
--      a ella) los registros kind = 'cycle'. Se aplica en el servidor (RLS),
--      no solo ocultándolo en pantalla.
--   3. Solo la atleta puede crear o cambiar su fila de privacidad.
--   4. Migración: las atletas que YA registraban su ciclo quedan
--      «compartiendo» (así funcionaba antes y aceptaron el aviso de
--      privacidad que lo incluye). Pueden dejar de compartir desde su perfil.
--      Quien empiece a registrarlo desde hoy queda en «solo yo».
--
-- Qué NO hace: no borra ni modifica registros del ciclo.
-- Correr después de multi-coach.sql y admin-coaches.sql.
-- Se puede correr más de una vez.
--
-- Cómo correrlo: Supabase → SQL Editor → New query → pega todo → Run.
-- =====================================================================

-- ¿La atleta comparte su ciclo con su coach? (security definer: lee pt_evo
-- sin pasar por RLS, para evitar recursión dentro de las políticas)
create or replace function public.pt_cycle_shared(em text) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((
    select (doc->>'share')::boolean
    from public.pt_evo
    where athlete_email = lower(em) and doc->>'kind' = 'cyclePriv'
    order by updated_at desc
    limit 1
  ), false)
$$;
revoke all on function public.pt_cycle_shared(text) from public, anon;
grant execute on function public.pt_cycle_shared(text) to authenticated;

-- Políticas RESTRICTIVAS (se suman como "y además" a las existentes)
-- Lectura: los registros del ciclo solo los ve la atleta, o su coach si ella comparte.
drop policy if exists "pt_cycle_priv_sel" on public.pt_evo;
create policy "pt_cycle_priv_sel" on public.pt_evo as restrictive for select to authenticated
  using (
    athlete_email = public.pt_me()
    or coalesce(doc->>'kind','') <> 'cycle'
    or public.pt_cycle_shared(athlete_email)
  );

-- Alta: el coach solo puede registrar ciclo si ella comparte; la fila de privacidad solo la crea ella.
drop policy if exists "pt_cycle_priv_ins" on public.pt_evo;
create policy "pt_cycle_priv_ins" on public.pt_evo as restrictive for insert to authenticated
  with check (
    athlete_email = public.pt_me()
    or (coalesce(doc->>'kind','') <> 'cycle' and coalesce(doc->>'kind','') <> 'cyclePriv')
    or (doc->>'kind' = 'cycle' and public.pt_cycle_shared(athlete_email))
  );

-- Cambios: mismas reglas antes y después del cambio.
drop policy if exists "pt_cycle_priv_upd" on public.pt_evo;
create policy "pt_cycle_priv_upd" on public.pt_evo as restrictive for update to authenticated
  using (
    athlete_email = public.pt_me()
    or (coalesce(doc->>'kind','') <> 'cycle' and coalesce(doc->>'kind','') <> 'cyclePriv')
    or (doc->>'kind' = 'cycle' and public.pt_cycle_shared(athlete_email))
  )
  with check (
    athlete_email = public.pt_me()
    or (coalesce(doc->>'kind','') <> 'cycle' and coalesce(doc->>'kind','') <> 'cyclePriv')
    or (doc->>'kind' = 'cycle' and public.pt_cycle_shared(athlete_email))
  );

-- Borrado: los registros del ciclo y la privacidad no los borra nadie más que la atleta
-- (las funciones de eliminar cuenta/cliente son security definer y siguen funcionando).
drop policy if exists "pt_cycle_priv_del" on public.pt_evo;
create policy "pt_cycle_priv_del" on public.pt_evo as restrictive for delete to authenticated
  using (
    athlete_email = public.pt_me()
    or (coalesce(doc->>'kind','') <> 'cycle' and coalesce(doc->>'kind','') <> 'cyclePriv')
  );

-- Migración: quienes ya registraban su ciclo siguen compartiendo (comportamiento anterior).
insert into public.pt_evo (id, athlete_email, doc, updated_at)
select 'cycpriv_' || e.athlete_email,
       e.athlete_email,
       jsonb_build_object(
         'id', 'cycpriv_' || e.athlete_email,
         'athleteId', e.athlete_email,
         'kind', 'cyclePriv',
         'share', true,
         'legacy', true,
         'date', to_char(current_date, 'YYYY-MM-DD'),
         'ts', (extract(epoch from now()) * 1000)::bigint
       ),
       now()
from (select distinct athlete_email from public.pt_evo where doc->>'kind' = 'cycle') e
on conflict (id) do nothing;

-- Verificación: lista las 4 políticas nuevas y cuántas atletas quedaron compartiendo
select policyname, permissive, cmd from pg_policies
 where schemaname = 'public' and tablename = 'pt_evo' and policyname like 'pt_cycle_priv%';
select count(*) as atletas_compartiendo from public.pt_evo
 where doc->>'kind' = 'cyclePriv' and (doc->>'share')::boolean;
