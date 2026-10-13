-- Run once in a new Supabase project's SQL Editor.
create table public.reading_groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 80),
  owner_id uuid not null references auth.users(id),
  start_date date,
  timezone text not null default 'America/Chicago',
  created_at timestamptz not null default now()
);
create table public.group_members (
  group_id uuid not null references public.reading_groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 60),
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);
create index members_user on public.group_members(user_id);
create table public.group_invitations (
  group_id uuid primary key references public.reading_groups(id) on delete cascade,
  code uuid not null unique default gen_random_uuid()
);
create table public.completions (
  group_id uuid not null,
  user_id uuid not null,
  day smallint not null check (day between 1 and 365),
  completed_at timestamptz not null default now(),
  primary key (group_id, user_id, day),
  foreign key (group_id, user_id) references public.group_members(group_id, user_id) on delete cascade
);
create table public.reflections (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null,
  user_id uuid not null,
  day smallint not null check (day between 1 and 365),
  body text not null check (char_length(trim(body)) between 1 and 3000),
  created_at timestamptz not null default now(),
  foreign key (group_id, user_id) references public.group_members(group_id, user_id) on delete cascade
);
create index reflections_day on public.reflections(group_id, day, created_at);

create function public.is_group_member(target uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.group_members where group_id=target and user_id=auth.uid());
$$;
alter table public.reading_groups enable row level security;
alter table public.group_members enable row level security;
alter table public.group_invitations enable row level security;
alter table public.completions enable row level security;
alter table public.reflections enable row level security;
create policy groups_read on public.reading_groups for select to authenticated using (public.is_group_member(id));
create policy members_read on public.group_members for select to authenticated using (public.is_group_member(group_id));
create policy completions_read on public.completions for select to authenticated using (public.is_group_member(group_id));
create policy completions_insert on public.completions for insert to authenticated with check (user_id=auth.uid() and public.is_group_member(group_id));
create policy completions_delete on public.completions for delete to authenticated using (user_id=auth.uid() and public.is_group_member(group_id));
create policy reflections_read on public.reflections for select to authenticated using (public.is_group_member(group_id));
create policy reflections_insert on public.reflections for insert to authenticated with check (user_id=auth.uid() and public.is_group_member(group_id));
create policy reflections_delete on public.reflections for delete to authenticated using (user_id=auth.uid() and public.is_group_member(group_id));

create function public.create_reading_group(group_name text, member_name text, zone text, starts date default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare gid uuid;
begin
  if auth.uid() is null then raise exception 'Sign in first'; end if;
  if not exists(select 1 from pg_catalog.pg_timezone_names where name=zone) then raise exception 'Invalid timezone'; end if;
  insert into public.reading_groups(name,owner_id,timezone,start_date) values(trim(group_name),auth.uid(),zone,starts) returning id into gid;
  insert into public.group_members values(gid,auth.uid(),trim(member_name),now());
  insert into public.group_invitations(group_id) values(gid);
  return gid;
end; $$;
create function public.join_reading_group(invite_code uuid, member_name text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare gid uuid;
begin
  if auth.uid() is null then raise exception 'Sign in first'; end if;
  select group_id into gid from public.group_invitations where code=invite_code;
  if gid is null then raise exception 'Invitation not found. Ask the group owner for a current code.'; end if;
  insert into public.group_members values(gid,auth.uid(),trim(member_name),now()) on conflict do nothing;
  return gid;
end; $$;
create function public.group_invite(target uuid, rotate boolean default false)
returns uuid language plpgsql security definer set search_path = '' as $$
declare result uuid;
begin
  if not exists(select 1 from public.reading_groups where id=target and owner_id=auth.uid()) then raise exception 'Only the group owner can manage invitations'; end if;
  if rotate then update public.group_invitations set code=gen_random_uuid() where group_id=target; end if;
  select code into result from public.group_invitations where group_id=target;
  return result;
end; $$;
create function public.set_group_start(target uuid, starts date)
returns void language plpgsql security definer set search_path = '' as $$
declare g public.reading_groups;
begin
  select * into g from public.reading_groups where id=target for update;
  if g.owner_id is distinct from auth.uid() or auth.uid() is null then raise exception 'Only the group owner can set the start date'; end if;
  if g.start_date is not null and g.start_date <= (now() at time zone g.timezone)::date then raise exception 'The group has started; its schedule is fixed'; end if;
  update public.reading_groups set start_date=starts where id=target;
end; $$;

-- Explicit grants: clients cannot change membership, ownership, timestamps, or invitation records.
revoke all on public.reading_groups, public.group_members, public.group_invitations, public.completions, public.reflections from anon, authenticated;
grant select on public.reading_groups, public.group_members, public.completions, public.reflections to authenticated;
grant insert(group_id,user_id,day), delete on public.completions to authenticated;
grant insert(group_id,user_id,day,body), delete on public.reflections to authenticated;
revoke all on function public.is_group_member(uuid), public.create_reading_group(text,text,text,date), public.join_reading_group(uuid,text), public.group_invite(uuid,boolean), public.set_group_start(uuid,date) from public, anon;
grant execute on function public.is_group_member(uuid), public.create_reading_group(text,text,text,date), public.join_reading_group(uuid,text), public.group_invite(uuid,boolean), public.set_group_start(uuid,date) to authenticated;
