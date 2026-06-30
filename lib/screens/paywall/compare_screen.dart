import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import 'paywall_screen.dart';

// ── Feature data ──────────────────────────────────────────────────────────────

class _Feature {
  final IconData icon;
  final String title;
  final String description;
  final bool isPro;

  const _Feature({
    required this.icon,
    required this.title,
    required this.description,
    required this.isPro,
  });
}

const _features = [
  _Feature(
    icon: Icons.menu_book_outlined,
    title: 'Bible Reading',
    description: 'KJV, NIV, CSB — read, highlight, and bookmark any passage.',
    isPro: false,
  ),
  _Feature(
    icon: Icons.edit_note_outlined,
    title: 'Notes & Journaling',
    description: 'Capture thoughts, reflections, and sermon notes.',
    isPro: false,
  ),
  _Feature(
    icon: Icons.route_outlined,
    title: 'Reading Plans',
    description: 'Structured paths through Scripture — Romans, Psalms, and more.',
    isPro: false,
  ),
  _Feature(
    icon: Icons.military_tech_outlined,
    title: 'Badges & Streaks',
    description: 'Track your consistency and earn badges as you grow.',
    isPro: false,
  ),
  _Feature(
    icon: Icons.group_outlined,
    title: 'Join 1 Group',
    description: 'Study with one community group using an invite code.',
    isPro: false,
  ),
  _Feature(
    icon: Icons.psychology_outlined,
    title: 'AI Study Sessions',
    description: 'SOAP, Inductive, Word Study, Lectio Divina — full AI-guided deep dives.',
    isPro: true,
  ),
  _Feature(
    icon: Icons.chat_bubble_outline,
    title: 'Ask Questions',
    description: 'Ask anything about a passage and get thoughtful, grounded answers.',
    isPro: true,
  ),
  _Feature(
    icon: Icons.auto_stories_outlined,
    title: 'AI Debrief',
    description: 'Let AI unpack your notes and surface spiritual themes across your journal.',
    isPro: true,
  ),
  _Feature(
    icon: Icons.translate_outlined,
    title: 'Greek & Hebrew Explorer',
    description: 'Go deeper with original language word studies on any passage.',
    isPro: true,
  ),
  _Feature(
    icon: Icons.groups_outlined,
    title: 'Unlimited Groups',
    description: 'Create and join as many groups as you want. Lead multiple communities.',
    isPro: true,
  ),
];

// ── CompareScreen ─────────────────────────────────────────────────────────────

class CompareScreen extends StatelessWidget {
  const CompareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final freeFeatures = _features.where((f) => !f.isPro).toList();
    final proFeatures  = _features.where((f) => f.isPro).toList();

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Close ──────────────────────────────────────────────────────
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.cardDark,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: AppColors.textMuted, size: 18),
                  ),
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ─────────────────────────────────────────────
                    const Text(
                      'What\'s included',
                      style: TextStyle(
                        fontFamily: 'Lora',
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.warmWhite,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Start free. Upgrade when you\'re ready to go deeper.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Free section ───────────────────────────────────────
                    _SectionLabel(label: 'Always Free', color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    ...freeFeatures.map((f) => _FeatureCard(feature: f)),

                    const SizedBox(height: 24),

                    // ── Pro section ────────────────────────────────────────
                    _SectionLabel(label: 'Dig Deeper Pro', color: AppColors.gold),
                    const SizedBox(height: 12),
                    ...proFeatures.map((f) => _FeatureCard(feature: f)),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // ── CTA ────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await showPaywall(context);
                      },
                      child: const Text(
                        'Start 3-Day Free Trial',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Cancel anytime. No charge during trial.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 16, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ── Feature card ──────────────────────────────────────────────────────────────

class _FeatureCard extends StatelessWidget {
  final _Feature feature;
  const _FeatureCard({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: feature.isPro
              ? AppColors.gold.withOpacity(0.07)
              : AppColors.cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: feature.isPro ? AppColors.gold.withOpacity(0.25) : AppColors.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: feature.isPro
                    ? AppColors.gold.withOpacity(0.15)
                    : AppColors.cardMid,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                feature.icon,
                color: feature.isPro ? AppColors.gold : AppColors.textMuted,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feature.title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: feature.isPro ? AppColors.warmWhite : AppColors.warmWhite,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    feature.description,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              feature.isPro ? Icons.auto_awesome : Icons.check_circle_outline,
              color: feature.isPro ? AppColors.gold : AppColors.sageGreen,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helper: show compare screen ───────────────────────────────────────────────

Future<void> showCompareScreen(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.black,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const CompareScreen(),
  );
}
