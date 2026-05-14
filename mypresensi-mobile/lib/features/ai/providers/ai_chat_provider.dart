// lib/features/ai/providers/ai_chat_provider.dart
// State management AI Assistant mahasiswa dengan Riverpod Notifier.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/ai_chat_repository.dart';

class AiChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime createdAt;

  const AiChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.createdAt,
  });
}

class AiChatState {
  final List<AiChatMessage> messages;
  final bool isLoading;
  final String? error;

  const AiChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  AiChatState copyWith({
    List<AiChatMessage>? messages,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final aiChatRepositoryProvider = Provider<AiChatRepository>((ref) {
  return AiChatRepository();
});

final aiChatProvider = NotifierProvider<AiChatNotifier, AiChatState>(AiChatNotifier.new);

class AiChatNotifier extends Notifier<AiChatState> {
  @override
  AiChatState build() => const AiChatState();

  Future<void> sendMessage(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty || state.isLoading) return;

    final userMessage = AiChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      content: trimmed,
      isUser: true,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      clearError: true,
    );

    try {
      final repo = ref.read(aiChatRepositoryProvider);
      final reply = await repo.sendMessage(trimmed);
      final assistantMessage = AiChatMessage(
        id: '${DateTime.now().microsecondsSinceEpoch}-ai',
        content: reply,
        isUser: false,
        createdAt: DateTime.now(),
      );
      state = state.copyWith(
        messages: [...state.messages, assistantMessage],
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}
