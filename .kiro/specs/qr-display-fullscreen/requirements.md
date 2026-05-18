# Requirements Document

## Introduction

Spec ini menambahkan **mode presentasi fullscreen QR sesi presensi** pada web admin/dosen MyPresensi. Saat ini QR cuma tampil inline ukuran kecil (160-180px) di card session-list dan modal MK detail — terlalu kecil untuk dibaca dari kursi mahasiswa belakang saat dosen mengajar dengan proyektor. Solusi: route baru `/sesi/[id]/qr` yang membuka di window terpisah dengan layout fullscreen (QR 360px, OTP 88pt monospace, countdown bar gold, stats hadir/total live polling 5 detik).

Fitur ini memenuhi gap **B1** dari `docs/TODO.md` (Prioritas 2 nomor 2: "QR Display Presentasi"). Mockup referensi: `docs/ui-research/mockups/qr-display.html` dengan inspirasi visual Slido / Kahoot / Mentimeter event projector mode.

Setiap implementasi WAJIB lulus `npm run type-check` exit 0 dan `npm run lint` clean sebelum task ditandai selesai (rule `02-quality-debugging-verification.md`), diakhiri smoke test manual oleh user.

## Glossary

- **Web_App**: Aplikasi Next.js `mypresensi-web/` yang dijalankan di laptop dosen / admin.
- **Qr_Display_Page**: Server Component baru di `app/(qr-projector)/sesi/[id]/qr/page.tsx` yang merender mode presentasi fullscreen.
- **Qr_Display_Client**: Client Component baru `qr-display-client.tsx` yang handle countdown, polling, dan UI interaktif.
- **Qr_Projector_Layout**: Layout minimal di `app/(qr-projector)/layout.tsx` tanpa sidebar/topbar.
- **Live_Stats_Endpoint**: Endpoint baru `GET /api/admin/sessions/[id]/live-stats` yang return `{ hadir: number, total: number }`.
- **Fullscreen_Trigger_Button**: Tombol "Tampilkan Fullscreen" di `app/(dashboard)/sesi/session-list.tsx` dan `app/(dashboard)/matakuliah/sessions-modal.tsx` yang membuka Qr_Display_Page di tab/window baru.
- **Session_Code**: 6-digit OTP rotasi per sesi (`sessions.session_code`), expired sesuai `session_code_expires_at` (default 3 menit).
- **Countdown_Timer**: UI timer hitung mundur dari `session_code_expires_at - now`. Berhenti di 00:00 → trigger Expired_Overlay.
- **Live_Stats**: Data polling setiap 5 detik berisi hadir count + total enrolled mahasiswa.
- **Expired_Overlay**: Overlay penuh saat Session_Code sudah expired, dengan tombol "Refresh Kode".
- **Polling_Interval**: 5 detik default untuk fetch Live_Stats.
- **Polling_Backoff**: Exponential backoff saat 3 consecutive errors → wait 30 detik.
- **AbortController**: API browser native untuk cancel in-flight fetch saat client unmount.
- **`session-list.tsx`**: File `app/(dashboard)/sesi/session-list.tsx` (existing) — daftar sesi grouped by MK.
- **`sessions-modal.tsx`**: File `app/(dashboard)/matakuliah/sessions-modal.tsx` (existing) — modal detail sesi MK.
- **requireRole**: Helper `app/lib/auth-guard.ts` (existing) — gate role admin/dosen.
- **canAccessCourse**: Helper `app/lib/auth-guard.ts` (existing) — gate ownership MK.
- **createAdminClient**: Helper `app/lib/supabase/server.ts` (existing) — Supabase service_role client (bypass RLS, dipakai setelah auth check).
- **type-check**: `npm run type-check` di `mypresensi-web/`. Exit 0 = TypeScript strict pass.
- **lint**: `npm run lint` di `mypresensi-web/`. 0 errors + 0 warnings = clean.

## Requirements

### Requirement 1: Route Group `(qr-projector)` Terisolasi

**User Story:** Sebagai dosen yang membuka mode presentasi, saya ingin halaman QR fullscreen TIDAK menampilkan sidebar atau topbar dashboard sehingga QR memenuhi viewport projector tanpa distraksi.

#### Acceptance Criteria

1. THE Web_App SHALL menyediakan route group baru `app/(qr-projector)/` dengan layout terisolasi (`layout.tsx`) yang TIDAK render sidebar maupun topbar.
2. THE Qr_Projector_Layout SHALL set metadata `robots: 'noindex, nofollow'` agar URL admin tidak ke-index search engine.
3. THE Qr_Projector_Layout SHALL menerapkan dark theme (background gradient navy ke hitam) sebagai base styling.
4. THE route URL SHALL tetap `/sesi/[id]/qr` (route group `(qr-projector)` tidak muncul di URL — Next.js convention).

### Requirement 2: Server-Side Auth & Ownership Gate

**User Story:** Sebagai admin sistem, saya ingin pastikan halaman QR fullscreen hanya bisa diakses oleh dosen pemilik MK atau admin, sehingga sesi mahasiswa lain tidak bocor.

#### Acceptance Criteria

1. WHEN user mengakses `/sesi/[id]/qr` tanpa autentikasi cookie aktif, THE Qr_Display_Page SHALL redirect ke `/login` (via middleware existing).
2. WHEN user mengakses dengan role mahasiswa, THE Qr_Display_Page SHALL redirect ke `/login` atau halaman error (per pattern `requireRole`).
3. WHEN dosen mengakses session dari MK yang BUKAN miliknya, THE Qr_Display_Page SHALL redirect ke `/sesi?error=no-access` via `canAccessCourse` check.
4. WHEN admin mengakses, THE Qr_Display_Page SHALL allow tanpa ownership check (admin global access).
5. THE Qr_Display_Page SHALL menggunakan `requireRole(['admin', 'dosen'])` + `canAccessCourse(user.id, role, session.course_id)` PADA SERVER COMPONENT (BUKAN client side) sebagai defense-in-depth.

### Requirement 3: Initial Data Fetch SSR

**User Story:** Sebagai dosen, saya ingin saat halaman QR fullscreen pertama kali muncul, data sesi (nama MK, OTP, countdown awal, stats awal) sudah ter-render — bukan loading flash kosong.

#### Acceptance Criteria

1. THE Qr_Display_Page SHALL fetch data sesi via SSR Server Component menggunakan `createAdminClient()` setelah auth gate berhasil.
2. THE SSR fetch SHALL mengambil dalam SATU query: `id`, `course_id`, `session_number`, `topic`, `mode`, `session_code`, `session_code_expires_at`, `is_active`, `started_at`, plus JOIN `courses(code, name, dosen:profiles(full_name))`.
3. THE Qr_Display_Page SHALL fetch initial Live_Stats SECARA PARALEL dengan session fetch via `Promise.all`, sehingga first paint sudah ada angka hadir/total.
4. WHEN session tidak ditemukan (deleted), THE Qr_Display_Page SHALL return `notFound()` Next.js (404).
5. THE Qr_Display_Page SHALL pass semua data ke Qr_Display_Client sebagai props (BUKAN re-fetch di client mount).

### Requirement 4: QR Code Visual

**User Story:** Sebagai mahasiswa di kursi belakang kelas, saya ingin QR code cukup besar untuk di-scan dari jarak ~5-10 meter.

#### Acceptance Criteria

1. THE Qr_Display_Client SHALL merender QR dengan ukuran minimum 360px (mockup spec) menggunakan komponen `QRCodeSVG` dari `qrcode.react`.
2. THE QR payload SHALL mengikuti format existing: `JSON.stringify({ sid: session.id, code: session.session_code, exp: session.session_code_expires_at })`.
3. THE QR card SHALL ditampilkan pada container putih dengan border-radius 24px, padding 24px, drop shadow gold accent (`box-shadow: 0 0 60px rgba(244,180,0,0.20)`).
4. THE QR card SHALL memiliki gradient border glow `linear-gradient(135deg, accent, primary)` dengan blur 20px sebagai signature visual.
5. WHERE Session_Code null atau is_active=false, THE Qr_Display_Client SHALL menampilkan placeholder/empty state dengan pesan "Sesi tidak aktif" + tombol kembali.

### Requirement 5: OTP Display Visual

**User Story:** Sebagai mahasiswa yang HP-nya gagal scan QR, saya ingin baca OTP 6-digit dari layar projector dan ketik manual di mobile app.

#### Acceptance Criteria

1. THE Qr_Display_Client SHALL menampilkan Session_Code dalam format **88pt monospace** (font JetBrains Mono atau equivalent) berwarna putih dengan letter-spacing 4px.
2. THE OTP block SHALL menampilkan label "KODE SESI" uppercase tracking 2px warna gold di atas digit.
3. THE OTP digit SHALL diberi visual separator titik tengah `·` warna gold antara digit ke-3 dan ke-4 (misalnya `847·392` BUKAN `847392` raw).
4. THE OTP block SHALL menggunakan background semi-transparent `rgba(255,255,255,0.05)` dengan border subtle dan backdrop-blur 10px (glassmorphism effect).

### Requirement 6: Countdown Bar & Timer

**User Story:** Sebagai dosen, saya ingin tahu berapa detik lagi OTP/QR akan expired sehingga bisa antisipasi mahasiswa yang masih scan.

#### Acceptance Criteria

1. THE Qr_Display_Client SHALL menampilkan progress bar horizontal di bawah OTP digit dengan fill width berdasarkan `(secondsRemaining / sessionCodeExpiryMinutes×60) × 100%`.
2. THE progress bar SHALL menggunakan gradient `linear-gradient(90deg, accent, #f59e0b)` dengan box-shadow gold glow.
3. THE Qr_Display_Client SHALL menampilkan teks countdown format `MM:SS` (mis. "02:34") di sebelah kanan progress bar dalam font monospace 22pt putih.
4. WHEN secondsRemaining = 0, THE Qr_Display_Client SHALL trigger Expired_Overlay (lihat Req 9).
5. THE countdown SHALL dihitung pure di client menggunakan `setInterval(1000ms)` recompute dari `(new Date(expiresAt).getTime() - Date.now())` agar tidak butuh server polling untuk timer.
6. THE countdown SHALL clearInterval saat client unmount (mencegah memory leak).

### Requirement 7: Live Stats Endpoint Backend

**User Story:** Sebagai pengembang yang menjaga konsistensi backend, saya ingin endpoint baru terisolasi di namespace admin (BUKAN mobile) untuk return live stats hadir + total enrolled.

#### Acceptance Criteria

1. THE Web_App backend SHALL menyediakan endpoint baru `GET /api/admin/sessions/[id]/live-stats` di file `app/api/admin/sessions/[id]/live-stats/route.ts`.
2. THE endpoint SHALL menggunakan `requireRole(['admin', 'dosen'])` untuk gate role.
3. THE endpoint SHALL menggunakan `canAccessCourse(user.id, role, session.course_id)` untuk gate ownership (kalau dosen).
4. THE endpoint SHALL menerapkan rate limit 60 request per 60 detik per kombinasi `(user_id, session_id)` menggunakan in-memory sliding window pattern.
5. WHEN auth fail, THE endpoint SHALL return status 401 dengan body `{ error: 'Tidak terautentikasi' }`.
6. WHEN ownership fail, THE endpoint SHALL return status 403 dengan body `{ error: 'Tidak ada akses ke sesi ini' }`.
7. WHEN session tidak ditemukan, THE endpoint SHALL return status 404 dengan body `{ error: 'Sesi tidak ditemukan' }`.
8. WHEN rate limit exceeded, THE endpoint SHALL return status 429 dengan body `{ error: 'Terlalu banyak permintaan' }`.
9. THE endpoint SHALL return status 200 dengan body `{ hadir: number, total: number }` saat sukses.
10. THE endpoint SHALL TIDAK memanggil `logAudit()` (read-only endpoint).
11. THE endpoint SHALL TIDAK mengexpose `session_code`, `session_code_expires_at`, atau field sensitif lain di response.
12. THE endpoint SHALL menggunakan `createAdminClient()` (service_role) untuk query DB SETELAH auth+ownership berhasil.

### Requirement 8: Live Stats Query

**User Story:** Sebagai pengembang yang menjaga performa, saya ingin endpoint stats memakai query efisien tanpa N+1 atau over-fetch.

#### Acceptance Criteria

1. THE endpoint SHALL menggunakan `Promise.all` untuk 2 count query parallel: (a) attendances dengan `session_id = $id AND status IN ('hadir', 'terlambat')`, (b) enrollments dengan `course_id = session.course_id`.
2. THE attendance count SHALL menyertakan status `'hadir'` AND `'terlambat'` (kedua status menandakan mahasiswa sudah scan dan tercatat di kelas).
3. THE attendance count SHALL TIDAK menyertakan status `'izin'`, `'sakit'`, atau `'alpa'` di angka hadir live (semua itu bukan kehadiran fisik).
4. THE response `total` field SHALL = count enrollments untuk MK terkait.
5. THE response `hadir` field SHALL ≤ `total` (invariant).

### Requirement 9: Expired State Overlay

**User Story:** Sebagai dosen, saat OTP expired di tengah kelas saya ingin tombol cepat untuk refresh kode tanpa keluar dari mode fullscreen.

#### Acceptance Criteria

1. WHEN Countdown_Timer mencapai 00:00, THE Qr_Display_Client SHALL menampilkan Expired_Overlay full-screen di atas QR card.
2. THE Expired_Overlay SHALL menampilkan judul "Kode Sesi Sudah Expired" Plus Jakarta Sans w800 large.
3. THE Expired_Overlay SHALL menampilkan tombol pill "Refresh Kode" yang panggil server action `refreshSessionCode(sessionId)` (existing di `app/lib/actions/sessions.ts`).
4. WHEN user klik "Refresh Kode" dan action sukses, THE Qr_Display_Client SHALL panggil `router.refresh()` Next.js untuk re-fetch data sesi terbaru dari server.
5. WHEN refresh fail, THE Qr_Display_Client SHALL menampilkan toast error via `@/lib/swal` (existing).
6. THE QR card di belakang Expired_Overlay SHALL di-blur 50% atau dim untuk indikasi visual bahwa kode lama sudah tidak valid.

### Requirement 10: Polling Lifecycle

**User Story:** Sebagai dosen, saya ingin angka hadir/total update setiap beberapa detik tanpa saya refresh halaman, tapi tidak boleh bombard server.

#### Acceptance Criteria

1. WHEN Qr_Display_Client mount, THE client SHALL start polling Live_Stats_Endpoint dengan interval 5 detik.
2. THE polling SHALL menggunakan `AbortController` untuk setiap fetch agar bisa cancel in-flight request saat unmount.
3. WHEN polling response 200, THE client SHALL update state stats dan reset error counter.
4. WHEN polling fail dengan network error atau status 5xx kurang dari 3 kali consecutive, THE client SHALL retry pada interval normal 5 detik.
5. WHEN polling fail 3 kali consecutive, THE client SHALL pakai backoff 30 detik untuk poll selanjutnya, dan tampilkan badge "Sync terganggu, akan retry 30 detik" di area stats.
6. WHEN polling sukses setelah backoff aktif, THE client SHALL reset error counter dan kembali ke interval 5 detik.
7. WHEN polling response 401, THE client SHALL `window.location.href = '/login'` (session expired di tengah kelas).
8. WHEN polling response 403, THE client SHALL stop polling permanently dan tampilkan banner "Tidak ada akses" + auto-close window setelah 3 detik.
9. WHEN polling response 404 (session deleted), THE client SHALL stop polling dan tampilkan banner "Sesi sudah dihapus" + auto-close window setelah 3 detik.

### Requirement 11: Polling Termination & Cleanup

**User Story:** Sebagai pengembang yang menjaga memory hygiene, saya ingin polling stop bersih saat dosen tutup window — tidak ada memory leak atau ghost network calls.

#### Acceptance Criteria

1. WHEN Qr_Display_Client unmount, THE client SHALL clearTimeout/clearInterval semua handle aktif.
2. WHEN unmount, THE client SHALL panggil `controller.abort()` pada AbortController in-flight (kalau ada).
3. WHEN AbortError catch, THE client SHALL silent (no toast, no log) — itu expected behavior bukan error.
4. AFTER unmount + 1 detik, THE client SHALL TIDAK lagi call `setState` atau callback `onSuccess`/`onError`.
5. THE Qr_Display_Client SHALL menggunakan `useEffect` cleanup pattern React standar untuk lifecycle management.

### Requirement 12: Stats Visual

**User Story:** Sebagai dosen, saya ingin progress kehadiran live ditampilkan jelas di bagian bawah projector sehingga saya tahu progress real-time.

#### Acceptance Criteria

1. THE Qr_Display_Client SHALL menampilkan strip stats di bagian bawah viewport dengan layout 3 kolom: stat hadir / progress bar / stat lain (atau strip sederhana 2 kolom dengan progress bar dominan).
2. THE stats display SHALL menampilkan angka `hadir` dengan font Plus Jakarta Sans w800 size 32 putih.
3. THE stats display SHALL menampilkan label "HADIR" + angka `total` enrolled (mis. "12 / 45 Hadir").
4. THE stats display SHALL menampilkan progress bar horizontal dengan fill width = `(hadir / total) × 100%`.
5. THE progress bar SHALL menggunakan gradient `linear-gradient(90deg, primary, success)` dengan shimmer animation.
6. WHEN total = 0 (kasus edge: MK tanpa enrollment), THE progress bar SHALL fixed di 0% dan tampilkan teks "Belum ada mahasiswa terdaftar".
7. WHEN polling state error backoff, THE stats display SHALL menampilkan badge kecil "Sync terganggu" di samping angka hadir, tapi angka cached terakhir tetap visible.

### Requirement 13: Fullscreen Trigger Button

**User Story:** Sebagai dosen, saya ingin akses ke mode fullscreen lewat tombol jelas di card sesi aktif yang sudah saya pakai sehari-hari.

#### Acceptance Criteria

1. THE `session-list.tsx` SHALL menampilkan tombol "Tampilkan Fullscreen" pada active session card (kondisi: `session.is_active && session.session_code`).
2. THE tombol SHALL menggunakan tag `<a>` dengan attribut `href={\`/sesi/${session.id}/qr\`}`, `target="_blank"`, `rel="noopener noreferrer"`.
3. THE tombol SHALL menampilkan icon Lucide `Maximize2` atau `ExternalLink` plus label "Tampilkan Fullscreen".
4. THE tombol SHALL menggunakan style secondary (outline atau ghost variant) — bukan primary dominan, agar tidak mendominasi tombol Refresh dan Copy yang sudah ada.
5. THE `sessions-modal.tsx` SHALL menampilkan tombol yang sama di card active session-nya.
6. THE tombol SHALL TIDAK pakai `window.open()` programmatic (anchor-based, semantic HTML).

### Requirement 14: Security Hardening

**User Story:** Sebagai admin sistem, saya ingin pastikan tidak ada celah security baru dari fitur ini.

#### Acceptance Criteria

1. THE Qr_Display_Page SHALL TIDAK menerima `session_code` sebagai query parameter URL (URL pattern `/sesi/[id]/qr` — `[id]` adalah session UUID, bukan code).
2. THE server-side log SHALL TIDAK pernah `console.log()` field `session_code` atau `session_code_expires_at`.
3. THE Live_Stats_Endpoint SHALL TIDAK mengexpose `session_code` atau field sensitif lain dalam response JSON.
4. THE error response SHALL menggunakan pesan generik Bahasa Indonesia, BUKAN melempar Supabase error mentah ke client.
5. THE rate limit SHALL dicek SEBELUM query DB executed, sehingga 429 tidak membebani DB saat abuse.
6. THE Fullscreen_Trigger_Button SHALL menggunakan `rel="noopener noreferrer"` mencegah `window.opener` injection.

### Requirement 15: Bahasa Indonesia Copy

**User Story:** Sebagai dosen yang berbahasa Indonesia, saya ingin semua label dan pesan di mode fullscreen menggunakan Bahasa Indonesia natural.

#### Acceptance Criteria

1. THE Qr_Display_Client SHALL menampilkan semua label visible (judul, button, instruction list, status badge) dalam Bahasa Indonesia.
2. THE Live_Stats_Endpoint SHALL mengembalikan pesan error dalam Bahasa Indonesia (contoh: "Tidak terautentikasi", "Tidak ada akses ke sesi ini", "Sesi tidak ditemukan", "Terlalu banyak permintaan").
3. WHERE error ditampilkan ke user, THE Qr_Display_Client SHALL menggunakan toast `@/lib/swal` dengan pesan ramah Bahasa Indonesia.

### Requirement 16: Visual Fidelity to Mockup

**User Story:** Sebagai pemilik produk yang sudah memoles mockup, saya ingin implementasi match dengan visual mockup di `qr-display.html`.

#### Acceptance Criteria

1. THE Qr_Display_Client SHALL menggunakan dark gradient background `radial-gradient(ellipse at top left, #0D2C5E 0%, #050d1c 60%)` di-apply di Qr_Projector_Layout.
2. THE Qr_Display_Client SHALL menampilkan gold radial glow accent di kanan atas dan blue radial glow di kiri bawah viewport (per mockup `.presentation::before` dan `::after`).
3. THE topbar fullscreen SHALL menampilkan brand logo + nama MK + status pill "SESI AKTIF" hijau dengan pulse-dot animasi.
4. THE topbar SHALL menampilkan tombol "Tutup" (close) di kanan atas yang panggil `window.close()` (window terpisah aman untuk close programmatic).
5. THE main content SHALL split 2 kolom: QR card kiri (~380px) + info area kanan (1fr) dengan gap 56px (per mockup `.pres-main`).
6. THE info area kanan SHALL menampilkan: course tag pill + course name h1 (42pt w800) + meta row (dosen + jam + lokasi + mode) + OTP block + countdown bar + instruction list "1-2-3" cara scan.
7. THE bottom strip SHALL menampilkan stats progress (Req 12).

### Requirement 17: Verification Gate

**User Story:** Sebagai engineer yang menjaga kualitas, saya ingin setiap task diverifikasi secara teknis sebelum ditandai selesai.

#### Acceptance Criteria

1. WHEN engineer menyelesaikan endpoint backend, THE engineer SHALL menjalankan `npm run type-check` di `mypresensi-web/` dan memastikan exit 0.
2. WHEN engineer menyelesaikan endpoint backend, THE engineer SHALL menjalankan `npm run lint` di `mypresensi-web/` dan memastikan 0 error 0 warning baru.
3. WHEN engineer menyelesaikan keseluruhan spec, THE engineer SHALL re-run kedua command di atas pasca-final wiring.
4. WHEN type-check atau lint fail, THE task SHALL TIDAK dianggap selesai hingga issue diperbaiki.

### Requirement 18: Manual Smoke Test

**User Story:** Sebagai pemilik produk, saya ingin verifikasi visual + integrasi yang tidak terdeteksi static analyzer divalidasi manual oleh user.

#### Acceptance Criteria

1. WHEN keseluruhan implementasi selesai dan kedua verification gate lulus, THE pemilik produk SHALL melakukan smoke test manual mencakup:
   - (a) Login dosen demo → buka /sesi page → klik tombol "Tampilkan Fullscreen" pada active session card
   - (b) Verify window baru terbuka dengan URL `/sesi/[id]/qr` di tab baru
   - (c) Verify visual: QR 360px, OTP 88pt mono dengan separator gold, countdown bar gold gradient, stats hadir/total tampil
   - (d) Verify polling: buka Network tab Chrome DevTools → cek request `live-stats` setiap 5 detik
   - (e) Demo scan QR pakai HP mahasiswa → verify hadir count naik di stats area dalam 5 detik
   - (f) Diamkan sampai countdown 00:00 → verify Expired_Overlay muncul + tombol Refresh Kode
   - (g) Klik Refresh Kode → verify countdown reset, polling resume
   - (h) Tutup window → verify Network tab no more polling requests (cleanup berhasil)
   - (i) Login mahasiswa → akses URL `/sesi/[id]/qr` direct → verify redirect/blocked (auth gate)
   - (j) Login dosen lain → akses URL session bukan miliknya → verify redirect ke /sesi (ownership gate)
2. THE manual smoke test SHALL menggunakan akun demo dari `mypresensi-web/.dev-accounts.md` atau `credentials-MUSTREAD.txt`.
3. THE manual smoke test result SHALL didokumentasikan di `dev-log.md` atau `CHANGELOG.md` (entri `[ADD]` per komponen baru).

### Requirement 19: Out of Scope (Explicit Non-Goals)

**User Story:** Sebagai pemilik produk yang ingin scope terkontrol, saya ingin pastikan fitur ini tidak mencakup hal-hal yang menjadi spec terpisah.

#### Acceptance Criteria

1. THE spec ini SHALL TIDAK mencakup QR rolling 5 detik dinamis (TOTP-like) — itu Phase 3 spec terpisah.
2. THE spec ini SHALL TIDAK menggunakan Supabase Realtime channel — itu Phase C1 spec terpisah, polling 5 detik adalah implementasi sementara yang bisa di-upgrade nanti.
3. THE spec ini SHALL TIDAK menampilkan activity feed "siapa scan barusan" — itu defer ke Phase B2 Live Monitor.
4. THE spec ini SHALL TIDAK menampilkan geofence ring visualization — itu defer ke Phase B2 Live Monitor.
5. THE spec ini SHALL TIDAK auto-refresh QR saat expiry — refresh manual via tombol Expired_Overlay sudah cukup.
6. THE Qr_Display_Page SHALL TIDAK responsive untuk mobile (<1280px). Phone yang akses URL ini boleh tampilkan banner "Buka di laptop untuk pengalaman terbaik" tapi konten tetap di-render fallback (degraded layout, akseptabel).
7. THE Qr_Display_Page SHALL TIDAK mengubah QR payload format (`{sid, code, exp}`). Mobile scanner Flutter TIDAK perlu disentuh.
