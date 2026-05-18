# UI Research — Referensi Admin Web MyPresensi

> **Tujuan**: Kumpulkan referensi konkret dari **produk web admin ternama** (di luar ranah presensi) sebagai standar bangunan untuk dashboard admin & dosen MyPresensi. Hasil riset ini fokus ke **UI, layout, styling, penempatan card, dan elemen per menu** — bukan sekadar link untuk browse.
>
> **Metode**: Web search bertahap + deep-read 2 artikel kelas-A (Linear redesign 2024, Dashboard Design Patterns 2026 — Art of Styleframe). Cross-reference dengan style direction MyPresensi (Corporate/SaaS clean, Tailwind 3, design token **Politani Blue `#2D86FF`** + Gold accent `#F4B400` + deep navy `#0D2C5E`).
>
> **Update 2026-05-15**: Versi awal dokumen ini menyebut `#5483AD` (Biru Baja TRPL) — ini SALAH. Real `mypresensi-web/app/globals.css:17` pakai `--color-primary: 45 134 255` (= `#2D86FF` Politani). Semua referensi di dokumen ini sudah dikoreksi.
>
> **Disclaimer**: Saya tidak bisa "melihat" screenshot. Dokumen ini menyajikan **spec konkret** + **pola observasi** + link untuk evaluasi visual sendiri.
>
> **Catatan ruang lingkup**: File `mobile-references.md` sudah ada (825 baris) untuk sisi mobile mahasiswa. File ini KHUSUS sisi admin/dosen web.

---

## DAFTAR ISI

1. [Inventaris Halaman Admin & Dosen MyPresensi](#1-inventaris-halaman-admin--dosen-mypresensi)
2. [Style Direction Established](#2-style-direction-established)
3. [Anatomi Layout Master (Shell)](#3-anatomi-layout-master-shell)
4. [Pola per Tipe Halaman](#4-pola-per-tipe-halaman)
5. [Pola Komponen Reusable](#5-pola-komponen-reusable)
6. [Design Tokens](#6-design-tokens)
7. [Anti-Pattern yang Wajib Dihindari](#7-anti-pattern-yang-wajib-dihindari)
8. [Action Items Prioritized](#8-action-items-prioritized)
9. [Daftar Referensi Lengkap](#9-daftar-referensi-lengkap)
10. [Cara Pakai Dokumen Ini](#10-cara-pakai-dokumen-ini)

---

## 1. Inventaris Halaman Admin & Dosen MyPresensi

Berdasarkan kode existing di `mypresensi-web/app/(dashboard)/*`:

### 1.1 Halaman Admin (full akses)

| # | Halaman | Tipe | Catatan |
|---|---------|------|---------|
| 1 | Dashboard Admin | Overview/KPI | Total mhs, dosen, MK, sesi aktif, anomali |
| 2 | Mahasiswa | Master Data CRUD | List + create + edit + import CSV + reset password |
| 3 | Dosen | Master Data CRUD | List + create + edit + assign MK |
| 4 | Mata Kuliah | Master Data CRUD | List + create + edit + assign dosen + manage enrollments |
| 5 | Enrollments | Relational | Daftar mahasiswa per MK (bulk add via CSV) |
| 6 | Sesi (oversight) | List read-only | Semua sesi cross-dosen, filter tgl/MK/dosen |
| 7 | Lokasi Kampus | Master Data CRUD | Preset koordinat GPS + radius |
| 8 | Audit Log | Timeline read-only | Filter actor/action/date, export |
| 9 | Settings | Configuration | radius geofence, threshold face, OTP TTL |
| 10 | Export | Wizard | Generate CSV/PDF per filter |
| 11 | Notifications | List | Inbox sistem |
| 12 | Profile | Account | Edit avatar, ganti password |

### 1.2 Halaman Dosen (scope MK yang diampu)

| # | Halaman | Tipe | Catatan |
|---|---------|------|---------|
| 1 | Dashboard Dosen | Overview/KPI | Sesi hari ini, izin pending, persentase rata-rata MK |
| 2 | Mata Kuliah | List scoped | Hanya yang diampu |
| 3 | Sesi | List + Create + Start | CRUD sesi + tombol Mulai → generate OTP |
| 4 | QR Display | Public/Presentation | Full-screen QR + OTP + counter peserta |
| 5 | Monitor Real-time | Live view | List mahasiswa yang sudah/belum submit |
| 6 | Izin (Approve/Reject) | Workflow | Inbox pengajuan dari mahasiswa |
| 7 | Rekap | Report | Persentase per MK, exportable (`rekap-filters.tsx` yang kamu buka) |
| 8 | Notifications | List | Inbox |
| 9 | Profile | Account | Same as admin |

### 1.3 Gap UI yang Kemungkinan Ada

| Gap | Dampak | Prioritas |
|-----|--------|-----------|
| Dashboard belum mengikuti "metric strip" 4-6 KPI | Info penting tersembunyi | High |
| Tabel master: filter+pagination+bulk action belum konsisten | UX power user terhambat | High |
| Audit log belum berbentuk timeline grouping tanggal | Sulit forensic cepat | Medium |
| Settings 1 page panjang scroll vs tab/section | Discoverability rendah | Medium |
| QR Display belum full-screen presentation mode | Sulit di-show proyektor | Medium |
| Monitor real-time polling lambat, belum WebSocket | Dosen refresh manual | Nice-to-have |
| Empty state tabel belum CTA jelas | User bingung mulai | Medium |
| Form: belum konsisten modal vs full-page | Inkonsisten UX | Medium |
| Page header belum breadcrumb di halaman dalam | Navigasi tidak jelas | Medium |

---

## 2. Style Direction Established

Dari rules + `app/globals.css` MyPresensi:

| Aspek | Nilai | Catatan |
|-------|-------|---------|
| Filosofi | Formal, bersih, profesional — Corporate/SaaS | TIDAK boleh terlihat AI-generated |
| Bahasa UI | Bahasa Indonesia | Pesan ramah, bukan teknis |
| Primary | `#2D86FF` (Politani Blue, dari politanisamarinda.ac.id) | |
| Primary hover | `#1E70E0` | |
| Primary dark | `#0D2C5E` (deep navy, hero gradient end) | |
| Accent | `#F4B400` (Gold pita logo Politani) | Kontras hangat |
| Status | success `#1A7F37`, warning `#9A6700`, danger `#CF222E` | |
| Background | `#F4F6F8` | Off-white gentle |
| Surface card | `#FFFFFF` | |
| Border | 1px `#E5E7EB` | Subtle |
| Font heading | Plus Jakarta Sans | |
| Font body | Inter | |
| Radius card | 12-16px | |
| Radius button | 999px (pill) | Established |
| Icons | Lucide React | TIDAK pakai emoji di UI |

**Direction**: extend style ini. **JANGAN** redesign radikal.

---

## 3. Anatomi Layout Master (Shell)

Dari deep-read **Linear redesign 2024** + **Dashboard Patterns 2026** (Art of Styleframe), pattern konsensus untuk admin SaaS modern:

### 3.1 Inverted L-Shape Shell

```
┌──────────────────────────────────────────────────────────────┐
│  TOP BAR  (48-56px tall, search + user menu + notif)         │
├─────────┬────────────────────────────────────────────────────┤
│         │  PAGE HEADER (icon + title + subtitle + actions)   │
│ SIDEBAR ├────────────────────────────────────────────────────┤
│  256px  │  CONTENT AREA (12-col CSS grid, 24px gutter)       │
│         │                                                    │
└─────────┴────────────────────────────────────────────────────┘
```

**Quote Linear (Karri Saarinen)**: *"I started to focus on this inverted L-shape. It's the global chrome of the application that controls the content in the main view."*

### 3.2 Sidebar — Spec Konkret

Dari Art of Styleframe + Linear + Vercel new dashboard:

| Spec | Nilai |
|------|-------|
| Expanded width | **256px (16rem)** |
| Collapsed width | 64px (icon rail) |
| Nav item height | **36px** desktop / 44px tablet |
| Padding horizontal | 12px |
| Border radius nav item | 8px |
| Active state | Bg primary 8% alpha + left 3px border accent |
| Section header | 12px UPPERCASE, color `#6B7280`, margin-top 24px |
| Transition collapse | 200ms ease-in-out (no content reflow) |
| Icon size | 16-20px Lucide |
| Gap icon ↔ label | 12px |

**Grouping pattern** (Notion, Linear, Vercel, Supabase Studio):

```
┌──────────────────────────────┐
│ ▾ MyPresensi · TRPL          │  workspace switcher
├──────────────────────────────┤
│ 🏠  Beranda                  │  primary
│ 🔔  Notifikasi    [3]        │  unread badge
├──────────────────────────────┤
│ DATA MASTER                  │  section header subdued
│ 👥  Mahasiswa                │
│ 👨‍🏫  Dosen                    │
│ 📚  Mata Kuliah              │
│ 📍  Lokasi Kampus            │
├──────────────────────────────┤
│ OPERASIONAL                  │
│ 📅  Sesi                     │
│ ✅  Rekap                    │
│ 📤  Export                   │
├──────────────────────────────┤
│ SISTEM                       │
│ 📜  Audit Log                │
│ ⚙️  Pengaturan               │
├──────────────────────────────┤
│ ▾  Riki (Admin)              │  bottom user menu
└──────────────────────────────┘
```

**Referensi**:
- Linear sidebar — [linear.app/now/how-we-redesigned-the-linear-ui](https://linear.app/now/how-we-redesigned-the-linear-ui)
- Vercel new dashboard — [vercel.com/try/new-dashboard](https://vercel.com/try/new-dashboard)
- Notion sidebar breakdown — [medium.com/@quickmasum/ui-breakdown-of-notions-sidebar-2121364ec78d](https://medium.com/@quickmasum/ui-breakdown-of-notions-sidebar-2121364ec78d)
- shadcn sidebar patterns — [medium.com/.../shadcn-sidebar-patterns](https://medium.com/write-a-catalyst/7-best-shadcn-sidebar-patterns-for-modern-saas-dashboards-ef1235cc920d)
- Supabase Studio — [deepwiki.com/supabase/supabase/2.1-studio-dashboard](https://deepwiki.com/supabase/supabase/2.1-studio-dashboard)

### 3.3 Top Bar — Minimalist

Pattern Linear/Stripe/Vercel: **bukan navigation primary**, hanya context global.

| Elemen | Posisi | Catatan |
|--------|--------|---------|
| Logo / nama institusi | Kiri (atau di sidebar) | |
| Breadcrumb | Kiri (kalau page dalam) | "Mahasiswa › Edit › Riki" |
| Search global `Cmd+K` | Tengah/kanan | Power user search across master |
| Notifikasi bell | Kanan | Count badge |
| User avatar menu | Paling kanan | Dropdown profile, logout |

**Tinggi**: 48-56px. **Border-bottom**: 1px subtle. **Anti-pattern**: JANGAN duplikasi navigasi top bar dan sidebar.

### 3.4 Page Header

```
┌─────────────────────────────────────────────────────┐
│ 👥  Mahasiswa                       [+ Tambah]      │
│     Kelola data mahasiswa TRPL                      │
├─────────────────────────────────────────────────────┤
│ Beranda › Data Master › Mahasiswa                   │
└─────────────────────────────────────────────────────┘
```

Spec:
- Icon 24-28px Lucide, color primary
- Title: Plus Jakarta Sans 24-28pt bold
- Subtitle: Inter 14pt color text-secondary
- Padding: 24px vertical, 32px horizontal
- Action utama (Tambah / Export / Refresh) di pojok kanan atas

### 3.5 Content Grid

Dari Art of Styleframe: **CSS Grid 12-column dengan gutter 24px**.

Layout standar:
- **Full-width**: `grid-column: 1 / -1` (tabel master, audit log)
- **Chart + tabel**: `span 7 + span 5`
- **3 card sejajar**: `span 4` × 3
- **Detail panel**: content `span 8` + sidebar `span 4`

Card minimum width: 280px (`auto-fill, minmax(280px, 1fr)`).

---

## 4. Pola per Tipe Halaman

### 4.1 Overview / Dashboard — KPI Strip + Activity

**Referensi terbaik**:

| Produk | Akses | Insight Pattern |
|--------|-------|-----------------|
| **Stripe Dashboard** | [stripe.com/dashboard](https://dashboard.stripe.com) | 4 KPI card di atas (Revenue, Charges, Payouts, Disputes) → mini sparkline. Below: tabel "Recent activity" + chart timeline. **Gold standard**. |
| **Linear** | [linear.app](https://linear.app) | Inbox priority items di atas → sections Cycles/Projects/Views. Info density tinggi, no fluff. |
| **Vercel new dashboard** | [vercel.com/try/new-dashboard](https://vercel.com/try/new-dashboard) | Sidebar collapse to icon rail, content area projects grid + recent activity right rail. |
| **Posthog** | [posthog.com/docs/product-analytics/dashboards](https://posthog.com/docs/product-analytics/dashboards) | KPI tiles + custom widget grid drag-drop. |
| **Mekari Talenta Dashboard** | [help-center.talenta.co/.../Dashboard-Menu-Overview](https://help-center.talenta.co/hc/en-us/articles/9123854858009-Dashboard-Menu-Overview) | Indonesia HRIS competitor. |

**Pola wajib MyPresensi Dashboard Admin**:

```
┌─────────────────────────────────────────────────────────────┐
│ 🏠  Selamat datang, Riki                  [Tahun Ajaran ▾] │
│     Ringkasan sistem hari ini                               │
├─────────────────────────────────────────────────────────────┤
│ ┌──────────┬──────────┬──────────┬──────────┐               │
│ │ 👥 1,234 │ 👨‍🏫 47    │ 📚 32    │ 📅 8     │  metric strip
│ │Mahasiswa │  Dosen   │   MK     │Sesi Aktif│               │
│ │ +12 bln  │   ─      │   +2 sem │  ⚡ Now  │               │
│ └──────────┴──────────┴──────────┴──────────┘               │
├─────────────────────────────────────────────────────────────┤
│ Aktivitas Hari Ini              │ Anomali / Alert           │
│ ┌────────────────────────────┐  │ ┌──────────────────────┐  │
│ │ 09:00 Sesi Algoritma mulai │  │ │ ⚠️ 3 mock_location  │  │
│ │ 09:15 Riki hadir (Algo)    │  │ │ ⚠️ 1 failed_login x5 │  │
│ │ 09:30 Sesi Basis Data mulai│  │ └──────────────────────┘  │
│ └────────────────────────────┘  │                           │
├─────────────────────────────────┴───────────────────────────┤
│ Grafik Tren Kehadiran 7 Hari Terakhir (Recharts)            │
└─────────────────────────────────────────────────────────────┘
```

**Spec Metric Card** (dari Art of Styleframe):

| Elemen | Spec |
|--------|------|
| Primary number | **28-32pt** bold Plus Jakarta Sans, high contrast |
| Label | 14pt color text-secondary, atas/bawah number |
| Trend indicator | Arrow up/down + persentase, 13pt color status |
| Sparkline (opsional) | 40px tall, color primary subtle |
| Card padding | 20-24px |
| Card width | 200-280px (auto-fill minmax) |
| Card radius | 12-14px |
| Border atau shadow | Pilih satu, JANGAN dua |

**Anti-pattern**:
- Welcome message besar di atas (waste prime real estate)
- Label panjang seperti "Total Active Students in System" — cukup "Mahasiswa"
- KPI > 6 card di satu baris

### 4.2 Master Data List — CRUD Tabel

**Referensi terbaik**:

| Produk | Insight Pattern |
|--------|-----------------|
| **shadcn/ui User List Management** | [shadcn.io/blocks/crud-list-users-01](https://www.shadcn.io/blocks/crud-list-users-01) | **Direct template** — table avatar+name+email+role+status, search, role filter, action menu per row. **Pakai struktur ini**. |
| **Shopify Polaris IndexTable** | [polaris-react.shopify.com](https://polaris-react.shopify.com/) | Bulk select + bulk action bar muncul di atas saat row dipilih. |
| **Linear issues table** | [linear.app](https://linear.app) | Filter chips + density mode (compact/comfortable) + column toggle. |
| **Stripe customers table** | [dashboard.stripe.com/customers](https://dashboard.stripe.com) | Pagination cursor-based + search + filter + export. |
| **Atlassian Jira issues** | [atlassian.design](https://atlassian.design) | Saved filter (My filters) — quick switch tanpa re-config. |

**Spec Tabel** (Art of Styleframe + Pencil & Paper):

| Elemen | Spec |
|--------|------|
| Row height | **48-52px comfortable** / 36-40px dense |
| Header sticky | `position: sticky, top: 0, z-index: 10`, bg solid |
| Column alignment | Text **left**, numbers **right**, status badge **center** |
| Sort indicator | Arrow di kolom aktif, subtle di sortable lain |
| Hover row | Bg `#F9FAFB` halus |
| Zebra stripes | **Hindari** kalau hover state aktif |
| Border | Horizontal 1px `#F0F2F4` antar row, no vertical |
| First column | Bisa pinned (sticky-left) untuk wide table |

**Layout Halaman Mahasiswa**:

```
┌────────────────────────────────────────────────────────────┐
│ 👥 Mahasiswa            [Import CSV] [+ Tambah Mahasiswa]  │
│    Kelola data mahasiswa TRPL                              │
├────────────────────────────────────────────────────────────┤
│ [🔍 Cari nama/NIM/email]  [Angkatan▾] [Status▾] [Reset]   │
├────────────────────────────────────────────────────────────┤
│ Showing 1-20 of 1,234           [Density▾] [Columns▾] [📤] │
├─┬─────┬──────────────┬──────────────┬──────────┬───────────┤
│☐│ 📷  │ NIM          │ Nama         │ Status   │ ⋯         │
├─┼─────┼──────────────┼──────────────┼──────────┼───────────┤
│☐│ [R] │ 22001234     │ Riki M.      │ ✅ Aktif │ ⋯         │
│☐│ [B] │ 22001235     │ Bayu W.      │ ⚠️ Reset │ ⋯         │
├─┴─────┴──────────────┴──────────────┴──────────┴───────────┤
│ [« Prev]   Hal 1 of 62   [Next »]    20 per hal ▾          │
└────────────────────────────────────────────────────────────┘
```

**Saat ada row dipilih** (bulk action bar sticky atas):

```
┌────────────────────────────────────────────────────────────┐
│ ✓ 3 dipilih  [Reset Password] [Nonaktifkan] [🗑 Hapus] [×] │
└────────────────────────────────────────────────────────────┘
```

**Action menu per row** (`⋯` dropdown):
- Lihat detail
- Edit
- Reset password
- Lihat enrollments
- (separator)
- Nonaktifkan (warning)
- Hapus (danger)

**Anti-pattern**:
- Action button per row sebagai column (boros space — pakai `⋯`)
- Filter modal terpisah — pakai filter chip horizontal
- Stack table rows jadi card di desktop

### 4.3 Detail / Edit Page

**Referensi**:

| Produk | Insight Pattern |
|--------|-----------------|
| **Linear issue detail** | Split: konten kiri (title + desc + comments) + sidebar kanan (meta status/assignee). |
| **Stripe customer detail** | Tabbed sections (Overview / Activity / Payments / Subscriptions). |
| **Shopify Polaris detail** | Header back button + title + actions. Body card stack per section. |

**Pola untuk MyPresensi (mis. detail mahasiswa)**:

```
┌────────────────────────────────────────────────────────────┐
│ ← Kembali                                                  │
│ 📷 Riki Mahbubillah                       [Edit] [⋯]       │
│    22001234 · TRPL Angkatan 2022                           │
├────────────────────────────────────────────────────────────┤
│ Tab: [Overview] [Riwayat] [Enrollments] [Audit]            │
├────────────────────────────────────────────────────────────┤
│ ┌──────────────────────────┐  ┌─────────────────────────┐  │
│ │ Informasi Akun           │  │ Statistik Cepat         │  │
│ │ Email: riki@politani.id  │  │ Sesi diikuti: 45        │  │
│ │ Telp:  ...               │  │ Persentase: 92%         │  │
│ │ Status: ✅ Aktif         │  │ Pengajuan izin: 3       │  │
│ └──────────────────────────┘  └─────────────────────────┘  │
│ ┌────────────────────────────────────────────────────────┐ │
│ │ Wajah Terdaftar                                        │ │
│ │ ✅ Terdaftar pada 10 Mei 2026                          │ │
│ │ [Reset Wajah]   (destructive — confirm dialog)         │ │
│ └────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────┘
```

**Anti-pattern**:
- Edit langsung inline di list (kecuali field tunggal seperti toggle)
- Modal untuk halaman dengan banyak section — pakai full-page

### 4.4 Form (Create / Edit) — Modal vs Page

**Aturan dari Eleken + LogRocket modal UX**:

| Kondisi | Pakai |
|---------|-------|
| Form ≤ 5 field, 1-step | **Modal** center |
| Form > 5 field atau multi-step | **Full page** atau **side sheet** |
| Form kontekstual (quick add) | **Side sheet** (drawer kanan) |
| Form dengan preview/wizard | **Full page wizard** |

**Pola modal create** (mis. Tambah Lokasi Kampus):

```
                    ┌─────────────────────────────┐
                    │ Tambah Lokasi Kampus     [×]│
                    ├─────────────────────────────┤
                    │ Nama Lokasi                 │
                    │ [_________________________] │
                    │ Latitude                    │
                    │ [_________________________] │
                    │ Longitude                   │
                    │ [_________________________] │
                    │ Radius (meter)              │
                    │ [_________________________] │
                    │      [Batal]  [Simpan]      │
                    └─────────────────────────────┘
```

**Pola full page create** (mis. Tambah Mahasiswa lengkap):

```
┌────────────────────────────────────────────────────────────┐
│ ← Batal                              [Simpan Sebagai Draft]│
│ Tambah Mahasiswa Baru                                      │
├────────────────────────────────────────────────────────────┤
│ Informasi Dasar                                            │
│ ┌────────────────────────────────────────────────────────┐ │
│ │ NIM *               Angkatan *                         │ │
│ │ [_______________]   [2022 ▾]                           │ │
│ │ Nama Lengkap *                                         │ │
│ │ [______________________________________________]       │ │
│ │ Email *                                                │ │
│ │ [______________________________________________]       │ │
│ └────────────────────────────────────────────────────────┘ │
│ Kontak (opsional)                                          │
│ ┌────────────────────────────────────────────────────────┐ │
│ │ No. Telepon    Alamat                                  │ │
│ └────────────────────────────────────────────────────────┘ │
│                              [Batal]  [Simpan & Lanjut]    │  sticky bottom
└────────────────────────────────────────────────────────────┘
```

**Spec form input**:

| Elemen | Spec |
|--------|------|
| Label | 13pt w500 above field, color text-secondary |
| Required indicator | `*` red kecil |
| Input height | 40px (jangan 32px — terlalu tight) |
| Input border | 1px `#D1D5DB`, focus 2px primary |
| Input radius | 8px |
| Helper text | 12pt color text-tertiary below field |
| Error text | 12pt color danger, **inline saat blur** |
| Field gap | 16-20px |
| Section gap | 32px |

**Inline validation wajib** (dari Eleken modal UX): on blur, bukan on keystroke (annoying), bukan on submit (terlambat). Pesan Bahasa Indonesia ramah.

### 4.5 Settings — Tabs / Sections

**Referensi**:

| Produk | Insight |
|--------|---------|
| **Notion settings** | Modal full-screen sidebar kiri (Account / Workspace / Plans / Connections). |
| **Linear settings** | Sidebar kiri grouped (Personal / Workspace / Integrations / Admin). |
| **Shopify Polaris settings** | Grid 2-col cards per category → click → detail page. |
| **Stripe settings** | Tabbed horizontal di atas + sub-section di body. |

**Pola untuk MyPresensi**:

```
┌────────────────────────────────────────────────────────────┐
│ ⚙️  Pengaturan                                             │
│    Konfigurasi sistem MyPresensi                           │
├──────────┬─────────────────────────────────────────────────┤
│ Umum     │  Pengaturan Umum                                │
│ Presensi │  ┌──────────────────────────────────────────┐   │
│ Lokasi   │  │ Nama Institusi                           │   │
│ Wajah    │  │ [Politeknik Pertanian Negeri Samarinda]  │   │
│ Notif    │  │ Tahun Akademik Aktif                     │   │
│ Audit    │  │ [2025/2026 - Genap ▾]                    │   │
│ Backup   │  │ Logo Institusi                           │   │
│          │  │ [upload area]                            │   │
│          │  │                          [Simpan]        │   │
│          │  └──────────────────────────────────────────┘   │
└──────────┴─────────────────────────────────────────────────┘
```

**Sub-section per kategori MyPresensi**:
- **Umum**: nama institusi, tahun akademik, logo, timezone
- **Presensi**: OTP TTL, face verification mode (optional/required)
- **Lokasi**: radius default, list lokasi kampus (CRUD inline)
- **Wajah**: threshold confidence (0.65 default), retry max
- **Notif**: enable email, enable push (kalau FCM nanti)
- **Audit**: retention period, export schedule
- **Backup**: DB schedule, last backup, manual trigger

**Pola "Danger Zone"** (terakhir):

```
┌──────────────────────────────────────────────┐
│ Zona Berbahaya                               │
├──────────────────────────────────────────────┤
│ Reset Threshold ke Default          [Reset]  │
│ Kembalikan ke 0.65 (rekomendasi)             │
├──────────────────────────────────────────────┤
│ Hapus Data Audit > 2 tahun         [Hapus]   │  red
│ Aksi tidak bisa dibatalkan                   │
└──────────────────────────────────────────────┘
```

**Anti-pattern**:
- Semua setting 1 page panjang scroll — discoverability rendah
- Modal untuk setting penuh — pakai dedicated page
- Save button per field — pakai explicit save di bottom section

### 4.6 Audit Log / Activity Timeline

**Referensi**:

| Produk | Insight |
|--------|---------|
| **Linear activity** | Inline activity feed di issue detail. |
| **Stripe Events log** | Timeline kronologis filter actor + event + date. Click → detail JSON. |
| **GitHub audit log** | Group by date, expandable rows dengan diff payload. |
| **Sentry events** | Card per event: icon kategori + title + meta + timestamp + tag. |
| **AppMaster pattern** | [appmaster.io/blog/audit-logging-internal-tools-activity-feed](https://appmaster.io/blog/audit-logging-internal-tools-activity-feed) | Filter actor/action/object/time, export, write-only log. |

**Spec timeline MyPresensi**:

```
┌────────────────────────────────────────────────────────────┐
│ 📜 Audit Log                                  [Export CSV] │
│    Semua aktivitas sistem (forensic)                       │
├────────────────────────────────────────────────────────────┤
│ [🔍 Cari]  [Actor▾]  [Action▾]  [Tgl 7 hari ▾]            │
├────────────────────────────────────────────────────────────┤
│ HARI INI                                                   │
│ ●─ 14:23  Riki M.   submit presensi (Algoritma)            │
│ │         IP: 10.0.0.5 · Device: Pixel 9a                  │
│ ●─ 14:15  Pak Andi  start session (Algoritma)              │
│ │         Lokasi: Lab Komp 2                               │
│ ●─ 13:50  Riki M.   login_mobile                           │
│                                                            │
│ KEMARIN                                                    │
│ ●─ 16:30  admin     reset_student_password (Bayu W.)       │
│ ●─ 10:00  SYSTEM    🚨 mock_location_detected (Bayu W.)    │  danger
│           Sesi: Basis Data · Lokasi: -0.5380, 117.1245     │
└────────────────────────────────────────────────────────────┘
```

**Pola wajib**:
- Group by tanggal ("Hari ini", "Kemarin", "10 Mei 2026") — scanning cepat
- Timeline visual dot + garis vertikal sederhana
- Color-coded action: normal abu, warning amber, danger merah
- Filter persisten di URL (`?actor=riki&action=login&from=2026-05-01`) — bisa di-share
- Detail expandable — click row → show full `details` JSON
- Export filtered result ke CSV

### 4.7 Calendar / Scheduling — Sesi

**Referensi**:

| Produk | Insight |
|--------|---------|
| **Google Calendar** | Week view default, event block colored per kategori. |
| **Sunsama** | [sunsama.com](https://www.sunsama.com/) | Daily focus + week overview, drag-drop. |
| **Cal.com / Calendly** | Available slot view sangat clean. |
| **Notion calendar database** | Calendar view dengan property colored. |
| **DayPilot scheduler** | [daypilot.org](https://www.daypilot.org/) | Resource scheduling — MK = resource, sesi = event. |

**Pattern relevan MyPresensi (List Sesi Dosen)**:

```
┌────────────────────────────────────────────────────────────┐
│ 📅 Sesi                          [📷 QR Display] [+ Sesi]  │
│    Sesi yang Anda buat                                     │
├────────────────────────────────────────────────────────────┤
│ Tab: [Hari Ini] [Minggu Ini] [Akan Datang] [Selesai]       │
├────────────────────────────────────────────────────────────┤
│ ┌────────────────────────────────────────────────────────┐ │
│ │ ⚡ AKTIF SEKARANG                                       │ │  hero card
│ │ Algoritma & Pemrograman                                │ │
│ │ Lab Komp 2 · Mulai 14:00 · 25 dari 32 hadir            │ │
│ │ OTP: 348592   ⌛ Berakhir 02:30                        │ │
│ │ [Tampilkan QR] [Refresh Kode] [Akhiri Sesi]            │ │
│ └────────────────────────────────────────────────────────┘ │
│ Akan Datang                                                │
│ ┌────────────────────────────────────────────────────────┐ │
│ │ 📚 Basis Data       Selasa 16:00-17:30                 │ │
│ │ Online · Belum dimulai                                 │ │
│ │ [Mulai Sesi] [Edit] [Hapus]                            │ │
│ └────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────┘
```

**View toggle** (advanced opsional): List / Calendar week / Timeline gantt.

### 4.8 QR Display / Live Monitor (Dosen)

**Use case**: Dosen klik "Tampilkan QR" → halaman full-screen yang bisa di-show via proyektor.

**Referensi**:

| Produk | Insight |
|--------|---------|
| **Slido / Mentimeter presentation mode** | Full-screen QR + 6-digit code besar + counter peserta live. |
| **Zoom waiting room** | Big text + secondary info. |
| **Kahoot game pin display** | Big PIN + QR + player count live. |

**Pola QR Display MyPresensi**:

```
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║              ALGORITMA & PEMROGRAMAN                         ║
║              Pak Andi · Lab Komp 2                           ║
║                                                              ║
║         ┌─────────────────┐                                  ║
║         │ ░▒▓ QR ░▒▓ QR  │     OTP: 348592                  ║
║         │ ▓░▒ QR ▒░▒ QR  │     ────────────                  ║
║         │ ▒▓░ QR ░▓▒ QR  │     Berakhir 02:30 ⌛             ║
║         └─────────────────┘                                  ║
║                                                              ║
║          25 / 32 mahasiswa sudah hadir                       ║
║          ████████████████░░░  78%                            ║
║                                                              ║
║  [↻ Refresh Kode]   [Akhiri Sesi]            🔒 Mode Layar  ║
╚══════════════════════════════════════════════════════════════╝
```

**Spec**:
- Background solid primary atau dark mode (kontras tinggi proyektor)
- QR 300-400px square di tengah-kiri
- OTP 64-96pt mono font (Plus Jakarta Sans display atau JetBrains Mono)
- Counter update real-time (Supabase Realtime atau polling 3 detik)
- Auto-refresh OTP saat expired (atau prompt dosen)
- Keluar full-screen via `Esc`

**Anti-pattern**:
- Sidebar/top bar tampil di mode presentasi — distract
- QR < 250px — mahasiswa belakang kelas tidak bisa scan
- Background gradient busy — QR susah scan

### 4.9 Live Monitor (Dosen)

```
┌────────────────────────────────────────────────────────────┐
│ 📊 Monitor Sesi: Algoritma & Pemrograman                   │
│    Mulai 14:00 · Berakhir 15:30                            │
├──────────────────────────┬─────────────────────────────────┤
│ ✅ Sudah Hadir (25)      │ ⏳ Belum Hadir (7)              │
│ ┌──────────────────────┐ │ ┌─────────────────────────────┐ │
│ │ [R] Riki   14:05     │ │ │ [F] Fauzan                  │ │
│ │ [B] Bayu   14:07     │ │ │ [G] Galih                   │ │
│ │ [A] Andre  14:08     │ │ │ [H] Hesti                   │ │
│ │ ... 22 lagi          │ │ │ ...                         │ │
│ └──────────────────────┘ │ └─────────────────────────────┘ │
└──────────────────────────┴─────────────────────────────────┘
```

**Update mechanism**:
- Supabase Realtime subscription ke `attendances` — best (instant)
- Atau polling 5 detik kalau Realtime tidak setup

### 4.10 Empty / Loading / Error States

**Dari Art of Styleframe**: *"You need three states for every dashboard component: Loading skeleton, Empty illustration+sentence+CTA, Error red/amber banner with retry."*

| State | Pola | Contoh MyPresensi |
|-------|------|-------------------|
| **Loading** | Skeleton shape (bukan spinner) | Card abu animasi pulse untuk row tabel |
| **Empty** | Icon + judul + 1 kalimat + CTA | "Belum ada mahasiswa. Tambah satu untuk mulai." [+ Tambah] |
| **Error** | Banner inline di komponen (BUKAN modal full-page) | "Gagal memuat data. [Coba Lagi]" |

**Spec skeleton table row**:
- Bg `#E5E7EB` animasi pulse 1-1.5 detik loop
- Shape match row (avatar lingkaran + 2 baris text rectangle)

**Empty state copy ramah Indonesia**:
- ❌ "Tidak ada data"
- ✅ "Belum ada sesi hari ini. Sesi berikutnya: Algoritma — Selasa 14:00"
- ✅ "Belum ada pengajuan izin. Mahasiswa bisa mengajukan via mobile app."

**Error state — JANGAN modal full-page** (Art of Styleframe pengalaman: "One flaky API endpoint made the whole dashboard unusable for 45 minutes"). Pakai banner inline di komponen yang gagal saja, sisanya tetap usable.

---

## 5. Pola Komponen Reusable

### 5.1 Card

| Tipe | Use case | Pattern |
|------|----------|---------|
| **Metric Card** | KPI dashboard | 200-280px, 28-32pt number, sparkline opsional |
| **Info Card** | Detail page section | Header `<h3>` + body grid 2-col label:value |
| **Action Card** | Quick action grid | Icon center + label + tap target full-card |
| **Status Card** | Sesi aktif / alert | Color-coded border-left 4px + icon + content |
| **Empty Card** | Empty state | Icon lingkaran + judul + deskripsi + CTA |

**Spec global**: Bg `#FFFFFF` · Border 1px `#E5E7EB` ATAU shadow soft (pilih satu) · Radius 12-16px · Padding 20-24px.

### 5.2 Button

| Tipe | Pakai | Spec |
|------|-------|------|
| Primary | Aksi utama 1 per halaman | Bg primary, text white, padding 10-12 × 20-24px, pill |
| Secondary | Aksi sekunder | Bg white, border primary, text primary |
| Tertiary | Aksi minor | Text only color primary |
| Destructive | Hapus/danger | Bg/border danger, text danger |
| Disabled | Saat tidak bisa | Opacity 50%, cursor not-allowed |

**Loading state**: Spinner Lucide + text "Menyimpan..." Indonesia.

### 5.3 Badge / Status Pill

| Status | Color | Use case |
|--------|-------|----------|
| Aktif / Hadir | success `#1A7F37` | Sesi aktif, kehadiran |
| Pending / Izin | warning `#9A6700` | Pengajuan menunggu |
| Ditolak / Alpa | danger `#CF222E` | Reject, alpa |
| Info | primary `#5483AD` | Neutral info |
| Inactive | neutral `#6B7280` | Disabled |

**Spec**: Padding 4×10px, radius 8px, bg color 10% alpha, text color 100%.

### 5.4 Search Bar `Cmd+K` Global

Pattern Linear/Stripe: trigger keyboard shortcut + click. Modal full-screen overlay. Group result: Mahasiswa / Dosen / MK / Sesi / Audit. Recent searches saved.

### 5.5 Filter Chip Bar

```
[🔍 Cari]  [Angkatan: 2022 ▾]  [Status: Semua ▾]  [Reset filter]
```
- Filter aktif: bg primary 10% alpha, text primary, `×` mini untuk remove
- Filter inactive: outline only
- "Reset filter" muncul saat ada minimal 1 filter aktif

### 5.6 Pagination

```
[« Prev]   Hal 1 of 62   [1] [2] [3] ... [62]   [Next »]    20 per hal ▾
                                                            Showing 1-20 of 1,234
```

Aturan: Cursor-based untuk halaman jauh, BUKAN OFFSET. Show "Showing X-Y of N". Selector per hal (10/20/50/100). Reset ke hal 1 saat filter berubah.

### 5.7 Tabs

Material 3 / Shadcn: underline indicator pada tab aktif (2-3px primary). Tab aktif primary bold, inaktif text-secondary. Padding 12 vertikal × 16 horizontal.

### 5.8 Modal & Side Sheet

| Tipe | Use case | Width | Position |
|------|----------|-------|----------|
| Modal center | Confirm, form ≤ 5 field | 480-560px | Center dim backdrop |
| Side sheet | Quick add, detail non-blocking | 400-480px | Slide from right |
| Drawer / bottom sheet | Mobile responsive | Full width | Slide from bottom |

**Konvensi confirm destructive**: SweetAlert2 (`@/lib/swal`) — sudah established. 2-step untuk hapus akun: edukasi → konfirmasi. **JANGAN** `window.confirm()` (BUG-008).

### 5.9 Toast / Notification Inline

- Position: top-right
- Duration: success 3s, error 5s, info 4s
- Icon kiri + judul + close `×` kanan
- Pakai `@/lib/swal` `toast.fire({ icon, title })`

### 5.10 Breadcrumb

```
Beranda › Data Master › Mahasiswa › Edit › Riki Mahbubillah
```

Color text-secondary, separator `›`. Last item bold color text-primary, no link. Click level untuk navigate.

---

## 6. Design Tokens

Sudah established di `mypresensi-web/app/globals.css` — **TIDAK perlu ubah**, hanya **konsistenkan**.

### 6.1 Color Tokens

```css
/* Sumber kebenaran: mypresensi-web/app/globals.css (RGB triplet syntax untuk rgb(var()/alpha) Tailwind v3) */

--color-primary:        45 134 255;       /* #2D86FF — Politani Blue, CTA & link */
--color-primary-hover:  30 112 224;       /* #1E70E0 — hover state */
--color-primary-dark:   13 44 94;         /* #0D2C5E — hero gradient end, navy */
--color-primary-subtle: 45 134 255 / 0.10;/* tint untuk bg badge/hover */

--color-accent:         244 180 0;        /* #F4B400 — Gold pita logo Politani */
--color-accent-subtle:  244 180 0 / 0.12;

--color-success:        26 127 55;        /* #1A7F37 */
--color-warning:        154 103 0;        /* #9A6700 */
--color-danger:         207 34 46;        /* #CF222E */

--color-background:     244 246 248;     /* #F4F6F8 — page bg */
--color-surface:        255 255 255;     /* #FFFFFF — card */
--color-border:         226 230 234;     /* #E2E6EA */

--color-text-primary:   28 32 36;        /* #1C2024 */
--color-text-secondary: 99 108 118;      /* #636C76 */
--color-text-disabled:  117 123 130;     /* #757B82 (WCAG AA pass vs white) */
```

Aturan: pakai variable RGB triplet syntax (`rgb(var(--color-primary))`) bukan hex hardcode. Untuk alpha pakai `rgba(var(--color-primary), 0.10)` atau `rgb(var(--color-primary) / 0.10)`. Hero gradient: `linear-gradient(135deg, rgb(var(--color-primary)) 0%, rgb(var(--color-primary-dark)) 100%)` — gold glow lewat `::before` pseudo radial accent.

### 6.2 Typography Scale

```
display-2xl:  36pt / 44 line-height / w800 / Plus Jakarta Sans  (Hero only)
display-xl:   30pt / 38 / w700 / Plus Jakarta Sans              (Page title XL)
display-lg:   24pt / 32 / w700 / Plus Jakarta Sans              (Page title)

heading-md:   20pt / 28 / w700 / Plus Jakarta Sans              (Card hero)
heading-sm:   18pt / 26 / w600 / Plus Jakarta Sans              (Card title)

body-lg:      16pt / 24 / w400 / Inter                          (Body emphasized)
body-md:      14pt / 20 / w400 / Inter                          (Default body)
body-sm:      13pt / 18 / w400 / Inter                          (Sub text)

label-md:     13pt / 18 / w500 / Inter                          (Form label)
label-sm:     12pt / 16 / w600 / Inter UPPERCASE letter-spacing (Section header)
caption:      11pt / 14 / w500 / Inter                          (Timestamp, meta)
```

### 6.3 Spacing Scale (4pt grid)

```
xs: 4   sm: 8   md: 12   lg: 16   xl: 20   2xl: 24   3xl: 32   4xl: 48
```

Aturan: Card padding 20-24px (lg-2xl) · Section gap 32px (3xl) · Row gap tabel 12px (md) · Button padding 10-12 × 20-24px.

### 6.4 Border Radius

```
sm: 6     (chip, badge)
md: 8     (input, button rect, nav item)
lg: 12    (card)
xl: 16    (card hero, modal)
2xl: 20   (card large)
full: 999 (pill button, avatar)
```

### 6.5 Shadow / Elevation

Minimal — Corporate style:

```css
/* Sumber kebenaran: globals.css real — layered dual (drop + ring) ala Linear/Vercel */
shadow-card:        0 1px 2px rgba(15,23,42,0.04),  0 0 0 1px rgba(15,23,42,0.04);   /* Card default */
shadow-card-hover:  0 8px 24px -8px rgba(45,134,255,0.20), 0 0 0 1px rgba(45,134,255,0.18); /* Hover primary tint */
shadow-elevated:    0 4px 12px -2px rgba(15,23,42,0.08), 0 2px 4px -2px rgba(15,23,42,0.04), 0 0 0 1px rgba(15,23,42,0.04);
shadow-hero:        0 10px 30px -8px rgba(13,44,94,0.40), 0 4px 12px -4px rgba(13,44,94,0.20); /* Hero card deep navy */
```

Aturan: pilih **border ATAU shadow**, JANGAN dua. Shadow tinted dengan primary alpha (bukan pure black) untuk feel premium.

---

## 7. Anti-Pattern yang Wajib Dihindari

### 7.1 Layout
- ❌ Duplikasi navigasi top bar + sidebar
- ❌ Top nav sebagai navigation utama untuk dashboard (gunakan sidebar)
- ❌ Sidebar > 280px (waste space)
- ❌ Hamburger menu di desktop (icon rail collapsed lebih baik)

### 7.2 Tabel
- ❌ Action button column per row (pakai `⋯` dropdown)
- ❌ Zebra stripes + hover state bersamaan (visual collision)
- ❌ Pagination 10 row default untuk power user (minimum 20-50)
- ❌ OFFSET pagination untuk page jauh (pakai cursor-based)
- ❌ Stack table rows jadi card di desktop

### 7.3 Form
- ❌ Validasi on keystroke (annoying) atau on submit only (terlambat) — pakai **on blur**
- ❌ Modal untuk form > 5 field — pakai full page
- ❌ Save button per field — pakai explicit save di bottom
- ❌ Pesan error teknis ("Invalid input") — pakai Bahasa Indonesia spesifik

### 7.4 Empty / Loading / Error
- ❌ Spinner-only loading — pakai skeleton matching shape
- ❌ Halaman kosong tanpa konteks — wajib pesan + CTA
- ❌ Modal full-page untuk error — pakai banner inline
- ❌ Pesan error mentah dari Supabase — sanitasi

### 7.5 Card / Visual
- ❌ Gradient warna acak — corporate style minimal
- ❌ Emoji untuk icon — pakai Lucide
- ❌ Border + shadow + dot indicator bersamaan — pilih max 2

### 7.6 Settings
- ❌ Semua setting 1 page panjang scroll — pakai tab/section
- ❌ Modal untuk setting page penuh — pakai dedicated page
- ❌ Tidak ada save indicator — user ragu apakah berhasil

### 7.7 Audit Log
- ❌ Plain tabel tanpa grouping tanggal
- ❌ Hide IP/device dari forensic view (itu yang dibutuhkan)
- ❌ Tidak bisa filter by actor/action — admin frustrasi

### 7.8 Security & UX Pesan
- ❌ "User dengan email X tidak ditemukan" (user enumeration) — pakai "Email atau password salah"
- ❌ Stack trace tampil ke user — log ke server, tampilkan pesan generik
- ❌ Toast > 5 detik untuk pesan biasa (terlalu lama)

---

## 8. Action Items Prioritized

Untuk MyPresensi admin/dosen web. Cek dulu kondisi existing sebelum implement.

### 🔴 High Priority (sebelum demo PBL)

1. **Audit shell layout konsistensi** — pastikan semua halaman pakai shell yang sama (sidebar 256px + page header + content grid). Cek `mypresensi-web/app/(dashboard)/layout.tsx` + halaman individu.

2. **Sidebar grouping konsisten** — section header (DATA MASTER / OPERASIONAL / SISTEM) dengan style `label-sm` uppercase. Pastikan order konsisten antar role admin/dosen.

3. **Page header standar** — setiap halaman dalam wajib: icon Lucide + title + subtitle + action button kanan. Tambah breadcrumb di halaman level 2+.

4. **Tabel master data** (Mahasiswa/Dosen/MK) — filter chip di atas, pagination footer, action `⋯` dropdown per row, bulk select + bulk action bar. Konsisten across 3 master.

5. **Dashboard metric strip 4 KPI** — Admin: total mhs / dosen / MK / sesi aktif. Dosen: sesi hari ini / izin pending / persentase rata-rata MK / total mahasiswa diampu. Pakai spec card 200-280px.

6. **Empty state semua list** — tabel kosong wajib pesan ramah Indonesia + CTA. Audit semua `useFormState({ items: [] })` path.

7. **Audit log timeline** — group by tanggal + filter actor/action/date di URL + export CSV. Saat ini mungkin masih plain tabel.

### 🟡 Medium Priority

8. **Settings page tab/section** — pecah single-page panjang jadi tab vertikal kiri (Umum/Presensi/Lokasi/Wajah/Notif/Audit/Backup) + Danger Zone di akhir.

9. **QR Display full-screen mode** — dosen klik "Tampilkan QR" → halaman tanpa sidebar/topbar, QR 300-400px, OTP 64-96pt mono, counter live, kontras tinggi proyektor.

10. **Live monitor real-time** — pakai Supabase Realtime subscription ke `attendances` agar update instant tanpa refresh manual.

11. **Inline validation form** — semua form Zod-backed dengan error muncul on blur per field, BUKAN saat submit. Pesan Bahasa Indonesia ramah.

12. **Detail page tabbed** — halaman detail mahasiswa/dosen/MK dengan tabs (Overview/Riwayat/Audit) bukan single long page scroll.

### 🟢 Nice-to-Have

13. **Search global `Cmd+K`** — modal search across mahasiswa/dosen/MK/sesi/audit. Pakai pattern Linear/Stripe.

14. **Density toggle tabel** — comfortable (52px row) vs dense (36px row). Power user pilih.

15. **Column toggle tabel** — show/hide column non-essential. Persist preference di localStorage.

16. **Saved filter** (Jira-style) — admin sering pakai filter sama → "Save current filter as: Mahasiswa Aktif Angkatan 2022".

17. **Export wizard multi-step** — Filter → Preview → Format (CSV/PDF) → Download. Tidak one-shot.

18. **Calendar week view** untuk sesi (opsional advanced) — toggle dari list ke calendar grid Mon-Sun.

---

## 9. Daftar Referensi Lengkap

### 9.1 Produk Web Admin Top-Tier (di luar presensi)

**Project Management & Productivity**:
- Linear — [linear.app](https://linear.app)
- Linear redesign 2024 — [linear.app/now/how-we-redesigned-the-linear-ui](https://linear.app/now/how-we-redesigned-the-linear-ui)
- Linear sidebar refresh — [linear.app/changelog/2024-12-18-personalized-sidebar](https://linear.app/changelog/2024-12-18-personalized-sidebar)
- Notion — [notion.so](https://notion.so)
- Notion sidebar guide — [notion.com/help/navigate-with-the-sidebar](https://www.notion.com/help/navigate-with-the-sidebar)
- Sunsama — [sunsama.com](https://www.sunsama.com/)

**Fintech & Payment Admin**:
- Stripe Dashboard — [dashboard.stripe.com](https://dashboard.stripe.com)
- Stripe Components — [docs.stripe.com/stripe-apps/components](https://docs.stripe.com/stripe-apps/components)

**Developer & DevOps Platform**:
- Vercel new dashboard — [vercel.com/try/new-dashboard](https://vercel.com/try/new-dashboard)
- Supabase Studio — [deepwiki.com/supabase/supabase/2.1-studio-dashboard](https://deepwiki.com/supabase/supabase/2.1-studio-dashboard)
- Supabase Design Blog — [supabase.com/blog/how-design-works-at-supabase](https://supabase.com/blog/how-design-works-at-supabase)
- Supabase UI Library — [supabase.com/ui](https://supabase.com/ui)

**Analytics**:
- PostHog Dashboards — [posthog.com/docs/product-analytics/dashboards](https://posthog.com/docs/product-analytics/dashboards)
- PostHog Real-time template — [posthog.com/templates/real-time-dashboard](https://posthog.com/templates/real-time-dashboard)

**E-commerce & Enterprise**:
- Shopify Polaris React — [polaris-react.shopify.com](https://polaris-react.shopify.com/)
- Shopify Polaris Design — [polaris-react.shopify.com/design](https://polaris-react.shopify.com/design)
- Shopify Polaris Layout — [polaris-react.shopify.com/design/layout](https://polaris-react.shopify.com/design/layout)
- Shopify Polaris Design System surf — [designsystems.surf/design-systems/shopify](https://designsystems.surf/design-systems/shopify)

**Atlassian (Jira/Confluence/Trello)**:
- Atlassian Design System — [designsystems.surf/design-systems/atlassian](https://designsystems.surf/design-systems/atlassian)
- Jira Customize Layout — [support.atlassian.com/.../customize-the-layout-and-design-of-jira-applications](https://support.atlassian.com/jira-cloud-administration/docs/customize-the-layout-and-design-of-jira-applications/)
- Jira UI Evolution 2025 — [community.atlassian.com/.../jira-s-ever-evolving-ui-2025-edition](https://community.atlassian.com/forums/Jira-articles/Jira-s-ever-evolving-UI-2025-Edition/ba-p/2966105)

**HRIS / Indonesia Direct Competitor**:
- Mekari Talenta Dashboard — [help-center.talenta.co/.../Dashboard-Menu-Overview](https://help-center.talenta.co/hc/en-us/articles/9123854858009-Dashboard-Menu-Overview)
- Mekari Talenta Dashboard New — [help-center.talenta.co/.../Dashboard-Menu-Overview-New-Version](https://help-center.talenta.co/hc/en-us/articles/41781114349721-Dashboard-Menu-Overview-New-Version)
- Talenta Product — [mekari.com/produk/talenta](https://mekari.com/produk/talenta/)

### 9.2 Component Library & Templates

- shadcn/ui Blocks (CRUD User List) — [shadcn.io/blocks/crud-list-users-01](https://www.shadcn.io/blocks/crud-list-users-01)
- shadcn Sidebar Patterns — [medium.com/.../shadcn-sidebar-patterns](https://medium.com/write-a-catalyst/7-best-shadcn-sidebar-patterns-for-modern-saas-dashboards-ef1235cc920d)
- Vercel Admin Templates — [vercel.com/templates/admin-dashboard](https://vercel.com/templates/admin-dashboard)
- Next.js + shadcn Admin — [vercel.com/templates/next.js/next-js-and-shadcn-ui-admin-dashboard](https://vercel.com/templates/next.js/next-js-and-shadcn-ui-admin-dashboard)
- v0 Dashboard Templates — [v0.app/templates/dashboards](https://v0.app/templates/dashboards)
- TailAdmin Top SaaS Templates 2026 — [tailadmin.com/blog/saas-dashboard-templates](https://tailadmin.com/blog/saas-dashboard-templates)

### 9.3 Articles & Case Studies (Wajib Baca)

**Layout & Patterns**:
- **Dashboard Design Patterns 2026 (Art of Styleframe)** — [artofstyleframe.com/blog/dashboard-design-patterns-web-apps](https://artofstyleframe.com/blog/dashboard-design-patterns-web-apps/) — **WAJIB**, sumber utama dokumen ini
- Dashboard UX (Lazarev) — [lazarev.agency/articles/dashboard-ux-design](https://www.lazarev.agency/articles/dashboard-ux-design)
- SaaS Layout Best Practices — [medium.com/.../designing-a-layout-structure-for-saas-products](https://medium.com/design-bootcamp/designing-a-layout-structure-for-saas-products-best-practices-d370211fb0d1)
- SaaS Navigation (Lollypop) — [lollypop.design/blog/2025/december/saas-navigation-menu-design](https://lollypop.design/blog/2025/december/saas-navigation-menu-design/)

**Tabel & Data**:
- Data Table UX Patterns (Pencil & Paper) — [pencilandpaper.io/articles/ux-pattern-analysis-enterprise-data-tables](https://www.pencilandpaper.io/articles/ux-pattern-analysis-enterprise-data-tables)
- UX Patterns Data Table — [uxpatterns.dev/patterns/data-display/table](https://uxpatterns.dev/patterns/data-display/table)
- Justinmind Data Table Design — [justinmind.com/ui-design/data-table](https://www.justinmind.com/ui-design/data-table)
- Enterprise Data Tables (Stephanie Walter) — [stephaniewalter.design/blog/essential-resources-design-complex-data-tables](https://stephaniewalter.design/blog/essential-resources-design-complex-data-tables/)
- Pagination Importance — [alfdesigngroup.com/post/why-pagination-is-important-for-table-design](https://www.alfdesigngroup.com/post/why-pagination-is-important-for-table-design)

**Modal vs Page (Form UX)**:
- Modal UX (Eleken) — [eleken.co/blog-posts/modal-ux](https://www.eleken.co/blog-posts/modal-ux)
- Modal UX Patterns (LogRocket) — [blog.logrocket.com/ux-design/modal-ux-design-patterns-examples-best-practices](https://blog.logrocket.com/ux-design/modal-ux-design-patterns-examples-best-practices/)
- Form Inspiration (Muzli) — [muz.li/inspiration/forms](https://muz.li/inspiration/forms/)

**KPI & Metric Cards**:
- Anatomy of KPI Card — [nastengraph.substack.com/p/anatomy-of-the-kpi-card](https://nastengraph.substack.com/p/anatomy-of-the-kpi-card)
- KPI Dashboard Design (Statsig) — [statsig.com/perspectives/kpi-dashboard-design-tips-metrics](https://www.statsig.com/perspectives/kpi-dashboard-design-tips-metrics)
- Better KPI Visualizations — [tabulareditor.com/blog/kpi-card-best-practices-dashboard-design](https://tabulareditor.com/blog/kpi-card-best-practices-dashboard-design)

**Audit Log / Activity**:
- Audit Logging Internal Tools (AppMaster) — [appmaster.io/blog/audit-logging-internal-tools-activity-feed](https://appmaster.io/blog/audit-logging-internal-tools-activity-feed)
- Unified Audit Timeline — [appmaster.io/blog/unified-audit-timeline-schema-ui](https://appmaster.io/blog/unified-audit-timeline-schema-ui)
- Activity Logs Pattern (alguidelines) — [alguidelines.dev/docs/navpatterns/patterns/activity-log](https://alguidelines.dev/docs/navpatterns/patterns/activity-log/)

**Calendar / Scheduling**:
- Calendar UI Examples 33 (Eleken) — [eleken.co/blog-posts/calendar-ui](https://www.eleken.co/blog-posts/calendar-ui)
- Calendar UI Examples (BricxLabs) — [bricxlabs.com/blogs/calendar-ui-examples](https://bricxlabs.com/blogs/calendar-ui-examples)

**Settings**:
- SaaS UI Settings Patterns — [saasui.design](https://www.saasui.design/)
- Designing Settings Case Study — [medium.com/.../redesigning-settings](https://medium.com/@sanyamjain18/%EF%B8%8F-redesigning-settings-1-of-2-architecting-the-interface-76225cd7a6df)

### 9.4 Inspiration Galleries

- **SaaSframe** — [saasframe.io/categories/dashboard](https://www.saasframe.io/categories/dashboard) (166 dashboard examples 2026)
- **Mobbin** — [mobbin.com](https://mobbin.com/) (paywalled tapi punya gallery free terbatas)
- **Dribbble SaaS Dashboard** — [dribbble.com/tags/saas-dashboard](https://dribbble.com/tags/saas-dashboard)
- **Behance** — [behance.net](https://www.behance.net/) (case studies panjang)
- **Pinterest SaaS Dashboard** — [pinterest.com/search/pins/?q=saas%20dashboard](https://www.pinterest.com/search/pins/?q=saas%20dashboard)

### 9.5 Design System Official

- shadcn/ui — [ui.shadcn.com](https://ui.shadcn.com)
- Shopify Polaris — [polaris-react.shopify.com](https://polaris-react.shopify.com/)
- Atlassian Design System — [atlassian.design](https://atlassian.design)
- Cash App Design System — [designsystems.surf/design-systems/cashapp](https://designsystems.surf/design-systems/cashapp)
- PostHog DESIGN.md inspiration — [getdesign.md/posthog/design-md](https://getdesign.md/posthog/design-md)

---

## 10. Cara Pakai Dokumen Ini

### 10.1 Untuk User (Riki)

1. **Browse referensi** — buka link di laptop, screenshot bagian yang menarik (sidebar Linear, KPI Stripe, tabel shadcn). Simpan di `docs/ui-research/mockups/`.

2. **Prioritize** — pakai §8 Action Items sebagai roadmap improvement. **Mulai dari High Priority** dulu.

3. **Iterate per halaman** — implement 1 halaman sekaligus, tes manual, gather feedback. JANGAN refactor seluruh app sekaligus.

4. **Update dokumen** — kalau temuan baru saat implementasi, append section "Update YYYY-MM-DD" di bawah masing-masing.

### 10.2 Untuk AI Agent (Cascade)

Sebelum redesign halaman admin web:

1. **WAJIB baca** §3 (shell layout) + §4 section yang relevan + §6 design tokens + §7 anti-pattern.
2. **Pertahankan style direction §2** — JANGAN redesign radikal.
3. **Action items §8** priority order — High dulu sebelum Medium.
4. **Verifikasi setelah implement**: `npm run type-check` + `npm run lint` + screenshot 3-state (loading/empty/error).
5. **Konsisten dengan komponen yang sudah ada** — reuse `.card`, `.btn-primary`, `.summary-card`, `.data-table`, `.badge-success/warning/danger`, `.input-field`, `.skeleton`, `.sidebar-nav-item` di `app/globals.css`. JANGAN bikin kelas baru tanpa alasan.
6. **Pesan UI Bahasa Indonesia ramah** — tidak teknis, tidak bocor struktur DB.
7. **Audit log** untuk semua mutasi — `logAudit({ action: 'snake_case', details })`.

### 10.3 Sumber Kebenaran Terkait

- `docs/plans/implementation_plan.md` — plan teknis & threat analysis
- `docs/ui-research/mobile-references.md` — referensi mobile mahasiswa (sister file)
- `.windsurf/rules/03-design-and-libraries.md` — design principles + library lock
- `.windsurf/rules/04-security-and-privacy.md` — security rules untuk fitur sensitif
- `mypresensi-web/app/globals.css` — design tokens runtime

---

**Last updated**: 2026-05-15 (initial version, hasil riset komprehensif dari user request 2026-05-15).
**Next review**: setelah implement Action Items §8 High Priority, atau saat ada gap baru ditemukan saat field test.


