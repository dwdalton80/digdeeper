import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/colors.dart';

// ── Public API ─────────────────────────────────────────────────────────────────

const _kPrefKey = 'coach_complete_v1';

/// Call this once on first HomeScreen load to decide whether to show the coach.
Future<bool> shouldShowCoach() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kPrefKey) != true;
}

/// Mark the coach as done so it never shows again.
Future<void> markCoachComplete() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kPrefKey, true);
}

// ── Step model ─────────────────────────────────────────────────────────────────

enum _SpotlightTarget {
  none,       // full dim overlay, no cutout
  topContent, // top 55% of screen (verse card area)
  navHome,
  navBible,
  navStudy,
  navNotes,
  navGroups,
}

class _CoachStep {
  final String title;
  final String body;
  final _SpotlightTarget spotlight;
  final IconData icon;

  const _CoachStep({
    required this.title,
    required this.body,
    required this.spotlight,
    required this.icon,
  });
}

const _steps = [
  _CoachStep(
    title: 'Welcome to Dig Deeper',
    body: 'A quick tour so you know where everything lives. Tap Next whenever you\'re ready.',
    spotlight: _SpotlightTarget.none,
    icon: Icons.waving_hand_outlined,
  ),
  _CoachStep(
    title: 'Your Daily Verse',
    body: 'Each day starts with a fresh scripture and a one-tap "Study This" button to open an AI-guided session on that passage.',
    spotlight: _SpotlightTarget.topContent,
    icon: Icons.auto_awesome_outlined,
  ),
  _CoachStep(
    title: 'Read the Bible',
    body: 'KJV, NIV, or CSB. Long-press any verse to highlight it, ask AI a question, or add it to your journal.',
    spotlight: _SpotlightTarget.navBible,
    icon: Icons.menu_book_outlined,
  ),
  _CoachStep(
    title: 'AI Study',
    body: 'Pick any passage and go deep — context, cross-references, Greek/Hebrew roots, and questions to sit with.',
    spotlight: _SpotlightTarget.navStudy,
    icon: Icons.psychology_outlined,
  ),
  _CoachStep(
    title: 'Groups',
    body: 'Create a study group and dig into scripture together. Invite friends, share verses, and discuss.',
    spotlight: _SpotlightTarget.navGroups,
    icon: Icons.group_outlined,
  ),
  _CoachStep(
    title: 'You\'re all set!',
    body: 'Start with today\'s verse, or open the Bible and pick a passage that\'s on your heart.',
    spotlight: _SpotlightTarget.none,
    icon: Icons.check_circle_outline,
  ),
];

// ── Widget ─────────────────────────────────────────────────────────────────────

class CoachOverlay extends StatefulWidget {
  final VoidCallback onDone;

  const CoachOverlay({super.key, required this.onDone});

  @override
  State<CoachOverlay> createState() => _CoachOverlayState();
}

class _CoachOverlayState extends State<CoachOverlay>
    with SingleTickerProviderStateMixin {
  int _step = 0;
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < _steps.length - 1) {
      _ctrl.reverse().then((_) {
        if (mounted) {
          setState(() => _step++);
          _ctrl.forward();
        }
      });
    } else {
      _finish();
    }
  }

  void _finish() {
    markCoachComplete();
    widget.onDone();
  }

  double _cardBottomOffset(_CoachStep step, EdgeInsets padding) {
    final isNavStep = step.spotlight != _SpotlightTarget.none &&
        step.spotlight != _SpotlightTarget.topContent;
    return isNavStep ? 49.0 + padding.bottom + 12 : 24.0 + padding.bottom;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final step = _steps[_step];
    final bottomOffset = _cardBottomOffset(step, padding);

    return Stack(
      children: [
        // Spotlight + dim overlay — fills the whole screen
        Positioned.fill(
          child: FadeTransition(
            opacity: _fade,
            child: CustomPaint(
              painter: _SpotlightPainter(
                target: step.spotlight,
                screenSize: size,
                bottomPadding: padding.bottom,
              ),
            ),
          ),
        ),

        // Tap-through blocker
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
          ),
        ),

        // Coach card — Positioned is a direct child of Stack ✓
        Positioned(
          left: 20,
          right: 20,
          bottom: bottomOffset,
          child: FadeTransition(
            opacity: _fade,
            child: _CoachCard(
              step: step,
              stepIndex: _step,
              totalSteps: _steps.length,
              onNext: _next,
              onSkip: _finish,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Spotlight painter ─────────────────────────────────────────────────────────

class _SpotlightPainter extends CustomPainter {
  final _SpotlightTarget target;
  final Size screenSize;
  final double bottomPadding;

  const _SpotlightPainter({
    required this.target,
    required this.screenSize,
    required this.bottomPadding,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.72);

    if (target == _SpotlightTarget.none) {
      canvas.drawRect(Offset.zero & size, paint);
      return;
    }

    final rect = _spotlightRect(size);
    if (rect == null) {
      canvas.drawRect(Offset.zero & size, paint);
      return;
    }

    // Draw full overlay then cut out the spotlight with a blend mode
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Gold border around spotlight
    final borderPaint = Paint()
      ..color = AppColors.gold.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(20)), borderPaint);
  }

  Rect? _spotlightRect(Size size) {
    final w = size.width;
    final h = size.height;
    // Nav bar occupies bottom ~83pt on modern iPhone (49 bar + 34 safe area)
    final navH = 49.0 + bottomPadding;
    final navTop = h - navH;

    // Width of each nav item
    const tabCount = 5;
    final tabW = w / tabCount;

    switch (target) {
      case _SpotlightTarget.topContent:
        // Highlights the top content area (verse card etc.) below the app bar
        return Rect.fromLTWH(12, 96, w - 24, h * 0.45).inflate(4);

      case _SpotlightTarget.navHome:
        return _navTabRect(0, tabW, navTop);
      case _SpotlightTarget.navBible:
        return _navTabRect(1, tabW, navTop);
      case _SpotlightTarget.navStudy:
        return _navTabRect(2, tabW, navTop);
      case _SpotlightTarget.navNotes:
        return _navTabRect(3, tabW, navTop);
      case _SpotlightTarget.navGroups:
        return _navTabRect(4, tabW, navTop);

      default:
        return null;
    }
  }

  Rect _navTabRect(int index, double tabW, double navTop) {
    const pad = 6.0;
    return Rect.fromLTWH(
      index * tabW + pad,
      navTop + pad,
      tabW - pad * 2,
      49.0 - pad * 2,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.target != target || old.screenSize != screenSize;
}

// ── Coach card ─────────────────────────────────────────────────────────────────

class _CoachCard extends StatelessWidget {
  final _CoachStep step;
  final int stepIndex;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _CoachCard({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.onNext,
    required this.onSkip,
  });

  bool get _isLast => stepIndex == totalSteps - 1;

  @override
  Widget build(BuildContext context) {
    final isLast = _isLast;

    return Material(
      color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.gold.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Step indicator dots
              Row(
                children: [
                  ...List.generate(totalSteps, (i) => Container(
                    width: i == stepIndex ? 18 : 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: i == stepIndex
                          ? AppColors.gold
                          : AppColors.gold.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  )),
                  const Spacer(),
                  if (!isLast)
                    GestureDetector(
                      onTap: onSkip,
                      child: Text(
                        'Skip tour',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.warmWhite.withOpacity(0.35),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Icon
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gold.withOpacity(0.2)),
                ),
                child: Icon(step.icon, color: AppColors.gold, size: 22),
              ),

              const SizedBox(height: 14),

              // Title
              Text(
                step.title,
                style: const TextStyle(
                  fontFamily: 'Lora',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.warmWhite,
                ),
              ),

              const SizedBox(height: 8),

              // Body
              Text(
                step.body,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  height: 1.55,
                  color: AppColors.warmWhite.withOpacity(0.6),
                ),
              ),

              const SizedBox(height: 20),

              // Button
              GestureDetector(
                onTap: onNext,
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isLast ? AppColors.gold : AppColors.gold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: isLast
                        ? null
                        : Border.all(color: AppColors.gold.withOpacity(0.3)),
                  ),
                  child: Center(
                    child: Text(
                      isLast ? 'Let\'s Go  →' : 'Next  →',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isLast ? AppColors.black : AppColors.gold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
