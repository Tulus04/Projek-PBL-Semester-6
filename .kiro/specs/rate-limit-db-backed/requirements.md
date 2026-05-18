# Requirements Document

## Introduction

Spec ini memigrasikan rate limiter di `mypresensi-web/` dari **in-memory `Map`** (di file `app/api/mobile/_lib/rate-limit.ts`) ke **DB-backed atomic** lewat tabel `rate_limit_log` yang sudah ada di Supabase (sejak migration 001 + kolom `device_id` di migration 014). Implementasi in-memory saat ini punya tiga masalah produksi:

1. **State hilang saat restart** — tiap kali Vercel cold-start atau redeploy, semua counter reset, sehingga user yang seharusnya masih di-block bisa langsung retry.
2. **Tidak scale-out** — bila Web_App pindah ke multi-instance (mis. multi-region Vercel), tiap instance punya `Map` sendiri, sehingga effective limit menjadi `max × instance_count`.
3. **Tidak ada audit forensik** — saat investigasi abuse, tidak ada record `siapa-hit-endpoint-berapa-kali` karena `Map` tidak persistent.

Solusi: setiap call rate-limit melakukan `INSERT` + window-`COUNT` ke tabel `rate_limit_log` lewat satu PL/pgSQL function `check_and_log_rate_limit(...)` yang `SECURITY DEFINER` + `SET search_path = public, pg_temp` (sesuai rule 04-security & 14-supabase). Cleanup data lama dilakukan **lazy probabilistic** (≈1% peluang per call) tanpa pg_cron. Pola ini sudah terbukti dipakai di `app/lib/ai/tools.ts:checkAiRateLimit` (DB-backed) — dijadikan referensi.

Scope migrasi: **10 callsite** (8 endpoint mobile + 2 endpoint admin live-monitor). Login attempt rate limit (`max_login_attempts`) dan AI chat rate limit (`checkAiRateLimit`) tidak masuk scope karena sudah di-handle terpisah.

Effort estimasi: **3-4 jam** (1 migration + refactor 1 helper + sentuh 10 callsite + verifikasi).

## Glossary

- **Web_App**: Aplikasi Next.js `mypresensi-web/` yang melayani admin/dosen via SSR + endpoint mobile/admin lewat Route Handler.
- **Rate_Limit_Log**: Tabel Postgres `public.rate_limit_log` (kolom: `id`, `user_id`, `endpoint`, `device_id`, `requested_at`).
- **Rate_Limit_Function**: PL/pgSQL function baru `public.check_and_log_rate_limit(p_user_id UUID, p_endpoint TEXT, p_device_id TEXT, p_window_seconds INTEGER, p_max_count INTEGER) RETURNS BOOLEAN`.
- **Cleanup_Function**: PL/pgSQL function baru `public.cleanup_rate_limit_log()` yang `DELETE` baris `requested_at < now() - interval '24 hours'`.
- **Lazy_Cleanup_Probability**: Konstanta peluang (default `0.01` = 1%) yang dipakai caller TypeScript untuk memutuskan apakah akan memanggil `Cleanup_Function` di akhir suatu request.
- **Rate_Limit_Module**: File `mypresensi-web/app/api/mobile/_lib/rate-limit.ts` setelah refactor — export `getDeviceId`, `buildEndpointKey`, dan `checkRateLimit` (async).
- **Composite_Key**: Tuple `(user_id, endpoint, device_id)` yang digunakan sebagai key window — sama dengan komposisi key in-memory saat ini.
- **Sliding_Window_Config**: Konfigurasi `{ windowSeconds, max }` per callsite (mis. `{ 60, 10 }` untuk submit presensi).
- **Counter_Window_Config**: Konfigurasi `{ windowSeconds, max }` untuk endpoint jarang & berat (mis. `{ 900, 3 }` untuk face register). Setelah migrasi DB-backed, **counter dan sliding diunifikasi** menjadi sliding window — perilaku produk identik untuk window pendek (≤15 menit) dan lebih akurat untuk burst.
- **Mobile_Endpoint**: Salah satu dari 8 endpoint di `app/api/mobile/...` yang wajib pakai rate limit.
- **Admin_Live_Endpoint**: Salah satu dari 2 endpoint di `app/api/admin/sessions/[id]/live-stats|live-state/route.ts`.
- **MCP_Apply_Migration**: Tool Supabase MCP `mcp0_apply_migration` yang track migration di history Supabase.
- **Type_Check_Pass**: Output `npm run type-check` di `mypresensi-web/` exit code 0, 0 errors.
- **Lint_Pass**: Output `npm run lint` di `mypresensi-web/` 0 errors, 0 warnings baru.
- **Build_Pass**: Output `npm run build` di `mypresensi-web/` exit code 0.
- **Advisor_Security_Pass**: Output `mcp0_get_advisors({ type: 'security' })` 0 issue baru dibandingkan baseline pre-migration.
- **P95_Latency_Budget**: Tambahan latensi p95 per request akibat round-trip RPC < 50 ms pada Supabase Free tier same-region.

## Requirements

### Requirement 1: Migration 022 — Index, Atomic Function, Cleanup Function

**User Story:** Sebagai pengembang backend, saya ingin Postgres punya satu function atomik untuk cek-dan-log rate limit, plus index yang menopang query window, agar caller tidak perlu mengeksekusi dua statement terpisah dan window query tetap cepat saat tabel `rate_limit_log` tumbuh.

#### Acceptance Criteria

1. THE Web_App SHALL memiliki migration baru `mypresensi-web/supabase/migrations/022_rate_limit_db_backed.sql`.
2. THE migration SHALL membuat composite index `IF NOT EXISTS idx_rate_limit_log_user_endpoint_device_time` pada `public.rate_limit_log (user_id, endpoint, device_id, requested_at DESC)`.
3. THE migration SHALL membuat function `public.check_and_log_rate_limit(p_user_id UUID, p_endpoint TEXT, p_device_id TEXT, p_window_seconds INTEGER, p_max_count INTEGER) RETURNS BOOLEAN`.
4. THE Rate_Limit_Function SHALL dideklarasikan `LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp`.
5. THE Rate_Limit_Function SHALL menghitung jumlah row di `rate_limit_log` dengan `user_id = p_user_id AND endpoint = p_endpoint AND device_id IS NOT DISTINCT FROM p_device_id AND requested_at >= now() - make_interval(secs => p_window_seconds)` di dalam satu blok atomik, lalu jika count `< p_max_count` SHALL `INSERT` row baru dan return `TRUE`, sebaliknya return `FALSE` tanpa `INSERT`.
6. THE migration SHALL membuat function `public.cleanup_rate_limit_log() RETURNS INTEGER` yang `DELETE FROM public.rate_limit_log WHERE requested_at < now() - interval '24 hours'` dan return jumlah row yang dihapus.
7. THE Cleanup_Function SHALL dideklarasikan `LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp`.
8. THE migration SHALL `REVOKE EXECUTE` pada kedua function dari `public` dan `anon`, lalu `GRANT EXECUTE` hanya ke `service_role`.
9. THE migration SHALL idempotent — pakai `CREATE INDEX IF NOT EXISTS` dan `CREATE OR REPLACE FUNCTION` agar re-run aman.
10. THE migration SHALL diapply via MCP_Apply_Migration sehingga tracked di Supabase migration history.
11. WHEN migration sudah diapply (terverifikasi tracked di `mcp0_list_migrations`), THE pengembang SHALL menjalankan `mcp0_get_advisors({ type: 'security' })` dan memastikan Advisor_Security_Pass; advisor TIDAK boleh dianggap pass selama migration belum diapply ke Supabase.

### Requirement 2: Atomicity & Concurrency Safety

**User Story:** Sebagai admin sistem yang khawatir abuse, saya ingin dua request bersamaan dari user yang sama tidak bisa bypass limit dengan trik race condition (mis. dua request bersamaan saat counter = max-1 sehingga keduanya lolos).

#### Acceptance Criteria

1. THE Rate_Limit_Function SHALL melakukan `COUNT` dan `INSERT` di dalam satu invocation tunggal yang berjalan sebagai satu transaksi PL/pgSQL.
2. WHEN dua request bersamaan dari Composite_Key yang sama tiba pada saat count = `max - 1`, THE Rate_Limit_Function SHALL meng-insert paling banyak satu row tambahan sebelum return `FALSE` untuk request berikutnya.
3. THE Rate_Limit_Function SHALL memakai `SELECT count(*)` di tabel berbasis Composite_Key dengan filter `requested_at >= now() - make_interval(secs => p_window_seconds)` — bukan dari snapshot client-side.
4. THE Rate_Limit_Module client-side SHALL TIDAK melakukan logika count atau insert sendiri — seluruh keputusan diserahkan ke Rate_Limit_Function.

### Requirement 3: Persistensi Lintas Restart

**User Story:** Sebagai admin sistem, saya ingin user yang sedang di-block tetap di-block setelah Vercel cold-start atau redeploy, karena window dihitung dari timestamp di DB.

#### Acceptance Criteria

1. THE Rate_Limit_Function SHALL memutuskan allow/block berdasarkan `requested_at` row di `rate_limit_log` yang persistent.
2. WHEN proses Web_App restart, THE Rate_Limit_Module SHALL TIDAK menyimpan state apapun di memory antar request.
3. WHEN user X telah hit limit endpoint E pada device D pada t0, AND server restart pada t1 (`t0 < t1 < t0 + windowSeconds`), THE Rate_Limit_Function SHALL tetap return `FALSE` untuk request user X di endpoint E pada device D selama `now() < t0 + windowSeconds`.

### Requirement 4: Refactor Rate_Limit_Module — Async API

**User Story:** Sebagai pengembang yang menyentuh 10 callsite, saya ingin signature rate limiter tetap minimal — caller cukup pakai satu function async yang return boolean — supaya migrasi tidak menyebar logic baru di setiap endpoint.

#### Acceptance Criteria

1. THE Rate_Limit_Module SHALL tetap mengekspor function `getDeviceId(req: NextRequest): string | null` dengan signature dan validasi (8-128 char alfanumerik + dash) yang identik dengan implementasi saat ini.
2. THE Rate_Limit_Module SHALL mengekspor function async `checkRateLimit(opts: { userId: string; endpoint: string; deviceId: string | null; windowSeconds: number; max: number }): Promise<boolean>` yang return `true` jika request diizinkan, `false` jika di-block. THE function SHALL menghormati keputusan dari Rate_Limit_Function — saat RPC sukses dan return `false`, function SHALL meneruskan `false` apa adanya tanpa override.
3. THE `checkRateLimit` SHALL memanggil Rate_Limit_Function lewat `createAdminClient().rpc('check_and_log_rate_limit', ...)`.
4. WHEN pemanggilan RPC mengalami **error infrastruktur apapun** (koneksi gagal, timeout, auth error, transient Postgres error), THE `checkRateLimit` SHALL menangkap error tersebut, menulis `console.error` dengan prefix `[rate-limit]`, dan return `true` (fail-open) — keputusan fail-open didokumentasikan di JSDoc dengan rasionalisasi bahwa block-all-traffic saat DB hiccup lebih buruk dari occasional rate-limit-bypass.
4a. THE `checkRateLimit` SHALL TIDAK pernah melempar exception ke caller — semua error path di-handle internal. Akibatnya callsite TIDAK perlu `try/catch` di sekitar pemanggilan rate limiter.
5. THE Rate_Limit_Module SHALL menghapus simbol-simbol in-memory lama: `buildRateLimitKey`, `checkSlidingRateLimit`, `checkCounterRateLimit`, `SlidingRateLimit`, `CounterRateLimit`, `CounterRateLimitEntry`.
6. THE Rate_Limit_Module SHALL TIDAK lagi mengimpor atau menyimpan `Map<string, ...>` di module scope.
7. THE Rate_Limit_Module SHALL diawali komentar header Bahasa Indonesia singkat yang menjelaskan tujuan + catatan keamanan (SECURITY DEFINER, fail-open).

### Requirement 5: Endpoint Identifier Konvensi

**User Story:** Sebagai admin yang membaca `rate_limit_log` saat investigasi, saya ingin kolom `endpoint` punya identifier yang stabil dan mudah di-grep.

#### Acceptance Criteria

1. THE Web_App SHALL menggunakan string identifier endpoint berformat path API tanpa slash awal, contoh `mobile/attendance/submit`, `mobile/face/verify`, `admin/sessions/live-stats`, `admin/sessions/live-state`.
2. THE identifier SHALL hardcoded di tiap callsite saat memanggil `checkRateLimit` — bukan dihitung dari `req.nextUrl.pathname` (path bisa mengandung dynamic segment seperti `[id]` yang membuat key berbeda per session).
3. WHERE callsite memerlukan key per-resource (mis. live-stats per session), THE callsite SHALL TIDAK mencampur resource-id ke kolom `endpoint`; resource-id (sessionId) SHALL ditaruh di kolom `device_id` lewat parameter `deviceId`.
4. WHERE callsite tidak memerlukan key per-resource, THE callsite SHALL meneruskan hasil `getDeviceId(req)` apa adanya (boleh `null` jika header `X-Device-Id` tidak hadir) — TIDAK boleh fabricate placeholder string atau skip rate limit.

### Requirement 6: Migrasi 10 Callsite — Mobile

**User Story:** Sebagai pengembang yang menjaga UX mobile tidak berubah, saya ingin 8 endpoint mobile tetap punya budget rate limit yang sama persis dengan implementasi in-memory saat ini.

#### Acceptance Criteria

1. THE `app/api/mobile/attendance/submit/route.ts` SHALL panggil `await checkRateLimit({ userId, endpoint: 'mobile/attendance/submit', deviceId, windowSeconds: 60, max: 10 })`.
2. THE `app/api/mobile/face/verify/route.ts` SHALL panggil `await checkRateLimit({ userId, endpoint: 'mobile/face/verify', deviceId, windowSeconds: 60, max: 10 })`.
3. THE `app/api/mobile/face/register/route.ts` SHALL panggil `await checkRateLimit({ userId, endpoint: 'mobile/face/register', deviceId, windowSeconds: 900, max: 3 })`.
4. THE `app/api/mobile/face/me/route.ts` (DELETE handler) SHALL panggil `await checkRateLimit({ userId, endpoint: 'mobile/face/me/delete', deviceId, windowSeconds: 3600, max: 3 })`.
5. THE `app/api/mobile/leave-requests/submit/route.ts` SHALL panggil `await checkRateLimit({ userId, endpoint: 'mobile/leave-requests/submit', deviceId, windowSeconds: 600, max: 5 })`.
6. THE `app/api/mobile/leave-requests/upload-evidence/route.ts` SHALL panggil `await checkRateLimit({ userId, endpoint: 'mobile/leave-requests/upload-evidence', deviceId, windowSeconds: 900, max: 10 })`.
7. THE `app/api/mobile/profile/avatar/route.ts` SHALL panggil `await checkRateLimit({ userId, endpoint: 'mobile/profile/avatar', deviceId, windowSeconds: 600, max: 5 })`.
8. THE `app/api/mobile/sessions/eligible-for-leave/route.ts` SHALL panggil `await checkRateLimit({ userId, endpoint: 'mobile/sessions/eligible-for-leave', deviceId, windowSeconds: 300, max: 30 })`.
9. WHEN `checkRateLimit` return `false`, THE Mobile_Endpoint SHALL membalas dengan HTTP 429 dan pesan Bahasa Indonesia yang sama dengan implementasi in-memory saat ini (tanpa membocorkan internal sistem).
10. THE setiap Mobile_Endpoint SHALL memanggil `getDeviceId(req)` untuk memperoleh `deviceId` dengan signature dan perilaku identik dengan implementasi saat ini (header `X-Device-Id`, validasi 8-128 char alfanumerik+dash, fallback `null`).
11. WHEN `checkRateLimit` return `true`, THE Mobile_Endpoint SHALL melanjutkan eksekusi handler normal — TIDAK ada perubahan response shape, header tambahan, atau side-effect baru pada path success akibat migrasi rate limit.
12. IF — meskipun kontrak REQ 4.4a melarang `checkRateLimit` melempar exception — implementasi `checkRateLimit` ternyata melempar exception yang tidak ter-handle, THEN THE Mobile_Endpoint SHALL membalas HTTP 429 dengan pesan generik Bahasa Indonesia sebagai backstop defensif (jangan biarkan request lolos). Catatan: kondisi ini tidak boleh terjadi di production path; defensif handling cukup di-implementasi via `try/catch` ringan di sekitar pemanggilan rate limiter pertama yang ditambahkan ke shared helper, BUKAN di tiap callsite.

### Requirement 7: Migrasi 10 Callsite — Admin Live Endpoint

**User Story:** Sebagai dosen yang membuka live-monitor, saya ingin polling endpoint live-stats / live-state tetap rate-limited per sesi saya — bukan per device — supaya satu dosen yang membuka 2 tab sesi berbeda tetap dapat budget yang masuk akal.

#### Acceptance Criteria

1. THE `app/api/admin/sessions/[id]/live-stats/route.ts` SHALL panggil `await checkRateLimit({ userId, endpoint: 'admin/sessions/live-stats', deviceId: sessionId, windowSeconds: 60, max: 60 })`.
2. THE `app/api/admin/sessions/[id]/live-state/route.ts` SHALL panggil `await checkRateLimit({ userId, endpoint: 'admin/sessions/live-state', deviceId: sessionId, windowSeconds: 60, max: 30 })`.
3. THE Admin_Live_Endpoint SHALL menggunakan parameter `deviceId` slot tabel (`device_id` text nullable) untuk menyimpan `sessionId` — kolom skema sudah generic dan tidak perlu diubah.
4. WHEN `checkRateLimit` return `false`, THE Admin_Live_Endpoint SHALL membalas dengan HTTP 429 dan pesan Bahasa Indonesia yang sama dengan implementasi in-memory saat ini.
5. WHEN `checkRateLimit` return `true`, THE Admin_Live_Endpoint SHALL melanjutkan handler normal tanpa perubahan response shape akibat migrasi rate limit.

### Requirement 8: Lazy Probabilistic Cleanup

**User Story:** Sebagai admin sistem, saya ingin cleanup baris lama berjalan tanpa pg_cron dan tanpa menyebabkan latency spike pada request user normal.

#### Acceptance Criteria

1. THE Rate_Limit_Module SHALL setelah memanggil Rate_Limit_Function, dengan probability `0.01` (Lazy_Cleanup_Probability), memanggil Cleanup_Function lewat `rpc('cleanup_rate_limit_log')` secara fire-and-forget (`void promise.catch(...)`)  yang TIDAK menunda response ke client.
2. THE pemanggilan cleanup SHALL TIDAK ditunggu (`await`) — kegagalan cleanup TIDAK boleh menggagalkan request user.
3. WHEN cleanup gagal, THE Rate_Limit_Module SHALL menulis `console.error` dengan prefix `[rate-limit-cleanup]` dan tidak melempar error ke caller.
4. THE Cleanup_Function SHALL bersifat aman dipanggil concurrent (idempotent semantic — `DELETE` row yang sudah dihapus oleh runner lain tidak menimbulkan error).
5. THE Lazy_Cleanup_Probability SHALL didefinisikan sebagai konstanta module-level yang mudah di-tuning (mis. di-set 0 saat unit test agar deterministic).

### Requirement 9: Performance Budget

**User Story:** Sebagai dosen yang ingin UX submit presensi tetap responsif, saya ingin migrasi DB-backed tidak menambah latensi yang terasa — round-trip RPC harus tetap dalam budget realistis untuk Supabase Free tier same-region.

#### Acceptance Criteria

1. THE Rate_Limit_Function SHALL mengeksekusi window query lewat composite index `idx_rate_limit_log_user_endpoint_device_time` (index-only scan / index scan, BUKAN seq scan). Status pemakaian index SHALL bisa diverifikasi via `EXPLAIN ANALYZE` di SQL Editor — kewajiban ini berlaku terlepas dari apakah dokumentasi P95_Latency_Budget di design.md sudah lengkap.
2. THE design.md SHALL men-dokumentasikan target P95_Latency_Budget < 50 ms tambahan per request pada koneksi same-region ke Supabase Free tier.
3. THE Rate_Limit_Module SHALL melakukan **satu** RPC call ke `check_and_log_rate_limit` per request — TIDAK boleh dua call (mis. count terpisah lalu insert).
4. THE Rate_Limit_Module SHALL TIDAK melakukan SELECT lain ke `rate_limit_log` di luar Rate_Limit_Function untuk keperluan rate limit per request.

### Requirement 10: Forensic Query

**User Story:** Sebagai admin yang investigasi abuse, saya ingin bisa men-query `rate_limit_log` untuk melihat siapa hit endpoint mana berapa kali dalam window waktu tertentu.

#### Acceptance Criteria

1. THE Rate_Limit_Log SHALL berisi kolom `user_id`, `endpoint`, `device_id`, `requested_at` setelah migrasi.
2. THE migration 022 SHALL TIDAK mengubah skema kolom existing (hanya menambah index + function).
3. WHERE admin perlu query "berapa kali user X hit endpoint E dalam 24 jam terakhir", THE query SHALL bisa dijalankan via SQL Editor dengan filter `WHERE user_id = ? AND endpoint = ? AND requested_at > now() - interval '24 hours'`.
4. THE Rate_Limit_Function SHALL meng-insert row baru hanya saat request **diizinkan** (request yang di-block TIDAK menambah row baru) — keputusan ini eksplisit di-dokumentasikan di design.md karena ada implikasi forensik (event "ditolak" tidak ter-record di `rate_limit_log`, tapi tetap bisa ditelusuri lewat `audit_logs` jika endpoint memanggil `logAudit` saat 429).
5. THE Rate_Limit_Function SHALL menempatkan keputusan allow/insert vs block/no-insert pada satu jalur kode tunggal (`IF count < max THEN INSERT...; RETURN TRUE; ELSE RETURN FALSE; END IF`) sebagai safeguard di level DB agar bug pada caller tidak bisa men-insert row saat decision-nya block.

### Requirement 11: Out of Scope (Explicit Non-Goals)

**User Story:** Sebagai pemilik produk, saya ingin pastikan scope spec ini tidak overlap dengan fitur lain yang sudah ada atau direncanakan terpisah.

#### Acceptance Criteria

1. THE spec ini SHALL TIDAK mengubah login attempt rate limit (`max_login_attempts` di tabel `settings`) — itu di-handle terpisah di flow auth.
2. THE spec ini SHALL TIDAK mengubah AI chat rate limit (`app/lib/ai/tools.ts:checkAiRateLimit`) — itu sudah DB-backed dan dijadikan referensi pola tapi tidak refactor.
3. THE spec ini SHALL TIDAK menambah Redis atau cache eksternal lain — DB-backed direct dianggap cukup untuk skala 150 mahasiswa.
4. THE spec ini SHALL TIDAK menambah pg_cron — cleanup memakai pendekatan lazy probabilistic.
5. THE spec ini SHALL TIDAK mengubah skema kolom tabel `rate_limit_log`. Penambahan index pada tabel existing dan pembuatan function baru di schema `public` BUKAN dianggap "skema change" yang dilarang — keduanya adalah bagian inti scope spec ini (Requirement 1).
6. THE spec ini SHALL TIDAK menambah endpoint admin baru untuk melihat rate-limit history — query forensik dilakukan langsung via SQL Editor / Studio.
7. THE spec ini SHALL TIDAK mengubah pesan error 429 yang sudah dipakai di tiap endpoint.

### Requirement 12: Verification Gate

**User Story:** Sebagai engineer yang menjaga kualitas, saya ingin setiap task diverifikasi secara teknis sebelum dianggap selesai.

#### Acceptance Criteria

1. WHEN engineer menyelesaikan migration 022, THE engineer SHALL verifikasi via `mcp0_list_migrations` bahwa migration baru tracked. IF migration TIDAK tracked, THEN task migration SHALL TIDAK dianggap selesai hingga issue tracking diperbaiki (mis. re-apply via MCP_Apply_Migration).
2. WHEN engineer menyelesaikan migration 022, THE engineer SHALL menjalankan `mcp0_get_advisors({ type: 'security' })` dan memastikan Advisor_Security_Pass.
3. WHEN engineer menyelesaikan refactor Rate_Limit_Module + 10 callsite, THE engineer SHALL menjalankan `npm run type-check` di `mypresensi-web/` dan memastikan Type_Check_Pass.
4. WHEN engineer menyelesaikan refactor, THE engineer SHALL menjalankan `npm run lint` di `mypresensi-web/` dan memastikan Lint_Pass.
5. WHEN engineer menyelesaikan refactor, THE engineer SHALL menjalankan `npm run build` di `mypresensi-web/` dan memastikan Build_Pass.
6. IF Type_Check_Pass, Lint_Pass, Build_Pass, atau Advisor_Security_Pass tidak terpenuhi, THEN THE task SHALL TIDAK dianggap selesai hingga issue diperbaiki.

### Requirement 13: Manual Smoke Test

**User Story:** Sebagai pemilik produk, saya ingin verifikasi end-to-end perilaku rate limit setelah migrasi sebelum spec dianggap selesai.

#### Acceptance Criteria

1. WHEN keseluruhan implementasi selesai dan Verification Gate lulus, THE engineer SHALL melakukan smoke test minimum berikut:
   - (a) Login mahasiswa di mobile / Postman dengan Bearer JWT valid + header `X-Device-Id` valid.
   - (b) Hit endpoint `/api/mobile/sessions/eligible-for-leave` sebanyak 11 kali secara cepat (<10 detik).
   - (c) Verify request ke-1 sampai ke-10 mendapat HTTP 200 / 401 normal (bergantung enrollment), request ke-11 mendapat HTTP 429.
   - (d) Tunggu 60 detik (window dilewati), hit lagi → request berhasil kembali.
   - (e) Buka SQL Editor Supabase, query `SELECT user_id, endpoint, device_id, requested_at FROM rate_limit_log WHERE user_id = '<id>' ORDER BY requested_at DESC LIMIT 15` → verify ada 10-11 row baru dengan `endpoint = 'mobile/sessions/eligible-for-leave'` dalam 1 menit terakhir.
2. THE engineer SHALL melakukan smoke test restart-persistence:
   - (a) Hit endpoint `/api/mobile/face/register` 3 kali dalam 1 menit (window 15 menit, max 3) hingga request ke-4 dapat 429.
   - (b) Restart `npm run dev` (atau redeploy di Vercel preview) — pastikan proses Web_App benar-benar restart.
   - (c) Hit endpoint sekali lagi pada device yang sama → tetap dapat 429 (window belum lewat).
3. THE engineer SHALL mendokumentasikan hasil smoke test di `dev-log.md` atau `CHANGELOG.md` dengan timestamp dan ringkasan singkat.

### Requirement 14: Backward Compatibility & Migration Risk

**User Story:** Sebagai pengembang yang melakukan migrasi 10 file, saya ingin pastikan signature dan response endpoint tidak berubah dari sudut pandang client mobile, agar tidak ada release mobile yang dipaksakan.

#### Acceptance Criteria

1. THE engineer SHALL **wajib** memodifikasi 10 callsite (8 mobile + 2 admin live) yang saat ini memanggil `checkSlidingRateLimit` / `checkCounterRateLimit` — meninggalkan callsite memakai API in-memory lama akan menyebabkan compile error karena Requirement 4.5 menghapus simbol-simbol tersebut. Modifikasi SHALL terbatas pada baris pemanggilan rate limiter (sync → `await`) dan tambahan parameter `endpoint` string; TIDAK boleh mengubah HTTP status code, body response, header, atau urutan validasi yang sudah ada di file tersebut.
2. THE response 429 SHALL tetap memiliki body shape yang identik dengan implementasi saat ini (tetap pakai helper `errorResponse` / `NextResponse.json` yang sama).
3. THE header `X-Device-Id` SHALL tetap diterima dengan validasi yang identik (8-128 char alfanumerik + dash).
4. WHEN client mobile lama (build sebelum spec ini) memanggil endpoint, THE Web_App SHALL tetap menerima dan rate-limit memakai key `(user_id, endpoint, NULL)` jika header `X-Device-Id` tidak ada.
5. THE migration 022 SHALL TIDAK memerlukan downtime — function & index baru, tabel existing tidak dimodifikasi struktur kolomnya.
