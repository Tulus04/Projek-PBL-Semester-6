---
inclusion: always
description: Protokol penggunaan Context7 MCP sebagai sumber dokumentasi resmi sebelum menulis kode yang pakai API library/framework. Cegah halusinasi API, signature usang, dan pola deprecated.
---

# Context7 — Dokumentasi Akurat Sebelum Kode

Rule ini lahir dari masalah nyata: AI sering **berhalusinasi nama API**, pakai **signature usang**, atau menyarankan **pola yang sudah deprecated** karena mengandalkan memori training yang ketinggalan versi. MyPresensi punya **library yang dikunci dengan versi spesifik** (lihat `03-design-and-libraries.md`) — kesalahan versi = bug runtime + waktu debugging terbuang.

**Context7** menyediakan dokumentasi + contoh kode terkini per library/versi. Wajib jadi *source of truth* sebelum menulis kode yang menyentuh API eksternal.

> Tool yang tersedia: `resolve-library-id` (cari Context7 library ID) → `query-docs` (ambil dokumentasi). Selalu `resolve` dulu kecuali user sudah kasih ID format `/org/project`.

## A. Iron Law — Doc-Before-Code

**SEBELUM** menulis atau mengubah kode yang memanggil API library/framework eksternal, AI **WAJIB** konsultasi Context7 dulu — JANGAN tulis dari memori.

Klaim "ini API yang benar" tanpa cek Context7 (saat ragu) = **PELANGGARAN**.

Bahasa yang dipakai saat tidak yakin:
- ✅ "Saya cek dulu signature-nya di Context7 sebelum tulis"
- ✅ "Context7 confirm API ini untuk versi X — aman dipakai"
- ❌ "Kayaknya method-nya namanya ini" (tebakan tanpa cek)
- ❌ "Seingat saya API-nya begini" (memori usang)

## B. WAJIB Pakai Context7 — Trigger

Panggil Context7 di situasi berikut:

1. **Pakai API library yang dikunci** di `03-design-and-libraries.md` dengan cara non-trivial:
   - Web: `zod`, `@supabase/ssr`, `@supabase/supabase-js`, `recharts`, `papaparse`, `jspdf` + `jspdf-autotable`, `react-easy-crop`, `qrcode.react`, `react-dom` (`useFormState`/`useFormStatus`), `next` App Router.
   - Mobile: `flutter_riverpod`/`riverpod`, `go_router`, `dio`, `flutter_secure_storage`, `mobile_scanner`, `google_mlkit_face_detection`, `tflite_flutter`, `camera`, `geolocator`, `permission_handler`, `image`.
2. **Perilaku spesifik-versi** — API yang beda antar major version (mis. Riverpod 3.x vs 2.x, go_router 17.x, Next.js 14 App Router vs Pages Router, React 18 `useFormState` BUKAN React 19 `useActionState` → lihat BUG-004).
3. **API tidak familiar / jarang dipakai** — method, opsi config, atau parameter yang tidak yakin namanya/signature-nya.
4. **Muncul error yang berhubungan dengan pemakaian API** (method not found, deprecated warning, breaking change, type mismatch dari library).
5. **Setup/konfigurasi library** (interceptor Dio, provider Riverpod, schema Zod kompleks, config build).

## C. BOLEH Skip Context7 — Hemat Waktu

Tidak perlu panggil Context7 untuk:

1. **Logika murni / algoritma** yang tidak pakai API eksternal (Haversine, cosine similarity, format tanggal manual, validasi if-else internal).
2. **Pola yang sudah established di codebase** — kalau ada contoh yang jelas-jelas berfungsi di repo (mis. template Server Action existing, Dio singleton getter), REUSE pola itu. Pelajari dari kode existing dulu (lihat `02` Fase 2).
3. **Pertanyaan konseptual umum** ("apa itu RLS", "kapan pakai Server vs Client Component") yang tidak butuh signature persis.
4. **Edit trivial** — rename variabel, perbaikan typo, ubah string Bahasa Indonesia, formatting.
5. **API yang baru saja di-confirm Context7** di sesi yang sama dan belum berubah konteksnya.

> Prinsip: Context7 untuk **akurasi API eksternal**, bukan pengganti baca kode existing. Codebase pattern > Context7 > memori.

## D. Workflow Singkat

1. **Identify** library + versi yang relevan (cek `package.json` / `pubspec.yaml` untuk versi terkunci — jangan asumsi latest).
2. **Resolve** → `resolve-library-id` dengan nama resmi (mis. "Riverpod", "Next.js", "Supabase"). Pilih ID dengan reputasi + coverage tertinggi yang match.
3. **Query** → `query-docs` dengan pertanyaan spesifik + sebut versi kalau perlu (mis. "go_router 17 ShellRoute with refreshListenable").
4. **Verify** terhadap versi terkunci — kalau Context7 kasih contoh versi beda, sesuaikan ke versi proyek.
5. **Tulis kode** berdasarkan hasil, lalu jalankan verifikasi (`npm run type-check` / `flutter analyze`) per rule `02` + `06`.

## E. Interaksi dengan Rule Lain

| Rule | Hubungan |
|------|----------|
| `02-quality-debugging-verification.md` | Context7 = input akurasi SEBELUM tulis; rule 02 = verifikasi SETELAH tulis. Keduanya wajib. |
| `03-design-and-libraries.md` | Daftar library terkunci = daftar prioritas yang WAJIB di-cross-check via Context7. Context7 TIDAK mengizinkan ganti library — lock tetap berlaku. |
| `06-runtime-verification.md` | Context7 kurangi risk API mismatch (salah satu sumber crash runtime yang disebut rule 06). |

## F. Anti-Pattern

- ❌ Tulis kode pakai API library dari memori lalu "lihat apakah jalan" (tebak-tebakan, dilarang rule 02).
- ❌ Pakai Context7 tapi abaikan versi terkunci proyek (contoh latest belum tentu cocok versi terpasang).
- ❌ Panggil Context7 untuk hal trivial sampai memperlambat kerja tanpa nilai tambah.
- ❌ Anggap Context7 menggantikan pembacaan kode existing — pattern di repo tetap rujukan pertama.
- ❌ Klaim API benar tanpa cek padahal ragu, lalu salah versi/signature.

## G. Update History

| Tanggal | Versi | Perubahan |
|---------|-------|-----------|
| 2026-05-31 | v1 | Rule lahir untuk paksa konsultasi Context7 sebelum tulis kode API eksternal. Iron Law doc-before-code + trigger wajib/skip + workflow + cross-ref rule 02/03/06. |
