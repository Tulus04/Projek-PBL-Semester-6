---
inclusion: manual
description: Root Cause Analysis (RCA) sistematis 4-fase untuk bug atau perilaku unexpected. Pakai saat menemukan bug yang tidak jelas penyebabnya, atau ketika fix-fix sebelumnya gagal.
---

# /debug-rca — Root Cause Analysis 4 Fase

Workflow ini memaksa proses debugging sistematis daripada tebak-tebakan. Berdasarkan disiplin dari `02-quality-debugging-verification.md`.

## Kapan pakai workflow ini?

- Bug muncul tapi tidak jelas dari mana
- Fix sebelumnya tidak menyelesaikan masalah, malah memunculkan masalah baru
- Test failing dan tidak jelas test atau kodenya yang salah
- Behavior production beda dengan dev — tidak bisa reproduce
- Sudah 2+ kali coba fix dan masih gagal

**Iron Law**: TIDAK BOLEH usulkan fix tanpa selesaikan Fase 1-3 dulu.

## Fase 1 — Investigasi (jangan langsung fix)

### Step 1.1 — Reproduce
```
- [ ] Apa langkah pasti untuk trigger bug?
- [ ] Selalu reproducible atau intermitten?
- [ ] Reproducible di emulator? HP fisik? Browser tertentu?
- [ ] Hanya di akun tertentu? Role tertentu?
```

Catat langkah reproduce di scratchpad atau `dev-log.md`. Ini wajib karena tanpa repro stabil, tidak bisa tahu fix berhasil.

### Step 1.2 — Baca Error Lengkap
Jangan skip stack trace. Baca SEMUA. Kalau panjang, baca akhir dulu (caused-by) lalu naik ke origin.

```powershell
# Web — buka DevTools console + Network tab
# Mobile — flutter run output + DevTools (tekan 'v')

# Logcat untuk error native (ML Kit, TFLite, native crash)
adb logcat -s flutter:I MlKitFaceDetection:V tflite:V Geolocator:I AndroidRuntime:E
```

### Step 1.3 — Cek Perubahan Terakhir
```powershell
# Apa yang berubah baru-baru ini?
git log --oneline -n 20

# Diff sejak commit terakhir yang stable
git diff <last-stable-commit>..HEAD

# File mana yang sering disentuh?
git log --pretty=format: --name-only --since="3 days ago" | sort | Get-Unique -Count | Sort-Object -Descending
```

### Step 1.4 — Tambah Log di Boundary
Untuk sistem multi-komponen (mobile → API → DB), log diagnostik di SETIAP boundary SEBELUM ubah logic:

```dart
// Mobile — sebelum kirim
debugPrint('[ATTENDANCE] Submit payload: ${jsonEncode(req.toJson())}')

// Mobile — saat terima response
debugPrint('[ATTENDANCE] Response status: ${response.statusCode}, body: ${response.data}')
```

```ts
// Server — di awal handler
console.log('[ATTENDANCE] Body received:', JSON.stringify(body))

// Sebelum & sesudah query DB
console.log('[ATTENDANCE] Insert payload:', insertPayload)
const { data, error } = await supabase.from('attendances').insert(insertPayload)
console.log('[ATTENDANCE] Insert result:', { data, error })
```

```sql
-- DB — kalau RLS dicurigai, test policy manual
SET ROLE authenticated;
SET request.jwt.claim.sub = '<user-uuid>';
SELECT * FROM attendances WHERE session_id = '<session-uuid>';
```

### Step 1.5 — Trace Data Flow
Mulai dari titik error, **trace ke hulu** sampai ketemu sumber nilai buruk. Tanyakan untuk setiap variabel:
- Dari mana datangnya?
- Kapan di-set?
- Siapa yang bisa modify?
- Asumsi tipe / shape — apakah benar?

## Fase 2 — Analisis Pola

### Step 2.1 — Cari Yang Berfungsi
Cari fitur serupa yang **berjalan benar**. Misal bug di `attendanceSubmitAction` → cari `leaveRequestSubmitAction` yang strukturnya sama.

### Step 2.2 — Bandingkan Struktur
Buat tabel mental (atau di scratchpad):

| Aspek | Yang berfungsi | Yang rusak |
|-------|----------------|------------|
| Struktur folder | `app/.../foo/` | `app/.../bar/` |
| Imports | `requireRole` + `createAdminClient` | `createAdminClient` saja ❌ |
| Validasi | Zod safeParse | Manual if-else ❌ |
| Mutation | `.insert(..., { returning: 'minimal' })` | `.insert(...)` |
| Audit | `await logAudit({...})` | (tidak ada) ❌ |
| Revalidate | `revalidatePath('/foo')` | (tidak ada) ❌ |

Setiap perbedaan = hipotesis potensial.

### Step 2.3 — List Asumsi
Apa yang diasumsikan kode? Apakah asumsi itu benar?
- "GPS pasti ada" — apa kalau permission denied?
- "Session masih aktif" — apa kalau dosen klik stop saat user submit?
- "Embedding format float[192]" — apa kalau corrupt di DB?

## Fase 3 — Hipotesis & Test

### Step 3.1 — Bentuk Satu Hipotesis
Format: **"Saya pikir [X] adalah root cause karena [Y]. Kalau saya ubah [Z], hasilnya akan [W]."**

Contoh:
> "Saya pikir `Dio` di-cache sebagai field di repository adalah root cause-nya, karena saat logout `DioClient.reset()` dipanggil tapi repository masih pegang instance lama. Kalau saya ubah field jadi getter `Dio get _dio => DioClient.instance`, request setelah re-login akan pakai instance baru dengan token baru."

### Step 3.2 — Test Minimal
Buat perubahan **paling kecil** untuk test hipotesis. Satu variabel saja.

### Step 3.3 — Verifikasi
- Reproduce langkah dari Fase 1.1 → bug masih muncul?
- Test boundary lain → tidak ada regresi baru?
- Cek log dari Fase 1.4 → flow data sekarang bagaimana?

### Step 3.4 — Kalau Gagal
**JANGAN** stack fix di atas fix. Kembali ke Fase 1 atau Fase 2 dengan hipotesis BARU.

Sudah 3+ kali gagal? **STOP**. Pertanyakan arsitektur. Diskusi dengan user sebelum coba lagi.

## Fase 4 — Implementasi

### Step 4.1 — Failing Test (jika feasible)
Tulis test yang **gagal** karena bug ini. Setelah fix, test harus pass.
```dart
test('Dio instance harus pakai token terbaru setelah relogin', () async {
  // Simulasi: login → logout → login ulang
  // Repository call → harus pakai token baru
})
```

### Step 4.2 — Single Fix
Implementasi **satu** fix yang address root cause. Hindari sekalian-an refactor besar di sini.

### Step 4.3 — Verifikasi Akhir
- [ ] Failing test sekarang pass
- [ ] Repro langkah Fase 1.1 → bug tidak muncul
- [ ] Test lain (yang sebelumnya pass) → masih pass
- [ ] `npm run type-check` / `flutter analyze` → 0 issues
- [ ] Smoke test full flow → tidak ada regresi visual

### Step 4.4 — Hapus Log Diagnostik
Log dari Fase 1.4 yang tidak perlu di production → hapus. Sisakan log yang memang berguna untuk monitoring (mis. error rate, performance).

### Step 4.5 — Dokumentasi
Update di `dev-log.md` atau `CHANGELOG.md`:
- Bug ID baru (mis. BUG-011)
- Gejala
- Root cause
- Fix
- Cara verify

Kalau bug ini fundamental atau bisa terjadi lagi → tambah ke section "Bug History" di `02-quality-debugging-verification.md`.

## Anti-Pattern (JANGAN dilakukan)

| Anti-Pattern | Realita |
|--------------|---------|
| "Quick fix dulu, investigasi nanti" | Fix tanpa investigasi sering bikin masalah baru. RCA lebih cepat jangka panjang. |
| "Coba ubah X dan lihat apakah jalan" | Tebak-tebakan tanpa hipotesis = trial and error tidak terstruktur. |
| "Saya yakin ini fix" tanpa verifikasi | "Yakin" ≠ "berhasil". Wajib verify. |
| "Coba satu fix lagi" setelah 2+ kegagalan | Berhenti. Pertanyakan arsitektur. |
| Fix multiple isu sekaligus | Tidak bisa isolasi mana yang berhasil. Satu fix per cycle. |

## Template Output untuk User

Setelah RCA selesai, sampaikan ke user dengan format:

```markdown
## Bug: <judul singkat>

**Gejala**: <apa yang user lihat>

**Root Cause**: <satu kalimat penyebab fundamental>

**Bukti Investigasi**:
- <log/diff/observasi 1>
- <log/diff/observasi 2>

**Fix**:
- File: `<path>`
- Perubahan: <single sentence>

**Verifikasi**:
- ✅ Repro step → tidak muncul
- ✅ Type-check / analyze → 0 issues
- ✅ Test lain → tidak regresi

**Catatan untuk masa depan**: <pelajaran agar tidak terulang>
```

## Referensi

Berbasis "Systematic Debugging" dari `obra/superpowers`. Adaptasi untuk konteks MyPresensi (mobile + API + DB).
