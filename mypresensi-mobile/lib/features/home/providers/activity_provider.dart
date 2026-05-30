// lib/features/home/providers/activity_provider.dart
// Riverpod provider untuk Activity Feed di Beranda.
// Pakai FutureProvider.autoDispose supaya data refetch saat user ke Beranda lagi
// setelah lama meninggalkan tab (state lama tidak stale).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/activity_models.dart';
import '../data/activity_repository.dart';

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return ActivityRepository();
});

/// Fetch 5 activity terakhir untuk Beranda (3 di-display + 2 buffer).
/// Auto-dispose: state hilang saat tab keluar dari widget tree, refetch saat masuk lagi.
final recentActivitiesProvider =
    FutureProvider.autoDispose<List<ActivityItem>>((ref) async {
  final repo = ref.read(activityRepositoryProvider);
  return repo.getRecentActivities(limit: 5);
});
