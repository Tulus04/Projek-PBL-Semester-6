# UI Research — Referensi Mobile UI/UX MyPresensi

> **Tujuan**: Kumpulkan referensi konkret (link aplikasi, case study, design system) yang bisa kamu **browse & evaluasi sendiri** sebelum redesign / improve UI mobile MyPresensi.
>
> **Metode riset**: Web search bertahap (Dribbble, Mobbin, Medium case studies, Material Design 3, Indonesia local fintech & HRIS apps) + cross-reference dengan style direction MyPresensi (Corporate/SaaS clean modern, Material 3, Plus Jakarta Sans + Inter, primary `#5483AD`).
>
> **Disclaimer**: Saya tidak bisa "melihat" screenshot. Dokumen ini menyajikan link konkret + analisis pattern. Evaluasi visual tetap di kamu.

---

## DAFTAR ISI

1. [Inventaris Screen Mobile MyPresensi](#1-inventaris-screen-mobile-mypresensi)
2. [Style Direction yang Sudah Established](#2-style-direction-yang-sudah-established)
3. [Referensi Per Screen](#3-referensi-per-screen)
   - 3.1 Splash & Login
   - 3.2 Home/Dashboard Mahasiswa
   - 3.3 Scan QR (Camera Viewfinder)
   - 3.4 Attendance Submit Result (Success/Failure)
   - 3.5 Face Registration (Multi-Pose Capture)
   - 3.6 Face Verification
   - 3.7 History Kehadiran (Summary + List)
   - 3.8 Notifications
   - 3.9 My Leave Requests (List + Tab Status)
   - 3.10 Submit Leave Request (Form)
   - 3.11 Profile + Danger Zone
   - 3.12 AI Chat (jika dipertahankan)
4. [Pattern Library Lintas-Screen](#4-pattern-library-lintas-screen)
5. [Design Tokens Recommendation](#5-design-tokens-recommendation)
6. [Action Items Prioritized](#6-action-items-prioritized)
7. [Daftar Referensi Lengkap](#7-daftar-referensi-lengkap)

---

## 1. Inventaris Screen Mobile MyPresensi

14 screen yang sudah ada di `mypresensi-mobile/lib/features/*/screens/`:

| # | Screen | File | Kategori | Status UI |
|---|--------|------|----------|-----------|
| 1 | Splash | `auth/screens/splash_screen.dart` | Onboarding | Belum dievaluasi |
| 2 | Login | `auth/screens/login_screen.dart` | Auth | Functional, perlu polish |
| 3 | Change Password | `auth/screens/change_password_screen.dart` | Auth | Functional |
| 4 | Home (Mahasiswa) | `home/screens/home_screen.dart` | Dashboard | Functional, dense info |
| 5 | Scan QR | `attendance/screens/scan_qr_screen.dart` | Camera | Belum dievaluasi |
| 6 | Attendance Result | `attendance/screens/attendance_result_screen.dart` | Confirmation | Functional |
| 7 | Face Registration | `face/screens/face_registration_screen.dart` | Camera/Biometric | Functional, complex flow |
| 8 | Face Verification | `face/screens/face_verification_screen.dart` | Camera/Biometric | Functional |
| 9 | History Kehadiran | `history/screens/history_screen.dart` | List + Summary | ✅ Updated 3-state |
| 10 | Notifications | `notifications/screens/notification_screen.dart` | List | ✅ Updated 3-state |
| 11 | My Leave Requests | `leave_requests/screens/my_leave_requests_screen.dart` | List + Tab | ✅ Updated 3-state |
| 12 | Submit Leave Request | `leave_requests/screens/submit_leave_request_screen.dart` | Form | Functional |
| 13 | Profile | `profile/screens/profile_screen.dart` | Account | ✅ Added hapus face button |
| 14 | AI Chat | `ai/screens/ai_chat_screen.dart` | Chat/Assistant | Optional feature |

### Gap Analysis Umum

| Gap | Dampak | Prioritas |
|-----|--------|-----------|
| Tidak ada loading skeleton untuk dashboard/home | User lihat halaman kosong saat load | 🟡 Sudah ada widget reusable, tinggal apply ke home |
| Camera UI (scan QR & face) belum punya guide visual yang jelas | User bingung posisi yang benar | 🔴 High |
| Tidak ada onboarding/permission priming sebelum request camera/location | User tolak permission tanpa konteks | 🟡 Medium |
| Form submit leave request: belum ada inline validation visual | User submit lalu baru tahu error | 🟡 Medium |
| Tidak ada celebrasi / mikro-animasi setelah submit success | User tidak dapat positive feedback | 🟢 Nice-to-have |
| Tidak ada dark mode | Tertinggal dari standar modern | 🟢 Skip untuk PBL |
| Profile menu masih satu-list, bisa dikelompokkan (akun/preferensi/privasi/danger) | Discoverability rendah | 🟡 Medium |
| Bottom navigation belum optimal (kalau ada) | Navigasi tidak intuitif | 🟡 Medium |

---

## 2. Style Direction yang Sudah Established

Dari `.windsurf/rules/03-design-and-libraries.md` + `lib/core/theme/app_colors.dart`:

| Aspek | Nilai | Catatan |
|-------|-------|---------|
| Filosofi | Formal, bersih, profesional — Corporate/SaaS | TIDAK terlihat AI-generated |
| Bahasa | Indonesia untuk UI text, Inggris untuk kode | Ramah, bukan teknis |
| Primary color | `#5483AD` (Biru Baja TRPL) | Konsisten brand |
| Status colors | success `#1A7F37`, warning `#9A6700`, danger `#CF222E`, info `#0969DA` | Material-inspired tone |
| Background | `#F4F6F8` | Off-white, gentle |
| Surface | `#FFFFFF` | Card background |
| Font heading | Plus Jakarta Sans | Bold, modern, profesional |
| Font body | Inter | Highly readable |
| Border radius | 12-16px untuk cards, 999px (full) untuk avatar | Soft rounded, bukan tajam |
| Spacing rhythm | 4 / 8 / 12 / 16 / 20 / 24 / 32 / 40 | Multiples of 4 (Material 8pt grid) |
| Elevation | Subtle border 0.5px + occasional shadow | Bukan heavy drop shadow |
| Icon style | Lucide / Material Outlined | Outline (bukan filled massa) |

**Direction tetap**: extend style ini, **JANGAN** redesign radikal.

---

## 3. Referensi Per Screen

### 3.1 Splash & Login

**State sekarang**: Functional, perlu polish micro-interaction.

**Referensi terbaik**:

| App | Akses | Insight Pattern |
|-----|-------|-----------------|
| **Jenius** (BTPN) | [Play Store](https://play.google.com/store/apps/details?id=com.btpn.dc) | Welcome screen dengan brand identity kuat, login form pakai animation halus, error state inline below field, password strength indicator. Login = NIK/email + password + biometric quick login. |
| **Livin' by Mandiri** | [Play Store](https://play.google.com/store/apps/details?id=id.bmri.livin) | Onboarding 3-screen pendek sebelum login (jelaskan value proposition). Login halaman tunggal, focus & breathing space. |
| **BRImo** | [Play Store](https://play.google.com/store/apps/details?id=id.co.bri.brimo) | Splash → input pengguna → input password (split 2 screen) — meningkatkan keyboard focus. |
| **Notion Mobile** | [Play Store](https://play.google.com/store/apps/details?id=notion.id) | Email-first login (modern pattern). Magic link option. |

**Insight pola yang bisa diadopsi**:
- ✅ **Onboarding 2-3 screen** sebelum login pertama kali (jelaskan: 3 layer presensi + privasi data). Pakai `flutter_native_splash` + animated PageView.
- ✅ **Inline validation** — error muncul di bawah field saat blur, bukan setelah submit.
- ✅ **Biometric quick login** (opsional, kalau HP support fingerprint) — pakai `local_auth` package, simpan token + flag "trust device".
- ✅ **Skeleton splash** — kalau splash > 1 detik, tampilkan logo + nama + tagline ("Presensi Politani TRPL").

**Yang TIDAK perlu**:
- ❌ Login dengan Google/Facebook (proyek internal kampus, NIM auto-provisioning saja).
- ❌ Onboarding 5+ screen (terlalu panjang untuk app yang dipakai daily).

---

### 3.2 Home / Dashboard Mahasiswa

**State sekarang**: Functional, info dense. Belum ada hierarchy yang jelas antara "primary action" vs "info display".

**Referensi terbaik**:

| App | Akses | Insight Pattern |
|-----|-------|-----------------|
| **Mekari Talenta** | [Web](https://www.talenta.co/en/features/attendance-management-software/time-attendance/) + [Play Store](https://play.google.com/store/apps/details?id=co.talenta) | DIRECT competitor MyPresensi: GPS attendance + face verification + payroll. Home: big "Check-in" button di atas, status hari ini (sudah/belum), recent activity below. |
| **Gadjian** | [Web](https://www.gadjian.com/) | HRIS Indonesia, attendance + payroll. Pattern dashboard mirip Talenta. |
| **Presensiku** | [Web](https://presensiku.id/) | Aplikasi presensi face + GPS Indonesia. Reference UI sederhana. |
| **Presence+ (Polije)** | [Pameran JTI Polije](https://pameran-jti.polije.ac.id/pameran/product/131/aplikasi-presensi-online-berbasis-mobile-dengan-face-recognition-dan-gps) | **DIRECT PEER**: aplikasi presensi mahasiswa Polije (Politeknik Negeri Jember) dengan face + GPS. Worth study karena context paling dekat dengan MyPresensi. |
| **Notion / Linear Mobile** | Play Store | Modern productivity dashboard: card hierarchy jelas, primary action FAB, secondary actions list. |
| **Sunsama** | [sunsama.com](https://www.sunsama.com/) | Daily planning app: hero "today" card, then upcoming. Vibe modern profesional. |

**Insight pola yang bisa diadopsi**:
- ✅ **Hero card "Sesi Aktif Sekarang"** di atas: kalau ada sesi yang sedang berjalan, kartu besar dengan info MK + dosen + lokasi + tombol "Scan QR" prominent. Kalau tidak ada sesi, kartu jadi "Tidak ada sesi sekarang. Sesi berikutnya: ..."
- ✅ **Quick action grid** 2x2 di bawah hero: Scan QR, Riwayat, Pengajuan Izin, Profil. Pakai Material 3 "filled card" dengan icon Lucide + label.
- ✅ **Status hari ini** — strip ringkas: "Hari ini: 2/3 sesi hadir" (jika multi sesi/hari).
- ✅ **Activity feed** 3-5 item terakhir: "10:30 — Presensi MK Algoritma berhasil" / "Kemarin — Pengajuan izin disetujui".
- ✅ **Greeting personal** — "Selamat pagi, [Nama]" dengan icon waktu (sun/moon).
- ✅ **Bottom Navigation Bar** — 4-5 tab: Home, Riwayat, Izin, Notifikasi, Profil. Pakai `NavigationBar` Material 3 (bukan `BottomNavigationBar` lama).

**Yang TIDAK perlu**:
- ❌ Chart/grafik di home (cukup di history screen dedicated).
- ❌ Banner iklan/promo (proyek internal, tidak ada monetization).
- ❌ Stories Instagram-style (tidak relevan).

**Sketsa wireframe** (text):
```
┌─────────────────────────────────────┐
│ Halo, Riki                    🔔 3 │  ← greeting + notif bell
│ Selamat siang                       │
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │ 🔵 Sesi Aktif                   │ │  ← hero card (gradient primary)
│ │ Algoritma & Pemrograman         │ │
│ │ Pak Andi · Lab Komputer 2       │ │
│ │ Dimulai 10:00 (30 menit lalu)   │ │
│ │  ┌──────────────────────────┐   │ │
│ │  │   📷 Scan QR Sekarang    │   │ │  ← CTA prominent
│ │  └──────────────────────────┘   │ │
│ └─────────────────────────────────┘ │
├─────────────────────────────────────┤
│ Aksi Cepat                          │
│ ┌──────┬──────┬──────┬──────┐       │
│ │ 📷   │ 📋   │ 📝   │ 👤   │       │  ← quick action grid 2x2
│ │ Scan │ Riwa │ Izin │ Pro- │       │
│ │  QR  │  yat │      │ fil  │       │
│ └──────┴──────┴──────┴──────┘       │
├─────────────────────────────────────┤
│ Aktivitas Terakhir          Lihat ⌄ │
│ ✅ 10:30 Presensi Algoritma berhasil│
│ ✅ Kemarin Izin disetujui Pak Andi  │
│ ⚠️ 2 hari lalu Alpa Basis Data      │
└─────────────────────────────────────┘
│ 🏠 📋 📝 🔔 👤  │  ← bottom nav 5 tab
```

---

### 3.3 Scan QR (Camera Viewfinder)

**State sekarang**: `mobile_scanner` library default, perlu polish UI guide.

**Referensi terbaik**:

| App | Akses | Insight Pattern |
|-----|-------|-----------------|
| **GoPay / GoFood scanner** | [Play Store](https://play.google.com/store/apps/details?id=com.gojek.app) | Frame guide kotak rounded di tengah, area di luar frame dim (rgba(0,0,0,0.6)), label di atas frame "Arahkan ke QR Code". Bottom: torch button + galeri upload. |
| **OVO scanner** | [Play Store](https://play.google.com/store/apps/details?id=ovo.id) | Sama: frame + dim overlay + hint. Tambah animasi line scanning vertical (visual feedback). |
| **DANA scanner** | [Play Store](https://play.google.com/store/apps/details?id=id.dana) | Frame kotak + 4 corner accent (sudut frame ada L-shape highlight primary color). |
| **Flutter Stuff QR Scanner Template** | [flutterstuff.com](https://flutterstuff.com/free-qr-code-scanner-app-ui-design/) | Template Flutter open ref untuk pola scanner viewfinder. |
| **Dribbble: QR Code Scanner gallery** | [dribbble.com/tags/qr-code-scanner](https://dribbble.com/tags/qr-code-scanner) | Banyak konsep visual: minimal/glassmorphism/dark mode. |

**Insight pola yang bisa diadopsi**:
- ✅ **Frame rounded** 250x250px di tengah (16-20px radius).
- ✅ **Overlay dim** rgba(0,0,0,0.6) di luar frame — fokus mata ke center.
- ✅ **4 corner accent** — L-shape kecil di 4 sudut frame, warna primary `#5483AD`, panjang ~20px.
- ✅ **Animated scan line** vertical bergerak naik-turun di dalam frame (Loop AnimationController duration 2 detik) — visual feedback "sedang aktif".
- ✅ **Hint text** di atas frame: "Arahkan kamera ke QR Code yang ditampilkan dosen".
- ✅ **Bottom controls**: tombol torch (toggle senter HP) + tombol "Bantuan" → bottom sheet dengan FAQ scan.
- ✅ **Success animation** singkat (200ms checkmark + haptic) saat QR terdeteksi sebelum navigate ke result screen.
- ✅ **Error UI** kalau QR bukan format MyPresensi: snackbar Indonesia "QR Code tidak valid. Pastikan kamu scan QR sesi dosen."

**Yang TIDAK perlu**:
- ❌ "Generate QR" feature (mahasiswa hanya scan, tidak generate).
- ❌ History QR yang pernah di-scan (privacy, tidak perlu).

---

### 3.4 Attendance Submit Result (Success / Failure)

**State sekarang**: Tampil hasil submit setelah scan + GPS + face. Bisa lebih dramatic + edukatif.

**Referensi terbaik**:

| App | Akses | Insight Pattern |
|-----|-------|-----------------|
| **GoPay / OVO transaction success** | Play Store | Big checkmark animation + amount + breakdown + share/done. Vibe: "kamu udah aman, transaksi tercatat". |
| **BCA mobile transfer success** | Play Store | Receipt-style: nominal hero + dari/ke + waktu + ID transaksi. Bottom: tombol Selesai (CTA primary) + Bagikan (secondary). |
| **Mobbin: Confirmation Screens** | [mobbin.com/explore/mobile/screens/confirmation](https://mobbin.com/explore/mobile/screens/confirmation) | Gallery pattern konfirmasi lintas aplikasi. |
| **Stripe / Square POS confirmation** | Play Store | Minimalist: checkmark hijau + 1 line message + return CTA. Tidak ada distraksi. |

**Insight pola yang bisa diadopsi**:
- ✅ **Hero state icon** — animated checkmark (success) atau X (failure) ukuran 80-100px di tengah atas. Pakai package `lottie` (kalau OK tambah dep) atau native `ScaleTransition`.
- ✅ **Status copy besar** Indonesia: "Presensi Berhasil!" / "Presensi Ditolak" — Plus Jakarta Sans 24-28pt bold.
- ✅ **Subtext** 1 line ramah: "Kamu tercatat HADIR di MK Algoritma" / "Lokasi kamu di luar radius kampus".
- ✅ **Breakdown card** "Detail Verifikasi" — list 3 layer:
  - ✓ QR Code: Valid (10:30 WIB)
  - ✓ Lokasi: Dalam radius (38 meter dari titik pusat)
  - ✓ Wajah: Cocok (similarity 0.87)
- ✅ **Tombol primary** "Selesai" → kembali ke home + invalidate history provider.
- ✅ **Tombol secondary** "Lihat Riwayat" → langsung ke history screen.
- ✅ **Failure path** — kalau ditolak, breakdown kasih tahu **layer mana yang gagal** + apa saran (mis. "Mendekat ke pusat kampus, lalu coba lagi").
- ✅ **Audit trail link** (opsional) — "Submit ID: ATT-2026-05-14-001234" kecil di bottom — buat dispute resolution.

**Yang TIDAK perlu**:
- ❌ Share to social media (privacy concern).
- ❌ Confetti animation berlebihan (terlalu casual untuk academic context).

---

### 3.5 Face Registration (Multi-Pose Capture)

**State sekarang**: Capture 7 frame averaging + L2 normalize. UI guide harus jelas.

**Referensi terbaik (E-KYC fintech)**:

| App | Akses | Insight Pattern |
|-----|-------|-----------------|
| **Jenius KYC face verification** | Play Store | Oval frame di tengah, hint "Posisikan wajah di dalam frame". Progress bar circular mengelilingi oval — fill saat capture progress. Hint berubah real-time: "Tahan posisi", "Sedikit lebih dekat", "Pencahayaan kurang". |
| **OVO ID verification** | Play Store | Sama pattern oval + circular progress. Tambah animasi "tilt left/right" untuk liveness check. |
| **DANA KYC** | Play Store | Step-by-step: 1) Foto KTP, 2) Selfie dengan KTP, 3) Liveness check. Each step ada illustration + instruction Indonesia jelas. |
| **Onfido / Jumio (global e-KYC)** | [Medium: Face detection ML Kit](https://medium.com/onfido-tech/face-detection-and-tracking-on-android-using-ml-kit-part-1-fbee4200d174) | Industry standard liveness: ramen-style oval frame, real-time face detection box, ML Kit landmark feedback. |
| **M2P Fintech Flutter liveness** | [m2pfintech.com blog](https://m2pfintech.com/blog/unmask-the-power-of-face-liveness-detection-integrating-google-ml-kit-into-your-flutter-app/) | **Tutorial Flutter** integrasi Google ML Kit liveness — directly applicable ke MyPresensi yang sudah pakai ML Kit. |
| **LinkedIn Advice: Facial Recognition UI** | [linkedin.com/advice/...](https://www.linkedin.com/advice/0/how-do-you-design-mobile-user-interface-facial) | Article tips desain UI face recognition. |

**Insight pola yang bisa diadopsi**:
- ✅ **Oval frame guide** di tengah viewfinder (bukan kotak). Garis 3px primary color. Outside frame dim rgba(0,0,0,0.5).
- ✅ **Circular progress** mengelilingi oval — kosong di awal, fill 0-100% saat capture 7 frame. Visual feedback progress concrete.
- ✅ **Real-time hint** di bawah oval:
  - Wajah tidak terdeteksi → "Arahkan kamera ke wajah Anda"
  - Wajah terlalu jauh → "Mendekat sedikit"
  - Wajah terlalu dekat → "Jauhkan sedikit"
  - Cahaya kurang → "Cari tempat dengan cahaya lebih baik"
  - Wajah tilt/miring → "Tegakkan kepala"
  - OK → "Tahan posisi, sedang mengambil sampel..."
- ✅ **Step indicator** kalau multi-pose: "1/3 — Lihat lurus" → "2/3 — Tilt kanan" → "3/3 — Tilt kiri". Atau single-pose lookStraight saja (sesuai BUG-010 fix di codebase).
- ✅ **Consent dialog SEBELUM masuk camera** — wajib! Sesuai rule `04-security-and-privacy.md`:
  ```
  Pendaftaran Wajah
  
  Wajah Anda akan disimpan sebagai data biometrik
  untuk verifikasi presensi. Data ini:
  • Hanya digunakan internal kampus
  • Dapat dihapus kapan saja via Profil
  • Tidak dibagikan ke pihak ketiga
  
  [Setuju & Lanjutkan]  [Batal]
  ```
- ✅ **Result screen** setelah register: checkmark + "Wajah berhasil didaftarkan" + tombol "Selesai".

**Yang TIDAK perlu**:
- ❌ Tampilkan embedding array di UI (security concern + tidak meaningful).
- ❌ Capture banyak pose (codebase pakai 7 frame averaging dari pose `lookStraight` saja — itu sudah cukup, jangan over-engineer).

---

### 3.6 Face Verification

**State sekarang**: Compare live embedding dengan stored. Threshold 0.65 default.

**Referensi terbaik**: sama dengan §3.5 (e-KYC apps).

**Insight pola yang bisa diadopsi**:
- ✅ **Sama oval frame** dengan registration, tapi label "Verifikasi Wajah" — konsistensi visual.
- ✅ **Real-time similarity score** (debug build saja, jangan production) → useful saat development tuning threshold.
- ✅ **Result feedback halus**:
  - Match (similarity ≥ threshold) → checkmark + auto-proceed ke next step (jangan modal yang harus user click).
  - No match → X + "Wajah tidak cocok. Coba lagi atau hubungi admin."
  - Retry counter — max 3 attempt, lalu fall back ke OTP/manual approval.
- ✅ **Auto-capture** saat face stable + di center frame (jangan paksa user tekan tombol).

---

### 3.7 History Kehadiran (Summary + List)

**State sekarang**: ✅ Sudah update dengan 3-state widget + summary card 5-kolom (Hadir/Telat/Izin/Sakit/Alpa).

**Referensi terbaik**:

| App | Akses | Insight Pattern |
|-----|-------|-----------------|
| **BCA Mobile / Livin' transaction history** | Play Store | Card per transaksi: icon kategori + nominal + tanggal + status badge. Filter chip di atas (Semua / Pemasukan / Pengeluaran). |
| **GoPay history** | Play Store | Group by tanggal ("Hari ini", "Kemarin", "10 Mei 2026") — easier scanning. |
| **Sunsama daily review** | [sunsama.com](https://sunsama.com) | Calendar list dengan visual: dot color per status, hover detail. |
| **Mobbin: Transaction history pattern** | [mobbin.com/explore/mobile/ui-elements/chip](https://mobbin.com/explore/mobile/ui-elements/chip) | Gallery filter chip + segmented control. |
| **Medium: Transaction History UX case study** | [medium.com/.../improving-transaction-history-ux](https://medium.com/design-bootcamp/from-confusion-to-clarity-improving-transaction-history-ux-2e43f2838954) | Case study konkret improve dari confusing → clear. |
| **Ionic Design Kit transaction history** | [ionicdesignkit.com](https://ionicdesignkit.com/blog/how-to-create-a-transaction-history-screen/) | Tutorial layout transaction history. |

**Insight pola yang bisa diadopsi**:
- ✅ **Summary card hero** (sudah ada — gradient primary, persentase besar, 5 stat icon) ← keep this, sudah bagus.
- ✅ **Filter chip horizontal scrollable** di atas list: "Semua", "Hadir", "Telat", "Izin", "Sakit", "Alpa". Pakai Material 3 `FilterChip`.
- ✅ **Group by tanggal** — section header "Hari ini", "Kemarin", "Minggu ini", "Bulan Mei" untuk scanning cepat.
- ✅ **Search bar** (kalau list panjang > 50 item) — search by nama MK.
- ✅ **Tap item → detail bottom sheet** dengan info lengkap: MK + sesi + dosen + waktu submit + GPS info + face similarity + audit ID.
- ✅ **Export button** di pojok kanan atas — generate PDF history (pakai jspdf yang sudah ada di web, atau backend endpoint baru). Helpful untuk laporan beasiswa / orang tua.

**Yang TIDAK perlu**:
- ❌ Edit/delete history (mahasiswa tidak boleh ubah data attendance — tidak ada use case legitimate).
- ❌ Komentar/note per attendance (out of scope).

---

### 3.8 Notifications

**State sekarang**: ✅ Sudah update dengan 3-state widget + unread badge di AppBar.

**Referensi terbaik**:

| App | Akses | Insight Pattern |
|-----|-------|-----------------|
| **Twitter/X notification** | Play Store | Tab segment "Semua" / "Sebutan" — gabung view, easy filter. |
| **Instagram notification** | Play Store | Group by waktu: "Hari ini", "Minggu ini", "Bulan ini". Compact. |
| **Notion notification** | Play Store | Sidebar inbox dengan unread bold + read normal. Tap → context navigation. |
| **Mobbin: Notification screens** | [mobbin.com/explore/mobile/screens/notifications](https://mobbin.com/explore/mobile/screens/notifications) | Gallery pattern notifikasi. |
| **Setproduct notification UI** | [setproduct.com/blog/notifications-ui-design](https://www.setproduct.com/blog/notifications-ui-design) | Best practices article. |
| **Toptal notification design guide** | [toptal.com/designers/ux/notification-design](https://www.toptal.com/designers/ux/notification-design) | Comprehensive guide. |

**Insight pola yang bisa diadopsi**:
- ✅ **Card unread distinct** — background `primarySurface` ringan + border primary + dot indicator (sudah implementasi).
- ✅ **Group by tanggal** section header — "Hari ini", "Kemarin", "Minggu ini".
- ✅ **Swipe to mark as read** — swipe horizontal item → mark read. Pakai `Dismissible` widget.
- ✅ **Tombol "Tandai Semua Dibaca"** di AppBar action — bulk operation.
- ✅ **Tap notif → deep link** ke screen relevan:
  - Notif tentang izin disetujui → buka My Leave Requests dengan filter item itu.
  - Notif tentang sesi baru → buka home / scan QR.
- ✅ **Push notification** (opsional, butuh Firebase Cloud Messaging) — out of scope untuk PBL.

**Yang TIDAK perlu**:
- ❌ Compose notification (mahasiswa hanya receive, tidak send).
- ❌ Mute/snooze per kategori (terlalu kompleks untuk scope kampus).

---

### 3.9 My Leave Requests (List + Status Tab)

**State sekarang**: ✅ Sudah update dengan 3-state widget + summary 3-kolom (Menunggu / Disetujui / Ditolak) + FAB Ajukan.

**Referensi terbaik**:

| App | Akses | Insight Pattern |
|-----|-------|-----------------|
| **Mekari Talenta leave module** | [talenta.co](https://www.talenta.co/) | DIRECT competitor pattern: list pengajuan dengan badge status + tab filter (Pending/Approved/Rejected). |
| **GoLeave (case study)** | [medium.com/.../ui-ux-case-study-goleave](https://medium.com/design-bootcamp/ui-ux-case-study-goleave-leave-management-app-26587dce54cc) | Case study konkret Southeast Asia leave management app. |
| **LeaveBoard mobile** | [leaveboard.com/mobile](https://leaveboard.com/mobile/) | Pattern leave app simple. |
| **HR HUB leave UI** | [hrhub.app/features/leave/easy-ui-for-leave-application](https://www.hrhub.app/features/leave/easy-ui-for-leave-application) | Reference UI sederhana. |
| **Figma E-Leave template** | [figma.com/community/file/1340618107441236036](https://www.figma.com/community/file/1340618107441236036/e-leave-mobile-application-design) | Free template e-leave mobile app — bisa di-fork untuk inspirasi visual. |

**Insight pola yang bisa diadopsi**:
- ✅ **Summary 3-kolom** (sudah ada) — keep.
- ✅ **Tab segment** di atas list: "Semua" / "Menunggu" / "Disetujui" / "Ditolak" — pakai Material 3 `TabBar` + `TabBarView`.
- ✅ **Tap card → detail screen** (bukan modal): info lengkap + tombol "Batalkan Pengajuan" (kalau status masih `pending`).
- ✅ **FAB "Ajukan"** (sudah ada) — keep, position right-bottom.
- ✅ **Attachment indicator** — kalau pengajuan ada lampiran (surat dokter), icon paperclip di card.
- ✅ **Review note prominent** — kalau ditolak, alasan dosen di-highlight (sudah ada di codebase) ← keep.

---

### 3.10 Submit Leave Request (Form)

**State sekarang**: Form pilih MK, tipe (izin/sakit), tanggal, alasan.

**Referensi terbaik**:

| App | Akses | Insight Pattern |
|-----|-------|-----------------|
| **Talenta leave submit** | Play Store | Date range picker, dropdown tipe, textarea alasan + attachment upload. Validation inline. |
| **Halodoc booking** | Play Store | Form step-by-step (1/3 → 2/3 → 3/3) dengan progress indicator. Good for complex form. |
| **Material Design 3 Forms** | [m3.material.io/components/text-fields](https://m3.material.io/components/text-fields) | Best practice text field, dropdown, date picker. |
| **Setproduct form design** | [setproduct.com/blog/...](https://www.setproduct.com/) | Form best practices articles. |

**Insight pola yang bisa diadopsi**:
- ✅ **Dropdown MK** — pakai `DropdownButtonFormField` dengan list MK yang user enrolled. Show MK code + name.
- ✅ **Segmented control tipe** — "Izin" vs "Sakit" sebagai 2 button radio (bukan dropdown 2 option — too few for dropdown).
- ✅ **Date picker** — kalau sesi sudah ada di DB, **prefer "pilih dari list sesi"** ketimbang date picker bebas (biar match ke sesi yang real).
- ✅ **Textarea alasan** — min 20 karakter, max 500. Counter di bottom-right (mis. "120/500").
- ✅ **Attachment upload** (opsional untuk sakit) — surat dokter PDF/image. Pakai `file_picker` (perlu tambah dep) atau `image_picker` (sudah ada/perlu cek).
- ✅ **Inline validation** — error muncul di bawah field saat blur, bukan saat submit.
- ✅ **Submit button** disabled sampai form valid — beri visual feedback (color muted).
- ✅ **Confirmation dialog** sebelum submit — preview pengajuan + "Ajukan / Batal".

---

### 3.11 Profile + Danger Zone

**State sekarang**: ✅ Sudah update dengan tombol "Hapus Data Wajah" merah outline.

**Referensi terbaik**:

| App | Akses | Insight Pattern |
|-----|-------|-----------------|
| **Notion profile** | Play Store | Profile section dipisah: Account / Workspace / Preferences / Privacy / Account deletion. Hierarchical. |
| **Apple Settings (iOS)** | iPhone built-in | Group sections dengan header subdued. Destructive di section terakhir. |
| **Smashing Magazine: Dangerous Actions** | [smashingmagazine.com/2024/09/...](https://www.smashingmagazine.com/2024/09/how-manage-dangerous-actions-user-interfaces/) | **Highly recommended read** — pattern destructive action lengkap. |
| **Setproduct settings UI** | [setproduct.com/blog/settings-ui-design](https://www.setproduct.com/blog/settings-ui-design) | Best practices settings screen. |
| **UX Design "Designing better settings"** | [uxdesign.cc/...](https://uxdesign.cc/designing-a-better-settings-page-for-your-app-fcc32fe8c724) | Article comprehensive. |
| **Uxcel Mobile Settings Lesson** | [uxcel.com/lessons/mobile-settings-745](https://uxcel.com/lessons/mobile-settings-745) | Interactive lesson. |
| **Reddit UI Design: Red Logout Button** | [reddit.com/.../do_we_really_need_a_red_logout_button](https://www.reddit.com/r/UI_Design/comments/1pjq8n4/do_we_really_need_a_red_logout_button/) | Diskusi pro/kontra red logout. |

**Insight pola yang bisa diadopsi**:
- ✅ **Group sections** dengan header subdued (text-tertiary, uppercase, 11pt):
  1. **AKUN** — Avatar, Nama, NIM, Email (read-only kebanyakan; foto bisa edit)
  2. **PREFERENSI** — Bahasa (kalau ada multi-lang), Notifikasi push (toggle), Tema (kalau dark mode)
  3. **KEAMANAN** — Ganti password, Aktif device list (kalau implement), Audit login terakhir
  4. **PRIVASI** — Lihat data tersimpan (face hash, profile data), **Hapus data wajah** ← yang sudah ada
  5. **APLIKASI** — Versi, Pengaturan kampus (read-only: lokasi pusat, radius), Bantuan, Tentang
  6. **DANGER ZONE** (paling bawah) — Logout (orange) + Hapus akun (red, kalau implement)
- ✅ **Destructive sequencing** — Logout TIDAK perlu super-red karena reversible. **Hapus data wajah** & **Hapus akun** wajib red + 2-step dialog (sudah implementasi untuk face data).
- ✅ **"Hapus Akun" link** subtle di paling bawah danger zone (kalau implement nanti) — bukan tombol prominent. Sesuai pattern Apple: hard to find tapi accessible.
- ✅ **Avatar tap → preview/edit** modal — pakai `react-easy-crop` equivalent di Flutter, atau pakai `image_picker` + crop manual.

**Yang TIDAK perlu**:
- ❌ Banyak setting yang user tidak bisa ubah (passive info hide di "About" section).
- ❌ Social profile (Instagram/LinkedIn) untuk app akademik.

---

### 3.12 AI Chat (jika dipertahankan)

**State sekarang**: `ai_chat_screen.dart` exists — saya tidak yakin fitur ini in-scope atau eksperimen.

**Saran**: Sebelum invest UI redesign, **klarifikasi dengan user**:
- AI Chat ini untuk apa? FAQ presensi? Tanya jadwal? Help desk?
- Pakai LLM apa? (OpenAI? Claude? Lokal?)
- Apakah ini in-scope PBL atau eksperimen yang bisa dihapus?

**Kalau dipertahankan**, referensi terbaik:

| App | Akses | Insight Pattern |
|-----|-------|-----------------|
| **ChatGPT mobile** | Play Store | Chat bubble pattern standar, message status, typing indicator. |
| **Notion AI** | Play Store | AI integrated dengan content workflow. |
| **WhatsApp** | Play Store | Chat UI familiar untuk user Indonesia. |

**Yang TIDAK perlu** kalau dipertahankan:
- ❌ Voice chat (over-engineered untuk PBL).
- ❌ Image generation (off-topic untuk presensi).

---

## 4. Pattern Library Lintas-Screen

### 4.1 Cards

| Tipe Card | Use Case | Pattern |
|-----------|----------|---------|
| **Hero Card** | Home "Sesi Aktif", History "Summary" | Gradient primary, padding 20px, radius 16-20px, white text |
| **Info Card** | List items (history, notif, leave) | White surface, border 0.5px, radius 14-16px, padding 14-16px |
| **Action Card** | Quick action grid home | White surface, icon center, label below, tap ripple |
| **Status Card** | Attendance result breakdown | White surface, border + colored icon left, padding 14px |
| **Empty Card** | Already implemented as `EmptyState` widget | Icon di lingkaran primarySurface + title + desc + CTA |

**Referensi**: [Material 3 Cards](https://m3.material.io/components/cards/guidelines).

### 4.2 Lists

- ✅ **Vertical list** dengan separator 10-12px (sudah pattern di codebase).
- ✅ **Pull-to-refresh** mandatory untuk list yang fetch network data (sudah implementasi).
- ✅ **Infinite scroll** (kalau list bisa > 100 item) — tidak perlu untuk PBL scale (1 semester history ~40 sesi max).
- ✅ **Group header** ("Hari ini", "Kemarin", "Minggu lalu") — improve scanning.
- ✅ **Sticky header** (kalau pakai group) — pakai `SliverPersistentHeader`.

### 4.3 Empty State (✅ Already Implemented)

Reference: [Eleken Empty State](https://www.eleken.co/blog-posts/empty-state-ux) + [Mockplus Empty State Examples](https://www.mockplus.com/blog/post/empty-state-ui-design).

Pattern: Icon di lingkaran color subdued + judul 1 baris + description 1-2 baris + CTA optional.

### 4.4 Skeleton Loading (✅ Already Implemented)

Reference: Material 3 + bawaan codebase `LoadingSkeleton`/`ListItemSkeleton`/`ListLoadingPlaceholder`.

Pattern: Animated pulse via `AnimatedBuilder` + `Color.lerp` — JANGAN tambah library `shimmer` (over-engineered).

### 4.5 Error State (✅ Already Implemented)

Pattern: Icon di lingkaran danger + judul + message ramah Indonesia + "Coba Lagi" button.

### 4.6 Modal & Dialog

- ✅ **Confirmation 1-step** untuk reversible actions (toggle setting): `AlertDialog` standar.
- ✅ **Confirmation 2-step** untuk destructive (hapus face, hapus akun): edukasi konsekuensi → konfirmasi destructive button red. **Sudah implementasi** di Profile screen.
- ✅ **Bottom sheet** untuk detail / picker — lebih native feel daripada modal di atas.
- ✅ **JANGAN** pakai `window.alert()` equivalent (mobile: skip native alert untuk konsistensi style).

### 4.7 Badge & Chip

| Tipe | Use Case | Style |
|------|----------|-------|
| **Status badge** | Hadir/Telat/Izin/Sakit/Alpa di history | Rounded 8px, padding 4x10px, bg colored 10% alpha, text colored 100% |
| **Unread badge** | Notifications | Dot 8px primary color |
| **Count badge** | "3 baru" di notification AppBar | Pill rounded full, bg danger, text white |
| **Filter chip** | History filter | Material 3 `FilterChip` selectable |
| **Type chip** | Leave request type "Izin"/"Sakit" | Outlined, icon left, color brand |

### 4.8 Forms

- ✅ **Material 3 outlined text fields** — pakai default, sudah cukup bagus.
- ✅ **Inline validation** — `validator: (v) => ...` return error message Indonesia. Show on blur, not on submit.
- ✅ **Helper text** di bawah field saat normal — explain format expected.
- ✅ **Counter** untuk textarea — kanan bawah.
- ✅ **Submit button full width** di bottom — habit mobile user.

### 4.9 Bottom Navigation

- ✅ **Material 3 `NavigationBar`** (bukan `BottomNavigationBar` lama) — wider tap area, label always visible, smooth indicator animation.
- ✅ **3-5 tab max** — lebih dari itu cluttered.
- ✅ **Icon + label** — JANGAN icon only (accessibility).
- ✅ **Active state indicator** — pakai default Material 3 (oval background pada active).

### 4.10 Permission Priming

**Pattern**: Sebelum request permission native, tampilkan **screen edukasi** dulu yang jelaskan kenapa app butuh permission ini + benefit ke user.

Referensi: [NN Group Permission Requests](https://www.nngroup.com/articles/permission-requests/) + [Icons8 mobile permissions](https://icons8.com/blog/articles/mobile-ux-design-user-permissions/).

**Pattern wajib MyPresensi**:
1. **Camera permission** — sebelum first scan QR / face register. Screen: "MyPresensi butuh akses kamera untuk scan QR sesi dan verifikasi wajah. Data foto tidak disimpan, hanya hash matematika untuk perbandingan."
2. **Location permission** — sebelum first submit attendance. Screen: "MyPresensi butuh akses lokasi untuk memastikan kamu di area kampus. Lokasi hanya dicatat saat presensi, tidak terus-menerus."

**JANGAN** langsung trigger system permission tanpa context — user akan tolak dan susah recovery.

---

## 5. Design Tokens Recommendation

Extend tokens yang sudah ada di `lib/core/theme/app_colors.dart`. **JANGAN ganti**, hanya **tambah** kalau perlu:

### 5.1 Color Tokens — Tambahan yang Direkomendasikan

```dart
// Tambahan untuk MyPresensi (ekstensi AppColors):

// Surface variants (untuk hierarchy)
static const Color surfaceElevated = Color(0xFFFFFFFF);  // Hero card on background
static const Color surfaceSunken = Color(0xFFF0F2F4);    // Input field background subtle

// Overlay (untuk camera dim, modal backdrop)
static const Color overlay50 = Color(0x80000000);  // 50% black
static const Color overlay60 = Color(0x99000000);  // 60% black (camera viewfinder)

// Hover/pressed state (untuk Material 3 components)
static const Color primaryPressed = Color(0xFF3A6B8F);  // = primaryDark
static const Color primaryHover   = Color(0x145483AD);   // primary 8% alpha
```

### 5.2 Typography Scale

Pakai `Theme.of(context).textTheme` Material 3 dengan custom GoogleFonts:

```dart
// Sudah ada: Plus Jakarta Sans (heading) + Inter (body)
// Recommendation scale (extend dari Material 3 default):

displayLarge:   28pt bold   Plus Jakarta Sans   // Hero "Presensi Berhasil!"
displayMedium:  24pt bold   Plus Jakarta Sans   // Section "Selamat pagi, Riki"
displaySmall:   20pt bold   Plus Jakarta Sans   // Card header

titleLarge:     18pt w700   Plus Jakarta Sans   // Page title
titleMedium:    16pt w600   Plus Jakarta Sans   // Card title
titleSmall:     14pt w600   Inter              // Section label

bodyLarge:      15pt w400   Inter              // Body paragraph
bodyMedium:     14pt w400   Inter              // Default body (most common)
bodySmall:      13pt w400   Inter              // Sub text, captions

labelLarge:     14pt w600   Inter              // Button text
labelMedium:    12pt w500   Inter              // Chip/badge
labelSmall:     11pt w500   Inter              // Caption, timestamp
```

### 5.3 Spacing Scale (Material 8pt Grid)

```dart
class Spacing {
  static const double xs  = 4;   // Inline gap, tight grouping
  static const double sm  = 8;   // Sub-section gap
  static const double md  = 12;  // Card internal padding (compact)
  static const double lg  = 16;  // Card padding (standard)
  static const double xl  = 20;  // Card padding (hero)
  static const double xxl = 24;  // Section gap
  static const double xxxl = 32; // Page padding top/bottom
}
```

### 5.4 Border Radius

```dart
class Radius {
  static const double sm  = 8;   // Chip, badge
  static const double md  = 12;  // Button, input field
  static const double lg  = 14;  // Card standard
  static const double xl  = 16;  // Card hero
  static const double xxl = 20;  // Hero card large
  static const double full = 999; // Pill, avatar
}
```

### 5.5 Elevation / Shadow

Minimal shadow (Corporate style — bukan playful):

```dart
// Card subtle (tidak floating, just separation)
BoxShadow(
  color: AppColors.primary.withValues(alpha: 0.04),
  blurRadius: 8,
  offset: const Offset(0, 2),
)

// Card hero (slight float)
BoxShadow(
  color: AppColors.primary.withValues(alpha: 0.12),
  blurRadius: 16,
  offset: const Offset(0, 4),
)

// FAB
BoxShadow(
  color: AppColors.primary.withValues(alpha: 0.25),
  blurRadius: 12,
  offset: const Offset(0, 4),
)
```

---

## 6. Action Items Prioritized

### 🔴 High Priority (sebelum smoke test e2e)

1. **Camera UI untuk Scan QR** — frame guide + corner accent + animated scan line + hint Indonesia. Improve visual instruction agar mahasiswa langsung tahu cara pakai. File: `lib/features/attendance/screens/scan_qr_screen.dart`.

2. **Camera UI untuk Face Register/Verify** — oval frame + circular progress + real-time hint. Crucial karena user pertama kali akan struggle kalau UI guide tidak jelas. File: `lib/features/face/screens/face_registration_screen.dart` + `face_verification_screen.dart`.

3. **Consent dialog face register** — wajib menurut UU PDP + rule `04-security-and-privacy.md`. Pattern 2-step persetujuan sebelum first capture.

4. **Permission priming screen** untuk camera & location — sebelum trigger system permission. Pasti meningkatkan acceptance rate.

5. **Attendance result screen** — hero icon animated + breakdown 3-layer (QR/GPS/Face) + Indonesian copy ramah. Saat ini terlalu plain.

### 🟡 Medium Priority

6. **Home redesign**: hero "Sesi Aktif" card + quick action grid 2x2 + activity feed 3-5 item. Saat ini info dense.

7. **Bottom Navigation Material 3** — kalau belum pakai `NavigationBar`, migrasi. 4-5 tab: Home / Riwayat / Izin / Notif / Profil.

8. **History filter chips** — "Semua/Hadir/Telat/Izin/Sakit/Alpa" + group by tanggal.

9. **Profile section grouping** — pecah jadi Akun/Preferensi/Keamanan/Privasi/Aplikasi/Danger Zone.

10. **Onboarding 2-screen** sebelum first login — jelaskan value proposition + privacy (1x show, simpan flag di SecureStorage).

### 🟢 Nice-to-Have (skip kalau scope ketat)

11. **Skeleton di home dashboard** — saat ini home kalau loading mungkin masih CircularProgressIndicator.

12. **Pull-to-refresh haptic feedback** — `HapticFeedback.mediumImpact()` saat refresh trigger.

13. **Submit success micro-animation** — `lottie` package (perlu tambah dep) atau native scale.

14. **Tap notif → deep link** ke screen relevan.

15. **Klarifikasi AI Chat scope** — kalau out-of-scope, hapus untuk reduce APK size.

---

## 7. Daftar Referensi Lengkap

### 7.1 Aplikasi Indonesia (Konteks Lokal)

**Fintech / Banking** (UI quality benchmark Indonesia):
- Jenius — [play.google.com/store/apps/details?id=com.btpn.dc](https://play.google.com/store/apps/details?id=com.btpn.dc)
- Livin' by Mandiri — [play.google.com/store/apps/details?id=id.bmri.livin](https://play.google.com/store/apps/details?id=id.bmri.livin)
- BCA mobile — [play.google.com/store/apps/details?id=com.bca](https://play.google.com/store/apps/details?id=com.bca)
- BRImo — [play.google.com/store/apps/details?id=id.co.bri.brimo](https://play.google.com/store/apps/details?id=id.co.bri.brimo)
- DANA — [play.google.com/store/apps/details?id=id.dana](https://play.google.com/store/apps/details?id=id.dana)
- OVO — [play.google.com/store/apps/details?id=ovo.id](https://play.google.com/store/apps/details?id=ovo.id)
- GoPay (di Gojek app) — [play.google.com/store/apps/details?id=com.gojek.app](https://play.google.com/store/apps/details?id=com.gojek.app)

**HRIS / Attendance** (direct competitor pattern):
- Mekari Talenta — [talenta.co/en/features/attendance-management-software/time-attendance](https://www.talenta.co/en/features/attendance-management-software/time-attendance/)
- Gadjian — [gadjian.com](https://www.gadjian.com/)
- Presensiku — [presensiku.id](https://presensiku.id/)
- Presence+ (Polije) — [pameran-jti.polije.ac.id/pameran/product/131](https://pameran-jti.polije.ac.id/pameran/product/131/aplikasi-presensi-online-berbasis-mobile-dengan-face-recognition-dan-gps) — **DIRECT PEER**

**Education**:
- Ruangguru — Play Store
- Quipper — Play Store
- (Kampus apps biasanya internal, tidak bisa diakses publik)

**Government / KYC**:
- Peduli Lindungi (legacy SatuSehat) — Play Store
- JAKI Jakarta — Play Store
- Halodoc — Play Store (KYC + booking)

### 7.2 Aplikasi Global

**Fintech**:
- Revolut, Monzo, N26 (Eropa)
- Cash App, Venmo, Wise (US)
- Wealthfront, Robinhood

**Productivity**:
- Notion — [notion.so](https://www.notion.so/)
- Linear — [linear.app](https://linear.app/)
- Sunsama — [sunsama.com](https://www.sunsama.com/)

**HRIS Global**:
- Workday Mobile
- Darwinbox
- BambooHR

### 7.3 Case Studies & Articles

- [Eleken: 15 Trusted Fintech UI Examples](https://www.eleken.co/blog-posts/trusted-fintech-ui-examples)
- [Procreator: 10 Fintech UX Best Practices 2026](https://procreator.design/blog/best-fintech-ux-practices-for-mobile-apps/)
- [Intisoftware: Review UI/UX M-BCA vs Livin' vs BRImo](https://www.intisoftware.com/blog/insights-2/yuk-review-ui-ux-m-bca-vs-livin-vs-brimo-24)
- [Medium: GoLeave UI/UX Case Study](https://medium.com/design-bootcamp/ui-ux-case-study-goleave-leave-management-app-26587dce54cc)
- [Medium: Improving Transaction History UX](https://medium.com/design-bootcamp/from-confusion-to-clarity-improving-transaction-history-ux-2e43f2838954)
- [Medium: Face Detection ML Kit Android (Onfido)](https://medium.com/onfido-tech/face-detection-and-tracking-on-android-using-ml-kit-part-1-fbee4200d174)
- [M2P Fintech: Liveness Detection ML Kit Flutter](https://m2pfintech.com/blog/unmask-the-power-of-face-liveness-detection-integrating-google-ml-kit-into-your-flutter-app/)
- [LinkedIn Advice: Facial Recognition Mobile UI](https://www.linkedin.com/advice/0/how-do-you-design-mobile-user-interface-facial)
- [Smashing Magazine: Managing Dangerous Actions](https://www.smashingmagazine.com/2024/09/how-manage-dangerous-actions-user-interfaces/)
- [Setproduct: Notifications UI Design](https://www.setproduct.com/blog/notifications-ui-design)
- [Setproduct: App Settings UI Design](https://www.setproduct.com/blog/settings-ui-design)
- [Toptal: Notification Design Guide](https://www.toptal.com/designers/ux/notification-design)
- [UX Magazine: Designing Notifications for Apps](https://uxmag.com/articles/designing-notifications-for-apps)
- [NN Group: Permission Request Design](https://www.nngroup.com/articles/permission-requests/)
- [Icons8: Mobile UX Permission Patterns](https://icons8.com/blog/articles/mobile-ux-design-user-permissions/)
- [UserOnboard: Permission Priming](https://www.useronboard.com/onboarding-ux-patterns/permission-priming/)
- [Blush: Empty States Secret Sauce](https://blush.design/blog/post/empty-states)
- [Eleken: Empty State UX](https://www.eleken.co/blog-posts/empty-state-ux)
- [Mockplus: 25 Empty State Examples](https://www.mockplus.com/blog/post/empty-state-ui-design)
- [UXPin: Empty States Best Practices](https://www.uxpin.com/studio/blog/ux-best-practices-designing-the-overlooked-empty-states/)
- [UX Design CC: Designing Better Settings](https://uxdesign.cc/designing-a-better-settings-page-for-your-app-fcc32fe8c724)
- [Ionic Design Kit: Transaction History](https://ionicdesignkit.com/blog/how-to-create-a-transaction-history-screen/)
- [Appricot Soft: Banking Transaction History Design](https://appricotsoft.com/blog/mobile-banking-app-development-how-to-design-transaction-history-that-users-actually-trust/)

### 7.4 Design System Official

- [Material Design 3](https://m3.material.io/) — primary reference (MyPresensi pakai Material 3 base)
- [Material 3 Cards](https://m3.material.io/components/cards/guidelines)
- [Material 3 Components Overview](https://m3.material.io/components)
- [Material 3 Text Fields](https://m3.material.io/components/text-fields)
- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines) — cross-reference
- [PatternFly Notification Badge Guideline](https://www.patternfly.org/components/notification-badge/design-guidelines/)
- [Android Developers: Material Mobile Components](https://developer.android.com/design/ui/mobile/guides/components/material-overview)

### 7.5 Inspiration Galleries (Visual Browse)

- **Mobbin** — [mobbin.com](https://mobbin.com/) (paywalled tapi punya gallery free terbatas)
  - [Confirmation screens](https://mobbin.com/explore/mobile/screens/confirmation)
  - [Permission screens](https://mobbin.com/explore/mobile/screens/permission)
  - [Notification screens](https://mobbin.com/explore/mobile/screens/notifications)
  - [Chip UI elements](https://mobbin.com/explore/mobile/ui-elements/chip)
- **Dribbble** — [dribbble.com](https://dribbble.com)
  - [QR Code Scanner](https://dribbble.com/tags/qr-code-scanner)
  - [QR Scanner](https://dribbble.com/tags/qr-scanner)
  - [Attendance App](https://dribbble.com/tags/attendance)
  - [Fintech Mobile](https://dribbble.com/tags/fintech_mobile)
- **Behance** — [behance.net](https://www.behance.net/) — case studies lebih panjang
- **Pinterest** — [Fintech App UI Design](https://www.pinterest.com/ideas/fintech-app-ui-design/959565140021/), [Attendance App UI](https://www.pinterest.com/ideas/attendance-app-ui-design/897636574853/)
- **Figma Community** — [figma.com/community](https://www.figma.com/community)
  - [Finance mobile apps](https://www.figma.com/community/mobile-apps/finance)
  - [E-Leave Mobile App Template](https://www.figma.com/community/file/1340618107441236036/e-leave-mobile-application-design)

### 7.6 Flutter-Specific

- [Flutter Stuff: QR Scanner UI Template](https://flutterstuff.com/free-qr-code-scanner-app-ui-design/)
- [Medium: Robust Face Recognition App Flutter](https://medium.com/@apoorv-gehlot/robust-face-recognition-app-development-a-step-by-step-guide-5c0fb2e21981)
- Material 3 Flutter docs — [docs.flutter.dev](https://docs.flutter.dev/release/breaking-changes/material-3-default)

---

## 8. Cara Pakai Dokumen Ini

1. **Browse referensi** — buka link di HP/laptop, screenshot bagian yang menarik.
2. **Prioritize** — pakai §6 Action Items sebagai roadmap improvement.
3. **Iterate** — implement 1-2 screen sekaligus, test di HP fisik, gather feedback.
4. **Update dokumen** — kalau temuan baru, append section "Update YYYY-MM-DD".

**Catatan untuk AI agent (Cascade)**:
- Sebelum redesign screen, **WAJIB** baca section §3 yang relevan + §5 design tokens.
- Pertahankan **style direction §2** — JANGAN redesign radikal.
- Action items §6 priority order — **mulai dari High** dulu sebelum Medium.
- Verifikasi setelah implement: `flutter analyze` + screenshot 3-state (loading/empty/error) untuk dokumentasi.

---

**Last updated**: 2026-05-15 (initial version, hasil riset komprehensif dari user request).
**Next review**: Setelah implement action items §6 High Priority, atau kalau ada gap baru ditemukan saat field test.
