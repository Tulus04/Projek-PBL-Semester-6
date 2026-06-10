// lib/features/home/data/week_utils.dart
// Util minggu (pure functions) untuk week strip Beranda — hitung awal minggu,
// geser antar minggu, klamping rentang, dan daftar 7 hari. Tanpa side effect/IO.

/// Kembalikan tanggal Senin pada minggu yang memuat [date].
///
/// Hasil dinormalisasi ke midnight lokal (year/month/day saja, jam = 0).
/// Senin direpresentasikan sebagai `weekday == 1`.
///
/// Properti:
/// - Idempoten: `weekStart(weekStart(d)) == weekStart(d)`.
/// - Hasil selalu `weekday == 1` (Senin).
DateTime weekStart(DateTime date) {
  // Normalisasi dulu ke midnight lokal agar aritmetika hari bebas dari jam/DST.
  final normalized = DateTime(date.year, date.month, date.day);
  // weekday: Senin=1 .. Minggu=7. Kurangi (weekday - 1) hari untuk mundur ke Senin.
  return normalized.subtract(Duration(days: normalized.weekday - 1));
}

/// Geser [weekStartDate] sebanyak [delta] minggu (× 7 hari).
///
/// Tetap di midnight lokal. [delta] boleh negatif (mundur) atau positif (maju).
DateTime addWeeks(DateTime weekStartDate, int delta) {
  final normalized =
      DateTime(weekStartDate.year, weekStartDate.month, weekStartDate.day);
  return normalized.add(Duration(days: delta * 7));
}

/// Klamping [ws] ke rentang [min, max].
///
/// Kembalikan [min] bila `ws < min`, [max] bila `ws > max`, selain itu [ws].
DateTime clampWeekStart(DateTime ws, {required DateTime min, required DateTime max}) {
  if (ws.isBefore(min)) return min;
  if (ws.isAfter(max)) return max;
  return ws;
}

/// Kembalikan 7 tanggal berurutan mulai dari [weekStartDate] (Senin..Minggu).
///
/// Masing-masing dinormalisasi ke midnight lokal.
List<DateTime> daysOfWeek(DateTime weekStartDate) {
  final normalized =
      DateTime(weekStartDate.year, weekStartDate.month, weekStartDate.day);
  return List<DateTime>.generate(
    7,
    (i) => normalized.add(Duration(days: i)),
  );
}
