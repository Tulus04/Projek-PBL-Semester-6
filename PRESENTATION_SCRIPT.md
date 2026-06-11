# Naskah Presentasi Kelompok PBL: MyPresensi

> [!TIP]
> Dokumen ini dirancang sebagai panduan alur presentasi untuk Demo PBL. Terdapat petunjuk **[AKSI DEMO]** bercetak tebal yang menandakan kapan audiens harus melihat ke layar proyektor atau HP.

---

## 1. Pembukaan & Visi Produk (Tulus Arya Danendra - Product Owner)
**Waktu Estimasi:** 2 Menit

**Narasi Tulus:**
"Selamat pagi Bapak/Ibu Dosen penguji dan rekan-rekan sekalian. Kami dari Tim PBL Semester 6 akan mempresentasikan **MyPresensi**, sebuah sistem absensi mahasiswa yang dirancang untuk mengatasi masalah 'titip absen' dan meningkatkan akurasi data kehadiran di kampus.

Sistem kami menggunakan metode **Verifikasi 3 Lapis**. Lapisan pertama menggunakan QR Code Dinamis, lapisan kedua memvalidasi titik koordinat GPS, dan lapisan ketiga menggunakan *Face Recognition* (pengenalan wajah).

Proyek ini kami kembangkan selama 6 minggu menggunakan metode *Scrum*. Izinkan tim kami menjelaskan alur pengembangan dan fitur yang telah dikerjakan, dimulai dari bagian *backend*."

---

## 2. Arsitektur Database & Backend (Eza Aditya Dewangga - Backend Engineer)
**Waktu Estimasi:** 3 Menit

**Narasi Eza:**
"Terima kasih, Tulus. Saya Eza, yang bertugas merancang *Backend* dan arsitektur *database*. 
Kami menggunakan **Supabase** (PostgreSQL) sebagai *database* utama. Untuk memastikan keamanan data, kami menerapkan kebijakan *Row Level Security* (RLS) di semua tabel, sehingga mahasiswa hanya bisa mengakses data presensi milik mereka sendiri.

**[AKSI DEMO: Buka *source code* API Submission atau tunjukkan diagram validasi di *slide* presentasi]**

Di sisi server, saya merancang API yang melakukan **Validasi 6-Lapis** saat presensi masuk. API ini mengecek:
1. Status sesi kelas (aktif/tidak aktif).
2. Validitas token QR.
3. Status pendaftaran mahasiswa di kelas tersebut.
4. Jarak radius GPS mahasiswa.
5. Pengecekan indikasi penggunaan *Fake GPS*.
6. Pencocokan vektor kemiripan wajah menggunakan kalkulasi *Cosine Similarity*. 

Dengan arsitektur ini, semua proses validasi dilakukan terpusat di server agar lebih aman."

---

## 3. Sistem Web Admin & Dosen (Abdul Latif - Web Frontend Ops)
**Waktu Estimasi:** 3 Menit

**Narasi Latif:**
"Selanjutnya saya Abdul Latif. Saya bertugas mengembangkan **Web Dashboard** untuk Admin dan Dosen menggunakan *Next.js 14*. 

**[AKSI DEMO: Buka Web MyPresensi, login sebagai Admin, lalu buka halaman kelola Mahasiswa dan peragakan fitur *Import CSV*]**

Melalui web ini, Admin dapat mengelola data mahasiswa, dosen, dan mata kuliah. Untuk mempermudah penginputan data, saya menambahkan fitur *Bulk Import* dari file CSV, sehingga pendaftaran ratusan mahasiswa bisa dilakukan sekaligus.

**[AKSI DEMO: Logout dari Admin, lalu login sebagai Dosen. Buka halaman Laporan Kehadiran dan tunjukkan tabel statistik serta tombol *Export*]**

Untuk pengguna Dosen, saya merancang halaman pelaporan di mana mereka bisa memantau statistik kehadiran secara *real-time* dan mengekspor rekap absensi ke PDF atau CSV. Saya juga membuat *Dashboard At-Risk Students* untuk mengidentifikasi mahasiswa yang tingkat kehadirannya di bawah batas minimal."

---

## 4. Eksekusi Mobile & Face Recognition (Tulus Arya Danendra - Lead Mobile Developer)
**Waktu Estimasi:** 4 Menit

**Narasi Tulus:**
"Kembali ke saya. Di sisi aplikasi *Mobile*, saya menggunakan *Flutter* untuk membangun antarmuka yang dipakai mahasiswa. 

Fokus utama saya adalah mengintegrasikan model *Machine Learning* **MobileFaceNet TFLite** langsung ke dalam aplikasi. 

**[AKSI DEMO: Buka aplikasi di HP/Emulator. Buka halaman Pendaftaran Wajah (*Face Registration*), peragakan proses pemindaian wajah ke kamera]**

Sistem ini mendeteksi dan mengubah wajah mahasiswa menjadi array vektor angka (192 dimensi). Sebagai bentuk kepatuhan terhadap **UU Pelindungan Data Pribadi (UU PDP)**, kami tidak menyimpan foto wajah mahasiswa di *database*, melainkan hanya menyimpan data vektornya saja.

Selain itu, saya mengimplementasikan algoritma **GPS Haversine** untuk menghitung jarak mahasiswa ke kelas, serta sistem deteksi *Mock Location* untuk menolak secara otomatis presensi dari mahasiswa yang terdeteksi memakai *Fake GPS*."

---

## 5. User Experience & Design System (I Made Sachio Dharmayasa - UI/UX Frontend)
**Waktu Estimasi:** 3 Menit

**Narasi Sachio:**
"Halo, saya Sachio. Tugas saya di proyek ini adalah merancang **Design System** agar antarmuka di Web dan Mobile terlihat konsisten, rapi, dan mudah digunakan.

**[AKSI DEMO: Pindah layar ke Web (Akun Dosen), buka sesi presensi yang sedang berlangsung, lalu klik tombol layar penuh (*Fullscreen Projector*)]**

Di sisi *Web*, saya membuat fitur *Live Monitor* untuk dosen berupa animasi SVG *Geofence Ring*. Saat fitur proyeksi QR (*Fullscreen*) ditampilkan di kelas, dosen dapat melihat secara *real-time* nama mahasiswa yang baru saja berhasil presensi tanpa harus memuat ulang halaman. 

**[AKSI DEMO: Kembali ke layar HP. Buka fitur unggah *Avatar* di menu Profil, lalu tunjukkan cara kerja AI Chatbot Assistant di pojok web/aplikasi]**

Untuk aplikasi *Mobile*, saya membuat alur *Onboarding* bagi pengguna baru, navigasi bawah, dan fitur manajemen profil seperti unggah *Avatar*. Saya juga merancang antarmuka untuk panel AI Chatbot yang akan sangat membantu menjawab pertanyaan pengguna dengan cepat."

---

## 6. Pengujian & Penjaminan Mutu (Muhammad Mukhlis Adim - QA Engineer)
**Waktu Estimasi:** 2 Menit

**Narasi Mukhlis:**
"Saya Mukhlis, bertugas sebagai *Quality Assurance* (QA). Fokus saya adalah memastikan seluruh alur sistem berjalan sesuai harapan sebelum rilis.

Saya telah melakukan *End-to-End (E2E) Testing* dari sisi *mobile* hingga *web*. Pengujian ini mencakup pengujian batas (*edge cases*), seperti mencoba absensi menggunakan foto cetak (*print-out*) untuk mengecoh *Face Recognition*, atau menggunakan alat pengubah lokasi (*Fake GPS*). Hasilnya, sistem validasi *backend* berhasil mendeteksi dan menolak upaya tersebut secara otomatis.

Kami juga melakukan optimasi ukuran file aplikasi (*Split APK Architecture*). Hasilnya, ukuran APK final berhasil diturunkan dari 122 MB menjadi sekitar **49 MB**, sehingga sangat ringan untuk diinstal di perangkat mahasiswa masa kini."

---

## 7. Kesimpulan & Penutup (Tulus / Dosen Pembimbing)
**Waktu Estimasi:** 1 Menit

**[AKSI DEMO: Buka satu layar proyektor menampilkan QR Code kelas (Web), sementara layar sebelahnya (HP/Screencast) menampilkan mahasiswa men-*scan* QR tersebut, memindai wajah, lalu berhasil presensi secara *Live*]**

**Narasi Penutup:**
"Sebagai penutup, dalam waktu 3 *Sprint* efektif (6 minggu), tim kami telah mengimplementasikan seluruh kebutuhan menjadi *release candidate* yang utuh. 

Sistem MyPresensi ini diharapkan mampu memberikan solusi presensi yang lebih akurat, transparan, dan aman untuk digunakan di kampus kita tercinta. 

Demikian presentasi dari kelompok kami. Selanjutnya, kami mempersilakan Bapak/Ibu dosen penguji jika ingin mencoba langsung mendemonstrasikan aplikasi ini melalui HP Bapak/Ibu sekalian. Sesi tanya jawab kami buka, terima kasih."
