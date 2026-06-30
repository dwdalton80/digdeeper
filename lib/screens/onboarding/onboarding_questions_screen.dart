import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/colors.dart';

// ── Data model ───────────────────────────────────────────────────────────────

class _Question {
  final String id;
  final String headline;
  final String subtitle;
  final IconData icon;
  final List<_Choice> choices;

  const _Question({
    required this.id,
    required this.headline,
    required this.subtitle,
    required this.icon,
    required this.choices,
  });
}

class _Choice {
  final String value;
  final String label;
  final String? emoji;

  const _Choice({required this.value, required this.label, this.emoji});
}

final _questions = [
  _Question(
    id: 'experience',
    headline: 'How familiar are you\nwith the Bible?',
    subtitle: 'We\'ll personalize your study depth.',
    icon: Icons.menu_book_outlined,
    choices: [
      _Choice(value: 'new',        label: 'Just getting started',    emoji: '🌱'),
      _Choice(value: 'some',       label: 'I\'ve read some of it',   emoji: '📖'),
      _Choice(value: 'regular',    label: 'I study regularly',       emoji: '✨'),
      _Choice(value: 'deep',       label: 'Deep student of the Word',emoji: '🎓'),
    ],
  ),
  _Question(
    id: 'goal',
    headline: 'What brings you\nto Dig Deeper?',
    subtitle: 'Your goal shapes your journey.',
    icon: Icons.flag_outlined,
    choices: [
      _Choice(value: 'habit',      label: 'Build a daily study habit',  emoji: '🔥'),
      _Choice(value: 'understand', label: 'Understand the Bible better',emoji: '💡'),
      _Choice(value: 'faith',      label: 'Grow my faith',              emoji: '🙏'),
      _Choice(value: 'community',  label: 'Study with others',          emoji: '👥'),
    ],
  ),
  _Question(
    id: 'time',
    headline: 'How much time can\nyou give each day?',
    subtitle: 'We\'ll suggest the right session length.',
    icon: Icons.schedule_outlined,
    choices: [
      _Choice(value: '5',   label: 'Just 5 minutes',    emoji: '⚡'),
      _Choice(value: '10',  label: 'About 10 minutes',  emoji: '🎯'),
      _Choice(value: '20',  label: '15–20 minutes',     emoji: '📚'),
      _Choice(value: '30',  label: '30+ minutes',       emoji: '🏆'),
    ],
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class OnboardingQuestionsScreen extends StatefulWidget {
  const OnboardingQuestionsScreen({super.key});

  @override
  State<OnboardingQuestionsScreen> createState() => _OnboardingQuestionsScreenState();
}

class _OnboardingQuestionsScreenState extends State<OnboardingQuestionsScreen>
    with TickerProviderStateMixin {
  int _currentPage = 0;
  final Map<String, String> _answers = {};
  bool _saving = false;

  late final PageController _pageCtrl;
  late final AnimationController _progressCtrl;
  late final Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      value: 1 / _questions.length,
    );
    _progressAnim = CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  void _selectChoice(String questionId, String value) {
    setState(() => _answers[questionId] = value);

    // Small delay so user sees selection animate, then advance
    Future.delayed(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      if (_currentPage < _questions.length - 1) {
        _currentPage++;
        _pageCtrl.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeInOutCubic,
        );
        _progressCtrl.animateTo(
          (_currentPage + 1) / _questions.length,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeInOut,
        );
      } else {
        _finish();
      }
    });
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'onboarding': {
            ..._answers,
            'completedAt': FieldValue.serverTimestamp(),
          },
          'onboardingComplete': true,
        }, SetOptions(merge: true));
      }
      // Cache locally so HomeScreen doesn't re-check Firestore next launch
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_questions_complete', true);
    } catch (_) {
      // Non-fatal — still proceed
    }
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.black,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                currentPage: _currentPage,
                total: _questions.length,
                progressAnim: _progressAnim,
                onSkip: _finish,
                saving: _saving,
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _questions.length,
                  itemBuilder: (_, i) => _QuestionPage(
                    question: _questions[i],
                    selected: _answers[_questions[i].id],
                    onSelect: (val) => _selectChoice(_questions[i].id, val),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final int currentPage;
  final int total;
  final Animation<double> progressAnim;
  final VoidCallback onSkip;
  final bool saving;

  const _TopBar({
    required this.currentPage,
    required this.total,
    required this.progressAnim,
    required this.onSkip,
    required this.saving,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '${currentPage + 1} of $total',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: AppColors.warmWhite.withOpacity(0.4),
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              if (!saving)
                GestureDetector(
                  onTap: onSkip,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppColors.warmWhite.withOpacity(0.35),
                    ),
                  ),
                )
              else
                const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.gold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Container(
              height: 3,
              color: AppColors.warmWhite.withOpacity(0.08),
              child: AnimatedBuilder(
                animation: progressAnim,
                builder: (_, __) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progressAnim.value,
                  child: Container(color: AppColors.gold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Question page ─────────────────────────────────────────────────────────────

class _QuestionPage extends StatefulWidget {
  final _Question question;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _QuestionPage({
    required this.question,
    required this.selected,
    required this.onSelect,
  });

  @override
  State<_QuestionPage> createState() => _QuestionPageState();
}

class _QuestionPageState extends State<_QuestionPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // Icon
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.gold.withOpacity(0.2)),
                ),
                child: Icon(q.icon, color: AppColors.gold, size: 24),
              ),

              const SizedBox(height: 22),

              Text(
                q.headline,
                style: const TextStyle(
                  fontFamily: 'Lora',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.warmWhite,
                  height: 1.25,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                q.subtitle,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppColors.warmWhite.withOpacity(0.45),
                ),
              ),

              const SizedBox(height: 36),

              // Choices
              ...q.choices.map((choice) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ChoiceTile(
                  choice: choice,
                  selected: widget.selected == choice.value,
                  onTap: () => widget.onSelect(choice.value),
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Choice tile ───────────────────────────────────────────────────────────────

class _ChoiceTile extends StatelessWidget {
  final _Choice choice;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected
            ? AppColors.gold.withOpacity(0.12)
            : AppColors.warmWhite.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? AppColors.gold.withOpacity(0.55)
              : AppColors.warmWhite.withOpacity(0.08),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          splashColor: AppColors.gold.withOpacity(0.08),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                if (choice.emoji != null) ...[
                  Text(choice.emoji!, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Text(
                    choice.label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected
                          ? AppColors.warmWhite
                          : AppColors.warmWhite.withOpacity(0.7),
                    ),
                  ),
                ),
                AnimatedOpacity(
                  opacity: selected ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 20, height: 20,
                    decoration: const BoxDecoration(
                      color: AppColors.gold,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, size: 13, color: AppColors.black),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
