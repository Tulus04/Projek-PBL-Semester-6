# Runbook — Database Backup & Recovery (MyPresensi)

> Dokumen ini panduan operasional untuk **disaster recovery** Supabase Postgres MyPresensi.
> Sasaran: developer/admin yang harus pulihkan database setelah insiden (data korup, salah migration, drop table tidak sengaja, kebocoran kredensial, dsb).
>
> **Iron law**: SEBELUM eksekusi langkah destruktif (DROP/DELETE massal, restore from backup) — **STOP, baca dulu seluruh runbook**, snapshot state saat ini, lalu eksekusi step demi step.

---

## 1. Daftar Aset Kritis & Klasifikasi

| Tabel | Tier | Backup Wajib? | Pemulihan |
|-------|------|---------------|-----------|
| `auth.users`, `profiles` | Tier 1 | ✅ | Tidak boleh hilang. Akun mahasiswa/dosen/admin. |
| `face_embeddings` | Tier 1 (biometrik) | ✅ | Hilang = mahasiswa harus daftar wajah ulang. UU PDP-sensitive. |
| `attendances`, `sessions`, `enrollments` | Tier 2 | ✅ | Riwayat presensi semester berjalan. |
| `leave_requests`, `notifications` | Tier 2 | ✅ | Bukti pengajuan izin & komunikasi. |
| `audit_logs` | Tier 2 | ✅ | Forensic insiden. Hilang = tidak bisa investigasi. |
| `courses`, `campus_locations`, `settings` | Tier 3 | ✅ | Static-ish, recovery bisa dari migration + seed. |
| `rate_limit_log` | Tier 4 | ❌ | Ephemeral, OK kosong setelah recovery. |

---

## 2. Strategi Backup (Pre-Incident)

### 2.1 Supabase Auto-Backup

**Free Plan (saat ini)**:
- Daily backup otomatis, retention **7 hari**.
- Lokasi: Dashboard → Project → Database → **Backups**.
- Format: full snapshot Postgres.
- **Limitasi**: Tidak ada PITR (Point-In-Time Recovery), tidak bisa restore ke timestamp spesifik (cuma daily).

**Pro Plan (rekomendasi pre-deploy production)**:
- PITR up to 7 days (recovery ke timestamp menit-spesifik).
- Backup retention 30 hari.
- WAL streaming aktif.

### 2.2 Manual Export Mingguan (Wajib)

Karena Free Plan retention pendek, **WAJIB** export manual mingguan:

```powershell
# Pakai pg_dump dari host lokal — butuh connection string Supabase
# Dapat dari Dashboard → Settings → Database → Connection string (URI mode)
# Format: postgresql://postgres:<password>@db.<ref>.supabase.co:5432/postgres

$BACKUP_DIR = "C:\Users\riki\Documents\Projek-PBL-Semester-6\backups"
$TIMESTAMP = Get-Date -Format "yyyyMMdd_HHmmss"
$DB_URI = "postgresql://postgres:<password>@db.<ref>.supabase.co:5432/postgres"

# Full dump (schema + data) — encrypted
pg_dump $DB_URI `
  --no-owner --no-acl `
  --format=custom `
  --file="$BACKUP_DIR\mypresensi_full_$TIMESTAMP.dump"

# Schema-only (untuk reproduksi struktur)
pg_dump $DB_URI `
  --no-owner --no-acl --schema-only `
  --file="$BACKUP_DIR\mypresensi_schema_$TIMESTAMP.sql"

# Data-only (untuk restore selektif)
pg_dump $DB_URI `
  --no-owner --no-acl --data-only `
  --file="$BACKUP_DIR\mypresensi_data_$TIMESTAMP.sql"
```

**Aturan storage backup**:
- Folder `backups/` di-gitignore (sudah, lihat `.gitignore`).
- Backup full mingguan, simpan minimal 4 minggu rolling.
- File `*.dump` tidak boleh commit ke Git (berisi data PII + biometrik hash).
- Encrypt file dengan password jika simpan di cloud (Google Drive/OneDrive):
  ```powershell
  # Pakai 7z dengan password
  7z a -p<password> -mhe=on backup_encrypted.7z mypresensi_full_*.dump
  ```

### 2.3 Migration File (Source of Truth Schema)

`mypresensi-web/supabase/migrations/00X_*.sql` adalah source of truth schema.

- **JANGAN** edit migration yang sudah jalan di production. Buat migration baru sebagai diff.
- **Semua migration** wajib di-track via `mcp0_apply_migration` (sejak 2026-05-14) — JANGAN apply manual via SQL Editor.
- Migration file di repo + Supabase migration history = recovery path schema.

---

## 3. Deteksi Insiden

### 3.1 Gejala yang Trigger Runbook Ini

| Gejala | Kemungkinan Penyebab | Severity |
|--------|----------------------|----------|
| Login mahasiswa gagal massal | RLS policy korup, profiles hilang | 🔴 Critical |
| Submit presensi error 500 di semua sesi | Schema mismatch, kolom hilang | 🔴 Critical |
| Audit log `mock_location_detected` > 5/menit | Serangan fake GPS terkoordinasi | 🟡 High |
| Audit log `failed_login` > 50/menit dari satu IP/device | Brute force | 🟡 High |
| `service_role` key bocor di Git/screenshot | Credential leak | 🔴 Critical |
| `face_embeddings` row tiba-tiba berkurang drastis | DELETE accidental, mass attack | 🔴 Critical |
| Migration baru fail di tengah, table half-created | Migration error | 🟡 High |

### 3.2 Tools Deteksi

```
# 1. Cek security advisor
mcp0_get_advisors({ project_id: '<ref>', type: 'security' })

# 2. Cek performance advisor (slow query indikasi missing index)
mcp0_get_advisors({ project_id: '<ref>', type: 'performance' })

# 3. Cek log error
mcp0_get_logs({ project_id: '<ref>', service: 'postgres' })   # DB error
mcp0_get_logs({ project_id: '<ref>', service: 'api' })        # API error
mcp0_get_logs({ project_id: '<ref>', service: 'auth' })       # Login error

# 4. Query forensic audit (cek aktivitas suspicious)
mcp0_execute_sql({
  project_id: '<ref>',
  query: `
    SELECT action, COUNT(*) as count, MAX(created_at) as last
    FROM audit_logs
    WHERE created_at > NOW() - INTERVAL '1 hour'
    GROUP BY action
    ORDER BY count DESC
    LIMIT 20
  `
})
```

---

## 4. Prosedur Recovery (Decision Tree)

```
[Insiden terjadi]
       │
       ▼
[Identifikasi jenis] ──→ Data korup / hilang? ──→ §4.1 Restore data
                    ──→ Schema rusak? ──────────→ §4.2 Reapply migration
                    ──→ Credential bocor? ──────→ §4.3 Rotate kredensial
                    ──→ Brute force aktif? ─────→ §4.4 Lockout & blokir
                    ──→ Mass attack? ───────────→ §4.5 Pause project
```

### 4.1 Restore Data dari Backup

**Skenario**: Tabel `attendances` ke-DELETE 1000+ row, atau database ter-corrupt.

**Step-by-step**:

```powershell
# 1. SNAPSHOT state saat ini sebelum restore (jangan langsung overwrite)
$TIMESTAMP_NOW = Get-Date -Format "yyyyMMdd_HHmmss"
pg_dump $DB_URI --no-owner --no-acl --format=custom `
  --file="backups\pre_restore_snapshot_$TIMESTAMP_NOW.dump"

# 2. Identifikasi backup terdekat sebelum insiden
# Lihat di Supabase Dashboard → Backups, atau folder backups\ lokal

# 3. (Opsional) Test restore di branch dulu (Supabase Pro)
# mcp0_create_branch — apply backup ke dev branch, verify, baru ke production

# 4. Restore via Supabase Dashboard (RECOMMENDED)
#    Dashboard → Database → Backups → pilih backup → "Restore"
#    Supabase akan apply backup + downtime ~5-15 menit.

# 5. Atau restore manual via pg_restore (data-only, tabel spesifik)
pg_restore --dbname=$DB_URI `
  --no-owner --no-acl `
  --data-only `
  --table=attendances `
  --table=sessions `
  "backups\mypresensi_full_<timestamp>.dump"
```

**Verifikasi pasca restore**:
```sql
-- Jumlah row sebelum vs sesudah
SELECT COUNT(*) FROM attendances WHERE created_at > '2026-01-01';
SELECT COUNT(*) FROM sessions;

-- Sanity check RLS
SELECT tablename, rowsecurity FROM pg_tables
WHERE schemaname = 'public' AND rowsecurity = false;
-- Expected: 0 rows (semua public tables harus RLS enabled)

-- Settings & seed data
SELECT * FROM settings;
SELECT * FROM campus_locations;
```

### 4.2 Reapply Migration (Schema Rusak)

**Skenario**: Migration baru fail di tengah, kolom hilang, constraint corrupt.

```
1. Identifikasi migration yang bermasalah:
   mcp0_list_migrations({ project_id: '<ref>' })

2. Cek state schema saat ini:
   mcp0_list_tables({ project_id: '<ref>', schemas: ['public'], verbose: true })

3. Tulis migration FIX (bukan edit migration lama):
   File: supabase/migrations/0XX_fix_<deskripsi>.sql
   - DROP/ALTER yang corrupt
   - Re-create dengan benar

4. Apply via MCP:
   mcp0_apply_migration({
     project_id: '<ref>',
     name: 'fix_<deskripsi>',
     query: '<SQL>'
   })

5. Verifikasi:
   - mcp0_get_advisors({ type: 'security' }) → 0 issue baru
   - Coba query critical: SELECT FROM attendances LIMIT 1
```

**Anti-pattern**: JANGAN edit migration yang sudah jalan & tracked. Selalu buat migration baru.

### 4.3 Rotate Kredensial (Service Role Bocor)

**Skenario**: `SUPABASE_SERVICE_ROLE_KEY` bocor di Git, screenshot, log.

```
1. STOP (segera) — jangan tunda
   → Asumsi attacker sudah punya akses bypass RLS

2. Rotate service role key:
   Supabase Dashboard → Settings → API → "Reset service_role secret"
   → Konfirmasi (irreversible — semua app yang pakai key lama akan 401)

3. Update .env.local di mypresensi-web/
   SUPABASE_SERVICE_ROLE_KEY=<new key>

4. Restart Next.js:
   - Local: Ctrl+C, npm run dev
   - Production: trigger redeploy di Vercel/host

5. Audit window penyalahgunaan:
   SELECT * FROM audit_logs
   WHERE created_at BETWEEN '<bocor_time>' AND NOW()
   ORDER BY created_at DESC;

   Cari action mencurigakan: bulk insert/delete, akses dari IP asing.

6. Force re-auth semua user (opsional, tapi recommended):
   -- Invalidate semua session aktif
   UPDATE auth.users SET updated_at = NOW();
   -- atau truncate tabel session yang Supabase pakai

7. Postmortem:
   - Bagaimana key bocor? (commit, screenshot, log file?)
   - Update .gitignore, audit history, rotate review process
```

### 4.4 Lockout & Blokir (Brute Force Aktif)

**Skenario**: Audit log menunjukkan 50+ `failed_login` dari satu device dalam 5 menit.

```sql
-- 1. Identifikasi device/IP penyerang
SELECT
  details->>'device_id' AS device_id,
  ip_address,
  COUNT(*) AS attempts,
  MAX(created_at) AS last_attempt
FROM audit_logs
WHERE action = 'failed_login'
  AND created_at > NOW() - INTERVAL '15 minutes'
GROUP BY 1, 2
ORDER BY attempts DESC
LIMIT 20;

-- 2. Identifikasi target user
SELECT
  details->>'email' AS target_email,
  COUNT(*) AS attempts
FROM audit_logs
WHERE action = 'failed_login'
  AND created_at > NOW() - INTERVAL '15 minutes'
GROUP BY 1
ORDER BY attempts DESC
LIMIT 20;

-- 3. Lockout target user (set is_active = false sementara)
UPDATE profiles
SET is_active = false
WHERE id IN (
  SELECT id FROM profiles
  WHERE email = '<target_email>'
);

-- 4. Notify user via channel resmi (WhatsApp dosen pembimbing, email)
-- Berikan password baru manual via admin reset, jangan biarkan user reset sendiri
-- karena attacker mungkin punya akses email user.
```

**Long-term**: Tambah Cloudflare/WAF di depan domain produksi (bukan dalam scope PBL, tapi catat untuk fase deployment real).

### 4.5 Pause Project (Mass Attack)

**Skenario**: Serangan masif terkoordinasi, attacker punya credential, audit log spam.

```
1. Pause Supabase project (emergency stop):
   Dashboard → Settings → General → "Pause project"
   → Project offline, attacker tidak bisa akses
   → Data tetap aman di DB

2. Investigate offline:
   - Download backup terbaru
   - Restore ke local Postgres untuk forensic
   - Identifikasi celah masuk

3. Patch celah:
   - Rotate semua credential (service_role, JWT secret jika perlu)
   - Apply migration security hardening tambahan
   - Update RLS policy yang lemah

4. Restore project:
   Dashboard → Settings → General → "Restore project"
   → Projek aktif lagi dengan patch applied

5. Notify pengguna (email/WhatsApp dosen):
   "Sistem MyPresensi mengalami pemeliharaan darurat. Mohon login ulang
    dan ganti password Anda."
```

---

## 5. Post-Incident — Postmortem Template

Setiap insiden Tier 1/2 wajib ada postmortem di `docs/incidents/<YYYYMMDD>-<deskripsi>.md`:

```markdown
# Insiden YYYY-MM-DD — <Deskripsi singkat>

## Ringkasan
- **Kapan terdeteksi**: YYYY-MM-DD HH:MM (timezone)
- **Kapan terjadi**: YYYY-MM-DD HH:MM (perkiraan, dari log)
- **Kapan termitigasi**: YYYY-MM-DD HH:MM
- **Severity**: 🔴 Critical / 🟡 High / 🟢 Low
- **User terdampak**: <jumlah / segmen>
- **Data terdampak**: <tabel & row count>

## Timeline
- HH:MM — Apa terjadi
- HH:MM — Bagaimana terdeteksi (alert / user report / manual check)
- HH:MM — Aksi yang diambil
- ...

## Root Cause
<Investigasi 4-fase RCA, lihat 02-quality-debugging-verification.md>

## Mitigasi
- Patch yang diterapkan
- Migration baru
- Konfigurasi yang diubah

## Action Items (preventif)
- [ ] Tambah RLS policy X
- [ ] Buat alert rule Y
- [ ] Update runbook bagian Z
- [ ] Training tim tentang W

## Lesson Learned
<Apa yang dipelajari, apa yang akan dilakukan beda lain kali>
```

---

## 6. Test Recovery (Drill — Wajib Quarterly)

Recovery yang tidak pernah di-test = recovery yang tidak ada.

**Drill quarterly** (per 3 bulan):

```
1. Buat dev branch via MCP:
   mcp0_create_branch({ project_id: '<ref>', name: 'recovery-drill-<date>' })

2. Apply backup terbaru ke branch.

3. Simulate insiden:
   - DROP table attendances
   - DELETE FROM profiles WHERE role = 'mahasiswa' LIMIT 5
   - Corrupt 1 RLS policy

4. Recover via runbook ini, hitung waktu pemulihan.

5. Hapus branch:
   mcp0_delete_branch({ branch_id: '<id>' })

6. Update runbook jika ada langkah yang ternyata tidak jalan / butuh perbaikan.
```

**Target RTO** (Recovery Time Objective):
- Tier 1 incident: < 30 menit dari deteksi ke recovery start.
- Tier 2 incident: < 2 jam.

---

## 7. Kontak Eskalasi

| Role | Saat Apa | Kontak |
|------|----------|--------|
| Dosen Pembimbing PBL | Insiden Tier 1 (data hilang/bocor) | <isi sesuai tim> |
| IT Kampus Politani | Insiden infrastruktur kampus (jaringan, server) | <isi sesuai tim> |
| Supabase Support | Bug platform, restore failure | support@supabase.com (Pro plan only) |
| Tim Inti MyPresensi | Konsultasi teknis | <isi sesuai tim> |

---

## 8. Referensi

- [Supabase Backups documentation](https://supabase.com/docs/guides/platform/backups)
- [PostgreSQL pg_dump official](https://www.postgresql.org/docs/current/app-pgdump.html)
- [UU PDP No. 27/2022 — Pasal 46 (Pemberitahuan Pelanggaran)](https://peraturan.bpk.go.id/Details/229798/uu-no-27-tahun-2022)
- `docs/plans/implementation_plan.md` — threat model lengkap MyPresensi
- `.windsurf/rules/04-security-and-privacy.md` — incident response singkat (mirror dokumen ini, lebih ringkas)

---

**Last updated**: 2026-05-14 (initial version, T3-#8 dari roadmap audit komprehensif).
**Next review**: Setelah drill quarterly pertama atau insiden nyata, mana yang lebih dulu.
