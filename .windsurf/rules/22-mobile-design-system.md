# Mobile Design System — MyPresensi

> **Status**: 🔒 FUNDAMENTAL — Rule ini wajib diikuti saat membangun atau mengubah UI mobile. Selaras dengan web (`mypresensi-web/app/globals.css`) untuk konsistensi cross-platform.
>
> **Mockup referensi visual**: `@docs/ui-research/mockups/mobile-mockup.html` (preview via `python -m http.server 8765` di folder mockups).
>
> **Riset referensi mendalam**: `@docs/ui-research/mobile-references.md`.
>
> **Anti-flat principle**: Mobile MyPresensi WAJIB pakai **layered shadows + duotone icons + hero glow + pill buttons + subtle gradients**. Bukan flat card-with-border style — itu terlihat AI-generated dan kurang premium.

## A. Sumber Kebenaran (Source of Truth)

| Token | Sumber | Status |
|-------|--------|--------|
| Color palette | `mypresensi-web/app/globals.css` `:root` block | ⚠️ **Mobile WAJIB sync ke ini** (saat ini masih `#5483AD`, target `#2D86FF`) |
| Typography | Plus Jakarta Sans (heading) + Inter (body) | ✅ Sudah konsisten |
| Spacing | Material 8pt grid (4/8/12/16/20/24/32/40) | ✅ Sudah konsisten |
| Radius | Card 16px, Button 999px (pill), Input 8px | ⚠️ Mobile saat ini banyak pakai 12-14px untuk button — perlu migrasi |
| Shadows | Layered dual (drop + ring) ala Linear/Vercel | ❌ Mobile saat ini flat — WAJIB upgrade |

**Catatan migrasi**: User sudah approve sync warna mobile ke web (sesi 2026-05-15). Update `lib/core/theme/app_colors.dart` perlu dilakukan sebagai task implementasi terpisah, lihat §F.

## B. Color Tokens — WAJIB

### Brand (Politani Web)

```dart
// lib/core/theme/app_colors.dart — TARGET (belum applied)
static const Color primary       = Color(0xFF2D86FF); // CTA & link utama
static const Color primaryHover  = Color(0xFF1E70E0); // hover state
static const Color primaryDark   = Color(0xFF0D2C5E); // hero gradient end (navy)
static const Color primaryDeep   = Color(0xFF082040); // shadow tint terdalam
static const Color primarySurface = Color(0xFFEAF3FF); // 10% tint background

// Accent — Gold pita logo Politani
static const Color accent     = Color(0xFFF4B400);
static const Color accentSoft = Color(0x4DF4B400); // 30% alpha — untuk hero glow
```

**Kapan pakai accent gold**:
- ✅ Hero card glow (radial top-right) — signature visual
- ✅ Highlight angka penting (`text-accent` pada nominal/persentase)
- ✅ Trend pill `up` indicator (opsional)
- ❌ JANGAN pakai untuk button utama (primary blue selalu menang)
- ❌ JANGAN pakai untuk text body (warna gold rendah contrast)

### Status Colors

```dart
static const Color success         = Color(0xFF1A7F37);
static const Color successSurface  = Color(0xFFECFDF5);  // 5% tint solid
static const Color successTint     = Color(0x1A1A7F37);  // 10% alpha — duotone bg

static const Color warning         = Color(0xFF9A6700);
static const Color warningSurface  = Color(0xFFFFFBEB);
static const Color warningTint     = Color(0x1A9A6700);

static const Color danger          = Color(0xFFCF222E);
static const Color dangerSurface   = Color(0xFFFEF2F2);
static const Color dangerTint      = Color(0x1ACF222E);

static const Color info            = Color(0xFF0969DA);
static const Color infoSurface     = Color(0xFFEFF6FF);
static const Color infoTint        = Color(0x1A0969DA);
```

**Pattern duotone — WAJIB untuk icon box & badge**:
- Background: `xxxTint` (alpha 10%)
- Foreground (icon/text): `xxx` (solid 100%)
- Contoh: `success-tint` background + `success` icon = clean duotone

### Neutrals

```dart
static const Color bg              = Color(0xFFF4F6F8); // canvas/scaffold
static const Color surface         = Color(0xFFFFFFFF); // card
static const Color surfaceSunken   = Color(0xFFF0F2F4); // input field bg, modal backdrop
static const Color border          = Color(0xFFE2E6EA); // border subtle (tapi prefer shadow)
static const Color borderStrong    = Color(0xFFD1D7DE); // border emphasis
```

### Text

```dart
static const Color textPrimary     = Color(0xFF1C2024); // judul, body utama
static const Color textSecondary   = Color(0xFF636C76); // subtitle, meta info
static const Color textTertiary    = Color(0xFF757B82); // disabled, caption
// Catatan: textTertiary dinaikkan dari #AEB4BB ke #757B82 untuk WCAG AA pass (4.55:1 vs white)
```

## C. Shadow Tokens — Anti-Flat Principle

> **Iron Law**: JANGAN pakai `border: 1px solid` untuk separation card. Pakai **layered shadow** untuk hidup.

### Layered Shadow Library

```dart
// Helper: BoxShadow list
class AppShadows {
  // Card normal — drop subtle + ring
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 2, offset: Offset(0, 1)),  // drop
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 0, spreadRadius: 1),       // ring
  ];

  // Card hover — primary tinted
  static const List<BoxShadow> cardHover = [
    BoxShadow(
      color: Color(0x332D86FF),
      blurRadius: 24,
      offset: Offset(0, 8),
      spreadRadius: -8,
    ),
    BoxShadow(color: Color(0x2E2D86FF), blurRadius: 0, spreadRadius: 1),
  ];

  // Card elevated — multi-layer drop
  static const List<BoxShadow> cardElevated = [
    BoxShadow(color: Color(0x140F172A), blurRadius: 12, offset: Offset(0, 4), spreadRadius: -2),
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 4, offset: Offset(0, 2), spreadRadius: -2),
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 0, spreadRadius: 1),
  ];

  // Hero card — DRAMATIC dengan navy tint
  static const List<BoxShadow> hero = [
    BoxShadow(
      color: Color(0x660D2C5E), // 40% alpha navy
      blurRadius: 30,
      offset: Offset(0, 10),
      spreadRadius: -8,
    ),
    BoxShadow(
      color: Color(0x330D2C5E), // 20% alpha navy
      blurRadius: 12,
      offset: Offset(0, 4),
      spreadRadius: -4,
    ),
  ];

  // FAB — primary tinted
  static const List<BoxShadow> fab = [
    BoxShadow(color: Color(0x662D86FF), blurRadius: 16, offset: Offset(0, 8), spreadRadius: -4),
    BoxShadow(color: Color(0x332D86FF), blurRadius: 0, spreadRadius: 1),
  ];

  // Button primary
  static const List<BoxShadow> button = [
    BoxShadow(color: Color(0x4D2D86FF), blurRadius: 2, offset: Offset(0, 1)),
  ];

  // Button hover
  static const List<BoxShadow> buttonHover = [
    BoxShadow(color: Color(0x732D86FF), blurRadius: 16, offset: Offset(0, 6), spreadRadius: -4),
  ];
}
```

### Aturan Pakai

| Komponen | Shadow | Kapan |
|----------|--------|-------|
| Card biasa (list item, info card) | `AppShadows.card` | Default |
| Card hover/pressed | `AppShadows.cardHover` | InkWell tap, ListTile interactive |
| Card elevated (modal, bottom sheet, dropdown) | `AppShadows.cardElevated` | Surface yang harus "menonjol" |
| Hero card (Home "Sesi Aktif", Summary History) | `AppShadows.hero` | Card statement utama 1 per screen max |
| FAB (Submit izin, Add new) | `AppShadows.fab` | Floating action button |
| Button primary | `AppShadows.button` → hover `buttonHover` | Tombol aksi utama |

**JANGAN**:
- ❌ Pakai `Border.all(color: AppColors.border, width: 1)` SEBAGAI pengganti shadow. Border boleh DI ATAS shadow untuk emphasis, tidak untuk separation.
- ❌ Pakai `elevation: X` di Material — tidak bisa di-tint ke primary/navy. Pakai `Container` + `decoration: BoxDecoration(boxShadow: ...)`.
- ❌ Pakai shadow heavy (blurRadius > 30) di card biasa. Itu untuk hero saja.

## D. Component Patterns — WAJIB

### D.1 Hero Card (Statement Surface)

**Pattern**: Gradient primary → navy + gold radial glow + white highlight + dramatic shadow.

**Anatomy**:
1. `BoxDecoration` background: `LinearGradient` 135deg `[primary, primaryDark]`
2. `boxShadow: AppShadows.hero`
3. Anak Stack: Container kosong `Positioned(top: -40%, right: -15%)` dengan `BoxDecoration(gradient: RadialGradient(colors: [accentSoft, transparent]))` 220x220 — ini **gold glow signature**
4. Anak Stack: Container kosong `Positioned(bottom: -30%, left: 25%)` dengan `RadialGradient` white 14% — depth highlight
5. Content `Column` di z-index atas (otomatis di Stack — last child on top)

**Reference visual**: lihat `mobile-mockup.html` Screen 1 (Home Hero "Sesi Aktif").

**Implementasi singkat (Flutter)**:

```dart
class HeroCard extends StatelessWidget {
  final Widget child;
  const HeroCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.hero,
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // Gold glow top-right
          Positioned(
            top: -88, right: -33,
            child: Container(
              width: 220, height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.accentSoft, Color(0x00F4B400)],
                  stops: [0.0, 0.65],
                ),
              ),
            ),
          ),
          // White highlight bottom-left
          Positioned(
            bottom: -54, left: 75,
            child: Container(
              width: 180, height: 180,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x24FFFFFF), Color(0x00FFFFFF)],
                  stops: [0.0, 0.7],
                ),
              ),
            ),
          ),
          // Content
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }
}
```

**Aturan pakai**: 1 hero card per screen MAX. Jangan banyak hero — kehilangan signifikansi.

### D.2 KPI Icon Box (Duotone)

**Pattern**: Container 38x38 rounded 12px dengan tint background + solid icon foreground.

**Variants**: `primary` (default), `success`, `warning`, `danger`, `info`, `accent`.

```dart
class KpiIconBox extends StatelessWidget {
  final IconData icon;
  final KpiColor variant;
  final double size;

  const KpiIconBox({
    super.key,
    required this.icon,
    this.variant = KpiColor.primary,
    this.size = 38,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _resolve(variant);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: colors.fg, size: size * 0.47),
    );
  }

  ({Color bg, Color fg}) _resolve(KpiColor v) => switch (v) {
        KpiColor.primary => (bg: AppColors.primarySurface, fg: AppColors.primary),
        KpiColor.success => (bg: AppColors.successTint, fg: AppColors.success),
        KpiColor.warning => (bg: AppColors.warningTint, fg: AppColors.warning),
        KpiColor.danger  => (bg: AppColors.dangerTint,  fg: AppColors.danger),
        KpiColor.info    => (bg: AppColors.infoTint,    fg: AppColors.info),
        KpiColor.accent  => (bg: AppColors.accentSoft,  fg: AppColors.warning),
      };
}

enum KpiColor { primary, success, warning, danger, info, accent }
```

**Pakai untuk**: quick action grid, activity feed, summary card icons, list item leading icon.

### D.3 Card Default

**Pattern**: White surface + radius 16 + layered shadow + padding 16.

```dart
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool elevated;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: elevated ? AppShadows.cardElevated : AppShadows.card,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: card,
    );
  }
}
```

### D.4 Button Pill (Primary & Secondary)

**Pattern**: Pill shape (radius 999), padding 13x20, font Plus Jakarta Sans 600, shadow primary tinted.

```dart
// Primary
ElevatedButton(
  onPressed: () {},
  style: ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(999),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
    textStyle: const TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontWeight: FontWeight.w600,
      fontSize: 14,
      letterSpacing: 0.14,
    ),
    elevation: 0, // pakai BoxShadow custom via Container parent
  ).copyWith(
    overlayColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.hovered)) return AppColors.primaryHover.withValues(alpha: 0.1);
      return null;
    }),
  ),
  child: const Text('Submit'),
)

// Secondary (outline pill)
OutlinedButton(
  onPressed: () {},
  style: OutlinedButton.styleFrom(
    foregroundColor: AppColors.primary,
    side: const BorderSide(color: AppColors.primary, width: 1.5),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(999),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
  ),
  child: const Text('Lihat Detail'),
)
```

**Lebar tombol**: Default `width: double.infinity` di mobile saat tombol berdiri sendiri di bottom screen. Di list/inline, tombol sesuai konten + icon.

### D.5 Trend Pill (▲/▼ Badge)

**Pattern**: Pill kecil dengan icon arrow + persentase, untuk indicator perubahan.

```dart
class TrendPill extends StatelessWidget {
  final TrendDirection direction;
  final String text; // "+12%" atau "-3"

  const TrendPill({super.key, required this.direction, required this.text});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (direction) {
      TrendDirection.up => (AppColors.successTint, AppColors.success, Icons.arrow_upward_rounded),
      TrendDirection.down => (AppColors.dangerTint, AppColors.danger, Icons.arrow_downward_rounded),
      TrendDirection.neutral => (Color(0x1A636C76), AppColors.textSecondary, Icons.remove_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 2),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w600,
              fontSize: 11,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

enum TrendDirection { up, down, neutral }
```

**Pakai untuk**: summary card history (% kehadiran vs minggu lalu), dashboard analytics.

### D.6 Hero Badge (Animated Pulse)

Status indicator di hero card dengan pulse dot.

```dart
class HeroBadge extends StatelessWidget {
  final String label;
  final Color dotColor;

  const HeroBadge({super.key, required this.label, this.dotColor = const Color(0xFF4ADE80)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseDot(color: dotColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 11,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
// _PulseDot: AnimationController scale 1.0 → 1.3 + opacity 1 → 0.7, repeat reverse, duration 1s
```

## E. Layout & Spacing Standards

### Page Structure

Setiap screen WAJIB punya struktur:

```
SafeArea
└── Scaffold (background: AppColors.bg)
    ├── AppBar (transparent atau colored sesuai context)
    ├── Body — single Column atau ListView
    │   ├── (Optional) Hero card di atas (1 max)
    │   ├── Section title (16pt w600 Plus Jakarta Sans)
    │   ├── Content cards (gap antar card 8-12px)
    │   └── (3-state widget: skeleton / empty / error sesuai kondisi)
    └── (Optional) BottomNavigationBar Material 3 / FAB
```

### Spacing Rhythm (4pt grid)

| Token | Pixel | Pakai untuk |
|-------|-------|-------------|
| `xs` | 4 | Inline gap rapat (icon dengan label, dot dengan text) |
| `sm` | 8 | Gap antar card di list, padding kompak |
| `md` | 12 | Card internal padding compact, gap antar group kecil |
| `lg` | 16 | Card padding standar, page horizontal padding |
| `xl` | 20 | Hero card padding, modal padding |
| `2xl` | 24 | Section gap (antar group besar) |
| `3xl` | 32 | Page top/bottom padding, hero margin |
| `4xl` | 40 | Mega gap (jarang) |

### Border Radius

| Token | Pixel | Pakai untuk |
|-------|-------|-------------|
| `sm` | 8 | Chip, badge, small pill, input |
| `md` | 12 | Quick action item, KPI icon box |
| `lg` | 14 | Card kompak |
| `xl` / `card` | 16 | **Card standar (default)** |
| `2xl` | 20 | Bottom sheet top corner, modal |
| `button` | 999 | **Button (selalu pill)** |
| `full` | 999 | Avatar, pulse dot, FAB circular |

## F. Migration Plan — `app_colors.dart`

⚠️ **TASK PENDING** (perlu user approval sebelum apply):

1. Update `lib/core/theme/app_colors.dart`:
   - `primary` `#5483AD` → `#2D86FF`
   - `primaryDark` `#3A6B8F` → `#0D2C5E`
   - `primaryLight` `#7BA3C7` → DROP (tidak dipakai di pattern web)
   - `primarySurface` `#E8F0F7` → `#EAF3FF`
   - **TAMBAH** `primaryHover` `#1E70E0`
   - **TAMBAH** `primaryDeep` `#082040`
   - **TAMBAH** `accent` `#F4B400` + `accentSoft` (alpha 30%)
   - Update text colors: `textPrimary` `#1A1D21` → `#1C2024`, `textSecondary` `#6B7280` → `#636C76`
   - Update border: `border` `#E2E6EA` (sudah sama)
   - Update gradient: `primaryGradient` colors → `[primary, primaryDark]` (sudah benar struktur, ganti nilai)
   - **TAMBAH** `headerGradient` 3-stop dengan accent gold

2. Buat file baru `lib/core/theme/app_shadows.dart`:
   - Class `AppShadows` dengan const lists: `card`, `cardHover`, `cardElevated`, `hero`, `fab`, `button`, `buttonHover` (lihat §C)

3. Buat file baru `lib/shared/widgets/`:
   - `hero_card.dart` — pattern §D.1
   - `kpi_icon_box.dart` — pattern §D.2
   - `app_card.dart` — pattern §D.3
   - `trend_pill.dart` — pattern §D.5
   - `hero_badge.dart` — pattern §D.6

4. Update existing screens secara bertahap:
   - `home_screen.dart` — apply hero card untuk "Sesi Aktif"
   - `history_screen.dart` — summary card sebagai hero + trend pill kehadiran
   - `attendance_result_screen.dart` — hero icon dengan pop animation + breakdown card
   - Quick action di home — pakai `KpiIconBox` duotone
   - Semua list item di history/notif/leave — replace `Border.all` dengan `AppShadows.card`

5. Verifikasi:
   - `flutter analyze` 0 issues
   - Screenshot 3-state per screen untuk visual confirmation
   - User review match dengan mockup `mobile-mockup.html`

## G. Anti-Pattern — JANGAN

### Visual

- ❌ `Border.all(color: AppColors.border, width: 1)` sebagai pengganti shadow — flat dan murah
- ❌ `Card(elevation: 4)` Material default — tidak bisa di-tint primary
- ❌ `LinearGradient` pelangi (multi-warna mencolok) — pakai gradient brand 2-stop saja
- ❌ Gradient di tombol kecil — hanya hero card yang punya gradient
- ❌ Drop shadow heavy (`blurRadius > 30`) di card biasa
- ❌ Border radius tajam (< 8px) untuk card — terlihat "vintage"
- ❌ Color hardcode di widget (`Color(0xFFE5E7EB)`) — pakai token dari `AppColors`
- ❌ Banyak hero card di 1 screen — kehilangan signifikansi (1 max)

### Komponen

- ❌ `BottomNavigationBar` Material 2 — pakai `NavigationBar` Material 3
- ❌ Pakai emoji untuk icon (😀) — pakai Lucide / Material outlined
- ❌ Button rectangle (radius 8) — semua button pill (radius 999)
- ❌ Modal sentral (`AlertDialog`) untuk konfirmasi destructive — pakai bottom sheet
- ❌ Loading `CircularProgressIndicator` polos di tengah halaman — pakai `LoadingSkeleton`/skeleton custom
- ❌ Empty state cuma teks "Tidak ada data" — pakai `EmptyState` widget dengan icon + CTA

### State Management

- ❌ `setState` di file lebih dari 200 lines — pindah ke Riverpod provider
- ❌ Skip 3-state handling (loading/empty/error) — WAJIB ada di setiap screen network-fetched

## H. Verification Checklist

Sebelum klaim screen "selesai":

- [ ] **Color**: Semua warna dari `AppColors` token, bukan hardcode hex
- [ ] **Shadow**: Card pakai `AppShadows.card` minimal, hero pakai `AppShadows.hero`
- [ ] **Radius**: Card 16, Button 999 pill, Input 8
- [ ] **Typography**: Heading Plus Jakarta Sans, body Inter, scale konsisten
- [ ] **Spacing**: Pakai 4pt grid (4/8/12/16/20/24/32)
- [ ] **3-state**: Loading skeleton + Empty state + Error state semua handled
- [ ] **Bahasa**: Semua user-facing text Indonesia (label, error, dialog)
- [ ] **Icon**: Lucide / Material outlined (bukan emoji, bukan filled massa)
- [ ] **Hero card**: Maksimal 1 per screen, dengan gold glow + navy shadow
- [ ] **Button**: Pill shape (radius 999), Plus Jakarta Sans, font weight 600
- [ ] **`flutter analyze`**: 0 issues
- [ ] **Screenshot match mockup**: Compare visual ke `mobile-mockup.html` screen yang sesuai

## I. Referensi Eksternal

- **Mockup HTML**: `@docs/ui-research/mockups/mobile-mockup.html` (live preview di `http://localhost:8765`)
- **Riset UI**: `@docs/ui-research/mobile-references.md` (650+ baris referensi konkret)
- **Web design tokens**: `@mypresensi-web/app/globals.css` `:root` block (sumber kebenaran)
- **Inspirasi pola**:
  - Linear/Vercel — layered shadow style
  - Mekari Talenta — card-based attendance pattern
  - Politani Web — primary palette + gold accent
  - Material Design 3 — component foundation

## J. Update History

| Tanggal | Versi | Perubahan |
|---------|-------|-----------|
| 2026-05-15 | v1 | Rule fundamental dibuat. Sync warna mobile ke web (`#2D86FF`). Layered shadows. Anti-flat principle. Migration plan untuk `app_colors.dart`. |
