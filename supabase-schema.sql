-- ============================================================
-- IT SERVICE REPORTS · Esquema Supabase
-- ============================================================
-- Cómo usar:
--   1. En tu proyecto Supabase → SQL Editor → New query
--   2. Pega TODO este archivo y corre ("Run")
--   3. Ve a Authentication → Providers → Email:
--        - Deja "Email" habilitado
--        - (Recomendado) Desactiva "Confirm email" durante el arranque
--          para que los usuarios creados desde la app entren de una
-- ============================================================

-- ================ TABLA: profiles ==========================
-- Extiende auth.users con rol, nombre, teléfono
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default '',
  email text not null,
  phone text,
  role text not null default 'technician'
    check (role in ('technician','supervisor','admin','super_admin')),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

-- ================ TABLA: clients ===========================
create table if not exists public.clients (
  id text primary key,
  name text not null default '',
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ================ TABLA: reports ===========================
create table if not exists public.reports (
  id text primary key,
  number text,
  client_id text,
  status text,
  date date,
  technician_id uuid references auth.users(id) on delete set null,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists reports_technician_idx on public.reports(technician_id);
create index if not exists reports_status_idx on public.reports(status);
create index if not exists reports_date_idx on public.reports(date desc);

-- ================ TABLA: app_settings ======================
-- Configuración global compartida entre todos los dispositivos
-- (logo, nombre de la empresa, colores de marca, etc.)
create table if not exists public.app_settings (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null
);

-- ================ GRANTS ===================================
-- Sin GRANTs, los roles del cliente reciben 'permission denied for table'
-- incluso si las políticas RLS son correctas. Postgres verifica grants
-- ANTES de evaluar las políticas RLS.
grant usage on schema public to authenticated, anon, service_role;
grant all on public.profiles     to authenticated, anon, service_role;
grant all on public.clients      to authenticated, anon, service_role;
grant all on public.reports      to authenticated, anon, service_role;
grant all on public.app_settings to authenticated, anon, service_role;

-- ================ TRIGGER: updated_at ======================
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end;$$;

drop trigger if exists touch_clients on public.clients;
create trigger touch_clients before update on public.clients
  for each row execute function public.touch_updated_at();

drop trigger if exists touch_reports on public.reports;
create trigger touch_reports before update on public.reports
  for each row execute function public.touch_updated_at();

-- ================ TRIGGER: nuevo perfil al sign-up =========
-- Cuando alguien se registra por auth.users, se crea su fila en profiles
-- (usando metadata name/phone/role si vino en el signUp, o defaults)
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, name, email, phone, role, active)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email,'@',1)),
    new.email,
    new.raw_user_meta_data->>'phone',
    coalesce(new.raw_user_meta_data->>'role', 'technician'),
    true
  )
  on conflict (id) do nothing;
  return new;
end;$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ================ HELPER: rol del usuario actual ==========
-- IMPORTANTE: estas funciones consultan public.profiles, que tiene RLS.
-- Deben ser SECURITY DEFINER para saltarse el RLS y evitar recursión
-- infinita cuando se usan dentro de las mismas políticas RLS.
create or replace function public.current_role_v()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid()
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select role in ('admin','super_admin','supervisor')
                   from public.profiles where id = auth.uid()), false)
$$;

create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select role = 'super_admin'
                   from public.profiles where id = auth.uid()), false)
$$;

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
alter table public.profiles enable row level security;
alter table public.clients  enable row level security;
alter table public.reports  enable row level security;

-- ------- profiles -------
-- Se usan políticas separadas para SELECT/UPDATE (own vs admin) porque
-- múltiples políticas se combinan con OR y así evitamos cualquier
-- posible recursión al evaluar helpers dentro de una sola política.
drop policy if exists profiles_self_read on public.profiles;
drop policy if exists profiles_read_own on public.profiles;
create policy profiles_read_own on public.profiles
  for select using (auth.uid() = id);

drop policy if exists profiles_read_all_admin on public.profiles;
create policy profiles_read_all_admin on public.profiles
  for select using (public.is_admin());

drop policy if exists profiles_self_update on public.profiles;
drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists profiles_update_all_super on public.profiles;
create policy profiles_update_all_super on public.profiles
  for update using (public.is_super_admin()) with check (public.is_super_admin());

drop policy if exists profiles_admin_insert on public.profiles;
drop policy if exists profiles_insert on public.profiles;
create policy profiles_insert on public.profiles
  for insert with check (auth.uid() = id or public.is_super_admin());

drop policy if exists profiles_admin_delete on public.profiles;
drop policy if exists profiles_delete_super on public.profiles;
create policy profiles_delete_super on public.profiles
  for delete using (public.is_super_admin());

-- ------- clients (todos los usuarios autenticados pueden ver/crear) -------
drop policy if exists clients_read on public.clients;
create policy clients_read on public.clients
  for select using (auth.role() = 'authenticated');

drop policy if exists clients_write on public.clients;
create policy clients_write on public.clients
  for insert with check (auth.role() = 'authenticated');

drop policy if exists clients_update on public.clients;
create policy clients_update on public.clients
  for update using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

drop policy if exists clients_delete on public.clients;
create policy clients_delete on public.clients
  for delete using (public.is_admin());

-- ------- reports -------
-- Técnicos ven sus reportes; admins/supervisores ven todos
drop policy if exists reports_read on public.reports;
create policy reports_read on public.reports
  for select using (
    technician_id = auth.uid() or public.is_admin()
  );

drop policy if exists reports_insert on public.reports;
create policy reports_insert on public.reports
  for insert with check (
    auth.role() = 'authenticated' and
    (technician_id = auth.uid() or public.is_admin())
  );

drop policy if exists reports_update on public.reports;
create policy reports_update on public.reports
  for update using (
    technician_id = auth.uid() or public.is_admin()
  ) with check (
    technician_id = auth.uid() or public.is_admin()
  );

drop policy if exists reports_delete on public.reports;
create policy reports_delete on public.reports
  for delete using (public.is_admin());

-- ------- app_settings -------
alter table public.app_settings enable row level security;

drop policy if exists app_settings_read on public.app_settings;
create policy app_settings_read on public.app_settings
  for select using (auth.role() = 'authenticated');

drop policy if exists app_settings_write on public.app_settings;
create policy app_settings_write on public.app_settings
  for insert with check (public.is_super_admin());

drop policy if exists app_settings_update on public.app_settings;
create policy app_settings_update on public.app_settings
  for update using (public.is_super_admin()) with check (public.is_super_admin());

-- ============================================================
-- OPCIONAL: crea al primer super admin (edita el email/pass)
-- ============================================================
-- 1) Ve a Authentication → Users → "Add user" y crea el correo
-- 2) Luego corre esta línea reemplazando el correo:
--    update public.profiles set role='super_admin', name='Nombre Completo'
--    where email='admin@tuempresa.com';
