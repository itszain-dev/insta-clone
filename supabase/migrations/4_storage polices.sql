alter table public.posts add column if not exists video_path text;
create index if not exists idx_posts_video_path on public.posts(video_path);


alter table public.posts
  add column if not exists media_type text check (media_type in ('image','video')) default 'image';

alter table public.posts
  add column if not exists thumb_url text;

alter table public.posts
  add column if not exists video_duration_seconds int;

create index if not exists idx_posts_media_type on public.posts(media_type);


alter table public.stories add column if not exists media_duration_seconds int;

update storage.buckets set public = false where id in ('posts','profilepics','stories');

drop policy if exists "Public can read public buckets" on storage.objects;
drop policy if exists "Public read stories" on storage.objects;
drop policy if exists "Authenticated upload stories" on storage.objects;
drop policy if exists "Owner update story files" on storage.objects;
drop policy if exists "Owner delete story files" on storage.objects;

create policy "Auth read objects"
  on storage.objects for select to authenticated
  using (bucket_id in ('posts','profilepics','stories'));

create policy "Auth insert objects"
  on storage.objects for insert to authenticated
  with check (bucket_id in ('posts','profilepics','stories'));

create policy "Owner update objects"
  on storage.objects for update to authenticated
  using (bucket_id in ('posts','profilepics','stories') and owner = auth.uid())
  with check (bucket_id in ('posts','profilepics','stories') and owner = auth.uid());

create policy "Owner delete objects"
  on storage.objects for delete to authenticated
  using (bucket_id in ('posts','profilepics','stories') and owner = auth.uid());


create or replace function public.toggle_like(p_post_id uuid, p_uid uuid)
returns void
language sql
security definer
set search_path = public
as $$
update public.posts
set likes = case
  when likes @> array[p_uid::text] then array_remove(likes, p_uid::text)
  else array_append(likes, p_uid::text)
end
where post_id = p_post_id;
$$;

grant execute on function public.toggle_like(uuid, uuid) to authenticated;

drop policy if exists "Anyone can like posts (update likes array)" on public.posts;
drop policy if exists "Users can create own posts" on public.posts;
create policy "Users can create own posts"
  on public.posts for insert to authenticated
  with check (uid = auth.uid());

drop policy if exists "Only owner can delete own post" on public.posts;
create policy "Only owner can delete own post"
  on public.posts for delete to authenticated
  using (uid = auth.uid());

drop policy if exists "Public read posts" on public.posts;
create policy "Public read posts"
  on public.posts for select using (true);

drop policy if exists "Owner can update own posts" on public.posts;
create policy "Owner can update own posts"
  on public.posts for update to authenticated
  using (uid = auth.uid())
  with check (uid = auth.uid());