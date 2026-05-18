// lib/core/theme/app_shadows.dart
// Layered shadow tokens untuk anti-flat principle (rule 22-mobile-design-system.md §D).
// JANGAN pakai Border.all sebagai pengganti shadow — itu flat & murah.
// Pattern: drop subtle + ring tinted, layered untuk depth premium ala Linear/Vercel.

import 'package:flutter/material.dart';

class AppShadows {
  AppShadows._();

  /// Card normal — drop subtle + ring. Default untuk semua card di list/feed.
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 0, spreadRadius: 1),
  ];

  /// Card hover/pressed — primary tinted. Untuk InkWell tap, ListTile interactive.
  static const List<BoxShadow> cardHover = [
    BoxShadow(
      color: Color(0x332D86FF),
      blurRadius: 24,
      offset: Offset(0, 8),
      spreadRadius: -8,
    ),
    BoxShadow(color: Color(0x2E2D86FF), blurRadius: 0, spreadRadius: 1),
  ];

  /// Card elevated — multi-layer drop. Untuk modal, bottom sheet, dropdown.
  static const List<BoxShadow> cardElevated = [
    BoxShadow(color: Color(0x140F172A), blurRadius: 12, offset: Offset(0, 4), spreadRadius: -2),
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 4, offset: Offset(0, 2), spreadRadius: -2),
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 0, spreadRadius: 1),
  ];

  /// Hero card — DRAMATIC dengan navy tint. 1 hero per screen MAX.
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

  /// FAB — primary tinted floating glow.
  static const List<BoxShadow> fab = [
    BoxShadow(color: Color(0x662D86FF), blurRadius: 16, offset: Offset(0, 8), spreadRadius: -4),
    BoxShadow(color: Color(0x332D86FF), blurRadius: 0, spreadRadius: 1),
  ];

  /// Button primary — subtle tinted shadow saat default.
  static const List<BoxShadow> button = [
    BoxShadow(color: Color(0x4D2D86FF), blurRadius: 2, offset: Offset(0, 1)),
  ];

  /// Button hover/pressed — lebih dramatis.
  static const List<BoxShadow> buttonHover = [
    BoxShadow(color: Color(0x732D86FF), blurRadius: 16, offset: Offset(0, 6), spreadRadius: -4),
  ];

  /// Bottom nav top edge — subtle shadow ke atas (separation dari content).
  static const List<BoxShadow> bottomNav = [
    BoxShadow(
      color: Color(0x0F0F172A),
      blurRadius: 12,
      offset: Offset(0, -2),
    ),
  ];
}
