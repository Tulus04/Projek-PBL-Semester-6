// lib/features/history/providers/history_provider.dart
// Riverpod providers untuk fitur riwayat kehadiran.
// FutureProvider auto-dispose — data di-refresh setiap kali tab dibuka.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/history_models.dart';
import '../data/history_repository.dart';

// Repository provider
final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepository();
});

// History data provider — auto-dispose, refresh-able
final historyProvider = FutureProvider.autoDispose<HistoryResponse>((ref) async {
  final repo = ref.read(historyRepositoryProvider);
  return repo.getHistory();
});
