---
description: Pola tambah migration Supabase baru (tabel/kolom + RLS + index + types) dan menjalankannya via Supabase MCP atau SQL Editor. Selalu ikuti urutan ini agar `001..00X` tetap konsisten.
---

# Add Supabase Migration

Workflow untuk menambah perubahan skema database. Migration ditaruh di `mypresensi-web/supabase/migrations/` dengan nomor urut.

## 1. Tentukan nomor & nama migration

### Konvensi Penomoran (Dual)

MyPresensi pakai **dua format penamaan** yang saling melengkapi:

| Lokasi | Format | Contoh |
|--------|--------|--------|
| File lokal di `supabase/migrations/` | **Sequential** `00X_<nama>.sql` (1-indexed) | `006_security_hardening.sql` |
| Supabase migration history (via MCP) | **Timestamp** `YYYYMMDDhhmmss_<nama>` (otomatis) | `20260514050201_security_hardening` |

**Aturan**:
1. Saat tulis SQL baru → simpan file di `mypresensi-web/supabase/migrations/00X_<nama>.sql` (sequential).
2. Saat apply via MCP → nama auto-jadi timestamp di history Supabase (kedua nama merujuk ke migration yang sama, sinkron).
3. Migration manual via SQL Editor TIDAK ke-track di Supabase history — SEJAK 2026-05-14, WAJIB lewat MCP `mcp0_apply_migration` agar history konsisten.

### Cek Nomor Terakhir Lokal

// turbo
```powershell
Get-ChildItem mypresensi-web/supabase/migrations -Name
```

Naikkan nomor (`006` → `007`). Nama format: `00X_<nama_singkat>.sql` (snake_case, deskriptif). Contoh:
- `007_add_terlambat_status.sql`
- `008_leave_request_evidence_storage.sql`

### Cek History Supabase

```
mcp0_list_migrations({ project_id: '<ref>' })
```

Kalau ada migration di Supabase history yang BELUM punya file lokal di repo (mis. di-apply manual via Studio sebelum MCP aktif), pertimbangkan dump SQL-nya & commit ke repo agar tetap reproducible.

**Aturan**: 1 migration = 1 perubahan logis. Jangan campur tambah-tabel-A + ubah-kolom-B + tambah-index-C kalau tidak saling tergantung.

## 2. Tulis SQL — Template lengkap

```sql
-- mypresensi-web/supabase/migrations/00X_<nama>.sql
-- <Penjelasan 1-2 kalimat: apa yang ditambah dan kenapa>

-- ===========================
-- TABEL / KOLOM BARU
-- ===========================
CREATE TABLE IF NOT EXISTS <tabel> (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  -- ... kolom-kolom
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- (jika ada kolom JSONB / array, tambahkan komentar)
COMMENT ON COLUMN <tabel>.<kolom> IS '...';

-- ===========================
-- SEED (opsional)
-- ===========================
INSERT INTO <tabel> (...) VALUES (...)
ON CONFLICT DO NOTHING;

-- ===========================
-- INDEXES
-- ===========================
CREATE INDEX IF NOT EXISTS idx_<tabel>_<kolom> ON <tabel>(<kolom>);

-- Partial index kalau hanya sebagian baris yang sering di-query:
CREATE INDEX IF NOT EXISTS idx_<tabel>_pending
  ON <tabel>(status) WHERE status = 'pending';

-- ===========================
-- ROW LEVEL SECURITY
-- ===========================
ALTER TABLE <tabel> ENABLE ROW LEVEL SECURITY;

-- Pilih policy yang sesuai (lihat 001_initial_schema.sql untuk pola yang ada):

-- a) User akses miliknya sendiri:
CREATE POLICY "Users can manage own <tabel>"
  ON <tabel> FOR ALL
  USING (auth.uid() = user_id);

-- b) Authenticated read-only, admin manage:
CREATE POLICY "Authenticated can read <tabel>"
  ON <tabel> FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admin can manage <tabel>"
  ON <tabel> FOR ALL
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ===========================
-- TRIGGER updated_at (kalau punya kolom updated_at)
-- ===========================
CREATE OR REPLACE TRIGGER trigger_<tabel>_updated_at
  BEFORE UPDATE ON <tabel>
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

**Yang JANGAN dilupakan**:
- `IF NOT EXISTS` di setiap CREATE — bikin migration idempotent.
- `ON CONFLICT DO NOTHING` di INSERT seed.
- `ENABLE ROW LEVEL SECURITY` segera setelah CREATE TABLE.
- Minimal 1 policy SELECT — tanpa policy, tabel jadi tidak bisa dibaca siapapun (default DENY).

## 3. Jalankan migration

### Opsi A: Supabase MCP (RECOMMENDED — history ke-track otomatis)

Pakai `mcp0_apply_migration` (DDL) atau `mcp0_execute_sql` (DML one-off):

```
mcp0_apply_migration({
  project_id: '<ref>',
  name: 'security_hardening',           // snake_case, akan jadi suffix timestamp
  query: '<isi SQL lengkap>'
})
```

Project ID: lihat di `mypresensi-web/.env.local` (`NEXT_PUBLIC_SUPABASE_URL` → bagian sebelum `.supabase.co`).

Cascade akan minta konfirmasi sebelum eksekusi DDL ke production.

**Setelah apply**: file lokal `00X_<nama>.sql` tetap ada di repo (sebagai source of truth untuk reviewer di Git). History Supabase punya entri `YYYYMMDDhhmmss_<nama>`. Keduanya sinkron, tidak ada duplikasi data.

### Opsi B: SQL Editor di Supabase Studio (manual — NOT RECOMMENDED untuk migration baru)

1. Buka Dashboard → SQL Editor → New query.
2. Paste seluruh isi `00X_<nama>.sql`.
3. **Run**.
4. Pastikan output: `Success. No rows returned`.

**Peringatan**: Migration via SQL Editor TIDAK ke-track di Supabase migration history. Kalau pakai opsi ini, dokumentasikan manual di `CHANGELOG.md` agar tim tahu kapan applied. Lebih baik pakai Opsi A.

### Verifikasi

// turbo
```powershell
$env:PGPASSWORD; # biarkan kosong jika tidak set
```

Atau pakai Supabase Studio → Table Editor → cek tabel/kolom muncul.

## 4. Update TypeScript types

File: `mypresensi-web/app/types/database.ts`

```ts
// Tambah interface baru, ikuti pola yang sudah ada
export interface NewEntity {
  id: string
  // ... field
  created_at: string
  updated_at?: string

  // Joined fields (optional) untuk relasi
  user?: Pick<Profile, 'id' | 'full_name'>
}
```

Atau regenerate via MCP:
```
mcp0_generate_typescript_types({ project_id: '<ref>' })
```
(lalu copy-paste output ke `app/types/database.ts`)

## 5. Cek security advisor

// turbo
```
mcp0_get_advisors({ project_id: '<ref>', type: 'security' })
```

Penting setelah DDL — tools ini akan flag jika RLS belum aktif atau policy hilang. Fix langsung sebelum lanjut.

## 6. Update kode

| Lokasi | Perlu update? |
|--------|---------------|
| `app/lib/actions/<domain>.ts` | Server Action baru sesuai workflow `add-server-action.md` |
| `app/api/mobile/...` | Endpoint mobile sesuai workflow `add-mobile-api-endpoint.md` |
| `app/(dashboard)/<halaman>/` | UI admin/dosen kalau perlu CRUD |
| `mypresensi-mobile/lib/features/...` | Model/repo/provider kalau dipakai mobile |

## 7. Update CHANGELOG

Tambah entri di `CHANGELOG.md`:

```markdown
| HH:MM | [ADD] | `supabase/migrations/00X_<nama>.sql` | <Penjelasan singkat> |
```

## 8. Checklist sebelum commit

- [ ] File migration nomornya berurutan (tidak skip).
- [ ] `IF NOT EXISTS` di setiap CREATE.
- [ ] RLS enabled + policy minimal SELECT untuk role yang relevan.
- [ ] Index untuk kolom yang dipakai di WHERE / JOIN.
- [ ] `app/types/database.ts` terupdate.
- [ ] `mcp0_get_advisors` security: 0 issue baru.
- [ ] CHANGELOG terupdate.
- [ ] Migration sudah dijalankan di Supabase project (jangan commit migration yang belum jalan).

## 9. Rollback (jika perlu)

Tidak ada rollback otomatis. Buat migration baru dengan nomor berikutnya yang `DROP` atau `ALTER` balik:

```sql
-- 00Y_revert_<nama>.sql
DROP TABLE IF EXISTS <tabel> CASCADE;
```

**Hati-hati**: `CASCADE` akan hapus row dari tabel lain yang punya foreign key. Cek dulu lewat `mcp0_list_tables` + `verbose: true`.
