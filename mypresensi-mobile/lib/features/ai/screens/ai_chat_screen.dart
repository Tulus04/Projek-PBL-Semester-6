// lib/features/ai/screens/ai_chat_screen.dart
// Screen Asisten AI mahasiswa — Variant A "Corporate Clean".
// Pattern: header putih + icon box, bubble user solid primary,
// bubble assistant white + border, suggestion chip dengan icon kategori,
// typing 3-dot bounce, markdown ringan (bold/italic + list).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/ai_chat_provider.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  static const _suggestions = <_Suggestion>[
    _Suggestion(
      icon: Icons.pie_chart_outline_rounded,
      title: 'Kehadiran saya',
      prompt: 'Berapa persen kehadiran saya?',
    ),
    _Suggestion(
      icon: Icons.warning_amber_rounded,
      title: 'Status risiko',
      prompt: 'Apakah saya termasuk mahasiswa berisiko?',
    ),
    _Suggestion(
      icon: Icons.school_outlined,
      title: 'Mata kuliah saya',
      prompt: 'Mata kuliah apa saja yang saya ambil?',
    ),
    _Suggestion(
      icon: Icons.help_outline_rounded,
      title: 'Cara ajukan izin',
      prompt: 'Cara ajukan izin sakit gimana?',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _controller.clear();
    await ref.read(aiChatProvider.notifier).sendMessage(trimmed);
    if (mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiChatProvider);

    ref.listen(aiChatProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Asisten AI',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: const [
                      _OnlineDot(),
                      SizedBox(width: 5),
                      Text(
                        'Online · Gemini 2.5 Flash',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.success,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        shape: const Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: state.messages.isEmpty
                  ? _buildEmptyState(state.isLoading)
                  : _buildMessageList(state),
            ),
            _buildInput(state.isLoading),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isLoading) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      children: [
        // Card intro
        Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.auto_awesome_outlined,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Apa yang ingin Anda tanyakan?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Saya bisa membantu cek kehadiran, MK, izin, dan panduan aplikasi. '
                'Hanya data akun Anda yang diakses.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Suggestion list dengan icon kategori
        ..._suggestions.map(
          (suggestion) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SuggestionChip(
              icon: suggestion.icon,
              title: suggestion.title,
              prompt: suggestion.prompt,
              onTap: isLoading ? null : () => _send(suggestion.prompt),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageList(AiChatState state) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: state.messages.length + (state.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.messages.length) {
          return const _TypingBubble();
        }
        final message = state.messages[index];
        return _MessageBubble(message: message);
      },
    );
  }

  Widget _buildInput(bool isLoading) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !isLoading,
              textInputAction: TextInputAction.send,
              minLines: 1,
              maxLines: 4,
              maxLength: 1000,
              onSubmitted: isLoading ? null : _send,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Tulis pertanyaan...',
                hintStyle: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 14,
                ),
                counterText: '',
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            height: 44,
            child: FilledButton(
              onPressed: isLoading ? null : () => _send(_controller.text),
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.border,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Sub-widgets
// ============================================================

class _Suggestion {
  final IconData icon;
  final String title;
  final String prompt;
  const _Suggestion({
    required this.icon,
    required this.title,
    required this.prompt,
  });
}

class _OnlineDot extends StatelessWidget {
  const _OnlineDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: AppColors.success,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final IconData icon;
  final String title;
  final String prompt;
  final VoidCallback? onTap;

  const _SuggestionChip({
    required this.icon,
    required this.title,
    required this.prompt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      prompt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final AiChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser ? null : Border.all(color: AppColors.border),
        ),
        child: isUser
            ? Text(
                message.content,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: Colors.white,
                ),
              )
            : _MarkdownBlock(text: message.content),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            _TypingDots(),
            SizedBox(width: 10),
            Text(
              'Menganalisis data...',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            // Stagger: setiap dot mulai 0.12 detik setelah dot sebelumnya
            final delay = index * 0.18;
            final t = (_controller.value - delay) % 1.0;
            // Bounce: opacity & translateY pakai sine curve
            final progress = t < 0.5 ? t * 2 : (1 - t) * 2;
            final opacity = 0.35 + (0.65 * progress.clamp(0.0, 1.0));
            final translateY = -3.0 * progress.clamp(0.0, 1.0);
            return Padding(
              padding: EdgeInsets.only(right: index < 2 ? 4 : 0),
              child: Transform.translate(
                offset: Offset(0, translateY),
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.textTertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ============================================================
// Markdown ringan — paragraf, **bold**, *italic*, ordered/unordered list.
// Sengaja tidak full markdown agar tidak butuh package baru.
// ============================================================
class _MarkdownBlock extends StatelessWidget {
  final String text;
  const _MarkdownBlock({required this.text});

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _renderBlock(blocks[i]),
        ],
      ],
    );
  }

  Widget _renderBlock(_Block block) {
    if (block is _OrderedList) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < block.items.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i < block.items.length - 1 ? 4 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 22,
                    child: Text(
                      '${i + 1}.',
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Expanded(child: _inlineText(block.items[i])),
                ],
              ),
            ),
        ],
      );
    }
    if (block is _UnorderedList) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < block.items.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i < block.items.length - 1 ? 4 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    width: 22,
                    child: Text(
                      '•',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Expanded(child: _inlineText(block.items[i])),
                ],
              ),
            ),
        ],
      );
    }
    final paragraph = block as _Paragraph;
    return _inlineText(paragraph.text);
  }

  Widget _inlineText(String text) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 13.5,
          height: 1.45,
          color: AppColors.textPrimary,
        ),
        children: _parseInline(text),
      ),
    );
  }
}

abstract class _Block {
  const _Block();
}

class _Paragraph extends _Block {
  final String text;
  const _Paragraph(this.text);
}

class _OrderedList extends _Block {
  final List<String> items;
  const _OrderedList(this.items);
}

class _UnorderedList extends _Block {
  final List<String> items;
  const _UnorderedList(this.items);
}

List<_Block> _parseBlocks(String text) {
  final lines = text.split(RegExp(r'\r?\n'));
  final blocks = <_Block>[];
  final buffer = <String>[];
  String? listType;
  final listItems = <String>[];

  void flushParagraph() {
    if (buffer.isEmpty) return;
    blocks.add(_Paragraph(buffer.join('\n').trim()));
    buffer.clear();
  }

  void flushList() {
    if (listType == null || listItems.isEmpty) return;
    if (listType == 'ol') {
      blocks.add(_OrderedList(List.unmodifiable(listItems)));
    } else {
      blocks.add(_UnorderedList(List.unmodifiable(listItems)));
    }
    listType = null;
    listItems.clear();
  }

  final orderedRegex = RegExp(r'^\s*\d+\.\s+(.*)$');
  final bulletRegex = RegExp(r'^\s*[-*]\s+(.*)$');

  for (final raw in lines) {
    final line = raw.trimRight();
    final ordered = orderedRegex.firstMatch(line);
    final bullet = bulletRegex.firstMatch(line);

    if (ordered != null) {
      flushParagraph();
      if (listType != 'ol') flushList();
      listType = 'ol';
      listItems.add(ordered.group(1) ?? '');
      continue;
    }
    if (bullet != null) {
      flushParagraph();
      if (listType != 'ul') flushList();
      listType = 'ul';
      listItems.add(bullet.group(1) ?? '');
      continue;
    }

    flushList();
    if (line.trim().isEmpty) {
      flushParagraph();
    } else {
      buffer.add(line);
    }
  }

  flushList();
  flushParagraph();
  return blocks;
}

// Inline parser: **bold**, *italic*
List<TextSpan> _parseInline(String text) {
  final spans = <TextSpan>[];
  final regex = RegExp(r'(\*\*([^*]+)\*\*|\*([^*]+)\*)');
  var lastIndex = 0;

  for (final match in regex.allMatches(text)) {
    if (match.start > lastIndex) {
      spans.add(TextSpan(text: text.substring(lastIndex, match.start)));
    }
    final bold = match.group(2);
    final italic = match.group(3);
    if (bold != null) {
      spans.add(
        TextSpan(
          text: bold,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    } else if (italic != null) {
      spans.add(
        TextSpan(
          text: italic,
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
      );
    }
    lastIndex = match.end;
  }
  if (lastIndex < text.length) {
    spans.add(TextSpan(text: text.substring(lastIndex)));
  }
  return spans;
}
