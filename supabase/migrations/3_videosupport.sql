-- Add media_type and optional thumb_url for video posters
alter table public.posts
  add column if not exists media_type text check (media_type in ('image','video')) default 'image';

alter table public.posts
  add column if not exists thumb_url text;

-- Optional: store duration or dimensions for better UX
alter table public.posts
  add column if not exists video_duration_seconds int;

-- Index if you plan to query by media_type
create index if not exists idx_posts_media_type on public.posts(media_type);