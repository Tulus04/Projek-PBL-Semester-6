---
trigger: always_on
description: Standar kualitas kode + disiplin debugging sistematis + verifikasi sebelum klaim selesai. Wajib dipatuhi tanpa pengecualian.
---

# Engineering Discipline — MyPresensi

Tiga pilar wajib: **kualitas kode**, **debugging sistematis** (root cause), **verifikasi sebelum klaim selesai**.

## A. Standar Kualitas Kode

### Wajib
1. **Setiap server action yang mutasi data** (create/update/delete/toggle) WAJIB panggil `logAudit({ action, details })` dari `@/lib/audit-logger`.
   - **Server Action (web)**: `logAudit({ action, details })` cukup — cookie session fallback ambil user_id otomatis.
   - **Route Handler mobile** (`/api/mobile/*`): WAJIB pass `userId: user.id` + `ipAddress` eksplisit. Bearer context TIDAK punya cookie, kalau lupa pass → `user_id = null` di audit_logs (lihat BUG-011).
   ```ts
   // Pattern WAJIB untuk endpoint mobile:
   const ipAddress = req.headers.get('x-forwarded-for') ?? req.headers.get('x-real-ip') ?? null
   await logAudit({
     action: 'mobile_xxx',
     userId: user.id,
     ipAddress,
     details: { /* ... */, user_agent: req.headers.get('user-agent') ?? null },
   })
   ```
2. **DRY** — tidak ada kode redundan. Setiap function punya 1 tanggung jawab.
3. **TypeScript strict** — hindari `any`. Pakai tipe dari `app/types/database.ts`. Untuk join Supabase yang sulit di-type, pakai `as unknown as Array<...>` lalu narrow.
4. **Error handling konsisten** — server action return `{ error: string|null, success: boolean, fieldErrors?: Record<string, string[]> }`. Jangan biarkan error terlempar tanpa penanganan.
5. **`createAdminClient()`** untuk operasi DB di server actions / route handler. **`createClient()`** hanya untuk auth context user (cek `auth.getUser()`).
6. **Komentar header file** — Bahasa Indonesia singkat (1-2 baris) menjelaskan lokasi + tujuan + catatan keamanan jika relevan. Contoh:
   ```ts
   // app/api/mobile/attendance/submit/route.ts
   // Endpoint submit presensi mahasiswa — 5 layer validasi + reject mock GPS.
   ```
7. **Audit action snake_case konsisten** (`create_session`, `mobile_attendance_submit`, `mock_location_detected`). Cari nama serupa di `app/lib/actions/*.ts` sebelum bikin baru.
8. **Pesan error Supabase JANGAN diteruskan mentah** ke user — sanitasi (lihat `loginAction`).

### Yang Tidak Boleh
- Memanggil `createAdminClient()` tanpa role/auth check sebelumnya.
- Lupa `revalidatePath()` setelah mutasi (UI tidak refresh).
- Hardcode URL, password, secret di kode (pakai `.env.local`).
- Tipe `any` tanpa alasan terdokumentasi.

## B. Debugging Sistematis — 4 Fase

### Iron Law
**TIDAK BOLEH** mengusulkan fix tanpa investigasi root cause. **Symptom fix = kegagalan**.

### Fase 1 — Investigasi Root Cause
SEBELUM mencoba fix:
1. Baca error message LENGKAP — jangan skip stack trace atau warning.
2. Reproduksi konsisten — apa langkah pastinya?
3. Cek perubahan terakhir — `git diff`, commit terbaru, dependency baru.
4. Untuk sistem multi-komponen (mobile → API → DB): tambahkan log diagnostik di **SETIAP boundary** SEBELUM fix.
5. Trace data flow — dari mana nilai buruk berasal? Lacak ke hulu.

### Fase 2 — Analisis Pola
1. Cari contoh yang **berfungsi** di codebase yang sama (mis. action lain yang serupa).
2. Bandingkan: apa yang berbeda antara yang jalan vs rusak?
3. List SEMUA perbedaan, sekecil apapun.
4. Pahami dependency dan asumsi yang dibuat kode.

### Fase 3 — Hipotesis & Testing
1. Bentuk **SATU** hipotesis jelas: "Saya pikir X adalah root cause karena Y".
2. Test dengan perubahan **TERKECIL** yang mungkin — satu variabel sekaligus.
3. Jika gagal → bentuk hipotesis BARU. JANGAN stack fix di atas fix.

### Fase 4 — Implementasi
1. Buat failing test case (jika memungkinkan).
2. Implementasi **SATU** fix yang address root cause.
3. Verifikasi: test pass? tidak ada test lain yang rusak?
4. Jika sudah **3+ fix gagal** → STOP. Pertanyakan arsitektur. Diskusikan dengan user sebelum mencoba lagi.

### Red Flags — STOP & Kembali ke Fase 1
- "Quick fix dulu, investigasi nanti"
- "Coba ubah X dan lihat apakah jalan"
- "Saya confident ini akan berfungsi"
- "Coba satu fix lagi" (setelah 2+ kali gagal)
- "Masalahnya simple, tidak perlu proses"

### Tabel Anti-Rasionalisasi
| Alasan | Realita |
|--------|---------|
| "Masalahnya simple" | Simple bug tetap punya root cause |
| "Darurat, tidak ada waktu" | Debugging sistematis LEBIH CEPAT dari tebak-tebakan |
| "Coba ini dulu" | Fix pertama menentukan pola kerja |
| "Fix multiple sekaligus hemat waktu" | Tidak bisa isolasi mana yang berhasil |

### Bug History MyPresensi
Bug-bug ini sudah ditemui & diperbaiki — JANGAN reintroduce:
- **BUG-001** sd **BUG-010**: lihat `dev-log.md` & `CHANGELOG.md`. Highlight: jangan pakai `useActionState` (React 19), jangan import dari `@/src/*`, jangan `window.confirm()`, jangan single-frame face embedding, jangan capture embedding di pose `turnRight`.
- **BUG-011** (2026-05-14): Audit logger pakai `createClient()` cookie-based — di endpoint mobile Bearer auth (tanpa cookie) → `user_id` null di `audit_logs`. Fix: caller mobile WAJIB pass `userId` + `ipAddress` eksplisit. Lihat rule A.1 di atas.

## C. Verifikasi Sebelum Klaim Selesai

### Iron Law
**TIDAK BOLEH** klaim "selesai" tanpa bukti verifikasi **segar**. Jika belum jalankan perintah verifikasi di pesan ini, TIDAK BOLEH klaim berhasil.

### Gate Function (urut)
1. **IDENTIFY**: Perintah apa yang membuktikan klaim ini?
2. **RUN**: Jalankan perintah LENGKAP (fresh, bukan hasil lama).
3. **READ**: Baca output penuh, cek exit code, hitung error/failure.
4. **VERIFY**: Apakah output mengkonfirmasi klaim? TIDAK → nyatakan status aktual + bukti. YA → klaim + bukti.
5. **BARU KEMUDIAN** buat klaim ke user.

### Tabel Verifikasi
| Klaim | Wajib Ada | TIDAK Cukup |
|-------|-----------|-------------|
| "Tidak ada error" | Output `npm run type-check` atau `flutter analyze`: 0 issues | "Seharusnya jalan" |
| "Build berhasil" | Output build command: exit 0 | Linter pass saja |
| "Bug sudah fix" | Test gejala asli: berhasil | "Kode sudah diubah" |
| "API berfungsi" | Curl/test response: status 200 + data benar | "Endpoint sudah dibuat" |
| "Migration jalan" | `mcp0_list_migrations` atau cek tabel di Studio | "SQL sudah ditulis" |
| "Fitur selesai" | Checklist point-by-point tercentang | "Test pass" saja |

### Perintah Verifikasi MyPresensi

**Web (Next.js)** — `cwd: mypresensi-web/`:
```powershell
npm run type-check    # TypeScript strict
npm run lint          # ESLint
npm run build         # Build penuh (untuk pre-merge)
```

**Mobile (Flutter)** — `cwd: mypresensi-mobile/`:
```powershell
flutter analyze       # Static analysis
flutter pub get       # Setelah ubah pubspec.yaml
flutter build apk --debug    # Build verifikasi (opsional, ~2 menit)
```

**Database (Supabase MCP)**:
```
mcp0_list_migrations({ project_id: '<ref>' })
mcp0_get_advisors({ project_id: '<ref>', type: 'security' })
```

### Login & Test Browser
SEBELUM login di browser/API test — WAJIB baca `mypresensi-web/.dev-accounts.md` atau `credentials-MUSTREAD.txt` untuk credential yang benar. JANGAN tebak.

### Red Flags — STOP
Jika akan menulis salah satu tanpa jalankan verifikasi:
- "Seharusnya jalan sekarang"
- "Saya yakin sudah benar"
- "Sudah selesai" / "Done!"
- "Tinggal [satu hal lagi]" tanpa verifikasi keseluruhan

## D. Prinsip Inti

Jangan shortcut verifikasi. **Jalankan perintah. Baca output. BARU klaim hasilnya.** Non-negotiable.

Root cause > symptom fix > workaround. Selalu prefer minimal upstream fix dibanding downstream patch.
