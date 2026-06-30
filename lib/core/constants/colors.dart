import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Core Palette ────────────────────────────────────────────────────────────
  static const black        = Color(0xFF0F0F0F);   // primary background
  static const cardDark     = Color(0xFF1A1A1A);   // card background
  static const cardMid      = Color(0xFF222222);   // elevated card
  static const border       = Color(0xFF2A2A2A);   // subtle dividers/borders
  static const gold         = Color(0xFFC8A96E);   // primary accent
  static const goldMuted    = Color(0xFF8A7040);   // muted gold for icons
  static const warmWhite    = Color(0xFFFAFAF7);   // primary text
  static const textMuted    = Color(0xFF888888);   // secondary text
  static const textDim      = Color(0xFF555555);   // tertiary / placeholders

  // ── Semantic aliases (keep old names working) ────────────────────────────
  static const deepSlate       = black;
  static const deepIndigo      = Color(0xFF2D3A8C);  // kept for legacy use
  static const warmGold        = gold;
  static const sageGreen       = Color(0xFF4A7C6F);
  static const textPrimary     = warmWhite;
  static const textSecondary   = textMuted;
  static const surface         = cardDark;
  static const surfaceVariant  = cardMid;
  static const error           = Color(0xFFFF3B30);
  static const warning         = Color(0xFFFF9F0A);
  static const success         = sageGreen;

  // ── Highlight colors (Bible reader) ─────────────────────────────────────
  static const highlightYellow = Color(0xFFFFF176);
  static const highlightGreen  = Color(0xFFA5D6A7);
  static const highlightBlue   = Color(0xFF90CAF9);
  static const highlightPink   = Color(0xFFF48FB1);

  // ── Theme-aware surface colors (use in non-const widgets) ───────────────
  /// Card background: dark in dark mode, white in light mode.
  static Color cardBg(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
      ? cardDark : Colors.white;

  /// Elevated card: cardMid in dark, warm-off-white in light.
  static Color cardElevated(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
      ? cardMid : const Color(0xFFF0EBE3);

  /// Subtle divider/border line.
  static Color divider(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
      ? border : const Color(0xFFDDD5C8);

  // ── Theme-aware text colors (use in non-const widgets) ──────────────────
  /// Primary text: warmWhite in dark, near-black in light.
  static Color label(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
      ? warmWhite : const Color(0xFF1C1005);

  /// Secondary text: textMuted in dark, warm-brown in light.
  static Color sublabel(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
      ? textMuted : const Color(0xFF6B5843);

  // ── Gradients ────────────────────────────────────────────────────────────
  static const LinearGradient indigoGradient = LinearGradient(
    colors: [Color(0xFF2D3A8C), Color(0xFF1A2060)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFC8A96E), Color(0xFFE8C87A)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF0F0F0F), Color(0xFF1A1A1A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
