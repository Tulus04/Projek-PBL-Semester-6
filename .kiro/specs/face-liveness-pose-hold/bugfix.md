# Bugfix Requirements — Face Liveness Pose Hold di Device Entry-Level

## Introduction

Saat tahap liveness check pada flow registrasi & verifikasi wajah, step `turnLeft` (dan secara struktur sama: `turnRight`) **tidak pernah ter-confirm** di device entry-level seperti **Realme RMX5000** (chipset MediaTek + ColorOS). User merasa "wajah tidak terdeteksi" → flow registrasi/verifikasi mentok di tengah jalan dan tidak bisa lanjut.

Bukti runtime dari logcat user di Realme RMX5000 menunjukkan ML Kit **berhasil** mendeteksi kepala menoleh dengan ekstrem (yaw 30°–57°, jauh di atas threshold 12° yang ditetapkan di `face_detection_service.dart:checkLivenessStep`). `passed=true` muncul puluhan kali, **tapi `holdMs` maksimum cuma sempat menyentuh 105 ms** — padahal threshold hold yang dibutuhkan (`_getHoldDurationMs(turnLeft)`) adalah **400 ms**. Logcat juga penuh GC pause 100–250 ms yang men-stretch interval antar frame ML Kit ke ~200–400 ms.

Mekanisme time-based hold di `face_provider.dart:_handleLivenessFrame` (yang didukung oleh `_passedGapResetMs = 500 ms`) bekerja baik di device kelas mid/high-tier, tapi destruktif di device entry-level: jitter pose alami (sebentar `passed=true`, sebentar `passed=false` saat ML Kit miss frame karena GC) sering menghasilkan gap `>500 ms` antara dua frame `passed=true`, yang mereset `_passedSinceMs` → `holdMs` selalu kembali kecil → step tidak pernah lulus.

Step `blinkEyes` lolos cepat (`_getHoldDurationMs(blinkEyes) = 0`) → membuktikan flow umum benar; bug spesifik berada pada **mekanisme akumulasi hold time** untuk pose-hold step (`turnLeft`, `turnRight`).

Dampak: mahasiswa pemilik HP entry-level (segmen besar di Politani) **tidak bisa registrasi wajah sama sekali**, sehingga fitur presensi via face recognition gagal onboarding. Risiko regresi: device mid/high-tier yang sebelumnya jalan harus tetap jalan, dan kombinasi anti-spoof multi-step + GPS + OTP tidak boleh melemah.

## Bug Analysis

### Current Behavior (Defect)

Apa yang terjadi sekarang ketika user di device entry-level mencoba step `turnLeft`/`turnRight`.

1.1 WHEN ML Kit FaceDetector menghasilkan stream frame dengan interval realistis 200–400 ms (Realme RMX5000 + ColorOS, di tengah GC pause 100–250 ms) DAN user benar-benar menahan pose noleh (yaw `|.| > 12°` selama ~1 detik) THEN sistem tidak pernah meng-confirm step `turnLeft`/`turnRight` karena `_passedSinceMs` di `_handleLivenessFrame` selalu di-reset.

1.2 WHEN di tengah window hold muncul satu atau lebih frame `passed=false` transien (jitter yaw natural saat user mempertahankan pose, atau ML Kit miss face satu frame) sehingga gap antar dua frame `passed=true` melebihi `_passedGapResetMs = 500 ms` THEN sistem menganggap user sudah "balik ke pose awal" dan meng-restart window dari nol, padahal user tidak pernah berubah pose secara nyata.

1.3 WHEN di device entry-level mekanisme `holdMs >= _getHoldDurationMs(state.livenessStep)` (= 400 ms untuk pose) dievaluasi terhadap akumulasi yang terus-menerus di-reset oleh klausul 1.2 THEN `holdMs` maksimum yang ter-record di logcat hanya ~105 ms (jauh di bawah 400 ms) sehingga branch `_advanceLivenessStep()` tidak pernah ter-trigger untuk pose-hold step.

1.4 WHEN step `turnLeft`/`turnRight` mentok di device entry-level THEN UI menampilkan instruksi "Tolehkan kepala ke kiri/kanan" terus-menerus tanpa progress, user tidak diberi tahu bahwa device-nya butuh hold lebih lama, dan registrasi/verifikasi wajah tidak bisa diselesaikan sampai user keluar paksa dari screen.

### Expected Behavior (Correct)

Apa yang **harus** terjadi setelah fix diterapkan, untuk input yang sama dengan bug condition (device entry-level, frame interval 200–400 ms, jitter pose natural).

2.1 WHEN ML Kit FaceDetector menghasilkan stream frame dengan interval 200–400 ms DAN user menahan pose noleh (yaw `|.| > 12°`) selama durasi yang reasonable (target ≤ ~1.5 detik real-time) THEN sistem SHALL meng-confirm step `turnLeft`/`turnRight` dan memajukan `livenessStep` ke step berikutnya.

2.2 WHEN di tengah window hold muncul 1–2 frame `passed=false` transien, ATAU gap antar frame `passed=true` membesar karena GC pause / ML Kit lambat (selama tidak melebihi batas toleransi yang baru), THEN sistem SHALL TIDAK reset progress hold; akumulasi bukti "user sedang menahan pose" SHALL tetap dipertahankan.

2.3 WHEN device entry-level dipakai dengan kondisi performa real-world (frame interval 200–400 ms, GC pause heavy) THEN sistem SHALL tetap achievable tanpa mensyaratkan user menahan pose secara tidak wajar (> ~2 detik real-time secara konsisten); kriteria "pose ditahan" SHALL dievaluasi dengan signal yang robust terhadap latency frame, bukan continuity ms-level.

2.4 WHEN debug log `[FACE LIVE]` aktif THEN sistem SHALL emit signal yang cukup informatif untuk men-tuning threshold di field test future tanpa guesswork (mis. jumlah frame `passed`, gap antar frame, durasi window) — supaya iterasi berikutnya berbasis data, bukan tebakan.

### Unchanged Behavior (Regression Prevention)

Behavior existing yang **wajib tetap utuh** setelah fix. Setiap regresi di area berikut adalah blocker.

3.1 WHEN user di device mid/high-tier dengan frame interval normal (50–150 ms) menjalankan step `turnLeft`/`turnRight` THEN sistem SHALL CONTINUE TO meng-confirm step dalam timing yang **tidak lebih lambat** dari sebelum fix (no UX regression untuk segmen yang selama ini OK).

3.2 WHEN user TIDAK menoleh atau yaw `|.| ≤ 12°` (pose tidak valid menurut `FaceDetectionService.checkLivenessStep`) THEN sistem SHALL CONTINUE TO menolak step (tidak ada false-confirm). Threshold deteksi pose di `face_detection_service.dart` tidak boleh dilonggarkan sebagai bagian dari fix ini.

3.3 WHEN step `blinkEyes` berjalan (event-transient, `_getHoldDurationMs(blinkEyes) = 0`) THEN sistem SHALL CONTINUE TO confirm step pada event detection pertama (`leftEye < 0.4 && rightEye < 0.4`) tanpa perubahan timing — fix ini tidak boleh meng-regress mekanisme blink.

3.4 WHEN step `lookStraight` (fase capture 7 embedding via `_handleCapturePoseFrame`) berjalan THEN sistem SHALL CONTINUE TO mengumpulkan embedding di pose lurus dengan logic yang sama (TFLite MobileFaceNet, multi-frame averaging) tanpa perubahan pipeline.

3.5 WHEN attacker mencoba spoof dengan foto statis / video singkat / replay tanpa gerakan kepala kontinu THEN sistem SHALL CONTINUE TO menolak: step `turnLeft`/`turnRight` masih harus membutuhkan **bukti pose ditahan multi-frame** (bukan instant-accept di frame pertama). Anti-spoof melalui kombinasi multi-step liveness + GPS + OTP TIDAK BOLEH dilemahkan.

3.6 WHEN user menjalankan urutan liveness `lookStraight → blinkEyes → turnLeft → turnRight` THEN sistem SHALL CONTINUE TO meng-enforce bahwa arah `turnRight` harus berlawanan dari `turnLeft` (lihat `FaceDetectionService._turnLeftDirection`) — anti-spoof multi-step preserved.

3.7 WHEN logging diagnostic `[FACE LIVE] step=… yaw=… leftEye=… rightEye=… passed=… holdMs=…` aktif (setiap kelipatan 5 frame di `_handleLivenessFrame`) THEN sistem SHALL CONTINUE TO emit log per-frame untuk field test debugging — fix tidak boleh menghilangkan signal logging existing.

3.8 WHEN error transien terjadi di fase liveness (wajah hilang frame, multiple faces, wajah terlalu kecil) THEN sistem SHALL CONTINUE TO menampilkan instruksi step utama yang benar (livenessInstruction safety net) dan hint kecil di `livenessHint`, tanpa regress ke status `detecting` yang menampilkan "Posisikan wajah, hadap lurus" di tengah pose hold.

3.9 WHEN privacy rule terkait biometrik berlaku (rule 04-security-and-privacy §B) THEN sistem SHALL CONTINUE TO tidak meng-log embedding array; logging diagnostic hanya boleh memuat signal turunan (yaw, eye-open prob, passed, durasi). Fix ini tidak boleh menambah field sensitif di log.
