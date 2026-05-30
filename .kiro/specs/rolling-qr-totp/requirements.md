# Requirements Document

## Introduction

Phase 3 v7 dari implementation plan: ganti QR statis 3-menit dengan **Rolling QR TOTP-like** (HMAC-SHA1 + window-based) untuk mencegah threat "share screenshot QR via WhatsApp ke teman di kos". Layer 1 dari 3-layer security MyPresensi (QR · GPS · Face).

**Konteks**: Layer 2 (GPS + Mock Detection) dan Layer 3 (Face Recognition WAJIB di kedua mode) sudah live. Threat utama yang dicover Phase 3 = anti-share screenshot, sambil **TIDAK** memunculkan false-reject akibat lag koneksi 4G kampus Politani Samarinda.

**User decisions yang sudah disepakati**:
- Algorithm: TOTP-like (HMAC-SHA1 + seed per-session + window-based generation)
- Window default: **A3 = 30 detik per window + tolerance ±1 = 90 detik effective acceptance**
- Backward compat: sessions yang punya `session_code` tapi `session_code_seed = NULL` → static equality (legacy behavior). Sessions baru → TOTP verify
- QR refresh strategy: web display polling 5 detik (BUKAN Supabase Realtime — overhead tidak worth)
- Mobile: **TIDAK ada perubahan kode**. Server yang adapt logic verifikasi

## Glossary

- **TOTP_Code**: 6-digit zero-padded string (`"428103"`) yang dihasilkan deterministik dari `(seed, window)` via HMAC-SHA1 + dynamic truncation. Format identik dengan kode session existing.
- **Session_Seed**: hex 64-char (32-byte random) per-session secret. Disimpan di `sessions.session_code_seed`. Tier 1 — server-side only.
- **Window**: integer = `floor(timestamp_ms / 30_000)`. Setiap window = 30 detik. Source-of-truth dihitung di server.
- **Tolerance_Window**: jumlah window di tiap arah yang server terima saat verifikasi. Default `1` = total 3 window check (`[now-1, now, now+1]`) = 90 detik effective.
- **Rolling_Mode**: state session dengan `session_code_seed IS NOT NULL`. Verifikasi TOTP.
- **Legacy_Mode**: state session dengan `session_code_seed IS NULL`. Verifikasi static equality + `session_code_expires_at` check (existing pre-Phase 3 behavior).
- **Static_Code**: 6-digit code di `sessions.session_code` yang berlaku selama 3 menit (existing pattern).
- **Cache_Code**: nilai `sessions.session_code` di rolling mode yang di-update setiap polling endpoint hit (= TOTP_Code current). Bukan source of truth — server selalu re-compute saat verify.
- **Window_Offset**: int `-1`, `0`, atau `+1` — posisi relatif window yang match saat verifikasi rolling. Disimpan di `audit_logs.details.qr_window_offset` untuk forensic.
- **Web_Display**: halaman dosen menampilkan QR — `/sesi/[id]/qr` (fullscreen projector) dan modal QR di `session-list.tsx`.
- **Admin_Endpoint**: `GET /api/admin/sessions/:id/current-code` — endpoint baru, dosen-only, return current TOTP_Code untuk polling.
- **Submit_Endpoint**: `POST /api/mobile/attendance/submit` — endpoint mobile existing yang akan di-refactor verifikasi-nya.
- **Share_Screenshot_Threat**: skenario mahasiswa A screenshot QR layar dosen → kirim ke mahasiswa B (di kos) via WhatsApp/Telegram → B coba scan + submit dari rumah.
- **Intercept_HTTPS_Threat**: skenario penyerang man-in-the-middle yang capture payload HTTPS submit → coba replay code yang sudah ditangkap.

## Requirements

### Requirement 1: Schema Migration `022_rolling_qr_seed.sql`

**User Story:** Sebagai pengembang backend, saya ingin menambah kolom `session_code_seed` ke tabel `sessions`, supaya verifikasi TOTP punya secret per-session yang server-side only.

> **Catatan penomoran**: file lokal pakai `022_rolling_qr_seed.sql` karena nomor 020 (sessions_started_at_index) dan 021 (enable_realtime_attendances) sudah dipakai migration sebelumnya. Spec referensi awal menyebut `020` — gunakan `022` untuk konsistensi sequential.

#### Acceptance Criteria

1. THE Web_Backend SHALL menyediakan migration baru `mypresensi-web/supabase/migrations/022_rolling_qr_seed.sql`.
2. THE migration SHALL menambah kolom `session_code_seed TEXT NULL` ke tabel `public.sessions`.
3. THE migration SHALL idempotent — gunakan `ADD COLUMN IF NOT EXISTS`.
4. THE migration SHALL menambahkan partial index `idx_sessions_active_with_seed ON sessions(id) WHERE session_code_seed IS NOT NULL AND is_active = true`.
5. THE migration SHALL menambahkan `COMMENT ON COLUMN` Bahasa Indonesia menjelaskan bahwa kolom ini server-side only dan jangan di-expose ke client.
6. THE migration SHALL diapply via `mcp0_apply_migration` — BUKAN manual SQL Editor — agar ke-track di Supabase migration history.
7. WHEN migration diapply, THE pengembang SHALL menjalankan `mcp0_get_advisors({ type: 'security' })` dan memastikan 0 issue baru muncul terkait kolom baru.
8. THE migration SHALL TIDAK mengubah kolom existing `session_code` atau `session_code_expires_at` — purely additive.

### Requirement 2: TOTP Utility Pure Function

**User Story:** Sebagai pengembang backend, saya ingin utility `app/lib/utils/totp.ts` yang men-generate dan memverifikasi TOTP code, supaya logic ter-isolasi, mudah di-test, dan reusable di submit endpoint serta admin endpoint.

#### Acceptance Criteria

1. THE Web_Backend SHALL menyediakan file baru `mypresensi-web/app/lib/utils/totp.ts`.
2. THE Totp_Utility SHALL meng-export function `generateCode(seedHex: string, window: number): string` yang return 6-digit zero-padded string.
3. THE generateCode SHALL menggunakan Node.js `crypto.createHmac('sha1', ...)` — TIDAK ada library eksternal seperti `otplib` atau `speakeasy`.
4. THE generateCode SHALL deterministik — input `(seedHex, window)` yang sama SELALU return string yang sama.
5. THE Totp_Utility SHALL meng-export function `getCurrentWindow(nowMs?: number): number` yang return `floor(nowMs / 30000)` dengan default `nowMs = Date.now()`.
6. THE Totp_Utility SHALL meng-export function `verifyWithTolerance(seedHex, inputCode, currentWindow, tolerance=1)` yang return `{ match: boolean, offset: number | null, window: number }`.
7. WHEN verifyWithTolerance dipanggil dengan code valid di window `currentWindow + offset` (offset dalam range `[-tolerance, +tolerance]`), THE function SHALL return `{ match: true, offset: <found_offset>, window: currentWindow }`.
8. WHEN verifyWithTolerance dipanggil dengan code valid di window di luar range tolerance, THE function SHALL return `{ match: false, offset: null, window: currentWindow }`.
9. WHEN verifyWithTolerance menerima `inputCode` bukan format 6-digit (length != 6 atau ada karakter non-digit), THE function SHALL return `{ match: false, offset: null, window: currentWindow }` tanpa error throw.
10. THE verifyWithTolerance SHALL menggunakan `crypto.timingSafeEqual` untuk komparasi string code — mitigasi timing side-channel.
11. THE Totp_Utility SHALL meng-export function `msUntilNextWindow(nowMs?: number): number` yang return milisecond sampai window berikutnya = `30000 - (nowMs % 30000)`.
12. THE Totp_Utility SHALL menggunakan konstanta module-level `WINDOW_SIZE_MS = 30_000`, `DIGIT_COUNT = 6`, `TOLERANCE_DEFAULT = 1` — supaya tightening ke A1 (5s + ±2) future-proof tinggal ganti konstanta.

### Requirement 3: Property Test untuk TOTP Utility

**User Story:** Sebagai pengembang, saya ingin property test untuk TOTP utility, supaya correctness algoritma terverifikasi otomatis dan regresi cepat ketahuan.

#### Acceptance Criteria

1. THE Web_Backend SHALL menyediakan file test `mypresensi-web/app/lib/utils/totp.test.ts` (atau sesuai naming convention test framework existing — Vitest/Jest).
2. THE Test_Suite SHALL mencakup tes determinisme — sama input return sama output.
3. THE Test_Suite SHALL mencakup tes round-trip — `verifyWithTolerance(seed, generateCode(seed, w), w, 0).match === true` untuk berbagai (seed, w).
4. THE Test_Suite SHALL mencakup tes tolerance — code dari window `w-1` dan `w+1` match saat tolerance=1 dengan offset benar.
5. THE Test_Suite SHALL mencakup tes rejection — code dari window outside tolerance (mis. `w-5`) di-reject.
6. THE Test_Suite SHALL mencakup tes input malformed — string length salah (5, 7), non-digit, empty — return match=false tanpa throw.
7. THE Test_Suite SHALL mencakup tes seed-isolation — seed berbeda menghasilkan code berbeda untuk window yang sama.
8. WHEN engineer menjalankan `npm test -- totp`, THE test suite SHALL pass exit 0.

### Requirement 4: Refactor Submit Endpoint — Verify TOTP atau Static Fallback

**User Story:** Sebagai mahasiswa, saya ingin submit presensi tetap berhasil dengan QR rolling yang baru, dan sebagai pengembang, saya ingin verifikasi yang adapt otomatis berdasarkan keberadaan seed.

#### Acceptance Criteria

1. THE Submit_Endpoint (`POST /api/mobile/attendance/submit`) SHALL membaca kolom `session_code_seed` saat fetch session.
2. WHEN `session.session_code_seed IS NOT NULL`, THE Submit_Endpoint SHALL memverifikasi `input.session_code` via `verifyWithTolerance(seed, input.session_code, getCurrentWindow(), 1)`.
3. WHEN verifyWithTolerance return `{ match: true, offset }`, THE Submit_Endpoint SHALL melanjutkan ke Layer 3 (enrollment) dan mencatat `qr_window_offset = offset` + `qr_verify_method = 'totp'` di audit log final.
4. WHEN verifyWithTolerance return `{ match: false }`, THE Submit_Endpoint SHALL return HTTP 400 dengan body `{"error": "Kode QR sudah lewat, mohon scan ulang."}` (Bahasa Indonesia ramah, tidak teknis).
5. WHEN `match: false` di mode rolling, THE Submit_Endpoint SHALL log audit dengan action `'qr_code_invalid_attempt'` plus details `{ session_id, qr_verify_method: 'totp', current_window, student_nim }`.
6. WHEN `session.session_code_seed IS NULL` (legacy session), THE Submit_Endpoint SHALL menggunakan static equality check existing — `session.session_code === input.session_code` AND `session.session_code_expires_at > now()` — IDENTIK dengan behavior pre-Phase 3.
7. WHEN legacy session reject karena code mismatch, THE error message SHALL "Kode sesi tidak valid." (existing copy).
8. WHEN legacy session reject karena expired, THE error message SHALL "Kode sesi sudah kedaluwarsa. Minta dosen untuk refresh kode." (existing copy).
9. THE Submit_Endpoint SHALL menambah field `qr_verify_method` (`'totp' | 'static_legacy'`) dan `qr_window_offset` (`number | null`) ke `details` audit log `mobile_attendance_submit`.
10. THE Submit_Endpoint SHALL TIDAK mengubah Layer 3 (enrollment), Layer 4 (duplicate), Layer 5 (GPS), Layer 6 (face) — perubahan TERBATAS pada Layer 2 (session_code check) saja.
11. THE Submit_Endpoint SHALL TIDAK mengembalikan `session_code_seed` dalam response body — tidak boleh ada path mana pun di response yang expose seed.

### Requirement 5: Admin Endpoint `GET /api/admin/sessions/:id/current-code`

**User Story:** Sebagai dosen, saya ingin web display projector + modal QR selalu menampilkan code TOTP yang current, supaya QR yang saya tayangkan selalu fresh dan mahasiswa baru bisa scan.

#### Acceptance Criteria

1. THE Web_Backend SHALL menyediakan endpoint baru `GET /api/admin/sessions/:id/current-code` di `mypresensi-web/app/api/admin/sessions/[id]/current-code/route.ts`.
2. THE Admin_Endpoint SHALL menggunakan auth cookie session (bukan Bearer JWT) — sesuai pattern endpoint admin lain.
3. THE Admin_Endpoint SHALL memanggil `requireRole(['admin', 'dosen'])` untuk gating role.
4. WHEN role = `dosen`, THE Admin_Endpoint SHALL memanggil `canAccessCourse(userId, 'dosen', session.course_id)` untuk ownership check.
5. WHEN role = `mahasiswa` atau anon, THE Admin_Endpoint SHALL return HTTP 401 atau 403 — TIDAK BOLEH mahasiswa akses endpoint ini.
6. WHEN session tidak ada di DB, THE Admin_Endpoint SHALL return HTTP 404 dengan pesan ramah.
7. WHEN `session.is_active = false`, THE Admin_Endpoint SHALL return HTTP 410 (Gone) dengan pesan "Sesi sudah berakhir".
8. WHEN session valid + rolling mode (`session_code_seed IS NOT NULL`), THE Admin_Endpoint SHALL return HTTP 200 body:
   ```json
   {
     "current_code": "428103",
     "window": 56789012,
     "ttl_ms_until_next": 14823,
     "is_rolling": true,
     "is_active": true,
     "expires_at": null
   }
   ```
9. WHEN session valid + legacy mode (`session_code_seed IS NULL`), THE Admin_Endpoint SHALL return HTTP 200 body dengan `is_rolling: false`, `current_code` = `session.session_code` static, `expires_at` = `session.session_code_expires_at`.
10. THE Admin_Endpoint SHALL set response header `Cache-Control: no-store` — code harus selalu fresh.
11. THE Admin_Endpoint SHALL TIDAK pernah memasukkan `session_code_seed` dalam response body — hanya `current_code`.
12. THE Admin_Endpoint SHALL meng-update kolom `sessions.session_code` (cache) dengan nilai TOTP current via `createAdminClient()` setelah compute — best-effort, lanjut response meskipun update gagal.
13. THE Admin_Endpoint SHALL TIDAK rate-limited (dosen-only akses, polling 5s = 12 req/menit per dosen ≪ threshold).

### Requirement 6: Update `startSessionAction` — Generate Seed

**User Story:** Sebagai dosen, saat saya klik "Mulai Sesi", saya ingin sistem otomatis generate seed rahasia + initial code, supaya rolling QR siap dipakai langsung.

#### Acceptance Criteria

1. THE `toggleSessionAction(sessionId, isActive=true)` di `app/lib/actions/sessions.ts` SHALL menggenerate seed via `crypto.randomBytes(32).toString('hex')` (64-char hex string).
2. THE action SHALL menghitung initial code via `generateCode(seed, getCurrentWindow())`.
3. THE action SHALL meng-UPDATE kolom `session_code_seed = $seed` + `session_code = $initialCode` + `session_code_expires_at = NOW() + 24 hours` + `is_active = true` + `started_at = NOW()`.
4. THE action SHALL TIDAK pernah meng-log `seed` atau `initialCode` mentah ke `audit_logs.details` — hanya field metadata seperti `code_length: 6`, `has_seed: true`, `qr_mode: 'rolling'`.
5. THE action SHALL tetap memanggil `createBulkNotifications` untuk mahasiswa enrolled (existing behavior).
6. THE action SHALL tetap mengembalikan `{ error: null, sessionCode: code, expiresAt }` — kontrak return tetap kompatibel dengan UI existing.
7. THE action SHALL tetap memvalidasi ownership via `canAccessCourse` sebelum mutasi DB.

### Requirement 7: Update `refreshSessionCode` — Rotate Seed

**User Story:** Sebagai dosen, saat saya klik "Refresh Kode", saya ingin seed di-rotate total (bukan cuma window pointer geser), supaya kalau saya curiga ada kebocoran seed lama, semua attempt dengan seed lama langsung di-reject.

#### Acceptance Criteria

1. THE `refreshSessionCode(sessionId)` di `app/lib/actions/sessions.ts` SHALL menggenerate seed BARU via `crypto.randomBytes(32).toString('hex')` — rotate, BUKAN reuse.
2. THE action SHALL menghitung initial code baru dari seed baru + current window.
3. THE action SHALL meng-UPDATE kolom `session_code_seed = $newSeed` + `session_code = $newCode` + `session_code_expires_at = NOW() + 24 hours`.
4. THE action SHALL memvalidasi `session.is_active = true` sebelum rotate — sesi non-aktif tidak boleh di-refresh.
5. THE action SHALL memvalidasi ownership via `canAccessCourse` sebelum mutasi.
6. THE action SHALL TIDAK pernah meng-log seed mentah atau code mentah ke `audit_logs.details` — hanya `{ session_id, code_length: 6, has_seed: true, rotated: true }`.
7. THE action SHALL tetap mengembalikan `{ error: null, sessionCode: code, expiresAt }` (kontrak return existing).

### Requirement 8: Refactor Web Display Projector — Polling Current Code

**User Story:** Sebagai dosen yang menampilkan QR di proyektor, saya ingin QR di layar otomatis update setiap kode ber-rolling, supaya screenshot lama langsung kadaluarsa.

#### Acceptance Criteria

1. THE Component `app/(qr-projector)/sesi/[id]/qr/qr-display-client.tsx` SHALL menambah state baru `currentCode: string | null` dan `windowTtlMs: number`, di-initialize dari prop SSR (kompatibel saat first render).
2. THE component SHALL menambah polling loop kedua via `useEffect` + `setTimeout` dengan interval 5000 ms ke endpoint `/api/admin/sessions/:id/current-code`.
3. THE polling loop baru SHALL paralel dengan polling `live-stats` existing — keduanya independen, tidak boleh race.
4. THE polling SHALL menggunakan `AbortController` untuk cleanup saat component unmount — sama pattern dengan polling existing.
5. WHEN response 200 dengan `is_rolling: true`, THE component SHALL set `currentCode = response.current_code` dan `windowTtlMs = response.ttl_ms_until_next`.
6. WHEN response 200 dengan `is_rolling: false` (legacy session), THE component SHALL set `currentCode = response.current_code` (static value) dan `windowTtlMs = 0` — fallback ke pattern existing.
7. WHEN response 410 (Gone), THE component SHALL menampilkan banner "Sesi sudah berakhir" dan auto-close window — pattern existing untuk 403/404.
8. WHEN response error 3x consecutive, THE polling SHALL backoff ke 30 detik (pattern existing).
9. THE QR rendering (`QRCodeSVG value={...}`) SHALL menggunakan `JSON.stringify({sid, code: currentCode, exp: ...})` — derive dari STATE `currentCode`, BUKAN dari prop initial.
10. THE OtpBlock countdown bar SHALL menampilkan `windowTtlMs` (turun dari 30s ke 0, lalu naik kembali setelah polling next tick yang dapat code baru).
11. THE Component SHALL tetap menampilkan `ExpiredOverlay` untuk legacy sessions yang `expires_at < now()` — backward compat.
12. THE Component SHALL TIDAK menampilkan `ExpiredOverlay` untuk rolling sessions — code "tidak pernah expired", hanya berubah nilai.

### Requirement 9: Refactor Modal QR di session-list — Polling Current Code

**User Story:** Sebagai dosen, modal QR di halaman daftar sesi (versi kompak) juga harus update otomatis seperti versi fullscreen, supaya konsisten.

#### Acceptance Criteria

1. THE Component `app/(dashboard)/sesi/session-list.tsx` SHALL menambah polling untuk setiap session aktif dengan `session_code_seed != null`.
2. THE polling SHALL hit `/api/admin/sessions/:id/current-code` dengan interval 5000 ms.
3. THE state baru `modalCurrentCodes: Record<string, { code: string; ttl: number }>` SHALL menyimpan code per session-id yang lagi di-display modal.
4. THE QR rendering modal (`QRCodeSVG value={...}`) SHALL menggunakan `currentCode` dari state, fallback ke prop `session.session_code` kalau polling belum sukses pertama kali.
5. THE OTP digit display (6 boxes 0-9) SHALL render dari state `currentCode.split('')`.
6. THE label "Kode berlaku" SHALL menampilkan `ttl` countdown dari state.
7. WHEN polling untuk session id X gagal 3x, THE polling specific session id X SHALL backoff 30 detik tanpa mengganggu polling session lain.
8. WHEN modal di-tutup atau session id berubah, THE polling specific session id sebelumnya SHALL di-cleanup via AbortController.
9. THE polling SHALL TIDAK aktif untuk legacy sessions (`session_code_seed = null`) — pakai static value dari prop existing.

### Requirement 10: Mobile — Tidak Ada Perubahan Kode

**User Story:** Sebagai pengembang mobile, saya tidak ingin ada perubahan kode mobile dalam Phase 3, supaya APK existing kompatibel dan tidak ada version-skew rilis.

#### Acceptance Criteria

1. THE Mobile_App SHALL TIDAK diubah dalam Phase 3 — TIDAK ada commit di folder `mypresensi-mobile/`.
2. THE Mobile_App SHALL tetap kirim payload `{session_id, session_code, latitude, longitude, ...}` (existing) ke `POST /api/mobile/attendance/submit`.
3. THE Mobile_App SHALL TIDAK mengetahui konsep "TOTP", "window", atau "seed" — abstraksi total di server.
4. APK lama (yang sudah ter-install di HP mahasiswa pra-Phase 3) SHALL berhasil submit ke session rolling-mode yang baru — backward compat di sisi server menjamin kompatibilitas.

### Requirement 11: Threat — Share Screenshot via WhatsApp

**User Story:** Sebagai sistem, saya ingin reject submit yang berasal dari screenshot QR yang sudah lewat, supaya skenario "share screenshot ke teman di kos" gagal.

#### Acceptance Criteria

1. WHEN screenshot QR yang ditangkap lebih dari 90 detik lalu dipakai untuk submit (oleh siapa pun), THE Submit_Endpoint SHALL reject dengan HTTP 400 + pesan "Kode QR sudah lewat, mohon scan ulang." — karena code-nya sudah outside tolerance window.
2. WHEN screenshot QR ditangkap dalam 90 detik dan dipakai submit, THE Submit_Endpoint MAY accept code-nya (di Layer 2), TAPI Layer 3 (Face WAJIB) masih akan reject kalau yang submit bukan mahasiswa terdaftar — defense in depth.
3. THE Tolerance_Window SHALL TIDAK lebih besar dari 120 detik (= window 30s + tolerance ±2). Saat ini default 90 detik (tolerance ±1).

### Requirement 12: Threat — Intercept HTTPS Replay

**User Story:** Sebagai sistem, saya ingin replay attack — capture payload via MITM lalu replay — gagal di submit, supaya windowing membatasi attack window.

#### Acceptance Criteria

1. WHEN attacker capture payload submit pada timestamp T dan replay pada T + 90s+, THE Submit_Endpoint SHALL reject (TOTP code outside tolerance window).
2. WHEN attacker replay payload identik dengan original mahasiswa (sebelum mahasiswa submit), THE Submit_Endpoint SHALL menjalankan UNIQUE constraint `(session_id, student_id)` — second insert reject karena duplicate (existing behavior).
3. WHEN replay terjadi DALAM 90 detik dari original, THE Submit_Endpoint MAY accept di Layer 2, TAPI Layer 3 (Face) masih harus pass — kalau attacker tidak punya wajah asli mahasiswa, mismatch → reject.

### Requirement 13: Tidak Ada False Reject dari Lag 4G

**User Story:** Sebagai mahasiswa pengguna koneksi 4G yang sering lag, saya ingin presensi saya tetap ke-accept meski submit terkirim 30-60 detik setelah scan QR, supaya saya tidak frustrasi karena ditolak terus.

#### Acceptance Criteria

1. WHEN mahasiswa scan QR di window `w` lalu submit terkirim ke server saat current window di server = `w+1`, THE Submit_Endpoint SHALL accept code (offset = -1).
2. WHEN delay total (scan → server-receive) tidak melebihi 90 detik, THE Submit_Endpoint SHALL accept dengan tolerance ±1.
3. WHEN delay melebihi 90 detik, THE Submit_Endpoint SHALL reject dengan pesan ramah meminta scan ulang — TIDAK boleh menyebut detail teknis seperti "TOTP" atau "window" ke mahasiswa.
4. THE Tolerance_Window SHALL bisa di-tune via konstanta module-level di `totp.ts` — bukan hardcode di submit handler — untuk maintenance future.

### Requirement 14: Backward Compat — Sessions Aktif Pre-Migration

**User Story:** Sebagai admin sistem, saya ingin saat deploy Phase 3 tidak break sessions yang sudah aktif sebelum migration, supaya mahasiswa yang lagi submit tidak crash.

#### Acceptance Criteria

1. WHEN session row punya `session_code_seed = NULL`, THE Submit_Endpoint SHALL menggunakan static equality check existing (Legacy_Mode).
2. WHEN session row punya `session_code_seed = NULL`, THE Admin_Endpoint SHALL return `is_rolling: false` + `current_code` = static value dari `session.session_code` + `expires_at` ISO existing.
3. WHEN session row punya `session_code_seed = NULL`, THE Web_Display SHALL fallback ke pattern existing — tampilkan static code, countdown sampai `expires_at`.
4. THE migration 022 SHALL TIDAK mengubah data row existing — `session_code_seed` di-set NULL untuk semua row pre-migration via `ADD COLUMN IF NOT EXISTS ... NULL` (default NULL untuk row existing).

### Requirement 15: Audit Log Forensic Enhancement

**User Story:** Sebagai admin keamanan, saya ingin audit log mencatat metadata verifikasi TOTP supaya saya bisa forensic kalau ada anomali (false reject pattern, share screenshot pattern, dll).

#### Acceptance Criteria

1. WHEN submit success di mode rolling, THE audit log entry `mobile_attendance_submit` SHALL include `qr_verify_method: 'totp'` dan `qr_window_offset: <number>` di field `details`.
2. WHEN submit success di mode legacy, THE audit log entry SHALL include `qr_verify_method: 'static_legacy'` dan `qr_window_offset: null`.
3. WHEN submit reject di Layer 2 mode rolling karena code mismatch, THE separate audit log entry SHALL ditulis dengan action `qr_code_invalid_attempt` plus details `{ session_id, qr_verify_method: 'totp', current_window, student_nim }`.
4. THE audit log entry `start_session` di mode rolling SHALL include `details: { ..., has_seed: true, qr_mode: 'rolling', code_length: 6 }`.
5. THE audit log entry `refresh_session_code` di mode rolling SHALL include `details: { ..., has_seed: true, rotated: true, code_length: 6 }`.
6. THE audit log entry SHALL TIDAK pernah memuat nilai `session_code_seed` mentah maupun nilai code mentah — hanya metadata length / boolean / offset.

### Requirement 16: Privacy & Security Hardening

**User Story:** Sebagai system architect, saya ingin seed ter-isolasi sebagai Tier 1 secret, supaya tidak ada path bocor accidental.

#### Acceptance Criteria

1. THE `session_code_seed` SHALL TIDAK pernah di-return di response body endpoint mana pun (`/api/mobile/*`, `/api/admin/*`, server action return value).
2. THE `session_code_seed` SHALL TIDAK pernah di-log via `console.log`, `debugPrint`, atau `logAudit()`.
3. THE Admin_Endpoint SHALL hanya bisa diakses oleh role `admin` ATAU `dosen` pemilik MK — pengujian negative case mahasiswa role harus return 401/403.
4. THE Database SHALL TIDAK menyediakan RLS policy yang memungkinkan role `authenticated` (web SSR cookie) atau `anon` membaca kolom `session_code_seed` — gunakan policy existing tabel `sessions` yang sudah deny untuk role tersebut.
5. THE Verify SHALL menggunakan `crypto.timingSafeEqual` untuk komparasi code — mitigasi side-channel attack (paranoid tapi murah).

### Requirement 17: Pesan Error Bahasa Indonesia Ramah

**User Story:** Sebagai mahasiswa pengguna mobile, saya ingin pesan error mudah dimengerti, supaya saya tahu langkah berikutnya tanpa bingung dengan jargon teknis.

#### Acceptance Criteria

1. WHEN Submit_Endpoint reject di Layer 2 mode rolling, THE response error message SHALL "Kode QR sudah lewat, mohon scan ulang." — tidak ada kata "TOTP", "window", "expired", "tolerance".
2. WHEN Submit_Endpoint reject di Layer 2 mode legacy code mismatch, THE response error message SHALL "Kode sesi tidak valid." (existing copy).
3. WHEN Submit_Endpoint reject di Layer 2 mode legacy code expired, THE response error message SHALL "Kode sesi sudah kedaluwarsa. Minta dosen untuk refresh kode." (existing copy).
4. WHEN Admin_Endpoint reject 410 (sesi berakhir), THE response error message SHALL "Sesi sudah berakhir."
5. THE Web_Display banner saat 410 SHALL "Sesi sudah berakhir. Window akan tertutup otomatis." — pattern existing untuk 403/404.

### Requirement 18: Verification Gate

**User Story:** Sebagai pengembang, saya ingin tidak boleh klaim selesai tanpa bukti verifikasi, supaya tidak ada regresi yang lolos.

#### Acceptance Criteria

1. WHEN engineer menyelesaikan migration, THE engineer SHALL menjalankan `mcp0_get_advisors({ project_id, type: 'security' })` dan memastikan 0 issue baru muncul.
2. WHEN engineer menyelesaikan code change, THE engineer SHALL menjalankan `npm run type-check` di `mypresensi-web/` exit 0.
3. WHEN engineer menyelesaikan code change, THE engineer SHALL menjalankan `npm run lint` di `mypresensi-web/` clean (0 error).
4. WHEN engineer menyelesaikan code change, THE engineer SHALL menjalankan `npm test -- totp` exit 0 (property test pass).
5. WHEN engineer menyelesaikan code change pre-merge, THE engineer SHALL menjalankan `npm run build` exit 0.
6. WHEN smoke test runtime selesai, THE engineer SHALL mendokumentasikan hasil di `dev-log.md` dengan tanggal + 7 langkah smoke (R5-related: start session, polling display, screenshot expire reject, refresh code rotate, legacy fallback, auth gate negative test).

### Requirement 19: Out of Scope Boundary

**User Story:** Sebagai pemilik produk, saya ingin batasan scope Phase 3 jelas, supaya pengembang tidak bias menambah fitur lain di luar kontrak yang disepakati.

#### Acceptance Criteria

1. THE Phase_3_Scope SHALL TIDAK menyertakan cron job untuk auto-rotate seed berkala — refresh manual via tombol UI saja.
2. THE Phase_3_Scope SHALL TIDAK menyertakan perubahan mobile app — folder `mypresensi-mobile/` tidak boleh tersentuh dalam phase ini.
3. THE Phase_3_Scope SHALL TIDAK menyertakan mode A1 (5 detik window + tolerance ±2). Default tetap A3 (30 detik + ±1) — tightening ke A1 hanya boleh dilakukan dengan mengubah konstanta module-level di `totp.ts` di future spec terpisah.
4. THE Phase_3_Scope SHALL TIDAK menyertakan integrasi Supabase Realtime channel untuk QR refresh — polling 5 detik sudah cukup.
5. THE Phase_3_Scope SHALL TIDAK menghilangkan kolom existing `session_code` atau `session_code_expires_at` — perubahan schema purely additive.
6. THE Phase_3_Scope SHALL TIDAK menyertakan rate limit di Admin_Endpoint — dosen-only akses, 12 req/menit per dosen di bawah threshold attack.
