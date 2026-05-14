# Scripts MyPresensi Web

Folder berisi script otomasi untuk testing, maintenance, dan tooling.

---

## `smoke-test-mobile-api.mjs` — Regression Test BUG-011

Smoke test otomatis untuk 5 endpoint mobile (`/api/mobile/*`) yang memverifikasi **BUG-011 fix** — setiap row di `audit_logs` harus punya `user_id`, `ip_address`, dan `details.user_agent` terisi (forensic trail lengkap).

### Coverage

| # | Endpoint | Audit Action | Expected |
|---|----------|--------------|----------|
| 1 | `POST /auth/login` | `mobile_login` | 200 + JWT |
| 2 | `POST /attendance/submit` (GPS valid) | `mobile_attendance_submit` | 201 status=hadir |
| 3 | `POST /attendance/submit` (`is_mock_location=true`) | `mock_location_detected` | **403 Forbidden** |
| 4 | `POST /leave-requests/submit` | `mobile_leave_request_submit` | 201 status=pending |
| 5 | `POST /face/register` | `mobile_face_register` | 201 + embedding_hash |
| 6 | `POST /auth/change-password` (forward + revert) | `mobile_change_password` ×2 | 200 success |
| – | Final query `audit_logs` | – | 100% rows dengan user_id+ip+ua terisi |

### Cara Pakai

**Prerequisites**:
1. Dev server jalan: `npm run dev`
2. Akun mahasiswa test ada di DB (default: Budi Santoso, NIM `P2100003`)
3. `.env.local` terisi `NEXT_PUBLIC_SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY`
4. Minimal 1 sesi `is_active=true` di MK001 (script set session_code-nya sendiri)

**Run**:
```powershell
npm run test:smoke
```

**Override (opsional)** via env var:
```powershell
$env:TEST_EMAIL='siti.nurhaliza@student.ac.id'; $env:TEST_NIM='P2100002'; $env:TEST_PASSWORD='P2100002@politani'; npm run test:smoke
```

| Env var | Default | Catatan |
|---------|---------|---------|
| `BASE_URL` | `http://localhost:3000` | URL dev server |
| `TEST_EMAIL` | `budi.santoso@student.ac.id` | Email mahasiswa test |
| `TEST_PASSWORD` | `P2100003@politani` | Password default (NIM@politani) |
| `TEST_NIM` | `P2100003` | Untuk lookup profile |

### Output

Colored console (ANSI escape) dengan per-test pass/fail, action breakdown, dan summary. Exit code:
- **0** = semua test pass, BUG-011 fix VERIFIED ✅
- **1** = ada yang gagal (lihat detail di output)

### Idempotency & Cleanup

Script **selalu cleanup** state DB di akhir (lewat `try-finally`), bahkan saat error:
- DELETE attendance/leave_request/face_embedding row yang dibuat selama test
- DELETE enrollment **hanya** kalau script yang buat (preserve enrollment existing)
- RESET `sessions.session_code = null`
- RESET `profiles.must_change_password = true`, `is_face_registered = false`
- Password mahasiswa di-revert ke default via roundtrip (forward → re-login → revert)

⚠️ **Audit logs row tetap dipertahankan** sebagai forensic trail historical. Tidak di-cleanup karena bagian dari design — log mencatat aksi smoke test legitimate (with user_agent `MyPresensi-SmokeTest/1.0 (Node)` mudah di-filter).

### Failure Modes

| Symptom | Kemungkinan |
|---------|-------------|
| `FATAL: ECONNREFUSED` | Dev server belum jalan |
| `Login failed 401` | Password mahasiswa berubah (lihat `.dev-accounts.md`) |
| `No active sessions in MK001` | Buat sesi aktif via dashboard dosen dulu |
| `Profile not found` | NIM tidak ada di DB |
| `WARNING: password mungkin masih TestSmoke...` | Revert gagal — reset manual via Supabase Dashboard atau dashboard admin |

### CI Integration (Future)

Script ini sudah CI-ready. Untuk integrasi dengan GitHub Actions / GitLab CI:
```yaml
- name: Smoke test mobile API
  env:
    NEXT_PUBLIC_SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
    SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
  run: |
    npm run dev &
    sleep 10
    npm run test:smoke
```

---

## Convention untuk Script Baru

Kalau menambah script baru di folder ini:

1. **File naming**: `kebab-case.mjs` (ES module) atau `.ts` (TypeScript via `tsx`)
2. **Komentar header**: tujuan + cara run + exit code semantics
3. **Idempotent**: bisa di-run berulang tanpa side-effect
4. **Always cleanup**: pakai `try-finally`, jangan tinggalkan state polluted
5. **Exit code**: `0` = success, `1` = failure (untuk CI)
6. **Tambah ke `package.json`**: `"test:xxx"` atau `"db:xxx"` namespace
7. **Update README ini**: section baru dengan coverage + cara pakai
