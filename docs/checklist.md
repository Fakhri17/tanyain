# Checklist — Anonymous Q&A Board

Progress pengerjaan berdasarkan `docs/plans.md`. Tandai `[x]` jika step sudah selesai & bisa dijalankan tanpa error.

---

## STEP 1 — Setup project ✅

- [x] Scaffold project Vue 3 dengan Vite (template `vue`, bukan Nuxt)
- [x] Install dependencies: `@supabase/supabase-js`, `vue-router`, `tailwindcss`
- [x] Setup Tailwind CSS (Vite + Vue) — `@tailwindcss/vite` + `@import "tailwindcss"` di `src/assets/main.css`
- [x] `src/lib/supabase.ts` — expose supabase client (`VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY`)
- [x] `.env.local` dengan placeholder env var
- [x] Vue Router `createWebHistory` + 5 route placeholder (`/`, `/login`, `/register`, `/dashboard`, `/inbox/:username`)
- [x] `App.vue` render `<RouterView />`
- [x] Hanya placeholder text, no UI
- [x] `npm run type-check` / build jalan tanpa error

---

## STEP 2 — Setup database Supabase ✅

- [x] SQL migration: tabel `profiles`
- [x] SQL migration: tabel `questions` (tanpa `sender_id` — anonim)
- [x] SQL migration: tabel `answers`
- [x] RLS policies: `profiles`
- [x] RLS policies: `questions`
- [x] RLS policies: `answers`
- [x] Trigger `handle_new_user` (auto-create profil)
- [x] Index pada `questions(inbox_owner_id)` dan `questions(status)`

> File: `supabase/migrations/0001_init_schema.sql` — paste ke Supabase SQL Editor lalu Run.

---

## STEP 3 — Auth: Register & Login ✅

- [x] Halaman Register (`/register`) + validasi client-side
- [x] Halaman Login (`/login`)
- [x] Composable `src/composables/useAuth.ts`
- [x] Navigation guard: `/dashboard` butuh login
- [x] Styling Tailwind (clean & functional)

---

## STEP 4 — Halaman publik penanya (`/inbox/:username`) ✅

- [x] Fetch profil pemilik inbox by username (+ handle 404 / not public)
- [x] Tampilkan display_name, bio
- [x] Form kirim pertanyaan anonim (textarea, counter, honeypot, validasi)
- [x] Pesan sukses + reset form (tanpa redirect)
- [x] Submit pakai anon client, tanpa data sender
- ~~Tampilkan daftar pertanyaan + jawaban~~ — dihapus, sesuai model NGL (Q&A tidak publik)

---

## STEP 5 — Dashboard pemilik inbox ✅

- [x] Layout dashboard (tab: Pertanyaan Masuk & Pengaturan Profil)
- [x] Fetch questions milik user + join answers
- [x] Filter tab: Semua | Pending | Sudah Dijawab
- [x] Card pertanyaan (body, status badge, waktu)
- [x] Aksi: Jawab / Sembunyikan / Tampilkan Lagi
- [x] Section Pengaturan Profil (update display_name, bio, is_public + copy link)
- [x] Realtime subscribe (opsional)

---

## STEP 6 — Polish & deploy ke Netlify ✅

- [x] `netlify.toml` (build + SPA redirect)
- [x] `src/components/AppNavbar.vue`
- [x] Halaman Home (deskripsi + CTA + redirect jika login)
- [x] `useToast.ts` + dipakai di semua form
- [x] Loading states (semua submit + skeleton/spinner)
- [ ] Env vars di Netlify (manual — isi di Netlify dashboard)
- [ ] Verifikasi akhir (build, route langsung, anon submit, proteksi dashboard, RLS)
