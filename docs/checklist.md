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

## STEP 4 — Halaman publik penanya (`/inbox/:username`)

- [ ] Fetch profil pemilik inbox by username (+ handle 404 / not public)
- [ ] Tampilkan display_name, bio, jumlah pertanyaan dijawab
- [ ] Form kirim pertanyaan anonim (textarea, counter, honeypot, validasi)
- [ ] Pesan sukses + reset form (tanpa redirect)
- [ ] Tampilkan daftar pertanyaan + jawaban (status `answered`)
- [ ] Submit pakai anon client, tanpa data sender

---

## STEP 5 — Dashboard pemilik inbox

- [ ] Layout dashboard (tab: Pertanyaan Masuk & Pengaturan Profil)
- [ ] Fetch questions milik user + join answers
- [ ] Filter tab: Semua | Pending | Sudah Dijawab
- [ ] Card pertanyaan (body, status badge, waktu)
- [ ] Aksi: Jawab / Sembunyikan / Tampilkan Lagi
- [ ] Section Pengaturan Profil (update display_name, bio, is_public + copy link)
- [ ] Realtime subscribe (opsional)

---

## STEP 6 — Polish & deploy ke Netlify

- [ ] `netlify.toml` (build + SPA redirect)
- [ ] `src/components/AppNavbar.vue`
- [ ] Halaman Home (deskripsi + CTA + redirect jika login)
- [ ] `useToast.ts` + dipakai di semua form
- [ ] Loading states (semua submit + skeleton/spinner)
- [ ] Env vars di Netlify
- [ ] Verifikasi akhir (build, route langsung, anon submit, proteksi dashboard, RLS)
