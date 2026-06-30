import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/plan_definitions.dart';
import '../../core/services/plan_service.dart';

// ── Providers ──────────────────────────────────────────────────────────────────

final activePlanProvider = StreamProvider<ActivePlanState?>((ref) {
  return PlanService().activePlanStream();
});

// ── Screen ─────────────────────────────────────────────────────────────────────

class ReadingPlansScreen extends ConsumerWidget {
  const ReadingPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(activePlanProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            surfaceTintColor: Colors.transparent,
            pinned: true,
            titleSpacing: 20,
            title: Text(
              'Reading Plans',
              style: TextStyle(
                fontFamily: 'Lora',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.label(context),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Active plan card ─────────────────────────────────────────
                activeAsync.when(
                  data: (active) {
                    if (active == null || active.isComplete) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CURRENT PLAN',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 10,
                            fontWeight: FontWeight.w700, color: AppColors.textDim,
                            letterSpacing: 1.2)),
                        const SizedBox(height: 10),
                        _ActivePlanCard(active: active),
                        const SizedBox(height: 32),
                      ],
                    );
                  },
                  loading: () => const SizedBox(height: 8),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                // ── All plans — rendered immediately from hardcoded data ──────
                Text('ALL PLANS',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 10,
                    fontWeight: FontWeight.w700, color: AppColors.textDim,
                    letterSpacing: 1.2)),
                const SizedBox(height: 12),

                // Plans render right away; activeAsync only controls isActive flag
                ...kAllPlans.map((plan) {
                  final active = activeAsync.valueOrNull;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PlanCard(
                      plan: plan,
                      isActive: active?.planId == plan.id,
                      onTap: () => _onPlanTap(context, ref, plan, active),
                    ),
                  );
                }),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _onPlanTap(
    BuildContext context,
    WidgetRef ref,
    PlanDef plan,
    ActivePlanState? active,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // Pass the screen context separately so we can show snackbars after the sheet closes
      builder: (sheetCtx) => _PlanDetailSheet(
        plan: plan,
        active: active,
        screenContext: context,
        onStart: () async {
          // If another plan is active, confirm switch — using screen context for dialog
          if (active != null && active.planId != plan.id) {
            Navigator.pop(sheetCtx); // close sheet using sheet's context
            final confirm = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: AppColors.cardDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text('Switch plans?',
                  style: TextStyle(fontFamily: 'Lora', color: AppColors.label(context))),
                content: Text(
                  'You\'re on day ${active.currentDay} of "${active.plan.title}". '
                  'Starting a new plan will abandon your current progress.',
                  style: TextStyle(fontFamily: 'Inter',
                    color: AppColors.sublabel(context), fontSize: 14, height: 1.5)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Cancel',
                      style: TextStyle(color: AppColors.sublabel(context))),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('Start "${plan.title}"',
                      style: TextStyle(color: AppColors.gold)),
                  ),
                ],
              ),
            );
            if (confirm != true || !context.mounted) return;
          } else {
            Navigator.pop(sheetCtx); // close sheet using sheet's context
          }

          try {
            await PlanService().startPlan(plan.id);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Could not start plan: $e'),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ));
            }
          }
        },
        onContinue: active?.planId == plan.id
          ? (sheetContext) {
              Navigator.pop(sheetContext);
              context.go('/reader', extra: {
                'book': active!.todayPassage.bookId,
                'chapter': active.todayPassage.chapter,
              });
            }
          : null,
      ),
    );
  }
}

// ── Active Plan Card ───────────────────────────────────────────────────────────

class _ActivePlanCard extends ConsumerWidget {
  final ActivePlanState active;
  const _ActivePlanCard({required this.active});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysLeft = active.plan.durationDays - active.completedDays.length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withOpacity(0.3)),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Image header
        if (active.plan.imagePath != null)
          SizedBox(
            height: 140,
            width: double.infinity,
            child: Stack(fit: StackFit.expand, children: [
              Image.asset(
                active.plan.imagePath!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: AppColors.cardElevated(context)),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, AppColors.cardDark.withOpacity(0.9)],
                  ),
                ),
              ),
            ]),
          ),
        Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(active.plan.title,
                style: TextStyle(fontFamily: 'Lora', fontSize: 18,
                  fontWeight: FontWeight.bold, color: AppColors.label(context))),
              const SizedBox(height: 4),
              Text(
                'Day ${active.currentDay} of ${active.plan.durationDays}  ·  $daysLeft days left',
                style: TextStyle(fontFamily: 'Inter', fontSize: 13,
                  color: AppColors.sublabel(context)),
              ),
            ]),
          ),
          GestureDetector(
            onTap: () => _confirmAbandon(context, ref),
            child: Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.close, color: AppColors.textDim, size: 18),
            ),
          ),
        ]),

        const SizedBox(height: 16),

        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: active.progressFraction,
            minHeight: 6,
            backgroundColor: AppColors.divider(context),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${active.completedDays.length} of ${active.plan.durationDays} days complete',
          style: TextStyle(fontFamily: 'Inter', fontSize: 11,
            color: AppColors.textDim),
        ),

        const SizedBox(height: 16),
        Divider(height: 1, color: AppColors.divider(context)),
        const SizedBox(height: 16),

        Text('TODAY',
          style: TextStyle(fontFamily: 'Inter', fontSize: 10,
            fontWeight: FontWeight.w700, color: AppColors.textDim,
            letterSpacing: 1.2)),
        const SizedBox(height: 6),
        Text(active.todayPassage.label,
          style: TextStyle(fontFamily: 'Lora', fontSize: 16,
            color: AppColors.label(context))),

        const SizedBox(height: 14),

        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () => context.go('/reader', extra: {
                'book': active.todayPassage.bookId,
                'chapter': active.todayPassage.chapter,
              }),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.cardElevated(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text('Read',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 14,
                      fontWeight: FontWeight.w600, color: AppColors.label(context))),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => _markComplete(context, ref),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text('Mark Complete',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 14,
                      fontWeight: FontWeight.w600, color: AppColors.black)),
                ),
              ),
            ),
          ),
        ]),
        ]),  // Column
        ),   // Padding
      ]),    // outer Column
    );
  }

  Future<void> _markComplete(BuildContext context, WidgetRef ref) async {
    final isLastDay = active.currentDay >= active.plan.durationDays;
    await PlanService().markDayComplete(active.planId);
    ref.invalidate(activePlanProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isLastDay
          ? '🎉 You completed "${active.plan.title}"!'
          : 'Day ${active.currentDay} complete!'),
        backgroundColor: AppColors.cardElevated(context),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _confirmAbandon(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Abandon plan?',
          style: TextStyle(fontFamily: 'Lora', color: AppColors.label(context))),
        content: Text(
          'You\'re on day ${active.currentDay} of "${active.plan.title}". '
          'Your progress will be lost.',
          style: TextStyle(fontFamily: 'Inter', color: AppColors.sublabel(context),
            fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Keep going',
              style: TextStyle(color: AppColors.sublabel(context))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Abandon',
              style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await PlanService().abandonPlan(active.planId);
    ref.invalidate(activePlanProvider);
  }
}

// ── Plan Detail Sheet ──────────────────────────────────────────────────────────

class _PlanDetailSheet extends StatelessWidget {
  final PlanDef plan;
  final ActivePlanState? active;
  final BuildContext screenContext;
  final Future<void> Function() onStart;
  final void Function(BuildContext sheetContext)? onContinue;

  const _PlanDetailSheet({
    required this.plan,
    required this.active,
    required this.screenContext,
    required this.onStart,
    this.onContinue,
  });

  bool get isActive => onContinue != null;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg(context),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(children: [
          // ── Scrollable content ──────────────────────────────────────────────
          Expanded(
            child: CustomScrollView(
              controller: controller,
              slivers: [
                // Image header
                SliverToBoxAdapter(
                  child: Stack(children: [
                    SizedBox(
                      height: 220,
                      width: double.infinity,
                      child: plan.imagePath != null
                        ? Image.asset(
                            plan.imagePath!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.cardElevated(context),
                              child: Icon(Icons.menu_book_rounded,
                                color: AppColors.textDim, size: 48),
                            ),
                          )
                        : Container(
                            color: AppColors.cardElevated(context),
                            child: Icon(Icons.menu_book_rounded,
                              color: AppColors.textDim, size: 48),
                          ),
                    ),
                    // Gradient overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              AppColors.cardDark.withOpacity(0.95),
                            ],
                            stops: const [0.4, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Close button
                    Positioned(
                      top: 12, right: 12,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close,
                            color: AppColors.label(context), size: 18),
                        ),
                      ),
                    ),
                    // Title overlay at bottom of image
                    Positioned(
                      bottom: 16, left: 20, right: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isActive)
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.gold.withOpacity(0.4)),
                              ),
                              child: Text('YOUR CURRENT PLAN',
                                style: TextStyle(fontFamily: 'Inter', fontSize: 10,
                                  fontWeight: FontWeight.w700, color: AppColors.gold,
                                  letterSpacing: 1.0)),
                            ),
                          Text(plan.title,
                            style: TextStyle(fontFamily: 'Lora', fontSize: 24,
                              fontWeight: FontWeight.bold, color: AppColors.label(context))),
                          const SizedBox(height: 4),
                          Text(plan.subtitle,
                            style: TextStyle(fontFamily: 'Inter', fontSize: 13,
                              color: AppColors.gold)),
                        ],
                      ),
                    ),
                  ]),
                ),

                // Body content
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Description
                      Text(plan.description,
                        style: TextStyle(fontFamily: 'Inter', fontSize: 15,
                          color: AppColors.sublabel(context), height: 1.6)),

                      const SizedBox(height: 28),

                      // Progress bar (active plan only)
                      if (isActive) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Day ${active!.currentDay} of ${active!.plan.durationDays}',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                                color: AppColors.textDim)),
                            Text(
                              '${active!.completedDays.length} complete',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                                color: AppColors.textDim)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: active!.progressFraction,
                            minHeight: 6,
                            backgroundColor: AppColors.divider(context),
                            valueColor:
                              const AlwaysStoppedAnimation<Color>(AppColors.gold),
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],

                      // Passage list
                      Text('READING SCHEDULE',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 10,
                          fontWeight: FontWeight.w700, color: AppColors.textDim,
                          letterSpacing: 1.2)),
                      const SizedBox(height: 12),

                      ...List.generate(plan.passages.length, (i) {
                        final day = i + 1;
                        final passage = plan.passages[i];
                        final isDone = active?.completedDays.contains(day) ?? false;
                        final isToday = isActive && active!.currentDay == day;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isToday
                                ? AppColors.gold.withOpacity(0.07)
                                : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: isToday
                                ? Border.all(color: AppColors.gold.withOpacity(0.25))
                                : null,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                              child: Row(children: [
                                // Day number
                                SizedBox(
                                  width: 32,
                                  child: Text(
                                    '$day',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isToday
                                        ? AppColors.gold
                                        : AppColors.textDim,
                                    ),
                                  ),
                                ),
                                // Passage label
                                Expanded(
                                  child: Text(
                                    passage.label,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      color: isDone
                                        ? AppColors.textDim
                                        : AppColors.label(context),
                                      decoration: isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                      decorationColor: AppColors.textDim,
                                    ),
                                  ),
                                ),
                                // Status icon
                                if (isDone)
                                  Icon(Icons.check_circle_rounded,
                                    color: AppColors.gold, size: 16)
                                else if (isToday)
                                  Icon(Icons.arrow_right_rounded,
                                    color: AppColors.gold, size: 20),
                              ]),
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 12),
                    ]),
                  ),
                ),
              ],
            ),
          ),

          // ── Fixed bottom action button ──────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomPadding),
            decoration: BoxDecoration(
              color: AppColors.cardBg(context),
              border: Border(top: BorderSide(color: AppColors.divider(context))),
            ),
            child: isActive
              ? GestureDetector(
                  onTap: () => onContinue!(context),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: AppColors.goldGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        'Continue — ${active!.todayPassage.label}',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 15,
                          fontWeight: FontWeight.w700, color: AppColors.black),
                      ),
                    ),
                  ),
                )
              : GestureDetector(
                  onTap: onStart,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: AppColors.goldGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        'Start Plan',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 15,
                          fontWeight: FontWeight.w700, color: AppColors.black),
                      ),
                    ),
                  ),
                ),
          ),
        ]),
      ),
    );
  }
}

// ── Plan List Card ─────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final PlanDef plan;
  final bool isActive;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
              ? AppColors.gold.withOpacity(0.4)
              : AppColors.divider(context),
          ),
        ),
        clipBehavior: Clip.hardEdge,
        child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Thumbnail
          SizedBox(
            width: 90,
            child: plan.imagePath != null
              ? Image.asset(
                  plan.imagePath!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.cardElevated(context),
                    child: Icon(Icons.menu_book_rounded,
                      color: AppColors.textDim, size: 28),
                  ),
                )
              : Container(
                  color: AppColors.cardElevated(context),
                  child: Icon(Icons.menu_book_rounded,
                    color: AppColors.textDim, size: 28),
                ),
          ),
          // Text content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(plan.title,
                        style: TextStyle(fontFamily: 'Lora', fontSize: 15,
                          fontWeight: FontWeight.bold, color: AppColors.label(context))),
                    ),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Active',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 10,
                            fontWeight: FontWeight.w700, color: AppColors.gold)),
                      ),
                  ]),
                  const SizedBox(height: 3),
                  Text(plan.subtitle,
                    style: TextStyle(fontFamily: 'Inter', fontSize: 11,
                      color: AppColors.gold)),
                  const SizedBox(height: 6),
                  Text(plan.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                      color: AppColors.sublabel(context), height: 1.4)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              isActive
                ? Icons.play_circle_filled_rounded
                : Icons.chevron_right_rounded,
              color: isActive ? AppColors.gold : AppColors.textDim,
              size: 22,
            ),
          ),
        ]),
        ), // IntrinsicHeight
      ),
    );
  }
}
