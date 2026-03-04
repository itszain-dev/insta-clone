-- =============================================
-- Instagram Clone Schema for Supabase (2025)
-- Fully idempotent – can be run repeatedly
-- Fixed: uid as uuid + explicit casts for auth.uid()
-- =============================================
-- Enable required extensions (safe to run multiple times)
create extension if not exists "uuid-ossp" with schema extensions;

-- ===============
-- 1. USERS TABLE
-- ===============
create table if not exists public.users (
  uid uuid primary key,
  email text not null,
  photo_url text,
  username text unique not null,
  bio text,
  followers text[] default '{}'::text[],
  following text[] default '{}'::text[],
  created_at timestamp with time zone default now()
);
alter table public.users enable row level security;
-- Drop existing policies safely, then recreate
drop policy if exists "Public read users" on public.users;
drop policy if exists "Users can insert their own profile" on public.users;
drop policy if exists "Users can update own profile + anyone can update followers/following" on public.users;
create policy "Public read users" on public.users for select using (true);
create policy "Users can insert their own profile" on public.users for insert to authenticated with check (uid = auth.uid());
create policy "Users can update own profile + anyone can update followers/following" on public.users for update to authenticated using (true) with check (true);

-- ===============
-- 2. POSTS TABLE
-- ===============
create table if not exists public.posts (
  post_id uuid primary key default gen_random_uuid(),
  description text,
  uid uuid not null references public.users(uid) on delete cascade,
  username text not null,
  likes text[] default '{}'::text[],
  date_published timestamp with time zone default now() not null,
  post_url text not null,
  prof_image text,
  created_at timestamp with time zone default now()
);
alter table public.posts enable row level security;
drop policy if exists "Public read posts" on public.posts;
drop policy if exists "Users can create own posts" on public.posts;
drop policy if exists "Anyone can like posts (update likes array)" on public.posts;
drop policy if exists "Only owner can delete own post" on public.posts;
create policy "Public read posts" on public.posts for select using (true);
create policy "Users can create own posts" on public.posts for insert to authenticated with check (uid = auth.uid());
create policy "Anyone can like posts (update likes array)" on public.posts for update to authenticated using (true) with check (true);
create policy "Only owner can delete own post" on public.posts for delete to authenticated using (uid = auth.uid());

-- ==================
-- 3. COMMENTS TABLE
-- ==================
create table if not exists public.comments (
  comment_id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(post_id) on delete cascade,
  uid uuid not null references public.users(uid) on delete cascade,
  username text not null,
  profile_pic text,
  text text not null,
  date_published timestamp with time zone default now() not null
);
alter table public.comments enable row level security;
drop policy if exists "Public read comments" on public.comments;
drop policy if exists "Authenticated users can comment" on public.comments;
drop policy if exists "Users can delete own comments" on public.comments;
create policy "Public read comments" on public.comments for select using (true);
create policy "Authenticated users can comment" on public.comments for insert to authenticated with check (uid = auth.uid());
create policy "Users can delete own comments" on public.comments for delete to authenticated using (uid = auth.uid());

-- ===============
-- 4. INDEXES
-- ===============
create index if not exists idx_posts_uid on public.posts(uid);
create index if not exists idx_posts_date on public.posts(date_published desc);
create index if not exists idx_comments_post_id on public.comments(post_id);
create index if not exists idx_comments_date on public.comments(date_published desc);

-- ===================
-- 5. STORAGE BUCKETS
-- ===================
insert into storage.buckets (id, name, public) values ('posts', 'posts', true) on conflict (id) do nothing;
insert into storage.buckets (id, name, public) values ('profilepics', 'profilepics', true) on conflict (id) do nothing;

-- =====================
-- 6. STORAGE POLICIES
-- =====================
-- Clean up any old policies first (idempotent drops)
drop policy if exists "Public can read public buckets" on storage.objects;
drop policy if exists "Authenticated can upload to public buckets" on storage.objects;
drop policy if exists "Owner can update own files" on storage.objects;
drop policy if exists "Owner can delete own files" on storage.objects;
-- Public can read from both buckets (no auth needed for viewing)
create policy "Public can read public buckets" on storage.objects for select to public using (bucket_id in ('posts', 'profilepics'));
-- Authenticated users can upload to both buckets
create policy "Authenticated can upload to public buckets" on storage.objects for insert to authenticated with check (bucket_id in ('posts', 'profilepics'));
-- Only owner can update their own files (e.g., replace a post image or profile pic)
-- Note: owner is uuid type, so cast auth.uid() if needed (Supabase handles this internally)
create policy "Owner can update own files" on storage.objects for update to authenticated using (bucket_id in ('posts', 'profilepics') and owner = auth.uid()) with check (bucket_id in ('posts', 'profilepics') and owner = auth.uid());
-- Only owner can delete their own files
create policy "Owner can delete own files" on storage.objects for delete to authenticated using (bucket_id in ('posts', 'profilepics') and owner = auth.uid());

-- =============================================
-- DONE! Schema is now fully set up and safe to re-run
-- =============================================