---
inclusion: always
description: Protokol dokumentasi progresif — wajib baca docs sebelum kerja/jawab, wajib catat setelah selesai. Cegah kerja ulang + klaim keliru soal status fitur.
---

# Documentation Discipline — MyPresensi

Rule ini lahir dari masalah nyata (sesi 2026-05-31 → lanjutan): user tanya "FCM sudah dikerjakan belum?", AI tidak tahu karena tidak cek dokumentasi dulu, lalu **salah klaim** "setup Firebase belum selesai" padahal `google-services.json` + `FIREBASE_SERVICE_ACCOUNT` sudah terpasang sejak sesi sebelumnya. Akar masalah: **tidak ada protokol baca-dulu + catat-sesudah**.

MyPresensi adalah proyek **progresif lintas-sesi** dengan konteks yang tersebar di banyak file markdown. AI mulai tiap sesi dengan memori kosong. Satu-satunya cara tahu "apa yang sudah dikerjakan" adalah **membaca dokumentasi yang sudah ada** — bukan menebak dari ingatan.

## A. Iron Laws — Tidak Boleh Ditawar

### Law 1: "Read-Before-Work" — Cek Dokumentasi SEBELUM Kerja/Jawab

SEBELUM mengerjakan task baru ATAU menjawab pertanyaan tentang **status/progres/keputusan** proyek, AI **WAJIB** cek sumber dokumentasi yang relevan dulu. JANGAN jawab dari ingatan/asumsi.

Trigger Law 1 (salah satu cukup):
- User tanya "apa yang sudah dikerjakan?", "ini sudah selesai belum?", "fitur X jalan tidak?"
- User minta kerjakan fitur yang mungkin sudah pernah disentuh
- User refer ke "sesi sebelumnya", "kemarin", "yang tadi"
- Akan menulis kode di area yang mungkin sudah ada implementasinya

Bahasa yang dipakai:
- ✅ "Saya cek dulu CHANGELOG + dev-log sebelum jawab status ini"
- ✅ "Berdasarkan `dev-log.md` BUG-019, fitur ini sudah di-fix di sesi 2026-05-23"
- ❌ "Seingat saya FCM belum dikerjakan" (ingatan, tanpa cek)
- ❌ "Harusnya sih belum selesai" (asumsi, tanpa bukti)

Kalau dokumentasi tidak cukup untuk memastikan → **verifikasi ke kode/file nyata** (grep, read, test path), BARU jawab. Bukti > ingatan.

### Law 2: "Record-After-Done" — Catat Dokumentasi SETELAH Selesai

SETELAH menyelesaikan unit kerja yang mengubah state proyek (tambah/ubah fitur, fix bug, migration, config, setup), AI **WAJIB** catat ke dokumentasi yang sesuai SEBELUM klaim "selesai" final.

Minimal yang wajib di-update:
1. **`CHANGELOG.md`** — entri per file yang berubah (format tabel `| Waktu | Jenis | File | Deskripsi |`, lihat rule `05` Section C).
2. **`dev-log.md`** — kalau ada bug fix / keputusan arsitektur / pelajaran (format bug retro, lihat rule `06` Section D).

Klaim "selesai" tanpa update dokumentasi (saat ada perubahan state) = **PELANGGARAN**.

### Law 3: "Doc Reflects Reality" — Dokumentasi Harus Sinkron dengan Kode

Kalau saat baca dokumentasi (Law 1) ditemukan **dokumentasi yang bertentangan dengan kode aktual** (mis. CHANGELOG bilang "belum", tapi file sudah ada), AI **WAJIB**:
1. Percaya **kode/file aktual** sebagai sumber kebenaran (bukan dokumentasi).
2. Flag diskrepansi ke user secara eksplisit.
3. Tawarkan koreksi dokumentasi supaya sinkron.

Dokumentasi usang lebih berbahaya dari tidak ada dokumentasi — bikin klaim keliru.

## B. Peta Sumber Dokumentasi — Cek yang Mana untuk Apa

| Pertanyaan / Task | Cek dokumen ini DULU |
|-------------------|----------------------|
| "Apa yang berubah baru-baru ini?" | `CHANGELOG.md` (kronologis per tanggal) |
| "Kenapa keputusan X diambil?" / "Bug Y sudah di-fix?" | `dev-log.md` (bug retro + keputusan teknis) |
| "Fitur Z statusnya gimana?" | Spec di `.kiro/specs/<fitur>/{requirements,design,tasks}.md` |
| "Setup tooling/service (Firebase, dll)?" | `docs/setup/*.md` |
| "Arsitektur / rencana besar?" | `docs/plans/implementation_plan.md`, `docs/decisions/*.md` |
| "Tech stack / struktur / migration list?" | `.kiro/steering/00-mypresensi-overview.md` |
| "Konvensi kode / pola wajib?" | `.kiro/steering/` (rule bernomor sesuai domain) |
| "Alur sistem non-teknis?" | `workflow_mypresensi.md` |

Urutan prioritas saat konflik: **Kode aktual > Spec > dev-log/CHANGELOG > steering > ingatan**.

## C. Workflow Singkat

### Saat MULAI task / MENJAWAB pertanyaan status
1. **Identify** dokumen relevan dari peta Section B.
2. **Read** (grep/read) dokumen tersebut — fokus ke bagian terkait.
3. **Verify** ke kode aktual kalau dokumentasi ambigu atau mungkin usang (Law 3).
4. **Answer/Work** berdasarkan bukti, sebut sumbernya ("berdasarkan X...").

### Saat SELESAI task
1. **Verifikasi** dulu sesuai rule `02` + `06` (type-check/analyze/build/runtime).
2. **Update `CHANGELOG.md`** — tambah entri per file (jenis + deskripsi Bahasa Indonesia).
3. **Update `dev-log.md`** kalau ada bug fix / keputusan / pelajaran.
4. **Update spec `tasks.md`** kalau kerja bagian dari spec (tandai task selesai).
5. **Update steering** kalau ada konvensi/pola baru yang lahir.
6. BARU klaim "selesai" + sebutkan dokumen apa saja yang sudah di-update.

## D. Interaksi dengan Rule Lain

| Rule | Hubungan |
|------|----------|
| `02-quality-debugging-verification.md` | Law 2 melengkapi gate verifikasi — "selesai" = verified + terdokumentasi. |
| `05-testing-and-release.md` Section C | Sumber format CHANGELOG (jenis `[ADD]/[MOD]/[FIX]/...`) — Law 2 pakai format ini. |
| `06-runtime-verification.md` Section D | Sumber format bug retro `dev-log.md` — Law 2 pakai format ini. |
| `07-context7-documentation.md` | Context7 = doc eksternal (API library); rule 08 = doc internal (state proyek). Keduanya "baca-dulu". |
| `00-mypresensi-overview.md` | Salah satu target baca Law 1 + target update kalau tech stack/migration berubah. |

## E. Anti-Pattern — JANGAN

- ❌ Jawab status fitur dari ingatan tanpa cek CHANGELOG/dev-log/kode.
- ❌ Kerjakan fitur "dari nol" tanpa cek apakah sudah ada implementasi parsial.
- ❌ Klaim "belum dikerjakan" / "sudah dikerjakan" tanpa bukti file/dokumentasi.
- ❌ Selesai task tapi tidak update CHANGELOG/dev-log — sesi berikutnya jadi buta lagi.
- ❌ Percaya dokumentasi membabi-buta padahal kode aktual bilang sebaliknya (Law 3).
- ❌ Update dokumentasi dengan klaim yang belum diverifikasi ("seharusnya jalan").

## F. Update History

| Tanggal | Versi | Perubahan |
|---------|-------|-----------|
| 2026-05-31 | v1 | Rule lahir dari insiden salah-klaim status FCM. 3 Iron Laws: Read-Before-Work, Record-After-Done, Doc-Reflects-Reality + peta sumber dokumentasi + workflow + cross-ref rule 00/02/05/06/07. |
