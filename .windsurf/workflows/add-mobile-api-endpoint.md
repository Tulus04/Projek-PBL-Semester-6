---
description: Pola standar membuat endpoint mobile baru di /api/mobile/* (Bearer auth + Zod + rate limit + audit) dan menyambungkannya ke Flutter via Dio.
---

# Add Mobile API Endpoint

Workflow untuk menambah endpoint baru yang dipakai aplikasi Flutter mahasiswa. Backend = Next.js API Route, **bukan** Supabase langsung dari mobile.

## 1. Tentukan path & method

Konvensi: `/api/mobile/<feature>/<action>/route.ts`. Method:

- **GET** untuk fetch data (riwayat, daftar sesi, profile).
- **POST** untuk mutasi atau request beraksi (submit, register, change password).

## 2. Tambah konstanta path di Flutter

File: `mypresensi-mobile/lib/core/network/api_endpoints.dart`

```dart
class ApiEndpoints {
  // ... yang sudah ada
  static const String fooSomething = '/api/mobile/foo/something';
}
```

Hardcode path di repository = **dilarang**.

## 3. Buat route handler

File: `mypresensi-web/app/api/mobile/foo/something/route.ts`

```ts
// app/api/mobile/foo/something/route.ts
// <Penjelasan singkat 1-2 baris Bahasa Indonesia tentang endpoint ini>

import { NextRequest } from 'next/server'
import { authenticateRequest, errorResponse, successResponse } from '../../_lib/auth'
import { createAdminClient } from '@/lib/supabase/server'
import { logAudit } from '@/lib/audit-logger'
import { z } from 'zod'

const bodySchema = z.object({
  // ... pesan error wajib Bahasa Indonesia
})

// === Rate limit (in-memory, opsional tapi sangat disarankan untuk POST) ===
// Konvensi naming: RATE_LIMIT_WINDOW_MS + RATE_LIMIT_MAX
// (konsisten dengan attendance/submit, face/register, leave-requests/submit)
const rateLimitMap = new Map<string, number[]>()
const RATE_LIMIT_WINDOW_MS = 60_000 // 1 menit
const RATE_LIMIT_MAX = 10            // max 10 request per window

function checkRateLimit(userId: string): boolean {
  const now = Date.now()
  const ts = (rateLimitMap.get(userId) ?? []).filter((t) => now - t < RATE_LIMIT_WINDOW_MS)
  if (ts.length >= RATE_LIMIT_MAX) return false
  ts.push(now)
  rateLimitMap.set(userId, ts)
  return true
}

export async function POST(req: NextRequest) {
  try {
    // 1. AUTH (Bearer + role mahasiswa + is_active)
    const auth = await authenticateRequest(req)
    if (auth.error) return errorResponse(auth.error, auth.status)
    const user = auth.user!

    // 2. RATE LIMIT
    if (!checkRateLimit(user.id)) {
      return errorResponse('Terlalu banyak permintaan. Coba lagi nanti.', 429)
    }

    // 3. PARSE & VALIDASI
    const body = await req.json()
    const parsed = bodySchema.safeParse(body)
    if (!parsed.success) {
      return errorResponse(parsed.error.errors[0]?.message ?? 'Input tidak valid', 400)
    }

    // 4. BUSINESS LOGIC pakai adminClient (bypass RLS, sudah aman karena step 1)
    const supabase = createAdminClient()
    // ... query / mutasi

    // 5. AUDIT
    await logAudit({
      action: 'mobile_foo_something',
      details: { user_id: user.id, /* ... */ },
    })

    // 6. RESPONSE
    return successResponse({ /* ... */ }, 200)
  } catch {
    return errorResponse('Terjadi kesalahan server.', 500)
  }
}
```

**Catatan keamanan**:
- Jangan return `error.message` dari Supabase apa adanya — sanitasi.
- Pesan error JSON standard: `{ "error": "...pesan Indonesia..." }` agar Dio handler di mobile bisa pungut via `data['error']`.
- Untuk endpoint sangat sensitif (face register, submit attendance), gunakan rate limit lebih ketat (lihat `face/register/route.ts`: 3/15min).

## 4. Buat model & repository di Flutter

### a. Model (`features/foo/data/foo_models.dart`)

```dart
class FooSomethingRequest {
  final String fieldA;
  const FooSomethingRequest({ required this.fieldA });
  Map<String, dynamic> toJson() => { 'field_a': fieldA };
}

class FooSomethingResponse {
  final String result;
  factory FooSomethingResponse.fromJson(Map<String, dynamic> json) =>
      FooSomethingResponse(result: json['result'] as String);
  const FooSomethingResponse({ required this.result });
}
```

### b. Repository (`features/foo/data/foo_repository.dart`)

```dart
class FooRepository {
  Dio get _dio => DioClient.instance;  // GETTER, bukan field

  Future<FooSomethingResponse> doSomething(FooSomethingRequest req) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.fooSomething,
        data: req.toJson(),
      );
      return FooSomethingResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  String _handleDioError(DioException e) {
    if (e.response?.data is Map<String, dynamic>) {
      final msg = e.response!.data['error'] as String?;
      if (msg != null && msg.isNotEmpty) return msg;
    }
    // Fallback per status code
    switch (e.response?.statusCode) {
      case 400: return 'Data yang dikirim tidak valid.';
      case 401: return 'Sesi berakhir. Silakan login ulang.';
      case 403: return 'Akses ditolak.';
      case 429: return 'Terlalu banyak permintaan. Tunggu beberapa saat.';
      case 500: return 'Server bermasalah. Coba lagi nanti.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Tidak dapat terhubung ke server.';
    }
    return 'Terjadi kesalahan tidak diketahui.';
  }
}
```

### c. Provider Riverpod (`features/foo/providers/foo_provider.dart`)

```dart
final fooRepositoryProvider = Provider<FooRepository>((ref) => FooRepository());

// Pilihan A: FutureProvider untuk fetch sederhana
final fooDataProvider = FutureProvider.autoDispose<FooSomethingResponse>((ref) async {
  return ref.read(fooRepositoryProvider).doSomething(FooSomethingRequest(fieldA: 'x'));
});

// Pilihan B: Notifier kalau perlu state machine (loading, error, success)
final fooSubmitProvider =
    NotifierProvider<FooSubmitNotifier, FooSubmitState>(FooSubmitNotifier.new);
```

## 5. Test koneksi

1. Restart `npm run dev` di web.
2. Hot restart Flutter (bukan hot reload — interceptor & config harus re-init).
3. Trigger dari UI mobile, cek log Dio (`[DIO] ...`) di console.
4. Cek `audit_logs` di Supabase Studio.
5. Untuk error → cek response body. Server error harus return JSON `{ "error": "..." }` agar pesan tampil di UI mobile.

## 6. Checklist sebelum commit

- [ ] Path endpoint terdaftar di `ApiEndpoints` (no hardcode).
- [ ] Auth check via `authenticateRequest()`.
- [ ] Zod validation dengan pesan Bahasa Indonesia.
- [ ] Rate limit untuk endpoint POST yang bisa di-spam.
- [ ] `logAudit()` untuk operasi yang merubah state penting.
- [ ] Response error JSON dengan field `error` (string Indonesia).
- [ ] Repository mobile pakai `Dio get _dio => DioClient.instance` (getter).
- [ ] `_handleDioError` mengikuti pola yang sudah ada.
- [ ] Sudah hot restart + smoke test dari UI mobile.
