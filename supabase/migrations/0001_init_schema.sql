-- =====================================================================
-- Anonymous Q&A Board — Database Schema (Step 2)
-- Stack: Supabase (PostgreSQL)
-- Cara pakai: paste seluruh file ini ke Supabase SQL Editor lalu Run.
-- =====================================================================

-- ---------------------------------------------------------------------
-- TABEL: profiles
-- ---------------------------------------------------------------------
create table if not exists public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  username     text unique not null
                 check (username ~ '^[a-z0-9_]{3,}$'),
  display_name text not null,
  bio          text not null default '',
  is_public    boolean not null default true,
  created_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- TABEL: questions
-- CATATAN: tidak ada kolom sender_id — submission harus benar-benar anonim.
-- ---------------------------------------------------------------------
create table if not exists public.questions (
  id             uuid primary key default gen_random_uuid(),
  inbox_owner_id uuid not null references public.profiles (id) on delete cascade,
  body           text not null
                   check (char_length(body) >= 5 and char_length(body) <= 500),
  status         text not null default 'pending'
                   check (status in ('pending', 'answered', 'hidden')),
  submitted_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- TABEL: answers
-- ---------------------------------------------------------------------
create table if not exists public.answers (
  id          uuid primary key default gen_random_uuid(),
  question_id uuid unique not null references public.questions (id) on delete cascade,
  body        text not null
                check (char_length(body) >= 1 and char_length(body) <= 1000),
  answered_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- INDEX
-- ---------------------------------------------------------------------
create index if not exists questions_inbox_owner_id_idx on public.questions (inbox_owner_id);
create index if not exists questions_status_idx          on public.questions (status);

-- ---------------------------------------------------------------------
-- TRIGGER: auto-create profil kosong setelah user register
-- Username & display_name diambil dari raw_user_meta_data jika tersedia,
-- jika tidak ada fallback ke turunan dari email.
-- ---------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  meta_username     text := new.raw_user_meta_data ->> 'username';
  meta_display_name text := new.raw_user_meta_data ->> 'display_name';
  base_username     text;
  final_username    text;
  suffix            int := 0;
begin
  -- Tentukan username dasar: dari metadata atau dari bagian lokal email.
  base_username := coalesce(
    nullif(meta_username, ''),
    regexp_replace(lower(split_part(new.email, '@', 1)), '[^a-z0-9_]', '', 'g')
  );

  -- Pastikan minimal 3 karakter & valid; jika tidak, pakai fallback id.
  if base_username is null or char_length(base_username) < 3 then
    base_username := 'user_' || left(replace(new.id::text, '-', ''), 8);
  end if;

  -- Jamin keunikan username dengan menambah suffix angka bila perlu.
  final_username := base_username;
  while exists (select 1 from public.profiles where username = final_username) loop
    suffix := suffix + 1;
    final_username := base_username || suffix::text;
  end loop;

  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    final_username,
    coalesce(nullif(meta_display_name, ''), final_username)
  );

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- =====================================================================
-- ROW LEVEL SECURITY
-- =====================================================================
alter table public.profiles  enable row level security;
alter table public.questions enable row level security;
alter table public.answers   enable row level security;

-- ---------------------------------------------------------------------
-- RLS: profiles
-- ---------------------------------------------------------------------
-- Semua user (termasuk anon) bisa SELECT profil yang is_public = true.
drop policy if exists "profiles_select_public" on public.profiles;
create policy "profiles_select_public"
  on public.profiles for select
  to anon, authenticated
  using (is_public = true);

-- User selalu bisa melihat profil miliknya sendiri (meski is_public = false).
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
  on public.profiles for select
  to authenticated
  using (auth.uid() = id);

-- User hanya bisa INSERT profil dengan id = auth.uid().
drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
  on public.profiles for insert
  to authenticated
  with check (auth.uid() = id);

-- User hanya bisa UPDATE profil miliknya sendiri.
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- ---------------------------------------------------------------------
-- RLS: questions
-- ---------------------------------------------------------------------
-- Role anon DAN authenticated boleh INSERT (anonim submission).
drop policy if exists "questions_insert_anon" on public.questions;
create policy "questions_insert_anon"
  on public.questions for insert
  to anon, authenticated
  with check (true);

-- Authenticated user hanya bisa SELECT questions miliknya.
drop policy if exists "questions_select_own" on public.questions;
create policy "questions_select_own"
  on public.questions for select
  to authenticated
  using (inbox_owner_id = auth.uid());

-- Siapa saja boleh SELECT questions berstatus 'answered' dari profil is_public = true.
drop policy if exists "questions_select_public_answered" on public.questions;
create policy "questions_select_public_answered"
  on public.questions for select
  to anon, authenticated
  using (
    status = 'answered'
    and exists (
      select 1 from public.profiles p
      where p.id = questions.inbox_owner_id
        and p.is_public = true
    )
  );

-- Authenticated user hanya bisa UPDATE questions miliknya (untuk ubah status).
drop policy if exists "questions_update_own" on public.questions;
create policy "questions_update_own"
  on public.questions for update
  to authenticated
  using (inbox_owner_id = auth.uid())
  with check (inbox_owner_id = auth.uid());

-- ---------------------------------------------------------------------
-- RLS: answers
-- ---------------------------------------------------------------------
-- Siapa saja boleh SELECT answers (public).
drop policy if exists "answers_select_public" on public.answers;
create policy "answers_select_public"
  on public.answers for select
  to anon, authenticated
  using (true);

-- Authenticated user boleh INSERT jika question_id menunjuk ke pertanyaan miliknya.
drop policy if exists "answers_insert_own_question" on public.answers;
create policy "answers_insert_own_question"
  on public.answers for insert
  to authenticated
  with check (
    exists (
      select 1 from public.questions q
      where q.id = answers.question_id
        and q.inbox_owner_id = auth.uid()
    )
  );

-- Authenticated user boleh UPDATE jawaban pada pertanyaan miliknya (untuk edit jawaban).
drop policy if exists "answers_update_own_question" on public.answers;
create policy "answers_update_own_question"
  on public.answers for update
  to authenticated
  using (
    exists (
      select 1 from public.questions q
      where q.id = answers.question_id
        and q.inbox_owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.questions q
      where q.id = answers.question_id
        and q.inbox_owner_id = auth.uid()
    )
  );
