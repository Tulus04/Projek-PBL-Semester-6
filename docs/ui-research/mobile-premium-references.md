# UI Research — Referensi Mobile Premium Non-Presensi

> **Tujuan**: Menambahkan referensi mobile UI dari **produk premium global** (di luar ranah presensi/attendance) yang belum di-cover oleh `mobile-references.md`. File sister ini fokus pada pola yang bisa diadopsi MyPresensi mahasiswa mobile dari produk berkelas Tier-1 dunia.
>
> **Mengapa file terpisah?** `mobile-references.md` predominan ke fintech Indonesia & HRIS (Talenta, Gadjian, Jenius, BCA, dll) — domain yang dekat presensi. File ini dedicated ke produk **luar domain** dengan UI premium kelas dunia (Linear, Cash App, Things 3, Headspace, Duolingo, Spotify, Airbnb, Notion, Revolut) yang punya pelajaran transferable.
>
> **Cross-reference**: Lihat `mobile-references.md` untuk pattern per-screen MyPresensi yang sudah ada. Lihat `admin-web-references.md` untuk sisi admin/dosen web.

---

## DAFTAR ISI

1. [Mengapa Belajar dari Produk Non-Presensi](#1-mengapa-belajar-dari-produk-non-presensi)
2. [Linear Mobile — Density + Calmness](#2-linear-mobile--density--calmness)
3. [Cash App — Premium Fintech US](#3-cash-app--premium-fintech-us)
4. [Notion Mobile — Workspace First](#4-notion-mobile--workspace-first)
5. [Things 3 / Todoist — Minimalist List Master](#5-things-3--todoist--minimalist-list-master)
6. [Spotify — Library + Card Hierarchy](#6-spotify--library--card-hierarchy)
7. [Airbnb — Search + Booking Flow](#7-airbnb--search--booking-flow)
8. [Duolingo — Gamification & Onboarding](#8-duolingo--gamification--onboarding)
9. [Headspace — Wellness & Personalization](#9-headspace--wellness--personalization)
10. [Revolut — Card-based Banking Home](#10-revolut--card-based-banking-home)
11. [Pola Lintas-App yang Layak Adopsi](#11-pola-lintas-app-yang-layak-adopsi)
12. [iOS 26 + Material 3 Navigation 2025-2026](#12-ios-26--material-3-navigation-2025-2026)
13. [Action Items untuk MyPresensi Mobile](#13-action-items-untuk-mypresensi-mobile)
14. [Daftar Referensi Lengkap](#14-daftar-referensi-lengkap)

---

## 1. Mengapa Belajar dari Produk Non-Presensi

Setiap kategori produk premium punya **muscle memory pattern** yang bisa di-cherry-pick:

| Kategori | Yang dicerna untuk MyPresensi |
|----------|-------------------------------|
| **Productivity (Linear, Notion)** | Density tinggi tanpa cluttered, navigation predictable, search-first |
| **Fintech US/EU (Cash App, Revolut)** | Card hierarchy, micro-interaction premium, konfirmasi destruktif clean |
| **Minimalist tasks (Things 3, Todoist)** | List UI master, group by date, swipe action, empty state ramah |
| **Media (Spotify, Apple Music)** | Library hierarchy, card-based home, hero + grid mix |
| **Travel (Airbnb)** | Search filter, map+list toggle, booking flow multi-step |
| **Edu/Wellness (Duolingo, Headspace)** | Onboarding questionnaire, reward microinteraction, streak/progress |

MyPresensi mahasiswa adalah **daily-use app** dengan akses cepat (presensi 5 detik) + occasional deep view (riwayat, izin). Pelajaran dari produk-produk di atas: optimasi untuk **task completion cepat** sambil tetap **profesional & terpercaya**.

---

## 2. Linear Mobile — Density + Calmness

### 2.1 Akses & Konteks
- App: [linear.app](https://linear.app) (iOS + Android)
- Domain: project management developer
- Reputasi: gold standard UI sleek 2024-2026
- Article: [linear.app/now/how-we-redesigned-the-linear-ui](https://linear.app/now/how-we-redesigned-the-linear-ui)
- iOS 26 Liquid Glass spin: [linear.app/now/linear-liquid-glass](https://linear.app/now/linear-liquid-glass)

### 2.2 Pattern yang Relevan untuk MyPresensi

**Inbox-as-home**: Linear mobile membuka langsung ke "Inbox" — bukan list project. Pattern: "show user what needs their attention NOW, lainnya nanti".

> **Aplikasi MyPresensi**: Home mahasiswa default ke **"Sesi Aktif Sekarang"** kalau ada (hero card prominent), kalau tidak default ke **"Sesi Berikutnya"** atau **notifikasi pending** — bukan list MK statis.

**Tab bar shape kustom**: Linear di iOS 26 punya tab bar yang bukan default Apple — mereka kontrol material untuk konsistensi merek.

> **Aplikasi MyPresensi**: Custom NavigationBar Material 3 dengan branded primary color, BUKAN bottom nav default abu-abu generik.

**Density tinggi tanpa cluttered**: List item Linear punya banyak meta (status icon + title + assignee avatar + priority + label) dalam 1 row 56-60px tinggi. Trick: hierarchy weight — title tebal, meta subdued.

> **Aplikasi MyPresensi**: List sesi/history bisa muat lebih banyak info per row tanpa bertambah tinggi — pakai weight typography (title bold, meta 12pt color-secondary).

**Loading skeleton match shape**: Skeleton row Linear betul-betul 1:1 sama row real (bukan generic gray box).

> **Aplikasi MyPresensi**: `LoadingSkeleton` (sudah ada di codebase) sudah benar — pertahankan pattern ini.

### 2.3 Yang TIDAK perlu ditiru
- Command palette `Cmd+K` di mobile (overkill untuk daily-use mahasiswa)
- Multi-team workspace switcher (MyPresensi single-tenant)

---

## 3. Cash App — Premium Fintech US

### 3.1 Akses & Konteks
- App: Cash App (Square)
- Domain: peer-to-peer payment + banking
- Design system: [designsystems.surf/design-systems/cashapp](https://designsystems.surf/design-systems/cashapp)
- Vibe: minimalist + bold typography + micro-animation

### 3.2 Pattern yang Relevan

**Big number hero**: Layar utama Cash App = balance besar di tengah (60-80pt bold). Ini pattern "surface most important number first".

> **Aplikasi MyPresensi**: Layar profil/riwayat mahasiswa — **persentase kehadiran** yang besar (mis. "92%") sebagai hero metric. Bukan tabel angka kecil.

**Tap target full card**: Setiap card Cash App tap-able full area (bukan hanya button kecil di sudut). Easier untuk thumb.

> **Aplikasi MyPresensi**: Card history per item — tap di mana saja → buka detail. Jangan pakai button kecil "Lihat detail" di sudut.

**Konfirmasi destruktif tegas tapi reversible**: "Send $50 to John?" → swipe-to-send, BUKAN tap button. Memberi friction yang feel premium (bukan annoying).

> **Aplikasi MyPresensi**: Untuk action destructive seperti "Hapus Wajah Terdaftar" — bisa pakai swipe-to-confirm atau hold-to-confirm (sudah ada 2-step dialog di codebase, bisa enhance).

**Micro-animation reward**: Setelah send sukses, ada animasi confetti subtle. Tidak berlebihan, sekitar 500ms.

> **Aplikasi MyPresensi**: Setelah submit presensi sukses → animasi checkmark + light haptic medium. **JANGAN confetti** (terlalu casual untuk academic), tapi hero icon scale-in OK.

### 3.3 Yang TIDAK perlu ditiru
- Cash Card customization (off-domain)
- Stock/Bitcoin trading (off-scope)

---

## 4. Notion Mobile — Workspace First

### 4.1 Akses & Konteks
- App: Notion (mobile companion)
- Domain: knowledge workspace
- Dribbble inspiration: [uiland.design/screens/notion](https://uiland.design/screens/notion/screens/0fe2e369-a00c-46ef-b7be-d42a8744ef19)

### 4.2 Pattern yang Relevan

**Search-first home**: Top of Notion mobile = search bar prominent, BUKAN list. Karena pattern user: "tahu yang dicari, butuh akses cepat".

> **Aplikasi MyPresensi**: Cocok untuk halaman riwayat saat list panjang (>50 item) — search bar di atas list, filter chip di bawah.

**Block-based interaction**: Setiap row tap → bottom sheet detail. Bukan navigate ke screen baru.

> **Aplikasi MyPresensi**: Tap item history → **bottom sheet detail** dengan info lengkap, BUKAN push screen baru. Lebih cepat untuk peek-and-back behavior.

**Sidebar di mobile = swipe**: Swipe dari kiri → sidebar muncul. Gak perlu hamburger button.

> **Aplikasi MyPresensi**: Profile/settings bisa diakses via swipe gesture dari kiri (advanced) atau tab "Profil" di bottom nav (simpel). Pilih tab nav untuk simplicity PBL.

### 4.3 Yang TIDAK perlu ditiru
- Editing block document (off-scope)
- AI integration (out of scope)

---

## 5. Things 3 / Todoist — Minimalist List Master

### 5.1 Akses & Konteks
- Things 3: [pcmag.com/reviews/things-3](https://www.pcmag.com/reviews/things-3) (iOS only, premium $9.99)
- Todoist: cross-platform free
- Reputasi: gold standard UI minimalist task list
- Article: [eleken.co/blog-posts/list-ui-design](https://www.eleken.co/blog-posts/list-ui-design) (Things & Todoist included)

### 5.2 Pattern yang Relevan

**Group by smart date**: "Today / Tomorrow / This Week / Upcoming / Anytime / Someday". Bukan tanggal absolute saja.

> **Aplikasi MyPresensi**: List history kehadiran — pakai grouping "Hari ini / Kemarin / Minggu ini / Bulan ini / Sebelumnya" daripada tanggal absolute. Lebih scanable.

**Swipe-to-action**: Swipe kanan → mark done (success color). Swipe kiri → reschedule/delete. **Sudah ditiru codebase** untuk notifikasi swipe-mark-read.

> **Aplikasi MyPresensi**: Notifikasi swipe-to-read sudah pattern — bisa diperluas ke leave request swipe-to-cancel (untuk pengajuan masih pending).

**Empty state ramah motivasional**: Things 3 saat list kosong: "Today is empty. What will you do today?" — bukan "No tasks".

> **Aplikasi MyPresensi**: Empty state harus jangan teknis. Contoh:
> - ❌ "No history found"
> - ✅ "Belum ada riwayat. Mulai presensi pertamamu hari ini!"

**No clutter**: Things 3 di home: header tipis + list. Tidak ada banner, tidak ada side menu icon, tidak ada FAB di home. Yang penting saja.

> **Aplikasi MyPresensi**: Home mahasiswa pertahankan minimalis. Hero card sesi aktif + quick action grid 2x2 + activity feed. Cukup.

### 5.3 Yang TIDAK perlu ditiru
- Drag-reorder list (mahasiswa tidak ubah order)
- Project hierarchy nested (off-scope)

---

## 6. Spotify — Library + Card Hierarchy

### 6.1 Akses & Konteks
- App: Spotify (cross-platform)
- Domain: music streaming
- Article: [medium.com/@marshall6/ui-ux-case-study-redesign-spotify-mobile-app](https://medium.com/@marshall6/ui-ux-case-study-redesign-spotify-mobile-app-ac382bc8703f)
- iOS UI Kit 2024: [figma.com/community/file/1416079450566123166](https://www.figma.com/community/file/1416079450566123166/spotify-ios-ui-kit-2024)

### 6.2 Pattern yang Relevan

**Card-based home dengan mixed sizes**: Hero card di atas (recently played) + grid 2-col card kecil + horizontal scrollable shelf. **Bukan single uniform list**.

> **Aplikasi MyPresensi**: Home mahasiswa sudah pattern hero+grid, pertahankan. Bisa tambah "horizontal shelf" untuk MK aktif (scroll horizontal kalau MK > 4).

**Library navigation flat**: Tab "Your Library" → Filter chip horizontal (Playlists / Artists / Albums / Podcasts / Downloaded). Bukan deep folder.

> **Aplikasi MyPresensi**: Riwayat mahasiswa pakai filter chip horizontal (Semua / Hadir / Telat / Izin / Sakit / Alpa) di atas list — sudah pattern. Pertahankan flat hierarchy, JANGAN folder per MK.

**Bottom nav 3-tab core (Home / Search / Library)**: Spotify dulu 4 tab, sekarang 3. Less is more.

> **Aplikasi MyPresensi**: Saat ini punya 5 tab (Beranda/Scan/Riwayat/Notif/Profil). Acceptable untuk daily-use app, tapi waspada bloat. JANGAN tambah jadi 6+.

**Now Playing persistent mini-player**: Saat lagu main, ada strip kecil di atas bottom nav. Tap → expand full.

> **Aplikasi MyPresensi (advanced)**: Saat ada sesi aktif, bisa ada strip mini di atas bottom nav: "🔵 Algoritma berlangsung — tap untuk Scan QR". Tap → langsung ke scan screen. Nice-to-have untuk PBL.

### 6.3 Yang TIDAK perlu ditiru
- Create button di tab bar (Spotify pun di-protes user)
- Algorithmic feed (out of scope)

---

## 7. Airbnb — Search + Booking Flow

### 7.1 Akses & Konteks
- App: Airbnb
- Article: [blog.prototypr.io/how-airbnb-became-a-leader-in-ux-design](https://blog.prototypr.io/how-airbnb-became-a-leader-in-ux-design-7d8ab8ad803e?gi=9bcac679446b)
- Mobbin: [banani.co/references/apps/airbnb](https://www.banani.co/references/apps/airbnb)

### 7.2 Pattern yang Relevan

**Multi-step form wizard**: Booking dipecah jadi step (Lokasi → Tanggal → Tamu → Konfirmasi). Setiap step layar penuh fokus.

> **Aplikasi MyPresensi**: Form pengajuan izin bisa pattern ini — 3 step (Pilih MK & sesi → Tipe & alasan → Lampiran & konfirmasi) dengan progress bar atas.

**Map + List toggle**: User bisa toggle antara list view dan map view untuk hasil search.

> **Aplikasi MyPresensi**: Untuk lokasi kampus admin/dosen, toggle antara list view (CRUD) dan map view (visualisasi titik) bisa keren — pakai package `flutter_map` atau `google_maps_flutter`. Out-of-scope untuk PBL kemungkinan.

**Filter modal full-screen**: Filter di Airbnb full-screen modal dengan banyak section (price range, type, amenities, dll). Section accordion-style.

> **Aplikasi MyPresensi**: Untuk filter rekap admin web atau riwayat mobile yang punya banyak filter, pattern modal full-screen lebih nyaman daripada drawer kecil.

**"Save" / Wishlist**: Heart icon konsisten di setiap card untuk save listing.

> **Aplikasi MyPresensi**: Tidak relevan langsung (mahasiswa tidak save MK). Tapi pattern bookmark icon konsisten bisa untuk "favorit dosen" di rating dosen (kalau ada fitur evaluation nanti).

### 7.3 Yang TIDAK perlu ditiru
- Hosting flow (out of scope)
- Reviews & ratings dengan star (academic context beda)

---

## 8. Duolingo — Gamification & Onboarding

### 8.1 Akses & Konteks
- App: Duolingo
- Article: [userguiding.com/blog/duolingo-onboarding-ux](https://userguiding.com/blog/duolingo-onboarding-ux)
- Onboarding flow: [mobbin.com/explore/flows/0acc27c7-4e01-481c-83b2-99f8d741bef1](https://mobbin.com/explore/flows/0acc27c7-4e01-481c-83b2-99f8d741bef1)

### 8.2 Pattern yang Relevan

**Onboarding questionnaire personalization**: 5-7 questions di first launch ("Why are you learning?" / "How much time?"). Output: personalized goal + path.

> **Aplikasi MyPresensi**: Onboarding mahasiswa first-time → tanya 2-3 hal: "Notifikasi reminder presensi: H-30 menit / H-15 / Off?" "Mode kamera default: depan / belakang?" — personalisasi UX tanpa over-engineering. Simpan di SecureStorage.

**XP / Streak reward**: Setelah lesson, ada animasi XP gain + streak counter. Dopamine micro-reward.

> **Aplikasi MyPresensi**: Gamifikasi minimal — "Streak hadir 5 hari berturut-turut" sebagai badge di profil. Tapi **HATI-HATI**: jangan over-gamify kelas akademik (ada risiko culturally tone-deaf untuk konteks Indonesia formal). Cukup simple counter, JANGAN big celebration animation untuk presensi.

**Progress bar prominent**: Setiap lesson punya progress bar atas (3/10 questions answered).

> **Aplikasi MyPresensi**: Untuk face registration multi-frame capture, sudah ada progress circular oval (di docs `mobile-references.md`). Pertahankan.

**Friendly mascot copy**: Owl Duo punya kepribadian — pesan error pun ramah. "Tidak ada koneksi" jadi "Ouch! Connection issue. Try again?"

> **Aplikasi MyPresensi**: Pesan ramah Indonesia — sudah pattern. Tapi **JANGAN bikin maskot** (over-engineering untuk academic kampus).

### 8.3 Yang TIDAK perlu ditiru
- Heart system (life lost) — manipulative pattern, tidak cocok academic
- Leaderboard kompetitif kelas (privacy concern)

---

## 9. Headspace — Wellness & Personalization

### 9.1 Akses & Konteks
- App: Headspace
- Article: [uxcam.com/blog/10-apps-with-great-user-onboarding](https://uxcam.com/blog/10-apps-with-great-user-onboarding/) (Headspace + Calm + Strava ranked top onboarding)

### 9.2 Pattern yang Relevan

**Onboarding "tell us about you"**: 3-4 questions tentang goal & schedule → personalized plan. Sama pattern dengan Duolingo tapi vibe lebih calm.

> **Aplikasi MyPresensi**: Sebelum first attendance, mahasiswa diajak setting: "Lokasi default kampus: Politani Kampus A?" (auto-suggest dari preset DB) "Notifikasi reminder: ya/tidak?" — feel like "we're setting up your account properly", bukan "we're harvesting data".

**Quiet color palette + calm typography**: Headspace pakai pastel + serif/rounded sans. Vibe: bukan rush, bukan stress.

> **Aplikasi MyPresensi**: Style direction sudah formal corporate (Plus Jakarta Sans + Inter). Untuk error/warning state, palette amber/red harus tetap calm — bukan harsh red ngeri. Pakai `#9A6700` warning yang sudah di token, bukan `#FF0000` mentah.

**Session completion celebration subtle**: Setelah meditasi selesai, screen "Well done. You meditated for 10 minutes." dengan fade-in soft, bukan confetti.

> **Aplikasi MyPresensi**: Setelah submit presensi sukses, screen result-nya bisa fade-in calm checkmark + pesan supportive "Presensi tercatat. Terima kasih sudah hadir." — vibe academic respectful, bukan game-y.

### 9.3 Yang TIDAK perlu ditiru
- Subscription paywall flow (proyek internal kampus, gratis)
- Audio player full-screen (off-domain)

---

## 10. Revolut — Card-based Banking Home

### 10.1 Akses & Konteks
- App: Revolut
- Free UI Kit: [figma.com/community/file/1372290114400007730](https://www.figma.com/community/file/1372290114400007730/revolut-free-ui-kit-by-marvilo)
- Case study redesign: [medium.com/design-bootcamp/recreating-revolut](https://medium.com/design-bootcamp/recreating-revolut-fbffc4dff746)

### 10.2 Pattern yang Relevan

**Hero balance card + horizontal scrollable accounts**: Atas: 1 hero card balance utama. Bawah: horizontal scroll card per account (USD/EUR/Crypto/Stocks).

> **Aplikasi MyPresensi**: Pattern bisa dipakai untuk **dashboard mahasiswa multi-MK** — hero "Statistik Semester Ini" + horizontal scroll card per MK (kotak warna + nama MK + persentase hadir).

**Quick action row**: Di bawah hero, 4-5 icon button bulat horizontal (Send / Request / Top up / Exchange / More).

> **Aplikasi MyPresensi**: Sudah pattern di plan mobile-references.md (quick action grid 2x2). Variant horizontal row 4 ikon juga OK — Scan QR / Riwayat / Izin / Profil.

**Transaction list dengan amount color-coded**: Hijau untuk income, abu-abu untuk neutral, merah untuk outgoing.

> **Aplikasi MyPresensi**: Riwayat — color-coded badge per status (sudah pattern hadir hijau / izin amber / alpa merah).

**Notification icon top-right minimal**: Hanya ikon bell + badge merah, tidak ada title "Notifications" di header (efficient header).

> **Aplikasi MyPresensi**: Bell icon di top-right home + badge counter sudah pattern. Pertahankan.

### 10.3 Yang TIDAK perlu ditiru
- Crypto/Stocks (off-domain)
- Multi-currency switcher (single tenant Indonesia kampus)

---

## 11. Pola Lintas-App yang Layak Adopsi

### 11.1 Onboarding "Personalize First"

**Pola**: First launch → 2-5 questions → personalized setup → main app.

**Apps yang pakai**: Duolingo, Headspace, Spotify (genre preference), Airbnb (interests).

**MyPresensi**:
- Q1: "Notifikasi reminder presensi sebelum sesi: H-30 / H-15 / H-5 / Off"
- Q2: "Lokasi default presensi: Kampus A / Kampus B / Tanya tiap kali"
- Q3 (skippable): "Setup wajah sekarang? (atau nanti via Profil)"

Simpan di SecureStorage flag `onboarded=true` agar tidak ulang.

### 11.2 Hero + Grid + Activity Feed Home

**Pola**: Home = hero card prominent + 4-6 quick action grid + recent activity feed bawah.

**Apps**: Spotify, Notion, Cash App, Revolut, Sunsama.

**MyPresensi** (sudah pattern di mobile-references.md §3.2):
```
[Hero: Sesi Aktif / Sesi Berikutnya]
[Grid 2x2: Scan / Riwayat / Izin / Profil]
[Activity feed 3-5 item]
```

### 11.3 Search-First untuk List Panjang

**Pola**: Search bar prominent di atas list saat data > 50 item.

**Apps**: Notion, Linear, Spotify Library, Things 3.

**MyPresensi**: Halaman riwayat mahasiswa kalau >50 item, pasti sebelum list ada search bar. Filter chip horizontal di bawah search.

### 11.4 Bottom Sheet untuk Detail Peek

**Pola**: Tap list item → bottom sheet (50-80% screen height) untuk detail. BUKAN navigate ke screen baru.

**Apps**: Notion, Linear, Spotify (track detail), Airbnb (filter).

**MyPresensi**: Tap riwayat item → bottom sheet detail (MK + sesi + waktu + GPS + face similarity). Lebih cepat balik ke list daripada push-pop screen.

### 11.5 Swipe Actions Konsisten

**Pola**:
- Swipe kanan = positive action (mark read, complete) — color success
- Swipe kiri = negative action (delete, dismiss) — color danger

**Apps**: Things 3, Todoist, Apple Mail, Twitter, WhatsApp.

**MyPresensi**: Sudah pattern untuk notifikasi (swipe-to-read). Bisa diperluas ke leave request (swipe-to-cancel pending).

### 11.6 Inline Validation + Save Indicator

**Pola**:
- Validation muncul on blur per field (bukan on keystroke, bukan on submit)
- Save button → loading spinner → success toast
- Auto-save indicator subtle ("Tersimpan otomatis 14:23")

**Apps**: Notion, Linear, Things 3.

**MyPresensi**: Form submit izin → validasi inline + tombol "Ajukan" loading → success toast + navigate kembali ke list.

### 11.7 Pull-to-Refresh + Skeleton Loading

**Pola**:
- Pull-to-refresh (haptic feedback medium impact saat trigger)
- Refresh → skeleton matching shape muncul → data baru ganti skeleton

**Apps**: Hampir semua premium app modern.

**MyPresensi**: Sudah pattern di history/notifications/leave (3-state). Pertahankan.

### 11.8 Permission Priming

**Pola**: Sebelum trigger system permission native (camera, location), tampilkan **screen edukasi custom** dulu.

**Apps**: Headspace, Calm, Duolingo.

**MyPresensi**: Wajib (sesuai mobile-references.md §4.10) — sebelum first scan QR / first attendance, tampilkan layar "Mengapa kami butuh akses ini" dengan tombol "Lanjut" → baru trigger system dialog.

---

## 12. iOS 26 + Material 3 Navigation 2025-2026

### 12.1 Sumber Resmi
- iOS 26 Design Guidelines: [learnui.design/blog/ios-design-guidelines-templates.html](https://www.learnui.design/blog/ios-design-guidelines-templates.html)
- Material 3 Navigation Bar: [m3.material.io/components/navigation-bar/overview](https://m3.material.io/components/navigation-bar/overview)
- Linear Liquid Glass adoption: [linear.app/now/linear-liquid-glass](https://linear.app/now/linear-liquid-glass)

### 12.2 Aturan Wajib

**Tab count**:
- iOS 26: 2-5 tab maksimal. Lebih dari itu wajib tab "More" catch-all.
- Material 3: 3-5 tab.

> **MyPresensi**: 5 tab (Beranda/Scan/Riwayat/Notif/Profil) tepat di batas. Acceptable. JANGAN tambah jadi 6+.

**Ketika modal terbuka**: HIDE tab bar. User fokus ke task.

> **MyPresensi**: Saat scan QR full-screen / face register / face verify — sembunyikan bottom nav. Pakai `Scaffold(bottomNavigationBar: showNav ? AppBottomNav() : null)` conditional.

**Indicator tab aktif**:
- iOS 26: pill background + tinted icon
- Material 3: pill background + label always visible

> **MyPresensi**: Material 3 NavigationBar (sudah pattern di plan), label always visible (BUKAN icon-only).

**Liquid Glass / Material You theming** (advanced):
- iOS 26 Liquid Glass: tab bar bisa custom shape & material translucency
- Material You: dynamic color berdasar wallpaper user

> **MyPresensi**: SKIP — over-engineering untuk PBL. Pertahankan static primary color `#5483AD`.

---

## 13. Action Items untuk MyPresensi Mobile

Update untuk `mobile-references.md` §6 — pertimbangkan untuk merge/append:

### 🔴 High Priority

1. **Onboarding 2-3 question questionnaire** sebelum first home — set notification reminder + lokasi default. Ref: Duolingo, Headspace.

2. **Tap-to-bottom-sheet** untuk detail history item (jangan push screen baru). Ref: Notion, Linear, Airbnb.

3. **Hide bottom nav** saat full-screen camera (scan QR, face register/verify). Ref: iOS 26 + Material 3 wajib.

4. **Hero metric "persentase kehadiran" besar** di profil mahasiswa — 60-80pt bold seperti Cash App balance. Visual hierarchy menjelaskan instan.

### 🟡 Medium Priority

5. **Group history by smart date** ("Hari ini / Kemarin / Minggu ini / Bulan ini / Sebelumnya") — Things 3 pattern.

6. **Mini sesi aktif strip** di atas bottom nav saat ada sesi berlangsung — Spotify Now Playing pattern. Tap → langsung scan screen.

7. **Subtle celebration** setelah submit presensi (fade-in checkmark + haptic medium) — Headspace pattern. **JANGAN** confetti / animasi berlebihan.

8. **Multi-step form wizard** untuk submit izin (Pilih MK & sesi → Tipe & alasan → Lampiran & konfirmasi) — Airbnb pattern.

### 🟢 Nice-to-Have

9. **Streak counter** "Hadir 5 hari berturut" sebagai badge profil — minimalist Duolingo pattern. JANGAN celebration berlebihan.

10. **Search bar prominent di atas list riwayat** saat > 50 item — Notion/Things pattern.

11. **Map view** untuk lokasi kampus (admin/dosen web) — Airbnb pattern, tapi out-of-scope mahasiswa mobile.

---

## 14. Daftar Referensi Lengkap

### 14.1 Apps Premium Tier-1 (Direct)

**Productivity**:
- Linear — [linear.app](https://linear.app) | iOS Liquid Glass — [linear.app/now/linear-liquid-glass](https://linear.app/now/linear-liquid-glass)
- Notion mobile — [uiland.design/screens/notion](https://uiland.design/screens/notion/screens/0fe2e369-a00c-46ef-b7be-d42a8744ef19)
- Things 3 — [pcmag.com/reviews/things-3](https://www.pcmag.com/reviews/things-3) | [productivewithchris.com/tools/things-3](https://productivewithchris.com/tools/things-3/)
- Todoist — [eleken.co/blog-posts/list-ui-design](https://www.eleken.co/blog-posts/list-ui-design)
- Sunsama — [sunsama.com](https://www.sunsama.com/)

**Fintech**:
- Cash App Design System — [designsystems.surf/design-systems/cashapp](https://designsystems.surf/design-systems/cashapp)
- Revolut UI Kit Free — [figma.com/community/file/1372290114400007730](https://www.figma.com/community/file/1372290114400007730/revolut-free-ui-kit-by-marvilo)
- Revolut redesign case — [medium.com/design-bootcamp/recreating-revolut](https://medium.com/design-bootcamp/recreating-revolut-fbffc4dff746)

**Media & Entertainment**:
- Spotify iOS UI Kit 2024 — [figma.com/community/file/1416079450566123166](https://www.figma.com/community/file/1416079450566123166/spotify-ios-ui-kit-2024)
- Spotify case study — [medium.com/@marshall6/ui-ux-case-study-redesign-spotify-mobile-app](https://medium.com/@marshall6/ui-ux-case-study-redesign-spotify-mobile-app-ac382bc8703f)

**Travel**:
- Airbnb UX leader — [blog.prototypr.io/how-airbnb-became-a-leader-in-ux-design](https://blog.prototypr.io/how-airbnb-became-a-leader-in-ux-design-7d8ab8ad803e?gi=9bcac679446b)
- Airbnb Mobbin alternative — [banani.co/references/apps/airbnb](https://www.banani.co/references/apps/airbnb)
- Booking vs Airbnb mobile — [goodui.org/blog/comparing-bookings-vs-airbnbs-mobile-homepage-ui](https://goodui.org/blog/comparing-bookings-vs-airbnbs-mobile-homepage-ui/)

**Education / Wellness**:
- Duolingo onboarding — [userguiding.com/blog/duolingo-onboarding-ux](https://userguiding.com/blog/duolingo-onboarding-ux)
- Duolingo iOS Mobbin flow — [mobbin.com/explore/flows/0acc27c7-4e01-481c-83b2-99f8d741bef1](https://mobbin.com/explore/flows/0acc27c7-4e01-481c-83b2-99f8d741bef1)
- 12 Apps Great Onboarding — [uxcam.com/blog/10-apps-with-great-user-onboarding](https://uxcam.com/blog/10-apps-with-great-user-onboarding/)
- Mobile UX Design Examples 2025 — [eleken.co/blog-posts/mobile-ux-design-examples](https://www.eleken.co/blog-posts/mobile-ux-design-examples)

### 14.2 Article Lintas-App

- iOS 26 Design Guidelines — [learnui.design/blog/ios-design-guidelines-templates.html](https://www.learnui.design/blog/ios-design-guidelines-templates.html)
- iOS 26 + Material 3 UI Kits (Moqups) — [moqups.com/blog/ios-26-material-design-3-ui-kits](https://moqups.com/blog/ios-26-material-design-3-ui-kits/)
- Material 3 Navigation Bar — [m3.material.io/components/navigation-bar/overview](https://m3.material.io/components/navigation-bar/overview)
- Mobile UX Examples 50+ — [eleken.co/blog-posts/mobile-ux-design-examples](https://www.eleken.co/blog-posts/mobile-ux-design-examples)
- Mobile Onboarding UI/UX Patterns — [appcues.com/blog/essential-guide-mobile-user-onboarding-ui-ux](https://www.appcues.com/blog/essential-guide-mobile-user-onboarding-ui-ux)
- List UI Design 30+ Examples — [eleken.co/blog-posts/list-ui-design](https://www.eleken.co/blog-posts/list-ui-design)

### 14.3 Design System Sources

- Cash App — [designsystems.surf/design-systems/cashapp](https://designsystems.surf/design-systems/cashapp)
- Material Design 3 — [m3.material.io](https://m3.material.io/)
- Apple HIG — [developer.apple.com/design/human-interface-guidelines](https://developer.apple.com/design/human-interface-guidelines)
- Mobbin (paywalled gallery) — [mobbin.com](https://mobbin.com/)
- Banani (free Mobbin alt) — [banani.co/references](https://www.banani.co/references)

### 14.4 Cross-Reference dengan File Sister

- `mobile-references.md` — referensi mobile attendance/Indonesia (sudah ada, 825 baris)
- `admin-web-references.md` — referensi admin web (top-tier non-presensi)
- `mockups/` — folder simpan screenshot referensi yang kamu ambil dari browse manual

---

## 15. Cara Pakai Dokumen Ini

### 15.1 Untuk User (Riki)

1. **Pakai sebagai pelengkap** `mobile-references.md`. File ini fokus produk premium global, file lain fokus konteks attendance Indonesia.
2. **Browse 1-2 app premium per minggu** — install di HP, eksplorasi 30 menit, screenshot bagian menarik.
3. **Map ke MyPresensi** — pertanyaan kunci tiap pattern: "Apakah ini meningkatkan task completion mahasiswa? Apakah feel-nya sesuai academic context kampus?"
4. **Implement increment** — adopsi 1-2 pattern per sprint, JANGAN copy-paste seluruh app.

### 15.2 Untuk AI Agent (Cascade)

Sebelum redesign mobile screen yang BELUM di-cover `mobile-references.md`:
1. **Cek file ini** untuk pattern non-presensi yang relevan.
2. **Verifikasi style direction** masih konsisten dengan `mobile-references.md` §2.
3. **JANGAN over-adopt** pattern yang merusak vibe academic profesional (mis. Duolingo over-gamification, Cash App casual confetti).
4. **Action items §13** prioritized.

---

**Last updated**: 2026-05-15 (initial version, hasil riset komprehensif user request 2026-05-15 untuk produk premium non-presensi).
**Next review**: setelah user browse 3-5 apps di §2-§10 dan ambil screenshot di `mockups/`, atau saat mau implement Action Items §13.
