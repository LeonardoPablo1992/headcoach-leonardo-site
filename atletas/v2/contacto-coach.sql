-- =========================================================
-- ProTrainerPlus · CONTACTO DEL COACH (teléfono y WhatsApp)
-- El número se guarda aparte del perfil público para proteger el dato:
--   · Lo ven siempre sus clientes activos y el administrador.
--   · En el catálogo solo si el coach marca «Mostrar mi WhatsApp en el catálogo».
-- Además, el cliente activo puede leer el perfil de su coach aunque esté oculto del catálogo.
-- Ejecutar en Supabase → SQL Editor. Se puede volver a correr.
-- =========================================================

create table if not exists public.pt_coach_contacts (
  email       text primary key,
  phone       text,               -- solo dígitos con lada de país, p. ej. 5215512345678
  show_public boolean not null default false,
  updated_at  timestamptz not null default now()
);
alter table public.pt_coach_contacts enable row level security;

-- ¿Es mi coach activo?
create or replace function public.pt_is_my_coach(p_coach text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.pt_links
                 where athlete_email = public.pt_me() and coach_email = lower(p_coach) and status = 'active');
$$;
revoke all on function public.pt_is_my_coach(text) from public, anon;
grant execute on function public.pt_is_my_coach(text) to authenticated;

drop policy if exists "pt_cc_read" on public.pt_coach_contacts;
create policy "pt_cc_read" on public.pt_coach_contacts for select to authenticated
  using (email = public.pt_me() or public.pt_is_admin() or public.pt_is_my_coach(email)
         or (show_public and exists (select 1 from public.pt_coach_profiles p where p.email = pt_coach_contacts.email and p.public)));
drop policy if exists "pt_cc_write" on public.pt_coach_contacts;
create policy "pt_cc_write" on public.pt_coach_contacts for all to authenticated
  using (email = public.pt_me() and public.pt_is_coach())
  with check (email = public.pt_me() and public.pt_is_coach());

-- El cliente activo ve el perfil de su coach (aunque no esté en el catálogo)
drop policy if exists "pt_cp_read" on public.pt_coach_profiles;
create policy "pt_cp_read" on public.pt_coach_profiles for select to authenticated
  using (public or email = public.pt_me() or public.pt_is_admin() or public.pt_is_my_coach(email));

-- Al borrar una cuenta, se borra su contacto
create or replace function public._pt_purge_contact() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  delete from public.pt_coach_contacts where email = lower(old.email);
  return old;
end $$;
drop trigger if exists pt_purge_contact on auth.users;
create trigger pt_purge_contact after delete on auth.users for each row execute function public._pt_purge_contact();
