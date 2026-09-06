import 'package:flutter/material.dart';

class AppColors {
  // Legacy / Backwards Compatibility Getters
  static const Color primary = Color(0xFF0284C7);
  static const Color secondary = Color(0xFF0F766E);
  static const Color background = Color(0xFFF8FAFC);
  static const Color text = Color(0xFF0F172A);
  static const Color white = Colors.white;
  static const Color error = Colors.red;

  // Primary Brand Colors
  static const Color primaryLight = Color(0xFF0284C7);
  static const Color primaryDark = Color(0xFF38BDF8);

  // Background Tones
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color bgDark = Color(0xFF0F172A);

  // Surface Tones
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E293B);
  
  static const Color surfaceContainerLight = Color(0xFFF1F5F9);
  static const Color surfaceContainerDark = Color(0xFF334155);

  // Text Tones
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  // Message Bubbles Light
  static const Color bubbleSentLight = Color(0xFF0284C7);
  static const Color bubbleSentTextLight = Colors.white;
  static const Color bubbleReceivedLight = Color(0xFFE2E8F0);
  static const Color bubbleReceivedTextLight = Color(0xFF0F172A);

  // Message Bubbles Dark
  static const Color bubbleSentDark = Color(0xFF0369A1);
  static const Color bubbleSentTextDark = Colors.white;
  static const Color bubbleReceivedDark = Color(0xFF334155);
  static const Color bubbleReceivedTextDark = Color(0xFFF8FAFC);

  // Avatar Palette Colors (For user initials)
  static const List<Color> avatarColors = [
    Color(0xFF0284C7),
    Color(0xFF0D9488),
    Color(0xFF7C3AED),
    Color(0xFFDB2777),
    Color(0xFFEA580C),
    Color(0xFF16A34A),
    Color(0xFF2563EB),
    Color(0xFF9333EA),
  ];

  static Color getAvatarColor(String name) {
    if (name.isEmpty) return avatarColors[0];
    final int hash = name.codeUnits.fold(0, (prev, element) => prev + element);
    return avatarColors[hash % avatarColors.length];
  }
}
