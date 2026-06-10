---
inclusion: always
description: Voice & tone copywriting MyPresensi — teks user-facing wajib manusiawi, ringkas, hangat ala super-app Indonesia (Gojek/Shopee/Tokopedia/Traveloka). Bukan teknis, bukan padat, bukan kaku.
---

# UX Writing & Voice — MyPresensi

Rule ini lahir dari masalah nyata (sesi 2026-05-31): teks onboarding + banyak screen mobile terasa **teknis, padat, dan kaku** — "Sistem absensi pintar dengan tiga lapis verifikasi — QR Code, GPS, dan Face Recognition. Khusus mahasiswa Prodi TRPL Politeknik Pertanian Negeri Samarinda." (24 kata, wrap 5 baris). User membandingkan dengan Gojek/Shopee/Tokopedia/Traveloka yang teksnya pendek, hangat, dan manusiawi.

Rule `03-design-and-libraries.md` Section A sudah cover **error/validasi/istilah user-facing** (subject+state, ringkas, jangan sebut konsep internal). Rule `09` ini memperluas ke **SEMUA teks user-facing**: judul, subjudul, body, onboarding, empty state, deskripsi fitur, tombol, dialog, toast. Fokus: **voice & tone**.

> Target audiens: mahasiswa Indonesia usia ~19-22. Mereka pakai Gojek, Shopee, DANA, Tokopedia tiap hari. Ekspektasi bahasa mereka = ramah, santai-tapi-sopan, langsung ke poin. Bukan bahasa skripsi atau manual teknis.

## A. Iron Laws — Tidak Boleh Ditawar

### Law 1: "Ngomong ke manusia, bukan ke mesin"

Setiap teks user-facing ditulis seakan menjelaskan ke teman, bukan menulis dokumentasi teknis. Hapus jargon. Mahasiswa tidak peduli "tiga lapis verifikasi" atau "Face Recognition" — mereka peduli "absen anti titip".

- ❌ "Sistem absensi pintar dengan tiga lapis verifikasi — QR Code, GPS, dan Face Recognition."
- ✅ "Absen jadi gampang. Scan QR, langsung tercatat."
- ❌ "Verifikasi Lokasi GPS dengan radius geofence yang ditentukan dosen."
- ✅ "Pastikan kamu ada di kelas saat absen."

### Law 2: "Pendek itu sopan"

Hormati waktu user. Teks panjang = beban baca. Patokan keras:
- **Judul**: ≤ 5 kata.
- **Subjudul / body onboarding**: ≤ 12 kata, idealnya muat **1-2 baris** (jangan 5 baris).
- **Deskripsi fitur / item list**: ≤ 8 kata, 1 baris.
- **Empty state pesan**: 1 kalimat pendek + 1 CTA.
- **Tombol**: 1-3 kata.

Kalau perlu lebih panjang → pecah jadi poin, atau buang yang tidak esensial. JANGAN paksa kalimat majemuk panjang.

### Law 3: "Pakai 'kamu', bukan 'Anda' atau pasif"

MyPresensi mobile = aplikasi mahasiswa. Sapaan **"kamu"** (akrab, sopan) — konsisten dengan Gojek/Tokopedia. JANGAN "Anda" (terlalu formal/korporat) dan JANGAN kalimat pasif kaku.

- ❌ "Pengguna diharuskan untuk melakukan verifikasi wajah."
- ✅ "Yuk, daftarkan wajah kamu dulu."
- Catatan: Web admin/dosen BOLEH "Anda" (audiens profesional). Mobile mahasiswa = "kamu".

### Law 4: "Jangan menakut-nakuti, jangan menggurui"

Tone hangat & positif. Hindari bahasa yang bikin user merasa salah, diawasi, atau bodoh.

- ❌ "Anda gagal melakukan absensi karena lokasi tidak valid."
- ✅ "Sepertinya kamu di luar area kelas. Coba lagi ya."
- ❌ "Sistem mendeteksi GPS palsu. Presensi ditolak." (menuduh)
- ✅ "Lokasi belum bisa dipastikan. Coba aktifkan ulang GPS." (saat applicable)

## B. Voice Principles — Karakter MyPresensi

Empat sifat suara (mirip brand voice Gojek/Tokopedia):

1. **Ramah** — seperti teman yang membantu, bukan petugas. Boleh "Yuk", "ya", "kok", secukupnya (jangan lebay).
2. **Ringkas** — to the point. Satu ide per kalimat.
3. **Jelas** — bahasa sehari-hari. Kata yang dimengerti tanpa mikir.
4. **Tenang** — tidak panik, tidak menyalahkan. Bahkan saat error.

Spektrum: **santai tapi tetap sopan**. Bukan formal-kaku (skripsi), bukan terlalu gaul (alay). Patokan: bahasa caption notifikasi Gojek/Tokopedia.

## C. Tabel Transformasi — Before → After

Contoh konkret dari konteks MyPresensi:

| Lokasi | ❌ Sebelum (teknis/padat) | ✅ Sesudah (manusiawi) |
|--------|--------------------------|----------------------|
| Onboarding welcome | "Sistem absensi pintar dengan tiga lapis verifikasi — QR Code, GPS, dan Face Recognition." | "Absen kuliah jadi simpel dan anti titip." |
| Onboarding fitur QR | "Dosen tampilkan QR di kelas, kamu scan via aplikasi untuk konfirmasi sesi yang benar." | "Scan QR dari dosen buat mulai absen." |
| Onboarding fitur GPS | "Pastikan kamu benar-benar di area kampus dengan radius geofence yang ditentukan dosen." | "Pastikan kamu ada di kelas." |
| Onboarding fitur wajah | "Pastikan kamu sendiri yang absen, bukan orang lain pakai HP-mu." | "Wajah kamu, bukti kehadiran kamu." |
| Onboarding login | "Login dengan NIM dan password yang dibagikan kampus. Jika password belum kamu ganti..." | "Masuk pakai NIM dan password dari kampus." |
| Empty riwayat | "Belum ada data absensi yang tercatat dalam sistem." | "Belum ada riwayat absen. Yuk mulai absen!" |
| Empty notifikasi | "Tidak ada notifikasi untuk ditampilkan saat ini." | "Belum ada notifikasi. Tenang, kami kabari kalau ada." |
| Error sesi | "401 Unauthorized — token tidak valid." | "Sesi kamu berakhir. Masuk lagi yuk." |
| Loading | "Memuat data, harap tunggu..." | "Sebentar ya..." |

## D. Checklist Sebelum Tulis/Approve Teks User-Facing

Sebelum commit teks baru, cek:

- [ ] **Panjang**: judul ≤ 5 kata? body ≤ 12 kata? muat 1-2 baris?
- [ ] **Jargon**: ada istilah teknis (geofence, verifikasi, sistem, embedding, threshold)? → ganti bahasa awam.
- [ ] **Sapaan**: pakai "kamu" (mobile)? bukan "Anda"/pasif?
- [ ] **Tone**: ramah & tenang? tidak menuduh/menggurui?
- [ ] **Aksi jelas**: user tahu harus apa setelah baca? (terutama empty/error state)
- [ ] **Konsisten**: istilah sama dengan kamus user di rule 03 Section A (QR, wajah, lokasi, sesi, presensi)?
- [ ] **Bahasa Indonesia**: tidak campur Inggris kecuali istilah yang sudah umum (scan, QR, login).

## E. Anti-Pattern — JANGAN

- ❌ Kalimat majemuk panjang dengan tanda hubung "—" yang menjejalkan 3 konsep.
- ❌ Sebut nama lengkap institusi panjang di tempat yang butuh ringkas ("Politeknik Pertanian Negeri Samarinda" → cukup "Politani" atau taruh di tempat lain).
- ❌ Istilah teknis bocor ke UI (geofence, Face Recognition, GPS spoofing, threshold, embedding) — pakai bahasa awam.
- ❌ "Anda" / "Pengguna" / kalimat pasif di mobile mahasiswa.
- ❌ Tone menuduh saat error ("Anda terdeteksi...", "Anda gagal...").
- ❌ Teks placeholder teknis ("Loading...", "Error 500", "null").
- ❌ Berlebihan gaul/alay ("Gass absen bestie!!!") — tetap sopan.
- ❌ Judul + subtitle yang mengulang info yang sama.

## F. Interaksi dengan Rule Lain

| Rule | Hubungan |
|------|----------|
| `03-design-and-libraries.md` Section A | Sumber kamus user-facing (QR/wajah/lokasi/sesi) + aturan error/validasi ringkas. Rule 09 perluas ke SEMUA teks (judul/body/onboarding), fokus voice & tone. |
| `22-mobile-design-system.md` | Layout/visual; rule 09 = isi teksnya. Teks ringkas mendukung layout konsisten (tidak overflow). |
| `01-agent-persona.md` UX Advocate | Rule 09 implementasi konkret "pesan Bahasa Indonesia ramah, bukan teknis". |
| `08-documentation-discipline.md` | Saat audit/ubah copy, catat perubahan ke CHANGELOG (Law 2 rule 08). |

## G. Update History

| Tanggal | Versi | Perubahan |
|---------|-------|-----------|
| 2026-05-31 | v1 | Rule lahir dari feedback teks onboarding terlalu teknis/padat. 4 Iron Laws (manusiawi, pendek, "kamu", tidak menakut-nakuti) + voice principles + tabel transformasi + checklist + anti-pattern. Referensi super-app Indonesia (Gojek/Shopee/Tokopedia/Traveloka). |
