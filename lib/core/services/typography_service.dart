import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Typography prefs model ────────────────────────────────────────────────────

enum TypographySize { small, medium, large, xl }
enum TypographyFont { serif, sansSerif }
enum TypographySpacing { compact, normal, spacious }

class TypographyPrefs {
  final TypographySize size;
  final TypographyFont font;
  final TypographySpacing spacing;

  const TypographyPrefs({
    this.size    = TypographySize.medium,
    this.font    = TypographyFont.serif,
    this.spacing = TypographySpacing.normal,
  });

  double get fontSize {
    switch (size) {
      case TypographySize.small:    return 14;
      case TypographySize.medium:   return 17;
      case TypographySize.large:    return 20;
      case TypographySize.xl:       return 23;
    }
  }

  String get fontFamily {
    return font == TypographyFont.serif ? 'Lora' : 'Inter';
  }

  double get lineHeight {
    switch (spacing) {
      case TypographySpacing.compact:   return 1.5;
      case TypographySpacing.normal:    return 1.75;
      case TypographySpacing.spacious:  return 2.1;
    }
  }

  String get sizeLabel {
    switch (size) {
      case TypographySize.small:  return 'Small';
      case TypographySize.medium: return 'Medium';
      case TypographySize.large:  return 'Large';
      case TypographySize.xl:     return 'Extra Large';
    }
  }

  String get fontLabel =>
    font == TypographyFont.serif ? 'Serif (Lora)' : 'Sans-Serif (Inter)';

  String get spacingLabel {
    switch (spacing) {
      case TypographySpacing.compact:  return 'Compact';
      case TypographySpacing.normal:   return 'Normal';
      case TypographySpacing.spacious: return 'Spacious';
    }
  }

  TypographyPrefs copyWith({
    TypographySize? size,
    TypographyFont? font,
    TypographySpacing? spacing,
  }) => TypographyPrefs(
    size:    size    ?? this.size,
    font:    font    ?? this.font,
    spacing: spacing ?? this.spacing,
  );
}

// ── Service ───────────────────────────────────────────────────────────────────

class TypographyService extends ChangeNotifier {
  static final TypographyService _instance = TypographyService._();
  TypographyService._();
  factory TypographyService() => _instance;

  TypographyPrefs _prefs = const TypographyPrefs();
  TypographyPrefs get prefs => _prefs;

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final sp = await SharedPreferences.getInstance();
    _prefs = TypographyPrefs(
      size: TypographySize.values[sp.getInt('typo_size') ?? 1],
      font: TypographyFont.values[sp.getInt('typo_font') ?? 0],
      spacing: TypographySpacing.values[sp.getInt('typo_spacing') ?? 1],
    );
    _loaded = true;
    notifyListeners();
  }

  Future<void> setSize(TypographySize size) async {
    _prefs = _prefs.copyWith(size: size);
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('typo_size', size.index);
  }

  Future<void> setFont(TypographyFont font) async {
    _prefs = _prefs.copyWith(font: font);
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('typo_font', font.index);
  }

  Future<void> setSpacing(TypographySpacing spacing) async {
    _prefs = _prefs.copyWith(spacing: spacing);
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('typo_spacing', spacing.index);
  }
}
