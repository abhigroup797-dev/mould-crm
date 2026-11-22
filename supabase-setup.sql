-- Mould CRM database setup for Supabase.
-- Run this once: Supabase > SQL Editor > New query > paste everything > Run.
-- It is safe to run again.

-- ---------- employees ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  name text not null default '',
  role text,                         -- 'admin', 'designer', 'op:VMC', ... ; null = no access
  created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;

create or replace function public.my_role() returns text
language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid()
$$;

create or replace function public.is_member() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select role is not null from public.profiles where id = auth.uid()), false)
$$;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select role = 'admin' from public.profiles where id = auth.uid()), false)
$$;

-- The login page uses this to know whether the first (admin) account still has to be created.
create or replace function public.has_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where role = 'admin')
$$;

-- Every new account gets a profile row. The very first account becomes admin.
-- Every later account has no access until an admin gives it a panel.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, name, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'name', ''),
    case when exists (select 1 from public.profiles where role = 'admin') then null else 'admin' end
  )
  on conflict (id) do nothing;
  return new;
end
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Admin sets a new password for an employee.
create or replace function public.admin_set_password(p_user uuid, p_password text) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  if not public.is_admin() then
    raise exception 'Only an admin can set passwords';
  end if;
  if length(p_password) < 6 then
    raise exception 'Password must be at least 6 characters';
  end if;
  update auth.users
     set encrypted_password = crypt(p_password, gen_salt('bf')), updated_at = now()
   where id = p_user;
end
$$;

drop policy if exists "profiles read" on public.profiles;
create policy "profiles read" on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_member());

drop policy if exists "profiles admin update" on public.profiles;
create policy "profiles admin update" on public.profiles for update to authenticated
  using (public.is_admin()) with check (true);

-- ---------- CRM data (moulds, parts, job work, file records) ----------
create table if not exists public.items (
  id uuid primary key default gen_random_uuid(),
  coll text not null,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.items drop constraint if exists items_coll_check;
alter table public.items add constraint items_coll_check
  check (coll in ('projects', 'parts', 'jobwork', 'files', 'productphotos', 'settings', 'tasks'));
create index if not exists items_coll_idx on public.items (coll);
alter table public.items enable row level security;

drop policy if exists "items read" on public.items;
create policy "items read" on public.items for select to authenticated
  using (public.is_member());

drop policy if exists "items add" on public.items;
-- Only an admin changes the dashboard settings.
create policy "items add" on public.items for insert to authenticated
  with check (public.is_member() and (coll <> 'settings' or public.is_admin()));

drop policy if exists "items change" on public.items;
create policy "items change" on public.items for update to authenticated
  using (public.is_member() and (coll <> 'settings' or public.is_admin()))
  with check (public.is_member() and (coll <> 'settings' or public.is_admin()));

-- Only an admin deletes moulds and parts. Anyone with access can delete job work
-- and the files they uploaded themselves.
drop policy if exists "items delete" on public.items;
create policy "items delete" on public.items for delete to authenticated
  using (
    public.is_admin()
    or coll = 'jobwork'
    or (coll = 'files' and data ->> 'by' = auth.uid()::text)
  );

-- Merges a change into one row, so two people editing the same part do not overwrite each other.
create or replace function public.merge_item(p_id uuid, p_patch jsonb) returns void
language sql security invoker set search_path = public as $$
  update public.items
     set data = (data || (p_patch - 'ops'))
                || case when p_patch ? 'ops'
                        then jsonb_build_object('ops', coalesce(data -> 'ops', '{}'::jsonb) || (p_patch -> 'ops'))
                        else '{}'::jsonb end,
         updated_at = now()
   where id = p_id
$$;

-- ---------- permissions for the website ----------
grant usage on schema public to anon, authenticated;
grant select, update on public.profiles to authenticated;
grant select, insert, update, delete on public.items to authenticated;
grant execute on function public.has_admin() to anon, authenticated;
grant execute on function public.my_role(), public.is_member(), public.is_admin() to authenticated;
grant execute on function public.merge_item(uuid, jsonb) to authenticated;
grant execute on function public.admin_set_password(uuid, text) to authenticated;

-- ---------- live updates ----------
do $$
begin
  alter publication supabase_realtime add table public.items;
exception when others then null;
end
$$;

-- ---------- file storage (private, 50 MB per file) ----------
insert into storage.buckets (id, name, public, file_size_limit)
values ('mould-files', 'mould-files', false, 52428800)
on conflict (id) do nothing;

drop policy if exists "mould files read" on storage.objects;
create policy "mould files read" on storage.objects for select to authenticated
  using (bucket_id = 'mould-files' and public.is_member());

drop policy if exists "mould files upload" on storage.objects;
create policy "mould files upload" on storage.objects for insert to authenticated
  with check (bucket_id = 'mould-files' and public.is_member());

drop policy if exists "mould files delete" on storage.objects;
create policy "mould files delete" on storage.objects for delete to authenticated
  using (bucket_id = 'mould-files' and (public.is_admin() or owner_id = auth.uid()::text));
