# Anonymous Q&A Board — Step Prompting Guide for AI Agent

> **Stack:** Vue 3 (Composition API) + Vite + Supabase + Tailwind CSS + Vue Router
> **Deploy target:** Netlify (static build)
> **Scope:** Build fitur satu per satu sesuai urutan step di bawah. Jangan skip step. Setiap step harus selesai dan bisa dijalankan sebelum lanjut ke step berikutnya.

---

## Konteks proyek

Aplikasi web di mana:
- **Pemilik inbox** bisa daftar/login, punya halaman publik di `/inbox/:username`
- **Penanya** bisa kirim pertanyaan anonim ke halaman tersebut **tanpa perlu login**
- Pemilik bisa lihat pertanyaan masuk di dashboard, menjawab, dan mempublikasikan jawaban
- Pertanyaan + jawaban yang dipublikasikan bisa dibaca siapa saja

---

## STEP 1 — Setup project

```
Buat project Vue 3 baru dengan Vite. Jangan gunakan Nuxt.

Langkah yang harus dilakukan:
1. Scaffold project dengan: npm create vite@latest anon-qa -- --template vue
2. Install dependencies berikut:
   - @supabase/supabase-js
   - vue-router
   - tailwindcss
3. Setup Tailwind CSS sesuai dokumentasi resmi untuk Vite + Vue
4. Buat file src/lib/supabase.js yang mengekspos supabase client menggunakan createClient dari @supabase/supabase-js. Gunakan import.meta.env.VITE_SUPABASE_URL dan import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY
5. Buat file .env.local dengan placeholder:
   VITE_SUPABASE_URL=your-project-url
   VITE_SUPABASE_PUBLISHABLE_KEY=your-key
6. Setup Vue Router dengan createWebHistory. Daftarkan route kosong dulu:
   - / → halaman Home (placeholder)
   - /login → halaman Login (placeholder)
   - /register → halaman Register (placeholder)
   - /dashboard → halaman Dashboard (placeholder)
   - /inbox/:username → halaman Inbox publik (placeholder)
7. Buat App.vue yang merender <RouterView />

Jangan buat UI apapun selain placeholder text di masing-masing halaman.
Pastikan `npm run dev` bisa jalan tanpa error.
```

---

## STEP 2 — Setup database Supabase

```
Buat SQL migration untuk schema database. Output berupa satu file SQL lengkap yang bisa dijalankan di Supabase SQL Editor.

Schema yang dibutuhkan:

Tabel: profiles
- id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE
- username text UNIQUE NOT NULL (hanya huruf kecil, angka, underscore, min 3 karakter)
- display_name text NOT NULL
- bio text DEFAULT ''
- is_public boolean DEFAULT true
- created_at timestamptz DEFAULT now()

Tabel: questions
- id uuid PRIMARY KEY DEFAULT gen_random_uuid()
- inbox_owner_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE
- body text NOT NULL CHECK (char_length(body) >= 5 AND char_length(body) <= 500)
- status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'answered', 'hidden'))
- submitted_at timestamptz DEFAULT now()
- CATATAN: tidak ada kolom sender_id — submission harus benar-benar anonim

Tabel: answers
- id uuid PRIMARY KEY DEFAULT gen_random_uuid()
- question_id uuid UNIQUE NOT NULL REFERENCES questions(id) ON DELETE CASCADE
- body text NOT NULL CHECK (char_length(body) >= 1 AND char_length(body) <= 1000)
- answered_at timestamptz DEFAULT now()

RLS Policies yang harus dibuat:

profiles:
- Semua user (termasuk anon) bisa SELECT profil yang is_public = true
- User hanya bisa UPDATE profil miliknya sendiri (auth.uid() = id)
- User hanya bisa INSERT profil dengan id = auth.uid()

questions:
- Role anon DAN authenticated boleh INSERT (with check: true) — ini untuk anonim submission
- Authenticated user hanya bisa SELECT questions miliknya (inbox_owner_id = auth.uid())
- Authenticated user hanya bisa UPDATE questions miliknya (untuk ubah status)
- Siapa saja boleh SELECT questions dengan status = 'answered' dari profil is_public = true

answers:
- Authenticated user boleh INSERT jika question_id menunjuk ke pertanyaan miliknya
- Siapa saja boleh SELECT answers (public)

Sertakan juga:
- Trigger untuk auto-create profil kosong setelah user register (handle_new_user)
- Index pada questions(inbox_owner_id) dan questions(status)

Output: satu blok SQL lengkap, siap di-paste ke Supabase SQL Editor.
```

---

## STEP 3 — Auth: Register & Login

```
Buat halaman Register dan Login di Vue 3. Gunakan Supabase Auth (email + password).

Halaman Register (/register):
- Form dengan field: email, password, username, display_name
- Validasi client-side:
  - Email harus valid format
  - Password minimal 8 karakter
  - Username: hanya huruf kecil, angka, underscore; minimal 3 karakter; maksimal 20 karakter
  - Display name tidak boleh kosong
- Alur:
  1. Cek ketersediaan username ke tabel profiles sebelum submit (query .eq('username', val))
  2. Panggil supabase.auth.signUp({ email, password })
  3. Setelah sukses, insert ke tabel profiles: { id: user.id, username, display_name }
  4. Redirect ke /dashboard
- Tampilkan error message yang jelas jika username sudah dipakai atau email sudah terdaftar

Halaman Login (/login):
- Form dengan field: email, password
- Panggil supabase.auth.signInWithPassword({ email, password })
- Redirect ke /dashboard setelah sukses
- Tampilkan error jika credentials salah

Buat composable src/composables/useAuth.js yang mengekspos:
- user (reactive, dari supabase.auth.getUser())
- login(email, password)
- register(email, password, username, displayName)
- logout()
- isLoggedIn (computed boolean)

Buat navigation guard di router: route /dashboard hanya bisa diakses jika isLoggedIn. Jika tidak, redirect ke /login.

Styling: gunakan Tailwind CSS. Desain tidak perlu mewah, cukup clean dan functional.
```

---

## STEP 4 — Halaman publik penanya (`/inbox/:username`)

```
Buat halaman src/pages/InboxPage.vue untuk route /inbox/:username.

Halaman ini bisa diakses tanpa login (publik).

Yang harus ditampilkan:
1. Fetch profil pemilik inbox berdasarkan username dari URL params
   - Query: supabase.from('profiles').select('id, display_name, bio, is_public').eq('username', username).single()
   - Jika profil tidak ditemukan atau is_public = false → tampilkan halaman 404 sederhana
2. Tampilkan: display_name, bio, dan jumlah pertanyaan yang sudah dijawab (opsional)
3. Form kirim pertanyaan anonim:
   - Satu textarea, placeholder: "Tanya sesuatu..."
   - Karakter counter (maks 500)
   - Tombol "Kirim"
   - Honeypot field tersembunyi (posisi absolute, left: -9999px) untuk anti-bot
   - Validasi: minimal 5 karakter, maksimal 500 karakter
4. Setelah submit berhasil:
   - Tampilkan pesan sukses: "Pertanyaanmu terkirim!"
   - Reset form
   - Jangan redirect
5. Tampilkan daftar pertanyaan yang sudah dijawab (status = 'answered') dari pemilik ini:
   - Query: questions dengan inbox_owner_id = profile.id dan status = 'answered', join answers
   - Tampilkan: body pertanyaan + body jawaban

Logika submit (gunakan supabase client anon — tidak perlu auth):
- Cek honeypot field: jika tidak kosong, diam-diam batalkan tanpa error
- Insert ke tabel questions: { inbox_owner_id: profile.id, body: questionText, status: 'pending' }
- Tidak ada data sender yang disimpan

Jangan tampilkan identitas penanya di manapun.
```

---

## STEP 5 — Dashboard pemilik inbox

```
Buat halaman src/pages/DashboardPage.vue untuk route /dashboard.
Halaman ini memerlukan auth (sudah diproteksi di Step 3).

Layout dashboard:
- Sidebar atau tab navigasi sederhana dengan dua section: "Pertanyaan Masuk" dan "Pengaturan Profil"

Section: Pertanyaan Masuk
1. Fetch semua questions milik user yang login:
   - Query: supabase.from('questions').select('*, answers(*)').eq('inbox_owner_id', user.id).order('submitted_at', { ascending: false })
2. Filter tampilan dengan tiga tab: Semua | Pending | Sudah Dijawab
3. Tiap card pertanyaan menampilkan:
   - Body pertanyaan
   - Status badge (pending / answered / hidden)
   - Waktu masuk (format: "2 jam yang lalu" atau tanggal)
4. Aksi per pertanyaan:
   a. Jika status = 'pending':
      - Tombol "Jawab": buka textarea di bawah card, submit memanggil:
        1. INSERT ke answers: { question_id, body: answerText }
        2. UPDATE questions SET status = 'answered' WHERE id = question_id
      - Tombol "Sembunyikan": UPDATE questions SET status = 'hidden'
   b. Jika status = 'answered':
      - Tampilkan jawaban yang sudah ditulis
      - Tombol "Edit Jawaban" (opsional, bisa skip untuk MVP)
   c. Jika status = 'hidden':
      - Tampilkan dengan opacity lebih rendah
      - Tombol "Tampilkan Lagi": UPDATE questions SET status = 'pending'

Section: Pengaturan Profil
- Form untuk update: display_name, bio, is_public (toggle)
- Tampilkan link profil publik: app.com/inbox/{username} (bisa di-copy)
- Simpan dengan: supabase.from('profiles').update({...}).eq('id', user.id)

Realtime (opsional tapi direkomendasikan):
- Subscribe ke postgres_changes pada tabel questions dengan filter inbox_owner_id = user.id
- Append pertanyaan baru ke list tanpa perlu reload halaman
- Tampilkan badge notifikasi jika ada pertanyaan baru masuk

Jangan tampilkan identitas penanya di manapun, termasuk di dashboard.
```

---

## STEP 6 — Polish & deploy ke Netlify

```
Selesaikan semua hal berikut sebelum deploy:

1. Buat file netlify.toml di root project:
   [build]
     command = "npm run build"
     publish = "dist"

   [[redirects]]
     from = "/*"
     to = "/index.html"
     status = 200

   Redirect ini penting agar Vue Router dengan history mode bisa berfungsi di Netlify.

2. Buat src/components/AppNavbar.vue:
   - Tampilkan link ke /dashboard dan tombol Logout jika user sudah login
   - Tampilkan link ke /login dan /register jika belum login
   - Gunakan composable useAuth dari Step 3

3. Halaman Home (/):
   - Jelaskan singkat apa itu aplikasi ini
   - Tombol CTA: "Buat Inbox Kamu" → /register
   - Jika sudah login, redirect langsung ke /dashboard

4. Error handling global:
   - Buat composable useToast.js sederhana untuk tampilkan notifikasi sukses/error
   - Gunakan di semua form (register, login, submit pertanyaan, jawab pertanyaan)

5. Loading states:
   - Semua tombol submit harus punya state loading (disabled + teks berubah jadi "Memproses...")
   - Tampilkan skeleton atau spinner saat fetch data

6. Environment variables di Netlify:
   - Tambahkan VITE_SUPABASE_URL dan VITE_SUPABASE_PUBLISHABLE_KEY di Netlify > Site settings > Environment variables
   - Jangan pernah hardcode nilai ini di kode

7. Verifikasi akhir sebelum deploy:
   - npm run build harus selesai tanpa error
   - Semua route bisa diakses langsung via URL (bukan hanya dari navigasi internal)
   - Submission anonim bisa dilakukan tanpa login
   - Dashboard tidak bisa diakses tanpa login
   - RLS Supabase sudah aktif dan tidak ada data yang bocor
```

---

## Catatan untuk AI agent

- Gunakan **Composition API** (`<script setup>`) di semua komponen, bukan Options API
- Semua interaksi Supabase harus selalu handle error (`const { data, error } = await supabase...`)
- Jangan simpan informasi apapun tentang penanya — tidak ada IP, tidak ada fingerprint
- Gunakan `import.meta.env` untuk semua environment variable, bukan `process.env`
- Jika ada langkah yang ambigu, tanyakan sebelum mengimplementasi
