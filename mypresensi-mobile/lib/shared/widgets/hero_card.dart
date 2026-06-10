// lib/shared/widgets/hero_card.dart
// Statement surface — gradient primary→navy + gold radial glow + white highlight
// + dramatic navy shadow (rule 22 §E.1).
// 1 hero card per screen MAX — kehilangan signifikansi kalau banyak.

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';

class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 18,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: AppColors.primaryHover,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: AppShadows.hero,
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // White highlight — bottom-left (depth + life)
          Positioned(
            bottom: -54,
            left: 75,
            child: IgnorePointer(
              child: Container(
                width: 180,
                height: 180,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x24FFFFFF), Color(0x00FFFFFF)],
                    stops: [0.0, 0.7],
                  ),
                ),
              ),
            ),
          ),
          // Content z-index atas (default Stack: last child on top)
          Padding(padding: padding, child: child),
        ],
      ),
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: card,
      ),
    );
  }
}
