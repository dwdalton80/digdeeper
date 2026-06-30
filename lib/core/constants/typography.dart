import 'package:flutter/material.dart';
import 'colors.dart';

class AppTypography {
  AppTypography._();

  // Display — Lora serif
  static const TextStyle displayLarge = TextStyle(
    fontFamily: 'Lora',
    fontSize: 34,
    fontWeight: FontWeight.w700,
    color: AppColors.warmWhite,
    height: 1.2,
    letterSpacing: -0.5,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: 'Lora',
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.warmWhite,
    height: 1.25,
    letterSpacing: -0.3,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: 'Lora',
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.warmWhite,
    height: 1.3,
  );

  // Verse text — Lora
  static const TextStyle verseText = TextStyle(
    fontFamily: 'Lora',
    fontSize: 22,
    fontWeight: FontWeight.w400,
    color: AppColors.warmWhite,
    height: 1.65,
    letterSpacing: 0.1,
  );

  static const TextStyle verseLarge = TextStyle(
    fontFamily: 'Lora',
    fontSize: 26,
    fontWeight: FontWeight.w400,
    color: AppColors.warmWhite,
    height: 1.7,
    letterSpacing: 0.1,
  );

  // Body — Inter
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: 'Inter',
    fontSize: 17,
    fontWeight: FontWeight.w400,
    color: AppColors.warmWhite,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: 'Inter',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.warmWhite,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: 'Inter',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  // Labels — Inter
  static const TextStyle labelLarge = TextStyle(
    fontFamily: 'Inter',
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.warmWhite,
    letterSpacing: 0.2,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: 'Inter',
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.warmWhite,
    letterSpacing: 0.1,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.5,
  );

  // Greek/Hebrew — Noto Serif
  static const TextStyle greekHebrew = TextStyle(
    fontFamily: 'NotoSerif',
    fontSize: 36,
    fontWeight: FontWeight.w400,
    color: AppColors.warmGold,
    height: 1.4,
  );

  static const TextStyle greekHebrewSmall = TextStyle(
    fontFamily: 'NotoSerif',
    fontSize: 20,
    fontWeight: FontWeight.w400,
    color: AppColors.warmGold,
    height: 1.4,
  );

  // CTA button
  static const TextStyle button = TextStyle(
    fontFamily: 'Inter',
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: 0.2,
  );

  static const TextStyle buttonSmall = TextStyle(
    fontFamily: 'Inter',
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.1,
  );
}
