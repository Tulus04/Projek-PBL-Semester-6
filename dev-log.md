# DEV LOG — MyPresensi (Technical Session Log)

> File ini adalah log teknis detail yang mencatat setiap file yang dibuat/diubah beserta alasan teknisnya.
> Update oleh: AI Assistant (Antigravity)
> Format: `[TIMESTAMP] [JENIS] path/file — keterangan teknis`

---

## SESSION 001 — 2026-04-06 | Fase 1: Web Foundation

**Durasi:** ~36 menit (20:57 – 21:33 WIB)
**Status:** ✅ SELESAI
**Dev Server:** Running @ http://localhost:3000

---

### Scaffold & Konfigurasi

```
[20:57] [SCAFFOLD] mypresensi-web/
        Dibuat dengan: npx create-next-app@14
        Flags: --typescript --tailwind --eslint --app --no-turbopack
        Issue: package.json tidak memiliki scripts
        Fix: Tulis ulang package.json manual

[20:57] [ADD] package.json
        Scripts: dev, build, start, lint, type-check
        next: 14.2.35 (pinned untuk stabilitas)
        react: 18.3.1 (bukan 19, karena useActionState belum stable)
        typescript: 5.8.3
        Deps: @supabase/ssr, @supabase/supabase-js, clsx, lucide-react,
              tailwind-merge, zod

[20:57] [ADD] .env.local.example
        Template untuk tim: SUPABASE_URL, ANON_KEY, SERVICE_ROLE_KEY

[20:57] [ADD] .env.local
        Berisi placeholder values (dummy)
        ⚠️ JANGAN commit file ini ke Git

[20:57] [MOD] tsconfig.json
        paths: "@/*" → "./app/*"
        Alasan: Struktur menggunakan app/ bukan src/app/
        
[20:57] [MOD] next.config.mjs
        Tambah: experimental.serverActions.allowedOrigins

[20:57] [MOD] tailwind.config.ts
        - fontFamily: Plus Jakarta Sans (heading), Inter (sans), JetBrains Mono
        - colors.primary: #5483AD (Biru TRPL)
        - colors.success: #1A7F37, warning: #9A6700, danger: #CF222E
        - borderRadius: card (16px), button (999px), input (8px)
        - boxShadow: card, card-hover, primary
```

---

### Folder Struktur

```
[20:57] [MKDIR] app/(auth)/login/
[20:57] [MKDIR] app/(dashboard)/dashboard/
[20:57] [MKDIR] app/(dashboard)/dosen/
[20:57] [MKDIR] app/(dashboard)/mahasiswa/
[20:57] [MKDIR] app/(dashboard)/matakuliah/
[20:57] [MKDIR] app/(dashboard)/rekap/
[20:57] [MKDIR] app/(dashboard)/export/
[20:57] [MKDIR] app/(dashboard)/settings/
[20:57] [MKDIR] app/(dashboard)/audit/
[20:57] [MKDIR] app/lib/supabase/
[20:57] [MKDIR] app/lib/actions/
[20:57] [MKDIR] app/lib/utils/
[20:57] [MKDIR] app/types/
```

---

### Design System

```
[20:57] [MOD] app/globals.css
        Dihapus: Semua default styling Next.js
        Ditambah:
        - @import Google Fonts (Plus Jakarta Sans + Inter + JetBrains Mono)
        - CSS Custom Properties (color tokens):
            --color-primary: 84 131 173 (= #5483AD)
            --color-background: 244 246 248 (= #F4F6F8)
            --color-surface: 255 255 255
            --color-border: 226 230 234
            --color-success/warning/danger dengan subtle variants
        - Komponen CSS Classes:
            .card → rounded-2xl, shadow-card, border tipis
            .btn-primary → pill (radius 999px), hover translateY(-1px)
            .btn-secondary → outline style
            .btn-danger → merah
            .badge / .badge-success/warning/danger/neutral
            .input-field → focus ring biru
            .form-label
            .data-table → tanpa border vertikal, row hover biru
            .summary-card / .summary-card-label / -value / -sublabel
            .page-title / .page-subtitle  
            .sidebar-nav-item (+ :hover + .active state)
            .skeleton (animate-pulse loading)
        - Scrollbar custom (minimalist, 6px)
```

---

### Type Definitions

```
[20:57] [ADD] app/types/database.ts
        Exports:
        - UserRole: 'admin' | 'dosen' | 'mahasiswa'
        - AttendanceStatus: 'hadir' | 'izin' | 'sakit' | 'alpa'
        - SessionMode: 'offline' | 'online'
        - LeaveRequestStatus: 'pending' | 'approved' | 'rejected'
        - LeaveRequestType: 'izin' | 'sakit'
        - Interface: Profile, Course, Enrollment, Session
        - Interface: Attendance, LeaveRequest, AuditLog, SystemSetting
        - Generic: ApiResponse<T>, PaginatedResponse<T>
        Catatan: Semua interface memiliki joined fields (optional) untuk
                 relasi tabel (misal: student?: Pick<Profile,...>)
```

---

### Supabase Layer

```
[20:57] [ADD] app/lib/supabase/server.ts
        createClient()      → anon key + cookie SSR (untuk RLS)
        createAdminClient() → service_role key (bypass RLS)
        ⚠️ createAdminClient HANYA boleh dipanggil dari Server Actions/API Routes
        
[20:57] [ADD] app/lib/supabase/client.ts
        createClient() → anon key only, untuk Client Components ('use client')
```

---

### Utility Functions

```
[20:57] [ADD] app/lib/utils/index.ts
        cn(...inputs)                    → merge Tailwind class (clsx + twMerge)
        formatDateId(dateString)         → "Senin, 06 April 2026"
        formatDateShort(dateString)      → "06 Apr 2026"
        formatTime(dateString)           → "14:30"
        calculateAttendanceRate(h, t)    → persentase (rounded)
        isAttendanceDanger(rate)         → rate < 80%
        getStatusLabel(status)           → "Hadir" | "Izin" | "Sakit" | "Alpa"
        getStatusColor(status)           → Tailwind class string untuk badge
        truncate(text, maxLength)        → text... 
        isValidNim(nim)                  → regex /^[A-Z]\d{7}$/
        generateDefaultPassword(nim)     → "${nim}@politani"
```

---

### Server Actions

```
[20:57] [ADD] app/lib/actions/auth.ts
        'use server' — semua berjalan di server, tidak ada secret di browser
        
        loginAction(prevState, formData)
        - Validasi: Zod schema (email format, password min 6)
        - Auth: supabase.auth.signInWithPassword()
        - Error: sanitasi pesan ("Invalid login credentials" → pesan user-friendly)
        - Success: revalidatePath + redirect('/dashboard')
        
        logoutAction()
        - supabase.auth.signOut() + redirect('/login')
        
        changePasswordAction(prevState, formData)
        - Validasi: password min 8 karakter, harus ada huruf kapital + angka
        - Validasi: confirmPassword harus cocok
        - Auth: supabase.auth.updateUser({ password })
        - DB: update profiles.must_change_password = false
        - Success: redirect('/dashboard')
        
        Types exported: LoginState, ChangePasswordState
```

---

### Middleware & Routing

```
[20:57] [ADD] middleware.ts (root level)
        PUBLIC_ROUTES = ['/login'] — selalu dilewatkan tanpa auth check
        
        Guard logic:
        1. Jika pathname ada di PUBLIC_ROUTES → NextResponse.next()
        2. Jika env belum dikonfigurasi (masih placeholder) → NextResponse.next()
        3. Jika env sudah ada: cek session via supabase.auth.getUser()
        4. Jika tidak ada user → redirect('/login')
        
        matcher: exclude _next/static, _next/image, favicon, gambar statis

[20:57] [MOD] app/page.tsx
        Dihapus: Seluruh halaman default Next.js (1024 bytes template)
        Replace: redirect('/login') — 3 baris
```

---

### Halaman Login

```
[20:57] [ADD] app/(auth)/login/page.tsx  [Server Component]
        - Metadata: title, description (SEO ready)
        - Layout: centered, max-w-md
        - Brand area: placeholder logo biru TRPL (16x16 rounded-2xl)
        - Heading: "MyPresensi" + subtitle institusi
        - Card: "Selamat Datang" + LoginForm
        - Footer: "Butuh bantuan? Hubungi admin prodi."
        
[20:57] [ADD] app/(auth)/login/login-form.tsx  [Client Component]
        - 'use client' — hanya interaktivitas UI
        - useFormState (react-dom) untuk Server Action binding
        - useFormStatus untuk submit button loading state
        - SubmitButton() terpisah agar bisa pakai useFormStatus
        - Toggle show/hide password dengan Eye/EyeOff icon (lucide-react)
        - Error display: global error + field-level error (email, password)
        - Accessible: aria-describedby, aria-label, htmlFor

[20:57] [MOD] app/layout.tsx
        - Metadata: title template "%s — MyPresensi", description
        - Preconnect: fonts.googleapis.com + fonts.gstatic.com
        - lang="id"
```

---

### Bug Tracker Sesi Ini

```
BUG-001: package.json kosong (tanpa scripts)
  Root cause: create-next-app@14 tidak generate scripts dalam kondisi ini
  Fix: Tulis ulang package.json dari scratch
  Status: ✅ FIXED

BUG-002: /login 404
  Root cause: File di src/app/ tapi Next.js serve dari root app/
  Fix: Copy semua file dari src/app/ ke app/, update tsconfig
  Status: ✅ FIXED

BUG-003: Middleware crash — "Invalid supabaseUrl"
  Root cause: @supabase/ssr createServerClient() throw jika URL kosong/placeholder
              Ini terjadi SEBELUM early return check kita
  Fix: Cek apakah env berisi placeholder text, jika ya → skip Supabase init
  Status: ✅ FIXED

BUG-004: useActionState tidak ditemukan
  Root cause: useActionState adalah React 19 API, kita pakai React 18
  Fix: Ganti dengan useFormState + useFormStatus dari react-dom
  Status: ✅ FIXED

BUG-005: Import @/lib/actions/auth tidak ditemukan
  Root cause: tsconfig paths @/* → ./src/* (path lama, tidak ada)
  Fix: Update tsconfig paths @/* → ./app/*
  Status: ✅ FIXED
```

---

## Struktur File Saat Ini (End of Session 001)

```
mypresensi-web/
├── app/
│   ├── (auth)/
│   │   └── login/
│   │       ├── page.tsx          ✅ Server Component
│   │       └── login-form.tsx    ✅ Client Component
│   ├── (dashboard)/
│   │   ├── dashboard/            ⏳ Empty (next session)
│   │   ├── dosen/                ⏳ Empty
│   │   ├── mahasiswa/            ⏳ Empty
│   │   ├── matakuliah/           ⏳ Empty
│   │   ├── rekap/                ⏳ Empty
│   │   ├── export/               ⏳ Empty
│   │   ├── settings/             ⏳ Empty
│   │   └── audit/                ⏳ Empty
│   ├── lib/
│   │   ├── supabase/
│   │   │   ├── server.ts         ✅ Server client + Admin client
│   │   │   └── client.ts         ✅ Browser client
│   │   ├── actions/
│   │   │   └── auth.ts           ✅ Login + Logout + Change Password
│   │   └── utils/
│   │       └── index.ts          ✅ 11 utility functions
│   ├── types/
│   │   └── database.ts           ✅ 10 interfaces + 5 union types
│   ├── globals.css               ✅ Design system TRPL + Mekari Talenta
│   ├── layout.tsx                ✅ Root layout + metadata
│   └── page.tsx                  ✅ Redirect → /login
├── middleware.ts                  ✅ Route guard + dev bypass
├── .env.local                    ⚠️ Berisi placeholder (isi dengan key asli)
├── .env.local.example            ✅ Template untuk tim
├── package.json                  ✅ Scripts + deps kompatibel
├── tailwind.config.ts            ✅ Color tokens TRPL
├── tsconfig.json                 ✅ Path alias @/* → ./app/*
└── next.config.mjs               ✅ Server Actions config

BELUM DIBUAT (Next Session):
├── app/(dashboard)/layout.tsx    ← Sidebar + top nav layout
├── app/(dashboard)/dashboard/page.tsx  ← Halaman dashboard utama
├── app/(auth)/change-password/   ← Force change password page
└── supabase/migrations/          ← SQL schema + RLS
```

---

## Pending untuk Session 002

- [x] Dashboard layout (sidebar + topbar)
- [x] Dashboard utama (summary cards + tabel ringkasan)
- [x] SQL migration file (semua tabel + RLS)
- [x] Supabase: project dibuat dan terhubung
- [ ] Force change password page
- [ ] Flutter: menunggu install SDK dari Riki
- [ ] Test login end-to-end (menunggu akun admin)

---

## SESSION 002 — 2026-04-06 | Fase 1: Database & Dashboard Shell

**Durasi:** ~52 menit (21:33 – 22:52 WIB)
**Status:** ✅ SELESAI (sebagian menunggu akun admin)
**Dev Server:** Running @ http://localhost:3000

---

### Supabase Setup & Koneksi

```
[21:35] [INFO] Riki berhasil buat akun Supabase + Organization

[21:58] [CFG] .env.local
        SEBELUM: semua berisi placeholder "your_..._here"
        SESUDAH: 
          NEXT_PUBLIC_SUPABASE_URL    = https://<your-project-ref>.supabase.co
          NEXT_PUBLIC_SUPABASE_ANON_KEY = eyJ... (anon key)
          SUPABASE_SERVICE_ROLE_KEY     = eyJ... (service role)
        Note: URL di-decode dari JWT payload (field "ref")

[21:58] [RESTART] npm run dev
        Alasan: env baru tidak terbaca tanpa restart
        Status: ✅ Server restart sukses, env terbaca

[22:00] [ADD] supabase/migrations/001_initial_schema.sql
        Tabel yang dibuat:
          - profiles          (id, full_name, nim_nip, role, semester, kelas,
                               is_face_registered, is_active, must_change_password)
          - face_embeddings   (user_id UNIQUE, embedding BYTEA, embedding_hash)
          - courses           (code, name, sks, semester, dosen_id, academic_year)
          - enrollments       (course_id, student_id, academic_year, UNIQUE constraint)
          - sessions          (course_id, session_code, geofence lat/lng/radius,
                               is_active, started_at, ended_at)
          - attendances       (session_id, student_id, status, geolocation data,
                               is_mock_location, wifi_ssid, face_confidence,
                               is_face_matched, is_liveness_passed, device info)
          - leave_requests    (student_id, session_id, type, reason, evidence_url,
                               status, reviewed_by, review_note)
          - settings          (key-value config, default 5 settings)
          - audit_logs        (user_id, action, details JSONB, ip_address)
          - rate_limit_log    (user_id, endpoint, requested_at)
        
        Indexes (11 buah):
          idx_attendances_session, idx_attendances_student, idx_attendances_status
          idx_leave_requests_student, idx_leave_requests_status (partial: WHERE pending)
          idx_sessions_course, idx_sessions_active (partial: WHERE is_active)
          idx_enrollments_student, idx_enrollments_course
          idx_profiles_role, idx_profiles_nim
        
        RLS Policies (10 tabel × beberapa policy):
          - profiles: user lihat/edit sendiri; admin lihat semua
          - face_embeddings: hanya pemilik
          - courses: semua user bisa lihat; admin/dosen bisa manage
          - enrollments: mahasiswa lihat sendiri; admin/dosen manage semua
          - sessions: semua user lihat; dosen manage sesi sendiri
          - attendances: mahasiswa lihat/insert sendiri; dosen/admin lihat semua
          - leave_requests: mahasiswa manage sendiri; dosen/admin approve
          - settings: hanya admin
          - audit_logs: admin SELECT; system INSERT (WITH CHECK TRUE)
        
        Functions & Triggers:
          update_updated_at_column() → auto-set updated_at = NOW()
          Trigger: profiles + face_embeddings BEFORE UPDATE
          
          handle_new_user() → auto-insert ke profiles saat user Auth baru dibuat
          Trigger: auth.users AFTER INSERT (SECURITY DEFINER)

[22:00] [RUN] Supabase SQL Editor — migration dijalankan
        Result: "Success. No rows returned" ✅
        Semua tabel, indexes, RLS, triggers, functions aktif
```

---

### Dashboard Web — Komponen Layout

```
[22:23] [MKDIR] app/components/layout/
[22:23] [MKDIR] app/components/ui/
[22:23] [MKDIR] app/components/dashboard/

[22:23] [ADD] app/(dashboard)/layout.tsx  [Server Component]
        - Validasi session: createClient().auth.getUser()
        - Jika tidak auth → redirect('/login')
        - Query profile: id, full_name, nim_nip, role, avatar_url, must_change_password
        - Jika must_change_password = true → redirect('/change-password')
        - Layout: flex h-screen overflow-hidden
          - Kiri: <Sidebar profile={profile} />
          - Kanan: flex-col
            - <TopBar profile={profile} />
            - <main> {children} </main>

[22:23] [ADD] app/components/layout/sidebar.tsx  [Client Component]
        'use client' → butuh usePathname() untuk active state
        
        Nav items (dengan filter per role):
          - Dashboard       → /dashboard    (admin, dosen)
          - Mahasiswa       → /mahasiswa    (admin only)
          - Dosen           → /dosen        (admin only)
          - Mata Kuliah     → /matakuliah   (admin, dosen)
          - Rekap Absensi   → /rekap        (admin, dosen)
          - Export Data     → /export       (admin only)
          - Audit Log       → /audit        (admin only)
          - Pengaturan      → /settings     (admin only)
        
        Struktur visual:
          - Header: logo biru 32x32 + teks "MyPresensi" + "TRPL · Politani"
          - Nav items: sidebar-nav-item class + active state (warna biru)
          - Footer: avatar initial huruf pertama + nama + role + tombol logout
        
        Logout: form action={logoutAction} — Server Action

[22:23] [ADD] app/components/layout/topbar.tsx  [Client Component]
        'use client' → butuh usePathname() untuk judul dinamis
        
        pageTitles map: 8 route → judul halaman Indonesia
        Layout:
          - Kiri: <h1> judul halaman
          - Kanan: Bell icon (notifikasi) + avatar + nama + role

[22:23] [ADD] app/(dashboard)/dashboard/page.tsx  [Server Component]
        getDashboardStats() — Promise.all 6 query paralel:
          1. COUNT profiles WHERE role=mahasiswa AND is_active=true
          2. COUNT profiles WHERE role=dosen AND is_active=true
          3. COUNT attendances WHERE status=hadir AND hari ini
          4. COUNT attendances WHERE status=alpa AND hari ini
          5. COUNT attendances WHERE status IN (izin,sakit) AND hari ini
          6. SELECT 8 absensi terbaru hari ini (dengan join student + session + course)
        
        Komponen UI:
          - Header: "Selamat Datang 👋" + tanggal Indonesia
          - 5 Summary Cards: Total Mahasiswa, Total Dosen, Hadir, Alpa, Izin/Sakit
            (warna angka berbeda per jenis: biru, biru, hijau, merah, kuning)
          - Tabel Absensi Terkini:
            Kolom: Mahasiswa (nama+NIM), Mata Kuliah, Topik, Waktu, Status (badge)
            Empty state: "Belum ada absensi hari ini."
```

---

### Struktur File Saat Ini (End of Session 002)

```
mypresensi-web/
├── app/
│   ├── (auth)/
│   │   └── login/
│   │       ├── page.tsx              ✅ Server Component
│   │       └── login-form.tsx        ✅ Client Component
│   ├── (dashboard)/
│   │   ├── layout.tsx                ✅ Shell layout (auth guard)
│   │   ├── dashboard/
│   │   │   └── page.tsx              ✅ Summary cards + tabel absensi
│   │   ├── dosen/                    ⏳ Empty
│   │   ├── mahasiswa/                ⏳ Empty
│   │   ├── matakuliah/               ⏳ Empty
│   │   ├── rekap/                    ⏳ Empty
│   │   ├── export/                   ⏳ Empty
│   │   ├── settings/                 ⏳ Empty
│   │   └── audit/                    ⏳ Empty
│   ├── components/
│   │   ├── layout/
│   │   │   ├── sidebar.tsx           ✅ Navigasi + role filter + logout
│   │   │   └── topbar.tsx            ✅ Judul dinamis + notifikasi
│   │   ├── ui/                       ⏳ Empty (next session)
│   │   └── dashboard/                ⏳ Empty (next session)
│   ├── lib/
│   │   ├── supabase/
│   │   │   ├── server.ts             ✅
│   │   │   └── client.ts             ✅
│   │   ├── actions/
│   │   │   └── auth.ts               ✅
│   │   └── utils/
│   │       └── index.ts              ✅
│   ├── types/
│   │   └── database.ts               ✅
│   ├── globals.css                   ✅
│   ├── layout.tsx                    ✅
│   └── page.tsx                      ✅ → redirect /login
├── supabase/
│   └── migrations/
│       └── 001_initial_schema.sql    ✅ SUDAH DIJALANKAN di Supabase
├── middleware.ts                     ✅
├── .env.local                        ✅ Terisi dengan key asli
├── .env.local.example                ✅
├── package.json                      ✅
├── tailwind.config.ts                ✅
├── tsconfig.json                     ✅
└── next.config.mjs                   ✅
```

---

## Pending untuk Session 003

- [ ] Buat akun admin pertama via Supabase Auth + SQL update
- [ ] Test login end-to-end (login → dashboard)
- [ ] Halaman Force Change Password (`/change-password`)
- [ ] Halaman Manajemen Mahasiswa (tabel + add + import CSV)
- [ ] Halaman Manajemen Dosen
- [ ] Halaman Mata Kuliah
- [ ] Flutter: menunggu install SDK dari Riki

---

## SESSION FINAL — 2026-05-14 | Tier 1 & Tier 2 CLOSED + Runbook Recovery

**Durasi:** ~3 jam (14:00 – 17:30 WIB)
**Status:** ✅ SEMUA Tier 1 & 2 CLOSED. Tier 3 partial (T3-#8 done, T3-#7 user-driven, T3-#9 butuh Pro plan).
**Verifikasi akhir:** web `npm run type-check` exit 0, `npm run lint` clean, mobile `flutter analyze` 0 issues, `mcp0_get_advisors security` 0 issue baru.

### Roadmap Status

| Task | Status | Catatan |
|------|--------|---------|
| T1-#1 DioException friendly mapping | ✅ CLOSED | `friendlyErrorMessage()` di `shared/utils/error_mapper.dart` |
| T1-#2 3-state mobile widgets | ✅ CLOSED | `LoadingSkeleton`/`EmptyState`/`ErrorState` reusable + applied 3 screen |
| T1-#3 Endpoint face-config | ✅ CLOSED | `GET /api/mobile/settings/face-config` + fallback graceful |
| T2-#4 Hak hapus face data | ✅ CLOSED | `DELETE /api/mobile/face/me` + UI 2-step dialog UU PDP |
| T2-#5 Rate limit per-device | ✅ CLOSED | Composite key `userId:deviceId` + migration 014 |
| T2-#6 Status terlambat | ✅ CLOSED | DB + backend + UI lengkap |
| T3-#7 Smoke test E2E | ⏳ User-driven | Butuh HP fisik (workflow `/release-build`) |
| T3-#8 DB recovery runbook | ✅ CLOSED | `docs/runbook/db-recovery.md` (8 section + drill protocol) |
| T3-#9 Monitoring & alerting | ⏳ Pro plan | Butuh upgrade Supabase Pro |

### File Baru / Diubah Sesi Ini

```
[16:01] [ADD] mypresensi-web/app/api/mobile/_lib/rate-limit.ts
        Helper sentral: buildRateLimitKey, getDeviceId(req),
        checkSlidingWindowRateLimit, checkCounterRateLimit + auto-prune.

[16:02] [MOD] mypresensi-web/app/api/mobile/auth/login/route.ts
        Composite rate limit user+device + audit capture device_id.

[16:02] [MOD] mypresensi-web/app/api/mobile/auth/change-password/route.ts
        Composite rate limit + audit device_id.

[16:03] [MOD] mypresensi-web/app/api/mobile/attendance/submit/route.ts
        Sliding window 5/menit per (user, device).

[16:04] [MOD] mypresensi-mobile/lib/core/network/dio_client.dart
        Inject header X-Device-Id otomatis di semua request via interceptor.

[16:05] [MOD] mypresensi-mobile/lib/core/storage/secure_storage.dart
        Method getOrCreateDeviceId() — UUID v4 generate-once + cache.

[16:10] [ADD] mypresensi-web/supabase/migrations/014_device_id_audit.sql
        Kolom rate_limit_log.device_id + BTREE expression index pada
        audit_logs((details->>'device_id')) untuk forensic JSONB query.
        Applied via mcp0_apply_migration.

[16:20] [ADD] mypresensi-web/app/api/mobile/face/me/route.ts
        DELETE endpoint (UU PDP Pasal 5-15) — auth + rate limit 3/jam +
        hard delete face_embeddings + set is_face_registered=false +
        audit log dengan previous_embedding_hash (bukan embedding).

[16:22] [MOD] mypresensi-mobile/lib/core/network/api_endpoints.dart
        Tambah ApiEndpoints.faceMine.

[16:22] [MOD] mypresensi-mobile/lib/features/face/data/face_repository.dart
        Method deleteMyFaceData().

[16:23] [ADD] mypresensi-mobile/lib/features/face/providers/face_provider.dart
        FaceDeletionNotifier — state machine idle/loading/success/error +
        invalidate storedEmbeddingProvider after success.

[16:23] [MOD] mypresensi-mobile/lib/features/auth/providers/auth_provider.dart
        Method markFaceUnregistered() — pasangan markFaceRegistered.

[16:24] [MOD] mypresensi-mobile/lib/features/profile/screens/profile_screen.dart
        Tombol "Hapus Data Wajah" (red outlined) hanya saat sudah register +
        dialog 2-step: edukasi konsekuensi → konfirmasi destruktif.

[16:30] [ADD] mypresensi-mobile/lib/shared/widgets/loading_skeleton.dart
        LoadingSkeleton (animated pulse manual via AnimatedBuilder) +
        ListItemSkeleton (avatar+2 baris) + ListLoadingPlaceholder (N cards).
        TIDAK pakai library `shimmer` agar APK tetap ramping.

[16:31] [ADD] mypresensi-mobile/lib/shared/widgets/empty_state.dart
        Widget: icon di lingkaran primarySurface + title + description ramah
        Indonesia + optional CTA button.

[16:32] [ADD] mypresensi-mobile/lib/shared/widgets/error_state.dart
        Widget: icon di lingkaran dangerSurface + title + message +
        tombol "Coba Lagi" opsional.

[16:35] [MOD] mypresensi-mobile/lib/features/history/screens/history_screen.dart
[16:36] [MOD] mypresensi-mobile/lib/features/notifications/screens/notification_screen.dart
[16:37] [MOD] mypresensi-mobile/lib/features/leave_requests/screens/my_leave_requests_screen.dart
        Refactor: pakai 3-state widget reusable, hapus _buildEmpty/_buildError lokal.
        Pull-to-refresh tetap aktif saat empty/error via ListView wrapper.

[16:42] [FIX] mypresensi-mobile/lib/shared/widgets/loading_skeleton.dart
        (_, __) → (_, _) — Dart 3.7+ lint unnecessary_underscores.

[17:00] [ADD] docs/runbook/db-recovery.md
        Runbook 8-section + drill protocol:
        §1 Aset kritis & klasifikasi
        §2 Strategi backup (auto + manual mingguan + migration source)
        §3 Deteksi insiden (advisor + log + forensic query)
        §4 Prosedur recovery (decision tree 5 skenario)
        §5 Postmortem template
        §6 Test recovery drill quarterly
        §7 Kontak eskalasi
        §8 Referensi

[17:25] [MOD] CHANGELOG.md
        3 section baru di sesi 2026-05-14: T2-#5 rate limit, T2-#4 hak hapus
        face data, T1-#2 3-state widgets. Roadmap status updated.

[17:30] [MOD] dev-log.md
        Session entry FINAL — penutup audit komprehensif.
```

### Verifikasi Akhir

```
PS web> npm run type-check; npm run lint
exit 0 — type-check clean, lint clean

PS mobile> flutter analyze
exit 0 — No issues found! (ran in 8.4s)

mcp0_get_advisors({ type: 'security' })
0 issue baru sejak migration 014. (1 INFO unused_index ekspektatif untuk
index forensic baru — hanya jadi "unused" sampai query forensic dipakai.)
```

### Pelajaran Sesi

1. **Rate limit per-device pakai composite key** lebih adil daripada per-IP atau per-user. 1 device bermasalah tidak block semua device user lain. Sliding window untuk endpoint frequent (attendance), counter window untuk operasi destruktif (face delete).

2. **3-state widget reusable** mengurangi duplikasi 4 tempat menjadi 1 source of truth. Pesan ramah Indonesia mandatory — JANGAN pakai pesan teknis ("401 Unauthorized") ke user.

3. **UU PDP hak hapus** wajib UI 2-step (edukasi → konfirmasi). Jangan instant delete biar user tidak salah klik. Audit log simpan hash (bukan data) untuk forensic.

4. **Runbook recovery** harus drillable. Test quarterly di dev branch (Pro plan) atau lokal Postgres restore. Recovery yang tidak pernah di-test = tidak ada.

### Yang Tidak Bisa Dikerjakan Sesi Ini (butuh user/upgrade)

- **T3-#7 Smoke test E2E**: butuh user jalankan `/release-build` workflow di HP fisik dengan koneksi LAN ke web dev server. AI tidak bisa eksekusi physical device.
- **T3-#9 Monitoring & alerting**: butuh upgrade Supabase Pro plan (~$25/bulan) untuk akses Log Drains + Alert Rules. Untuk PBL semester saat ini, manual review log via `mcp0_get_logs` cukup.

### Next Session Hint

Saat user siap untuk smoke test e2e:
1. Jalankan `/start-dev` workflow.
2. `/release-build` untuk APK release dengan obfuscate.
3. Install di HP fisik via `adb install -r`.
4. Smoke test full flow: login → scan QR → submit (in/out radius) → fake GPS test → face register → face verify → izin submit → notif.
5. Document hasil di `docs/incidents/` jika ada bug, atau update CHANGELOG sebagai sesi smoke test pass.

