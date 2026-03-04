-- Enable required extensions
create extension if not exists "uuid-ossp" with schema extensions;
create extension if not exists "pg_cron" with schema extensions; -- needed for cron job

-- Stories table
create table if not exists public.stories (
  story_id uuid primary key default gen_random_uuid(),
  uid uuid not null references public.users(uid) on delete cascade,
  username text not null,
  media_url text not null,
  media_type text not null check (media_type in ('image','video')),
  thumb_url text,
  caption text,
  created_at timestamptz default now(),
  expires_at timestamptz default (now() + interval '24 hours'),
  is_archived boolean default false,
  views_count int default 0
);

alter table public.stories enable row level security;

-- RLS Policies for stories
drop policy if exists "Public read active stories" on public.stories;
drop policy if exists "Insert own story" on public.stories;
drop policy if exists "Owner update story" on public.stories;
drop policy if exists "Owner delete story" on public.stories;

create policy "Public read active stories"
  on public.stories for select
  using (not is_archived and expires_at > now());

create policy "Insert own story"
  on public.stories for insert to authenticated
  with check (uid = auth.uid());

create policy "Owner update story"
  on public.stories for update to authenticated
  using (uid = auth.uid()) with check (uid = auth.uid());

create policy "Owner delete story"
  on public.stories for delete to authenticated
  using (uid = auth.uid());

-- Story views table
create table if not exists public.story_views (
  story_id uuid not null references public.stories(story_id) on delete cascade,
  viewer_uid uuid not null references public.users(uid) on delete cascade,
  viewed_at timestamptz default now(),
  primary key (story_id, viewer_uid)
);

alter table public.story_views enable row level security;

drop policy if exists "Viewer or owner can read views" on public.story_views;
drop policy if exists "Insert own view" on public.story_views;

create policy "Viewer or owner can read views"
  on public.story_views for select to authenticated
  using (
    viewer_uid = auth.uid()
    or exists (
      select 1 from public.stories s
      where s.story_id = story_views.story_id and s.uid = auth.uid()
    )
  );

create policy "Insert own view"
  on public.story_views for insert to authenticated
  with check (viewer_uid = auth.uid());

-- Trigger to increment views_count
create or replace function public.increment_story_views()
returns trigger language plpgsql as $$
begin
  update public.stories
  set views_count = views_count + 1
  where story_id = new.story_id;
  return new;
end;
$$;

drop trigger if exists story_views_counter on public.story_views;
create trigger story_views_counter
  after insert on public.story_views
  for each row execute function public.increment_story_views();

-- Indexes
create index if not exists idx_stories_uid on public.stories(uid);
create index if not exists idx_stories_created on public.stories(created_at desc);
create index if not exists idx_stories_expires on public.stories(expires_at);
create index if not exists idx_story_views_story on public.story_views(story_id);

-- Storage bucket
insert into storage.buckets (id, name, public)
values ('stories', 'stories', true)
on conflict (id) do nothing;

-- FIXED Storage policies (this was causing the syntax error)
drop policy if exists "Public read stories" on storage.objects;
drop policy if exists "Authenticated upload stories" on storage.objects;
drop policy if exists "Owner update story files" on storage.objects;
drop policy if exists "Owner delete story files" on storage.objects;

create policy "Public read stories"
  on storage.objects for select
  using (bucket_id = 'stories');

create policy "Authenticated upload stories"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'stories');

create policy "Owner update story files"
  on storage.objects for update to authenticated
  using (bucket_id = 'stories' and owner = auth.uid())
  with check (bucket_id = 'stories' and owner = auth.uid());

create policy "Owner delete story files"
  on storage.objects for delete to authenticated
  using (bucket_id = 'stories' and owner = auth.uid());

-- Optional: hourly cleanup job (only works if pg_cron is enabled)
select cron.schedule(
  'cleanup_expired_stories',
  '0 * * * *',  -- every hour
  $$
    update public.stories
    set is_archived = true
    where expires_at < now() and not is_archived;

    delete from public.stories
    where expires_at < now() - interval '7 days';
  $$
);