---
inclusion: always
description: Protokol runtime verification untuk paksa AI tidak klaim "selesai" sampai bukti runtime sukses. Komplemen rule 02 (static + debugging) dengan fokus E2E + screenshot proof.
---

# Runtime Verification Protocol — MyPresensi

Rule ini lahir dari pelajaran konkret: AI sering klaim "selesai" setelah `flutter analyze` clean tapi app **crash di runtime** (RangeError, missing class, broken navigation). Static analyzer tidak bisa catch:

- Off-by-one di index array (`_animated(4, ...)` saat `_sectionCount = 4`)
- Reference identifier yang belum di-define (`const _TrplWelcomeIllustration()` tanpa class)
- Visual layout broken (overflow, alignment, widget tidak render)
- Navigation flow rusak (route exist tapi guard block silently)
- API contract mismatch (server return field X, mobile decode field Y)

Rule 02 sudah cover **static + debugging fundamentals**. Rule ini cover **runtime guarantees**.

## A. Iron Laws — Tidak Boleh Ditawar

### Law 1: "Static hijau ≠ runtime aman"

Jika perubahan affect **runtime behavior** (UI widget, route, provider, API endpoint), AI **WAJIB** melengkapi salah satu bukti:

1. **Build success** (`flutter build apk --debug` atau `npm run build` exit 0), ATAU
2. **Visual confirmation dari user** (screenshot/screencast), ATAU
3. **Runtime smoke test** (curl endpoint, scripted Selenium-like, dst)

Klaim "selesai" tanpa salah satu = **PELANGGARAN**.

### Law 2: "No half-baked commit"

Jika AI menulis kode yang reference identifier baru (class, function, constant, type), AI **WAJIB**:

- Selesaikan definisinya di **edit yang sama**, ATAU
- STOP + flag eksplisit di response: "**PAUSE — saya menulis reference X tanpa define-nya. Tidak boleh build sampai saya finish [list yang harus diselesaikan]**"

JANGAN pivot ke topik baru sambil meninggalkan dangling reference. Itu time-bomb.

### Law 3: "Pre-edit sanity scan untuk magic numbers"

Sebelum tambah/ubah **index/length yang depend pada constant existing**:

1. Grep constant tersebut (`_sectionCount`, `kMaxRetries`, dll)
2. Konfirmasi value-nya **support index baru**
3. Update kalau perlu, di **same edit**, dengan komentar konteks

Magic number = high-risk untuk off-by-one. Prevent at source, jangan tunggu RangeError.

### Law 4: "Screenshot-as-proof untuk UI changes"

Jika AI edit widget Flutter / komponen React yang affect render:

1. Klaim WIP, BUKAN "selesai", setelah static checks pass
2. Request explicitly: "**Mohon hot restart + screenshot first launch — saya butuh konfirmasi visual sebelum klaim selesai**"
3. Setelah user kirim screenshot OK, BARU klaim "verified".

JANGAN klaim "looks correct" tanpa lihat screenshot. AI **tidak bisa** lihat pixel layout dari static analysis.

## B. Verification Log Table — Wajib di Response "Selesai"

Setiap response yang klaim selesai (terkait runtime change), **WAJIB** include block:

```markdown
## ✅ Verifikasi

| Check | Result |
|-------|--------|
| `getDiagnostics` | ✅ 0 issues |
| `flutter analyze` / `npm run type-check` | ✅ 0 issues |
| Build (jika applicable) | ✅ exit 0 / ⏳ skipped |
| **Runtime visual (USER)** | ⏳ **Mohon screenshot setelah hot restart** |
```

Status legend:
- ✅ Confirmed pass
- ❌ Confirmed fail (HARUS fix)
- ⏳ Pending (request user action)
- ➖ N/A (jelaskan kenapa skip)

JANGAN tulis "selesai" tanpa table ini saat ada perubahan runtime. Ini paksa transparency — user lihat langsung apa yang sudah verify, apa yang belum.

## C. Pre-Commit Code Review Checklist (AI Self-Audit)

Sebelum claim selesai, AI WAJIB menjawab pertanyaan berikut **eksplisit di response** (bisa singkat tapi tidak skip):

### C1 — Runtime Affect

- [ ] Apakah perubahan ini affect runtime (UI render, navigation, data fetch)? Jika **ya** → Law 1 + Law 4 wajib applied.

### C2 — Identifier Completeness

- [ ] Apakah saya reference class/function/constant baru? Jika **ya**:
  - [ ] Apakah definisinya ada di same edit / file existing?
  - [ ] Sudah saya verify dengan grep?

### C3 — Magic Number Audit

- [ ] Apakah saya tambah index/length yang depend constant existing? Jika **ya**:
  - [ ] Sudah grep constant tersebut?
  - [ ] Value support index baru? Atau perlu update juga?

### C4 — Cross-File Dependencies

- [ ] Apakah file lain reference identifier yang saya rename/hapus? (Cari pakai grep)
- [ ] Apakah server response shape match mobile decode? (Untuk perubahan API)

## D. Bug Retro Discipline

Setelah ada **production-blocking error** (build fail, crash, broken flow yang user laporkan), AI **WAJIB** append entry ke `dev-log.md`:

```markdown
## YYYY-MM-DD — BUG-NN: [Title]

**Symptom**: [Error message yang user lihat]

**Root cause**: [1-2 paragraf — apa pattern engineering yang melahirkan bug ini]

**Why slipped past**: [Kenapa static analysis / verifikasi sebelumnya tidak catch]

**Prevention**: [Rule/protokol baru yang harus diikuti supaya tidak terulang. Cross-ref rule 02/06 jika relevant]

**Files affected**: [List file yang ke-edit untuk fix]
```

Itu bikin pelajaran **structured + searchable**. Bug yang sudah documented = lebih tidak mungkin terulang dibanding bug yang lupa di-track.

## E. Anti-Pattern Saat Klaim Selesai

JANGAN tulis salah satu kalau verifikasi belum lengkap:

- ❌ "Seharusnya jalan sekarang"
- ❌ "Build cuma static — saya yakin runtime aman"
- ❌ "Tidak ada error analyze, beres"
- ❌ "Sudah selesai!" tanpa table verifikasi
- ❌ "Tinggal screenshot, tapi kayanya benar" (klaim positif tanpa bukti)
- ❌ "Looks correct di code, run aja" (rasionalisasi skip runtime)

Pakai bahasa hati-hati saat verifikasi belum complete:

- ✅ "Static checks pass. **Mohon screenshot** untuk verify runtime"
- ✅ "Saya pause — **belum finish definisi X**, tidak aman build sekarang"
- ✅ "**Belum saya runtime-test**. Risk: low / medium / high karena [alasan]"

## F. Cross-Reference Rule Lain

| Rule | Topik | Hubungan dengan rule ini |
|------|-------|--------------------------|
| `02-quality-debugging-verification.md` | Static + debugging fundamentals | Rule 06 = layer di atas 02 (runtime focus) |
| `05-testing-and-release.md` | Manual QA checklist | Rule 06 = automation/discipline, Rule 05 = checklist konkret per fitur |
| `01-agent-persona.md` | Anti-yes-man + verification mindset | Rule 06 implementasi konkret dari prinsip itu |

## G. Bug History — Lessons Learned

### 2026-05-22 — Activity Feed RangeError

**Symptom**: `RangeError (length): Invalid value: Not in inclusive range 0..3: 4` saat buka Beranda mobile setelah tambah section Activity Feed.

**Root cause**: AI tambah `_animated(4, _buildActivityFeedSection(...))` tanpa update `_sectionCount = 4`. Index 4 out-of-bound karena `_controllers` cuma punya 4 element (0-3).

**Why slipped past**: `flutter analyze` tidak catch out-of-bound runtime access pada `late final List<...>`. Static analyzer tidak track relationship antara constant dan loop bound.

**Prevention**:
- Law 3 (pre-edit constant scan) — grep constant `_sectionCount` SEBELUM tambah `_animated(4, ...)`
- Law 1 (build success) — kalau saya jalankan `flutter build apk --debug`, error ini akan ke-catch sebelum user runtime

**Files affected**: `mypresensi-mobile/lib/features/home/screens/home_screen.dart`

### 2026-05-22 — Onboarding `_TrplWelcomeIllustration` Build Error

**Symptom**: `lib/features/onboarding/screens/onboarding_screen.dart:290:17: Error: Not a constant expression. const _TrplWelcomeIllustration()`

**Root cause**: AI tulis `const _TrplWelcomeIllustration()` di Step 1 sebagai placeholder, lalu pivot ke topik audit Profile **sebelum** define class-nya. Reference dangling.

**Why slipped past**: AI klaim selesai di task lain padahal task onboarding belum complete. Tidak ada self-check "apakah saya finish unit kerja ini sebelum lompat?"

**Prevention**:
- Law 2 (no half-baked commit) — wajib finish definisi di same edit, ATAU flag eksplisit "PAUSE"
- C2 di self-audit checklist — grep identifier baru sebelum klaim selesai

**Files affected**: `mypresensi-mobile/lib/features/onboarding/screens/onboarding_screen.dart`

## H. Update History

| Tanggal | Versi | Perubahan |
|---------|-------|-----------|
| 2026-05-22 | v1 | Rule lahir dari 2 bug pattern di session: RangeError out-of-bound + dangling reference. 4 Iron Laws + Verification Log Table + Self-Audit Checklist + Bug Retro Discipline. |
