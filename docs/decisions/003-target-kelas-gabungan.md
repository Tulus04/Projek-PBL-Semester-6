# Keputusan Desain: Multi-select Target Kelas untuk Kelas Gabungan

## Status
**DISETUJUI** (13 Juni 2026)

## Konteks
Saat dosen memulai sesi presensi, dosen harus memilih kelas target (contoh: "Kelas 6A", "Kelas 6B"). Saat ini, kolom `target_kelas` disimpan sebagai string tunggal pada tabel `sessions` di database.
Namun, terdapat kondisi riil di kampus di mana sebuah mata kuliah diselenggarakan secara bersamaan untuk kelas gabungan (misal gabungan Kelas A dan Kelas B pada jam yang sama).

## Keputusan
Untuk mengakomodasi kelas gabungan, antarmuka pemilihan kelas target saat pembuatan sesi oleh dosen harus diubah dari **dropdown pilihan tunggal** menjadi **checklist (multi-select / checkbox group)**.

### Implikasi Teknis & Implementasi:

1. **Struktur Database (Supabase):**
   * Pilihan A: Mengubah tipe kolom `target_kelas` di tabel `sessions` menjadi `text[]` (array string) atau `jsonb` agar dapat menyimpan banyak kelas (contoh: `['6A', '6B']`).
   * Pilihan B: Membuat tabel relasi many-to-many baru `session_target_classes (session_id, target_kelas)`.
   * *Rekomendasi*: Menggunakan tipe data array (`text[]`) pada kolom `target_kelas` di tabel `sessions` karena lebih ringkas dan meminimalisir penambahan join query yang rumit di API.

2. **Backend API (`mypresensi-web`):**
   * Endpoint verifikasi presensi (`/api/mobile/attendance/verify-qr` dan `/api/mobile/attendance/submit`) wajib diperbarui untuk mencocokkan kelas mahasiswa (misal kelas mahasiswa adalah "6A") dengan array target kelas sesi (`target_kelas` array).
   * Validasi kecocokan akan diubah dari:
     `session.target_kelas === student.kelas`
     menjadi:
     `session.target_kelas.includes(student.kelas)` (atau menggunakan pencarian array PostgreSQL `student.kelas = ANY(session.target_kelas)`).

3. **Frontend Web UI (`mypresensi-web`):**
   * Di dalam modal/form pembuatan sesi, dropdown input `Target Kelas` diganti dengan daftar checkbox (checklist) untuk kelas-kelas yang aktif.

4. **Mobile App UI (`mypresensi-mobile`):**
   * Tampilan detail sesi pada beranda mahasiswa akan disesuaikan untuk dapat menampilkan kelas gabungan (misal: "Target: Kelas 6A, 6B").

---

## Konsekuensi
* **Kompatibilitas Migrasi**: Perlu dipastikan migrasi kolom `target_kelas` dari string ke array tidak mematahkan data sesi lama yang sudah ada di database produksi.
* **Validasi API Mobile**: Validasi di API mobile harus dibuat lebih fleksibel agar dapat membaca format array/list target kelas.
