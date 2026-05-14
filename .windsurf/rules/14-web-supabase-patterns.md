---
trigger: glob
globs: mypresensi-web/**
description: Pola Supabase Postgres yang wajib diikuti — RLS security, query performance (index), schema design, data access patterns, monitoring.
---

# Supabase Postgres Patterns — `mypresensi-web/`

Komplemen `10-web-conventions.md` dan workflow `/add-supabase-migration`. Fokus di best practice Postgres + Supabase untuk MyPresensi.

## A. Query Performance — CRITICAL

### Index Discipline
1. **SELALU buat index** untuk kolom yang sering di-WHERE, JOIN, atau ORDER BY.
2. **Foreign key kolom WAJIB di-index** — Postgres TIDAK auto-index FK. Tabel join tanpa FK index = full scan.
3. **Composite index** untuk multi-kolom filter. **Urutan kolom = urutan filter**: equality dulu, range terakhir.
   ```sql
   -- Untuk query: WHERE course_id = ? AND created_at > ?
   CREATE INDEX idx_attendances_course_date ON attendances(course_id, created_at);
   ```
4. **Partial index** untuk filter yang sering, hanya sebagian baris:
   ```sql
   CREATE INDEX idx_active_sessions ON sessions(course_id) WHERE is_active = true;
   CREATE INDEX idx_pending_leaves ON leave_requests(student_id) WHERE status = 'pending';
   ```
5. **Hindari `SELECT *`** — pilih hanya kolom yang dibutuhkan, kurangi I/O.
6. **`EXPLAIN ANALYZE`** untuk debug query lambat. `Seq Scan` di tabel besar = tanda butuh index. `Index Scan` = bagus.

### Pagination — Cursor-Based
Pakai cursor (`WHERE id > last_id`) BUKAN `OFFSET`. `OFFSET` lambat untuk halaman jauh karena tetap scan baris yang di-skip.

```sql
-- ✅ Cursor-based
SELECT * FROM attendances
WHERE created_at < $cursor
ORDER BY created_at DESC
LIMIT 20;

-- ❌ Offset (lambat di halaman 100+)
SELECT * FROM attendances
ORDER BY created_at DESC
LIMIT 20 OFFSET 2000;
```

Untuk admin dashboard yang butuh "halaman X dari Y" — OK pakai offset, tapi siapkan COUNT terpisah & cache.

### N+1 Prevention
- Pakai JOIN atau subquery untuk data terkait, bukan loop single-query.
- Contoh anti-N+1:
  ```ts
  // ❌ N+1
  const courses = await supabase.from('courses').select('*')
  for (const c of courses.data) {
    const dosen = await supabase.from('profiles').select('full_name').eq('id', c.dosen_id).single()
  }

  // ✅ Single query dengan join
  const { data } = await supabase
    .from('courses')
    .select('*, dosen:profiles!courses_dosen_id_fkey(id, full_name)')
  ```

### Batch Operations
- **Insert banyak**: `INSERT INTO ... VALUES (...), (...), (...)` — bukan loop single insert.
- **UPSERT**: `ON CONFLICT DO UPDATE` — bukan SELECT lalu INSERT (race condition).
- Supabase JS: `.insert([row1, row2, ...])` atau `.upsert([...], { onConflict: 'unique_col' })`.

## B. RLS Security — CRITICAL

### Wajib di Setiap Tabel Baru
1. **`ALTER TABLE xxx ENABLE ROW LEVEL SECURITY;`** SEGERA setelah CREATE TABLE.
2. Tanpa policy → tabel jadi **deny all** (default DENY). Minimal harus ada 1 policy SELECT untuk role yang relevan.
3. **RLS policy WAJIB pakai `auth.uid()`** — JANGAN parameter dari client.
4. Hindari function **VOLATILE** dalam policy — pakai **STABLE** atau **IMMUTABLE** untuk performa.
5. Cache role check di subquery / CTE jika dipakai berkali-kali:
   ```sql
   -- Pola untuk policy yang cek role
   CREATE POLICY "Admin can do all" ON foos FOR ALL
   USING (
     EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
   );
   ```

### Defense-in-Depth (3 Layer)
1. **Layer 1 — Middleware**: cek session + admin-only routes (`/mahasiswa`, `/dosen`, `/audit`, `/settings`, `/export`).
2. **Layer 2 — Server Action / Route Handler**: `requireRole(['admin','dosen'])` + (jika perlu) `canAccessCourse(userId, role, courseId)`.
3. **Layer 3 — RLS Postgres**: policy granular per tabel.

Ketiganya saling backup. Kalau salah satu bocor, dua lainnya masih nahan.

### `createClient()` vs `createAdminClient()`

| Client | Pakai untuk | RLS |
|--------|-------------|-----|
| `createClient()` (anon + cookies) | `auth.getUser()`, query yg patuh RLS user | Aktif (per-row gating) |
| `createAdminClient()` (service_role) | Mutasi DB di Server Action / Route Handler **setelah** auth check | **Bypass RLS** |

**Aturan emas**: Sebelum `createAdminClient()` untuk operasi sensitif, **selalu** validasi user dulu via `createClient().auth.getUser()` atau `requireRole()`.

### Test RLS Policy
Setelah tulis policy, test:
1. Sebagai `anon` → harus reject sesuai design (kebanyakan tabel kita: anon tidak boleh SELECT apapun).
2. Sebagai `authenticated` (cookie) → harus return baris milik user / yang relevan dengan role.
3. Sebagai `service_role` (admin client) → bypass semua, return semua.

## C. Schema Design

### Wajib
1. **UUID primary key** — `id UUID DEFAULT gen_random_uuid() PRIMARY KEY`. JANGAN `SERIAL` (mudah di-enumerate).
2. **NOT NULL + DEFAULT** untuk kolom wajib:
   ```sql
   status TEXT NOT NULL DEFAULT 'pending'
   created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
   ```
3. **CHECK constraint** untuk validasi level DB. Contoh:
   ```sql
   status TEXT NOT NULL CHECK (status IN ('hadir', 'izin', 'sakit', 'alpa'))
   role TEXT NOT NULL CHECK (role IN ('admin', 'dosen', 'mahasiswa'))
   ```
4. **`TIMESTAMPTZ`** untuk timestamp, BUKAN `TIMESTAMP` (yang tanpa timezone).
5. **Lowercase identifiers** — hindari `"CamelCase"` quoted names. Pakai `snake_case`.
6. **Index pada FK** wajib (lihat Section A).
7. **`updated_at` trigger** kalau punya kolom tersebut:
   ```sql
   CREATE OR REPLACE TRIGGER trigger_<tabel>_updated_at
     BEFORE UPDATE ON <tabel>
     FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
   ```

### SECURITY DEFINER Functions
Saat tulis function `SECURITY DEFINER` (mis. `handle_new_user`, custom RLS helper):
- **WAJIB** `SET search_path = public, pg_temp` agar tidak rentan search_path injection.
  ```sql
  CREATE OR REPLACE FUNCTION my_helper()
  RETURNS ... LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public, pg_temp
  AS $$ ... $$;
  ```

### Migration Idempotency
- `IF NOT EXISTS` di setiap CREATE.
- `ON CONFLICT DO NOTHING` di INSERT seed.
- 1 migration = 1 perubahan logis. Jangan campur tambah-tabel-A + ubah-kolom-B + index-C kalau tidak saling tergantung.

## D. Connection & Concurrency

1. **Connection pooling** — Supabase sudah built-in via PgBouncer. JANGAN buat connection baru per request.
2. **`statement_timeout`** untuk query yang berisiko panjang:
   ```sql
   SET LOCAL statement_timeout = '10s';
   ```
3. **Race condition** di submit presensi → ditangani via `UNIQUE(session_id, student_id)` constraint, bukan check-then-insert.

## E. Sensitive Field Handling

1. **`session_code`**: TIDAK BOLEH di-return ke client lewat GET endpoint. Hanya server yang generate dan dosen yang lihat di UI mereka.
2. **`face_embeddings`**: array float (192-d). JANGAN expose ke endpoint publik. Hanya server-side comparison.
3. **`audit_logs`**: hanya admin yang boleh SELECT. JANGAN expose ke `/api/mobile/*`.
4. **Password**: di-hash oleh Supabase Auth — tidak ada di `profiles`. Jangan tambah kolom `password` di tabel public.
5. **Email**: Supabase Auth (`auth.users.email`) tidak otomatis sync ke `profiles.email`. Saat update email user via admin → panggil **dua tempat**:
   ```ts
   await supabase.auth.admin.updateUserById(id, { email: newEmail })
   await supabase.from('profiles').update({ email: newEmail }).eq('id', id)
   ```

## F. Monitoring & Audit

1. **`pg_stat_statements`** — cek query paling sering / paling lambat.
2. **`mcp0_get_advisors({ project_id, type: 'security' })`** WAJIB dijalankan setelah setiap migration baru. Flag jika RLS belum aktif atau policy hilang.
3. **`mcp0_get_advisors({ project_id, type: 'performance' })`** untuk cek missing index, slow query.
4. **`audit_logs` table** — setiap mutasi penting wajib panggil `logAudit()`. Cari nama action serupa di `app/lib/actions/*.ts` sebelum bikin baru.
5. **Autovacuum** — pastikan jalan, monitor dead tuples lewat Supabase Studio → Database → Statistics.

## G. Migration Workflow

Lihat workflow lengkap di `/add-supabase-migration`. Ringkasan:
1. Naikkan nomor migration (`001..00X`) atau pakai timestamp `YYYYMMDDhhmmss_<nama>` jika via MCP.
2. SQL: tabel + RLS + policy + index + trigger.
3. Jalankan via `mcp0_apply_migration` (DDL) atau SQL Editor manual.
4. Update `app/types/database.ts`.
5. Run `mcp0_get_advisors` security.
6. Update CHANGELOG.

## H. Common Pitfalls MyPresensi

1. **`anon` role TIDAK punya SELECT** ke tabel public manapun (sejak migration 006). Web SSR pakai role `authenticated` (cookie auth) atau `service_role` (admin client). Mobile pakai `service_role` via `/api/mobile/*`. JANGAN tambah `GRANT SELECT ... TO anon` kecuali ada alasan public read sangat eksplisit.
2. **`authenticated` role punya SELECT ke tabel public** — intentional, gating per-row via RLS. JANGAN revoke kecuali yakin web SSR tidak butuh.
3. **`audit_logs` & `notifications`: TIDAK ADA insert policy permissive**. Insert hanya via `service_role` (`createAdminClient()`) yang bypass RLS. Server actions yang panggil `logAudit()` / kirim notifikasi WAJIB pakai admin client.
4. **Migration history Supabase**: sejak MCP aktif (2026-05-14), migration baru pakai `mcp0_apply_migration` agar otomatis ke-track dengan timestamp. Migration manual via SQL Editor tidak ke-track di history Supabase.
5. **Function `handle_new_user`, `update_updated_at_column`, `rls_auto_enable`** sudah punya `search_path` eksplisit. Saat tulis function baru, SELALU `SET search_path = public, pg_temp` di SECURITY DEFINER functions.

## I. Referensi

Best practice lengkap: `https://github.com/supabase/agent-skills/tree/main/skills/supabase-postgres-best-practices`. Sesuaikan dengan konvensi MyPresensi.
