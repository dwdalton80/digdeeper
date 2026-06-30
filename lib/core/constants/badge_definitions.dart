import 'package:flutter/material.dart';

/// A single badge definition.
class BadgeDef {
  final String id;
  final String name;
  final String description;  // short earned label
  final String howToEarn;    // shown in the "View All" sheet
  final IconData icon;       // placeholder until real assets are added
  final Color color;
  // Set this to a real asset path once Derek drops the icons in.
  // e.g. 'assets/images/badges/badge_first_step.png'
  final String? assetPath;

  const BadgeDef({
    required this.id,
    required this.name,
    required this.description,
    required this.howToEarn,
    required this.icon,
    required this.color,
    this.assetPath,
  });
}

/// All Dig Deeper badges in display order.
const kAllBadges = <BadgeDef>[
  // ── Study milestones ───────────────────────────────────────────────────────
  BadgeDef(
    id: 'first_step',
    name: 'First Step',
    description: 'Completed your first AI study',
    howToEarn: 'Complete your first AI study session.',
    icon: Icons.school_outlined,
    color: Color(0xFFE8B84B), // gold
    assetPath: 'assets/images/badges/badge_first_step@3x.png',
  ),
  BadgeDef(
    id: 'deep_roots',
    name: 'Deep Roots',
    description: 'Completed 5 AI studies',
    howToEarn: 'Complete 5 AI study sessions.',
    icon: Icons.park_outlined,
    color: Color(0xFF4CAF50), // green
    assetPath: 'assets/images/badges/badge_deep_roots@3x.png',
  ),
  BadgeDef(
    id: 'devoted',
    name: 'Devoted',
    description: 'Completed 25 AI studies',
    howToEarn: 'Complete 25 AI study sessions.',
    icon: Icons.auto_stories_outlined,
    color: Color(0xFF5B8AF5), // blue
    assetPath: 'assets/images/badges/badge_devoted@3x.png',
  ),

  // ── Word Study ─────────────────────────────────────────────────────────────
  BadgeDef(
    id: 'word_seeker',
    name: 'Word Seeker',
    description: 'Completed your first Word Study',
    howToEarn: 'Complete a Word Study (Greek · Hebrew) session.',
    icon: Icons.translate_outlined,
    color: Color(0xFF26A69A), // teal
    assetPath: 'assets/images/badges/badge_word_seeker@3x.png',
  ),
  BadgeDef(
    id: 'lexicon',
    name: 'Lexicon',
    description: 'Completed 5 Word Studies',
    howToEarn: 'Complete 5 Word Study sessions.',
    icon: Icons.history_edu_outlined,
    color: Color(0xFF26A69A),
    assetPath: 'assets/images/badges/badge_lexicon@3x.png',
  ),

  // ── Notes ──────────────────────────────────────────────────────────────────
  BadgeDef(
    id: 'scribe',
    name: 'Scribe',
    description: 'Saved your first note',
    howToEarn: 'Save your first note in the Notes tab.',
    icon: Icons.edit_outlined,
    color: Color(0xFFF06292), // pink
    assetPath: 'assets/images/badges/badge_scribe@3x.png',
  ),
  BadgeDef(
    id: 'chronicler',
    name: 'Chronicler',
    description: 'Saved 10 notes',
    howToEarn: 'Save 10 notes in the Notes tab.',
    icon: Icons.menu_book_outlined,
    color: Color(0xFFF06292),
    assetPath: 'assets/images/badges/badge_chronicler@3x.png',
  ),

  // ── Reading & highlights ───────────────────────────────────────────────────
  BadgeDef(
    id: 'marked',
    name: 'Marked',
    description: 'Highlighted your first verse',
    howToEarn: 'Long-press any verse in the Reader and highlight it.',
    icon: Icons.highlight_outlined,
    color: Color(0xFFFFB300), // amber
    assetPath: 'assets/images/badges/badge_marked@3x.png',
  ),
  BadgeDef(
    id: 'explorer',
    name: 'Explorer',
    description: 'Studied in 5 different books',
    howToEarn: 'Complete AI studies in 5 different books of the Bible.',
    icon: Icons.explore_outlined,
    color: Color(0xFF9C6FE0), // purple
    assetPath: 'assets/images/badges/badge_explorer@3x.png',
  ),

  // ── Streak ─────────────────────────────────────────────────────────────────
  BadgeDef(
    id: 'seven_days',
    name: 'Seven Days',
    description: 'Studied 7 days in a row',
    howToEarn: 'Complete a study for 7 consecutive days.',
    icon: Icons.local_fire_department_outlined,
    color: Color(0xFFFF7043), // deep orange
    assetPath: 'assets/images/badges/badge_seven_days@3x.png',
  ),

  // ── Community ──────────────────────────────────────────────────────────────
  BadgeDef(
    id: 'iron_sharpens',
    name: 'Iron Sharpens Iron',
    description: 'Posted in a group',
    howToEarn: 'Post something in a group community feed.',
    icon: Icons.groups_outlined,
    color: Color(0xFF5B8AF5),
    assetPath: 'assets/images/badges/badge_iron_sharpens_iron@3x.png',
  ),
  BadgeDef(
    id: 'prayer_warrior',
    name: 'Prayer Warrior',
    description: 'Added a prayer request in a group',
    howToEarn: 'Add a prayer request in any group.',
    icon: Icons.volunteer_activism_outlined,
    color: Color(0xFF9C6FE0),
    assetPath: 'assets/images/badges/badge_prayer_warrior@3x.png',
  ),
];

/// Look up a badge by ID.
BadgeDef? badgeById(String id) {
  try {
    return kAllBadges.firstWhere((b) => b.id == id);
  } catch (_) {
    return null;
  }
}
