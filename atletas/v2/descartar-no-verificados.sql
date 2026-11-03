-- =========================================================
-- ProTrainerPlus · DESCARTAR REGISTROS NO VERIFICADOS (24 h)
-- Si una cuenta nueva (coach o atleta) no confirma su correo en 24 horas, se descarta:
-- se borran su acceso, su perfil y cualquier solicitud pendiente. Puede volver a registrarse.
-- Corre solo cada hora con pg_cron. Se puede volver a correr sin problema.
--
-- Protecciones: nunca toca cuentas que ya entraron alguna vez, que tienen entrenamientos,
-- que tienen coach activo o que son del coach principal.
-- =========================================================

create or replace function public.pt_purge_unverified() returns int
language plpgsql security definer set search_path = public, auth, storage as $$
declare r record; n int := 0;
begin
  for r in
    select lower(u.email) as em from auth.users u
    where u.email is not null
      and u.email_confirmed_at is null
      and u.last_sign_in_at is null
      and u.created_at < now() - interval '24 hours'
  loop
    if exists (select 1 from public.coaches where lower(email) = r.em)
       or exists (select 1 from public.pt_tasks where athlete_email = r.em)
       or exists (select 1 from public.pt_links where athlete_email = r.em and status = 'active')
       or exists (select 1 from public.pt_coaches where email = r.em and status in ('trial','active')) then
      continue;
    end if;
    delete from public.pt_links where athlete_email = r.em and status in ('pending','invited');
    delete from public.pt_links where coach_email = r.em and status in ('pending','invited');
    delete from public.pt_coach_profiles where email = r.em;
    delete from public.pt_coaches where email = r.em;
    perform public._pt_purge_email(r.em);   -- perfil, datos y acceso (auth.users)
    n := n + 1;
  end loop;
  return n;
end $$;
revoke all on function public.pt_purge_unverified() from public, anon, authenticated;

-- Tarea programada: cada hora, al minuto 17
create extension if not exists pg_cron;
do $$
begin
  perform cron.unschedule(jobid) from cron.job where jobname = 'ptp-descartar-no-verificados';
  perform cron.schedule('ptp-descartar-no-verificados', '17 * * * *', 'select public.pt_purge_unverified()');
end $$;
