# Smoke Test Checklist — MyPresensi (Sesi Mei 2026)

> Checklist verifikasi 10 fitur yang sudah selesai diimplementasi sebelum demo PBL.
> Pakai dokumen ini side-by-side dengan SQL helper di `scripts/smoke-test/*.sql`.
> Setiap step penting punya 3 checkbox: **UI** · **DB** · **audit_logs** (rule `02-quality-debugging` A.1).

## Ringkasan

| Tier | Fitur | Total Effort |
|------|-------|--------------|
| **P0 (BLOCKER)** | Mock GPS · Face Verify · At-Risk Revoke · Login → Submit | ~30 menit |
| **P1 (CRITICAL)** | Live Monitor + Realtime · QR Fullscreen · Leave Evidence · Avatar · Onboarding | ~1 jam |
| **P2 (NICE-TO-HAVE)** | Hak hapus face (UU PDP) · Realtime reconnect | ~30 menit |
| **TOTAL** | 10 fitur + universal | ~2 jam |

**Aturan emas**:
- ❌ Failed P0 = STOP. Fix dulu sebelum lanjut. Jangan demo dengan P0 fail.
- ⚠️ Failed P1 = downgrade demo experience. Catat sebagai known-issue + workaround.
- ℹ️ Failed P2 = file as known-issue di `dev-log.md`, lanjutkan demo.

## Prerequisites Umum

Sebelum mulai test, pastikan:

- [ ] Backend web running di `localhost:3000`: `cd mypresensi-web && npm run dev`
- [ ] Migration sudah apply (cek `mcp0_list_migrations` → terbaru = `021_enable_realtime_attendances`)
- [ ] Akun test sudah siap di `mypresensi-web/.dev-accounts.md` atau `credentials-MUSTREAD.txt`
  - Admin (web)
  - Dosen 1 (web — punya MK aktif)
  - Mahasiswa 1, 2, 3 (mobile — enrolled di MK Dosen 1)
- [ ] Mobile emulator (Pixel 9a API 36) ATAU HP fisik dengan APK debug terpasang
- [ ] APK release build sudah di-build (untuk test mock GPS — wajib release, debug bypass `isMocked`):
  ```powershell
  cd mypresensi-mobile
  flutter build apk --release --obfuscate --split-debug-info=build/symbols
  adb install -r build/app/outputs/flutter-apk/app-release.apk
  ```
- [ ] Fake GPS app terinstall di device fisik release-build (mis. "Fake GPS Location" di Play Store)
- [ ] Supabase Studio terbuka untuk run SQL helper (`scripts/smoke-test/*.sql`)

## 2-Window Setup Guide (Live Monitor)

Diagram konkret untuk fitur showcase utama:

```
┌─────────────────────────────────────────────────┐  ┌─────────────────────┐
│ Window 1 — Browser Desktop (Chrome)             │  │ Window 2 — Mobile   │
│                                                 │  │ (Emulator/HP)       │
│ Login: dosen1@trpl.politanisamarinda.ac.id      │  │                     │
│ URL  : /sesi → klik card sesi aktif             │  │ Login: mhs1@…       │
│        → klik tombol "Live Monitor"             │  │ Tap "Scan QR"       │
│ Lihat: geofence ring 380px, KPI bar, activity   │  │ Scan QR di Window 1 │
│        feed, student grid 30 mhs                │  │ (atau dari /qr      │
│                                                 │  │ fullscreen di       │
│ ┌─────────────────┐                             │  │ Window 1)           │
│ │  Geofence Ring  │ ◄── dot mhs muncul          │  │                     │
│ │  ° °  ●         │     <2 detik setelah        │  │                     │
│ │   ° ●           │     mahasiswa submit        │  │                     │
│ │  °              │                             │  │                     │
│ └─────────────────┘                             │  │                     │
└─────────────────────────────────────────────────┘  └─────────────────────┘
```

Expected: setelah mahasiswa submit di Window 2, dot di geofence ring Window 1 berubah hijau **dalam <2 detik** (Realtime, bukan polling 5 detik).

---

# 🚨 P0 — BLOCKER (wajib pass, ~30 menit)

## Fitur: Login → Submit Attendance (E2E Happy Path) [P0]

**Spec**: `.kiro/specs/realtime-attendances-channel/`, `mypresensi-web/app/api/mobile/attendance/submit/route.ts`
**Effort**: 8 menit
**Prerequisites**: dosen sudah login web + ada sesi aktif. Mahasiswa belum submit di sesi ini.

### Setup
1. Window 1 (web): Login dosen → buka `/sesi` → ada satu card sesi aktif dengan QR + OTP
2. Window 2 (mobile): Login mahasiswa1 (akun bersih, GPS asli, bukan mock)
3. Catat `<SESSION_ID>` dari URL `/sesi/<id>/live` atau dari Section 1.1 `verify-attendance.sql`

### Test Steps

1. **Action**: Mahasiswa tap "Scan QR" di home → arahkan kamera ke QR di Window 1
   - [ ] **UI behavior**: Bottom sheet konfirmasi muncul ("Anda akan presensi di MK X · Pertemuan N"), tombol "Konfirmasi" enabled
   - [ ] **DB row**: belum ada row baru (baseline). Jalankan `verify-attendance.sql` Section 1.3 → expected `existing_count = 0`
   - [ ] **audit_logs**: belum ada audit row submit

2. **Action**: Mahasiswa tap "Konfirmasi" → tunggu spinner GPS + (opsional) face verify
   - [ ] **UI behavior**: success snackbar hijau "Presensi tercatat" + redirect ke /home, today summary update (Hadir +1)
   - [ ] **DB row**: jalankan `verify-attendance.sql` Section 2.1 → ada 1 row baru dengan `status='hadir'`, `is_mock_location=false`, `is_location_valid=true`, `distance_meters` non-null
   - [ ] **DB sanity**: jalankan Section 2.2 → kolom `sanity = 'OK'` (Haversine konsisten)
   - [ ] **audit_logs**: jalankan Section 3.1 → ada row `mobile_attendance_submit` dengan `user_id=<STUDENT_ID>`, `ip_address` non-null, `details.session_id` cocok
   - [ ] **audit shape**: jalankan Section 3.2 → `has_session_id=true`, `has_device_id=true`, `has_user_agent=true`

3. **Action**: Mahasiswa coba submit lagi ke sesi yang sama (re-tap Scan)
   - [ ] **UI behavior**: error snackbar "Anda sudah pernah presensi di sesi ini" (UNIQUE constraint enforce)
   - [ ] **DB row**: jalankan Section 2.3 → tetap `attendance_rows = 1` (bukan 2)

---

## Fitur: Mock GPS Rejection [P0 — anti-fraud, RELEASE BUILD]

**Spec**: rule `04-security` E, `05-testing-and-release` Section A — debug build bypass `isMocked`
**Effort**: 7 menit
**Prerequisites**: APK **release** terinstall di HP fisik, Fake GPS app aktif, sesi aktif

### Setup
1. Aktifkan Fake GPS:
   - Settings → Developer Options → "Select mock location app" → pilih Fake GPS
   - Buka Fake GPS app → set lokasi ke Politani `(-0.5378, 117.1242)` (atau lokasi mana saja, biar `isMocked=true`)
2. Pastikan APK release sudah di-install (debug build TIDAK akan reject — `isMocked` bypass otomatis di debug)

### Test Steps

1. **Action**: Mahasiswa (release APK) tap Scan QR → konfirmasi submit
   - [ ] **UI behavior**: error dialog merah Bahasa Indonesia "Lokasi palsu terdeteksi. Presensi ditolak demi keamanan." + tombol Tutup. TIDAK redirect ke success
   - [ ] **DB row**: jalankan `verify-attendance.sql` Section 4.1 → `attendance_rows_after_mock = 0` (atau sama dengan baseline). Server reject pre-insert.
   - [ ] **audit_logs**: jalankan Section 4.2 → ada row `mock_location_detected` dengan `ip_address` non-null + `details.session_id` + `details.student_lat`/`student_lng` (untuk forensic)

2. **Action**: Matikan Fake GPS, aktifkan GPS asli, retry
   - [ ] **UI behavior**: submit berhasil normal (sama seperti happy path)
   - [ ] **DB row**: row baru dengan `is_mock_location=false` muncul

> ⚠️ **Wajib release build**. Debug build di Android otomatis bypass `isMocked` flag dari `geolocator` — tidak akan reproduce. Lihat rule `05-testing-and-release` G.2.

---

## Fitur: Face Verification Server-Side (T0-#10) [P0 — UU PDP biometrik]

**Spec**: `.kiro/specs/face-verification-server-side/spec.md`
**Effort**: 8 menit
**Prerequisites**: mahasiswa1 sudah register wajah, sesi dengan `face_verification_mode=required` (set via admin /settings)

### Setup
1. Login admin → /settings → set `face_verification_mode = required` → simpan
2. Mahasiswa1 sudah punya 1 row di `face_embeddings` (cek via `verify-face.sql` Section 1.1)

### Test Steps

1. **Action**: Mahasiswa scan QR sesi → flow lanjut ke Face Verification screen → wajah cocok
   - [ ] **UI behavior**: countdown 7-frame, snackbar "Wajah cocok" hijau → lanjut submit success
   - [ ] **DB row attendances**: jalankan `verify-attendance.sql` Section 2.1 → `face_confidence` non-null (≥ 0.65), `is_face_matched=true`, `is_liveness_passed=true`
   - [ ] **audit_logs**: jalankan `verify-face.sql` Section 3.1 → row `mobile_face_verify` dengan `matched=true`, `similarity` ≥ threshold, `leaked_raw_embedding=false` (rule 04-security B.3 — JANGAN log embedding mentah)

2. **Action**: Mahasiswa lain (mahasiswa2 yang BELUM register wajah) coba submit di sesi yang sama
   - [ ] **UI behavior**: redirect ke /face-register screen dengan banner "Daftarkan wajah dulu"
   - [ ] **audit_logs**: jalankan `verify-attendance.sql` Section 5 → row `face_not_registered_attempt` muncul

3. **Action**: Curl test endpoint lama yang DIHAPUS — `GET /api/mobile/face/embedding`
   ```powershell
   curl -i http://localhost:3000/api/mobile/face/embedding -H "Authorization: Bearer <jwt>"
   ```
   - [ ] **HTTP**: response 404 (endpoint dihapus per task T1.3 spec). Embedding mentah TIDAK PERNAH bocor ke client.

4. **Action**: Test wajah orang lain (atau foto wajah lain) ke verify endpoint
   - [ ] **UI behavior**: snackbar "Wajah tidak cocok, coba ulang" + tetap di face-verify screen
   - [ ] **DB row attendances**: TIDAK ada row insert (server reject pre-insert)
   - [ ] **audit_logs**: row `face_mismatch_attempt` muncul (Section 5)

---

## Fitur: At-Risk RPC Revoke Public Access (T0-#11) [P0 — security advisor]

**Spec**: `.kiro/specs/at-risk-rpc-revoke-public/spec.md`, migration 018
**Effort**: 5 menit
**Prerequisites**: Supabase Studio terbuka

### Setup
- Tidak perlu UI/mobile interaction. Pure DB grant verification.

### Test Steps

1. **Action**: Jalankan `verify-face.sql` Section 5.1 (function grants check)
   - [ ] **DB grants**: output exactly 4 baris:
     - `anon          | false`
     - `authenticated | false`
     - `service_role  | true`
     - `postgres      | true`
   - Kalau `anon` atau `authenticated` = true → STOP. Migration 018 belum apply.

2. **Action**: Jalankan Section 5.2 (SECURITY DEFINER + search_path)
   - [ ] **DB**: `is_security_definer = true`, `config_settings` include `search_path=public, pg_temp` (rule 14-supabase G + 04-security B)

3. **Action**: Coba RPC call sebagai anon (curl tanpa Authorization)
   ```powershell
   curl -i -X POST "<SUPABASE_URL>/rest/v1/rpc/get_at_risk_students" `
     -H "apikey: <ANON_KEY>" `
     -H "Content-Type: application/json" `
     -d "{}"
   ```
   - [ ] **HTTP**: response **403** atau **42501 permission denied** (BUKAN 200 dengan data)

4. **Action**: Verifikasi caller internal masih jalan (smoke test web)
   - [ ] **UI**: login admin → buka `/dashboard` (Server Action `getAtRiskSummary` pakai `createAdminClient()` = service_role) → widget at-risk muncul tanpa error
   - [ ] **UI**: buka `/dashboard/at-risk` → list mahasiswa muncul

5. **Action**: Run advisor untuk konfirmasi 0 issue
   - [ ] **MCP**: `mcp0_get_advisors({ type: 'security' })` → tidak ada `*_security_definer_function_executable` untuk `get_at_risk_students`

---

# 🎯 P1 — CRITICAL Demo Showcase (~1 jam)

## Fitur: Live Monitor Dosen + Realtime <2 detik (Phase B2 + C1) [P1]

**Spec**: `.kiro/specs/live-monitor-dosen/`, `.kiro/specs/realtime-attendances-channel/`
**Effort**: 15 menit (fitur showcase utama)
**Prerequisites**: 2-Window setup (lihat atas), 3 mahasiswa siap di mobile

### Setup
1. Window 1 (Chrome desktop): Login dosen → /sesi → klik card sesi aktif → klik tombol **"Live Monitor"** di action row
2. Window 2 + 3 + 4 (mobile emulator atau HP): Login mahasiswa1, 2, 3
3. Buka Chrome DevTools di Window 1 → tab Network → filter "WS" — verify 1 WebSocket connection ke `wss://<project>.supabase.co/realtime/v1/websocket`
4. Catat `<SESSION_ID>` dari URL `/sesi/<id>/live`

### Test Steps

1. **Action**: Inisial paint Live Monitor
   - [ ] **UI behavior**: 4 KPI card (Hadir 0 / Telat 0 / Belum 30 / Total 30), geofence ring 380px dengan 3 dashed circle, activity feed empty state "Menunggu mahasiswa scan QR...", student grid 30 card opacity 50% status "Belum"
   - [ ] **UI status**: badge "LIVE - Sesi Aktif" pulse-dot animation di header
   - [ ] **DB realtime**: jalankan `verify-realtime.sql` Section 1.1 → tabel `attendances` ada di publication `supabase_realtime` (1 row)
   - [ ] **DB replica**: Section 1.3 → `replica_identity = FULL`

2. **Action**: Mahasiswa1 scan QR di Window 2 (GPS valid, lokasi in-radius)
   - [ ] **UI Window 1**: dalam **<2 detik** (bukan 5 detik polling), dot mahasiswa1 muncul di geofence ring berwarna hijau, student card mhs1 transition dari "Belum" → "Hadir" dengan animation pulse 1 detik, KPI Hadir 0→1, activity feed prepend event mhs1
   - [ ] **DB row**: jalankan `verify-realtime.sql` Section 6 → row mhs1 muncul dengan `scanned_at` < 2 detik dari sekarang
   - [ ] **DB live state**: Section 4.2 → `hadir=1, belum=29, total=30`
   - [ ] **audit_logs**: row `mobile_attendance_submit` untuk mhs1 muncul (`verify-attendance.sql` Section 3.1)

3. **Action**: Mahasiswa2 + mahasiswa3 scan barengan (race condition test)
   - [ ] **UI Window 1**: 2 dot baru muncul di ring, KPI Hadir 1→3, activity feed 2 event baru di-prepend (newest first)
   - [ ] **DB count**: Section 4.2 → `hadir=3`

4. **Action**: Mahasiswa4 scan dengan Fake GPS (mock location)
   - [ ] **UI Window 1**: dot mhs4 muncul dengan styling **danger merah** (atau banner "1 mahasiswa upaya mock"), KPI Ditolak +1
   - [ ] **DB row**: TIDAK ADA row attendance baru (server reject pre-insert) — verify `verify-attendance.sql` Section 4.1
   - [ ] **audit_logs**: row `mock_location_detected` muncul

5. **Action**: Tutup browser tab Window 1 (cleanup)
   - [ ] **UI**: tab tertutup, di Network DevTools tidak ada lagi message WebSocket setelah close
   - [ ] **Memory**: tidak ada zombie subscription (cleanup `channel.unsubscribe()` + `removeChannel()` per spec C1 task 2.1)

6. **Action**: Klik "Akhiri Sesi" di Live Monitor
   - [ ] **UI behavior**: SweetAlert2 konfirmasi → "Yakin akhiri sesi?" → klik OK → status berubah "Sesi Berakhir" → redirect /sesi
   - [ ] **DB**: `sessions.is_active=false`, `sessions.ended_at` non-null
   - [ ] **audit_logs**: row `end_session` (lihat sessions.ts logAudit)

---

## Fitur: QR Display Fullscreen Web (Phase B1) [P1]

**Spec**: `.kiro/specs/qr-display-fullscreen/`
**Effort**: 10 menit
**Prerequisites**: dosen sudah login web, ada sesi aktif

### Setup
1. Window 1 (laptop primary): /sesi → klik card sesi aktif
2. (Idealnya) Layar 2 / proyektor terkoneksi via HDMI

### Test Steps

1. **Action**: Klik tombol **"Tampilkan Fullscreen"** di action row card sesi aktif
   - [ ] **UI behavior**: window/tab baru terbuka dengan URL `/sesi/<id>/qr`, layout fullscreen TANPA sidebar/topbar, dark theme `#050d1c`
   - [ ] **UI elements**: QR 360px di tengah, OTP 88pt monospace dengan separator gold, countdown bar gold di bawah OTP, stats hadir/total di footer

2. **Action**: Drag tab baru ke layar 2 / proyektor → maximize
   - [ ] **UI**: QR + OTP terbaca dari kursi paling belakang (~5-7 meter)
   - [ ] **UI title tab**: "<MK> · Pertemuan N — QR Presensi" (bantu identify saat Alt+Tab)

3. **Action**: Buka Chrome DevTools → Network tab → filter "live-stats"
   - [ ] **Polling**: setiap 5 detik muncul GET request ke `/api/admin/sessions/<id>/live-stats` → 200 response `{ hadir, total }`
   - [ ] **DB stat sanity**: jalankan `verify-realtime.sql` Section 5 → angka hadir/total sama dengan response API

4. **Action**: Mahasiswa scan QR di mobile
   - [ ] **UI**: dalam ≤5 detik, counter "Hadir X/Y" naik 1 (polling refresh)
   - [ ] **DB**: row attendance baru di `verify-attendance.sql` Section 2.1

5. **Action**: Diamkan sampai countdown OTP hits 00:00 (≈3 menit, atau set TTL pendek di settings)
   - [ ] **UI**: ExpiredOverlay muncul dengan judul "Kode Sesi Sudah Expired" + tombol pill primary "Refresh Kode", QR di-blur 50%

6. **Action**: Klik "Refresh Kode"
   - [ ] **UI**: countdown reset ke 3 menit baru, OTP value berubah, QR re-render
   - [ ] **DB**: `sessions.session_code` berubah, `session_code_expires_at` extend
   - [ ] **audit_logs**: row `refresh_session_code` (rule sessions.ts logAudit) — `details` TIDAK include `session_code` mentah (rule 04-security C, BUG-relevant)

7. **Action**: Login mahasiswa di Chrome lain → akses URL `/sesi/<id>/qr` direct
   - [ ] **UI**: redirect ke /login (auth gate Server Component) — TIDAK render UI

8. **Action**: Login dosen LAIN (bukan owner MK ini) → akses URL direct
   - [ ] **UI**: redirect ke `/sesi?error=no-access` (ownership gate `canAccessCourse`)

9. **Action**: Tutup tab QR Display
   - [ ] **Network**: setelah close, tidak ada lagi polling request (AbortController cleanup)

---

## Fitur: Upload Bukti Izin/Sakit (P3-#1) [P1]

**Spec**: `.kiro/specs/leave-evidence-upload/spec.md`, migration 019
**Effort**: 10 menit
**Prerequisites**: bucket `leave-evidence` aktif, mahasiswa siap di mobile, sesi minimal 1 untuk pilihan

### Setup
1. Jalankan `verify-leave-evidence.sql` Section 1 → confirm bucket private + 2 storage policies (INSERT + SELECT) + UPDATE/DELETE absent (immutable)
2. Mahasiswa login mobile → tab "Izin"

### Test Steps

1. **Action**: Tap FAB "Ajukan Izin" → wizard step 1 → pilih sesi → step 2 pilih "Sakit" + isi alasan ≥10 char → step 3
   - [ ] **UI behavior**: step bar 4-step animate (1→2→3), upload zone dashed primary muncul "Tambahkan Foto Bukti — JPG/PNG/WEBP, maks 5 MB"

2. **Action**: Tap upload zone → pilih galeri → pilih foto JPG <5MB
   - [ ] **UI**: spinner upload muncul di camera badge, lalu thumbnail preview 180px height + tombol X overlay
   - [ ] **DB row**: jalankan `verify-leave-evidence.sql` Section 2.1 → ada row di `storage.objects` bucket=`leave-evidence`, path format `<STUDENT_ID>/<32hex>.jpg`
   - [ ] **audit_logs**: Section 2.2 → row `mobile_leave_evidence_upload` dengan `details.path`, `details.size`, `details.mime`

3. **Action**: Tap "Lanjut" → step 4 review → tap "Kirim Pengajuan"
   - [ ] **UI**: snackbar success "Pengajuan terkirim" → kembali ke list MyLeaveRequests, item baru status "Menunggu"
   - [ ] **DB row**: jalankan Section 3.1 → row `leave_requests` dengan `status='pending'`, `evidence_url` berisi PATH (bukan full URL — rule spec R3)
   - [ ] **DB format**: Section 3.2 → `path_format_ok=true`, `prefix_match_owner=true` (defense-in-depth)
   - [ ] **audit_logs**: Section 3.3 → row `mobile_leave_request_submit` dengan `details.has_evidence=true`

4. **Action**: Login dosen (web) → /izin → klik baris pengajuan tadi → klik "Lihat Bukti"
   - [ ] **UI**: tab baru terbuka dengan signed URL Supabase Storage (`?token=…&Expires=…`), foto muncul
   - [ ] **DB**: jalankan Section 4.1 → file masih ada (immutable, tidak ada policy DELETE untuk authenticated)
   - [ ] **TTL**: tunggu 6 menit → reload tab signed URL → response 403/410 (URL expired, TTL 5 menit)

5. **Action** (cross-tenant): Login mahasiswa B → coba akses URL Storage direct mahasiswa A
   ```
   GET <SUPABASE_URL>/storage/v1/object/leave-evidence/<MHS_A_ID>/<file>.jpg
   Authorization: Bearer <jwt-mhs-B>
   ```
   - [ ] **HTTP**: 403 Forbidden (RLS prefix check)
   - [ ] **DB anomaly**: jalankan Section 6 → 0 row (no upload dengan prefix mismatch)

6. **Action**: Coba upload file non-image (rename `.txt` ke `.jpg`)
   - [ ] **UI**: snackbar danger "Format file tidak valid" — magic bytes check di server
   - [ ] **DB**: tidak ada row baru di storage.objects

---

## Fitur: Avatar Upload Mobile (P3-#3) [P1]

**Spec**: `.kiro/specs/avatar-upload-mobile/spec.md`
**Effort**: 5 menit
**Prerequisites**: bucket `avatars` aktif (existing dari migration awal), mahasiswa login mobile

### Test Steps

1. **Action**: Mahasiswa di tab Profil → tap avatar circle
   - [ ] **UI behavior**: bottom sheet "Pilih Foto Profil" dengan opsi Galeri / Kamera
   - [ ] **DB baseline**: jalankan `verify-leave-evidence.sql` Section 5.2 → catat `avatar_url` saat ini (atau null)

2. **Action**: Pilih galeri → pilih foto JPG → konfirmasi crop
   - [ ] **UI**: spinner di camera badge avatar, ~2 detik kemudian success snackbar + avatar refresh dengan foto baru
   - [ ] **DB file**: Section 5.1 → row di `storage.objects` bucket=`avatars`, name=`<STUDENT_ID>.jpg`
   - [ ] **DB profile**: Section 5.2 → `avatar_url` updated dengan `?t=<timestamp>` (cache buster)
   - [ ] **audit_logs**: Section 5.3 → row `mobile_avatar_upload` dengan `details.path`, `details.size`

3. **Action**: Hot restart app (kill + buka lagi)
   - [ ] **UI**: avatar baru tetap muncul (loaded dari URL baru, cache buster bypass)

4. **Action**: Upload non-image (rename `.txt`)
   - [ ] **UI**: error "Format gambar tidak valid"
   - [ ] **DB**: tidak ada row baru

5. **Action** (rate limit): Upload 6 kali dalam 10 menit
   - [ ] **UI**: ke-6 dapat snackbar "Terlalu banyak upload, coba lagi nanti" (HTTP 429)

---

## Fitur: Onboarding Mobile 3-Step (Phase B3) [P1]

**Spec**: `.kiro/specs/onboarding-mobile/`
**Effort**: 5 menit
**Prerequisites**: Mobile emulator atau HP fisik

### Setup
1. Uninstall app (atau emulator wipe data) — pastikan `SharedPreferences.hasSeenOnboarding` tidak ada
2. Install ulang APK debug

### Test Steps

1. **Action**: Cold open app pertama kali
   - [ ] **UI**: splash dwell ~2 detik → navigate ke `/onboarding` (BUKAN /login)
   - [ ] **UI Step 1**: brand "MyPresensi", illustration card primary gradient + Hand-shake icon, judul "Selamat Datang", tombol "Lanjut" + "Lewati" top-right, step indicator 3 dot (active 24px primary, inactive 8px)

2. **Action**: Tap "Lanjut"
   - [ ] **UI**: PageView slide horizontal 300ms ease-in-out → Step 2
   - [ ] **UI Step 2**: illustration success + Shield icon, feature list 3-item duotone (QR info / GPS warning / Face success), step indicator dot 2 active

3. **Action**: Tap "Lanjut"
   - [ ] **UI Step 3**: illustration amber + Rocket icon, privacy summary 2-point, tombol "Masuk Sekarang"

4. **Action**: Tap "Masuk Sekarang"
   - [ ] **UI**: navigate ke /login (BUKAN /onboarding)
   - [ ] **Storage**: `SharedPreferences.hasSeenOnboarding = true` (verify via `adb shell run-as <package> cat shared_prefs/...xml` jika perlu)

5. **Action**: Kill app + buka lagi
   - [ ] **UI**: splash dwell → navigate langsung ke /login (skip onboarding karena flag = true)

6. **Action** (skip path): Uninstall + reinstall → di Step 1 tap "Lewati"
   - [ ] **UI**: navigate /login langsung + flag set true

---

# 🌟 P2 — Polish & Edge Case (~30 menit)

## Fitur: Hak Hapus Face Data (UU PDP Pasal 5-15) [P2]

**Spec**: rule `04-security` B.4, `mypresensi-web/app/api/mobile/face/me/route.ts`
**Effort**: 5 menit
**Prerequisites**: mahasiswa1 sudah register wajah (1 row di `face_embeddings`)

### Test Steps

1. **Action**: Baseline check
   - [ ] **DB**: jalankan `verify-face.sql` Section 1.1 → ada 1 row dengan `embedding_hash` non-null
   - [ ] **DB**: Section 1.2 → `is_face_registered=true`

2. **Action**: Mahasiswa di tab Profil → cari section "Privasi" / "Wajah Terdaftar" → tap "Hapus Wajah Terdaftar"
   - [ ] **UI**: SweetAlert konfirmasi destruktif "Yakin hapus data wajah? Anda perlu daftar ulang sebelum bisa verifikasi presensi." → tap Hapus
   - [ ] **UI**: snackbar success "Data wajah dihapus" + flag UI berubah jadi "Belum terdaftar"

3. **Action**: Verify hard delete + flag flip
   - [ ] **DB**: jalankan Section 4.1 → `embedding_rows_after_delete = 0`
   - [ ] **DB**: Section 4.2 → `is_face_registered = false`
   - [ ] **audit_logs**: Section 4.3 → row `mobile_face_delete` dengan `details.previous_hash` (forensic), `details.registered_at`, `device_id`

4. **Action**: Mahasiswa coba submit di sesi `face_verification_mode=required`
   - [ ] **UI**: redirect ke /face-register (flag false) — flow re-register

---

## Fitur: Live Monitor Reconnect setelah CHANNEL_ERROR [P2]

**Spec**: `.kiro/specs/live-monitor-dosen/design.md` §Sequence "Reconnect after network blip"
**Effort**: 5 menit
**Prerequisites**: Live Monitor aktif (Window 1), sesi aktif

### Test Steps

1. **Action**: Window 1 di Live Monitor → DevTools Network → disable WiFi laptop
   - [ ] **UI**: dalam ~5-10 detik, banner "Sync terganggu, mencoba sambung ulang…" muncul, KPI tetap show angka cached (last known)
   - [ ] **Network**: WebSocket connection state berubah (CHANNEL_ERROR)

2. **Action**: Mahasiswa scan QR saat WiFi mati Window 1 (mahasiswa pakai data seluler/WiFi lain)
   - [ ] **DB**: row baru muncul di tabel attendances (verify-realtime.sql Section 6)
   - [ ] **UI Window 1**: BELUM update (channel down — events tidak buffered)

3. **Action**: Re-enable WiFi laptop
   - [ ] **UI**: dalam ≤10 detik, banner hilang, hook auto re-fetch `/live-state` (gap close), dot mahasiswa baru muncul di ring, KPI Hadir update
   - [ ] **Status**: badge "LIVE" pulse aktif lagi

---

# Cleanup & Reporting

Setelah semua tier selesai:

- [ ] Reset Fake GPS app: matikan + non-aktifkan di Developer Options
- [ ] Logout semua window browser
- [ ] Catat hasil ringkas di `dev-log.md` atau `CHANGELOG.md` entri `[CHORE] Smoke test sesi <tanggal>`:
  - Tier P0: pass/fail per fitur
  - Tier P1: pass/fail
  - Tier P2: pass/fail/skip
  - Issue ditemukan → buat spec `bug/<nama>` di `.kiro/specs/` (jangan langsung fix tanpa root cause investigation — rule `02-quality` Section B)

---

## Referensi SQL Helper

| File | Cover fitur |
|------|-------------|
| `scripts/smoke-test/verify-attendance.sql` | Login → Submit, Mock GPS rejection, Face attempt logs |
| `scripts/smoke-test/verify-face.sql` | Face register/verify/delete, At-Risk RPC grants |
| `scripts/smoke-test/verify-leave-evidence.sql` | Bucket policies, Upload evidence, Submit izin, Avatar (P3-#3) |
| `scripts/smoke-test/verify-realtime.sql` | Realtime publication, REPLICA IDENTITY, Live Monitor query, QR Display polling |

Pakai dengan substitusi `<STUDENT_ID>`, `<SESSION_ID>`, `<COURSE_ID>`, `<REQUEST_ID>`, `<EVIDENCE_PATH>` sesuai konteks test.

## Catatan untuk Demo Hari-H

1. **Prep H-1**: jalankan full P0 + P1 sehari sebelum demo. Kalau ada fail, ada window untuk fix.
2. **Hari-H**: jalankan ulang P0 saja (10 menit) sebagai sanity check — pastikan tidak ada regresi semalam.
3. **Backup plan**: kalau Realtime tidak jalan saat demo, fallback ke QR Display Fullscreen polling 5 detik (Phase B1) — tetap impressive.
4. **Akun demo**: pakai akun di `credentials-MUSTREAD.txt` — **JANGAN** share screen yang menampilkan password di slide.
