import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/subscription_provider.dart';
import '../../core/services/subscription_service.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  String _selected = kProductYearly;
  bool _purchasing = false;
  bool _restoring = false;

  @override
  Widget build(BuildContext context) {
    final service  = ref.watch(subscriptionProvider);
    final products = service.products;
    final isPro    = service.isPro;

    // Auto-dismiss if they just purchased
    if (isPro) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }

    final yearly  = service.productById(kProductYearly);
    final monthly = service.productById(kProductMonthly);

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Close button ─────────────────────────────────────────────
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
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // ── Icon ─────────────────────────────────────────────
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome, color: AppColors.gold, size: 36),
                    ),
                    const SizedBox(height: 20),

                    // ── Headline ─────────────────────────────────────────
                    const Text(
                      'Dig Deeper Pro',
                      style: TextStyle(
                        fontFamily: 'Lora',
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.warmWhite,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Unlock everything and go deeper every day.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        color: AppColors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // ── Features ─────────────────────────────────────────
                    ..._features.map((f) => _FeatureRow(icon: f.$1, label: f.$2)),
                    const SizedBox(height: 32),

                    // ── Plan picker ───────────────────────────────────────
                    if (service.loading || products.isEmpty)
                      const CircularProgressIndicator(color: AppColors.gold)
                    else ...[
                      if (yearly != null)
                        _PlanTile(
                          product: yearly,
                          selected: _selected == kProductYearly,
                          badge: 'Best Value',
                          onTap: () => setState(() => _selected = kProductYearly),
                        ),
                      const SizedBox(height: 12),
                      if (monthly != null)
                        _PlanTile(
                          product: monthly,
                          selected: _selected == kProductMonthly,
                          onTap: () => setState(() => _selected = kProductMonthly),
                        ),
                    ],

                    // ── Error ─────────────────────────────────────────────
                    if (service.pendingError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        service.pendingError!,
                        style: const TextStyle(color: AppColors.error, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),

            // ── CTA ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
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
                      onPressed: _purchasing || service.loading || products.isEmpty
                          ? null
                          : () => _startPurchase(service),
                      child: _purchasing
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.black,
                              ),
                            )
                          : const Text(
                              'Start Free Trial',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _restoring ? null : () => _restore(service),
                    child: Text(
                      _restoring ? 'Restoring…' : 'Restore Purchases',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppColors.textMuted,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Cancel anytime. Subscription renews automatically.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
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

  Future<void> _startPurchase(SubscriptionService service) async {
    final product = service.productById(_selected);
    if (product == null) return;
    setState(() => _purchasing = true);
    await service.purchase(product);
    if (mounted) setState(() => _purchasing = false);
  }

  Future<void> _restore(SubscriptionService service) async {
    setState(() => _restoring = true);
    await service.restorePurchases();
    if (mounted) setState(() => _restoring = false);
  }
}

// ── Feature list ──────────────────────────────────────────────────────────────

const _features = [
  (Icons.psychology_outlined,    'AI Study — deep dives into any passage'),
  (Icons.auto_stories_outlined,  'AI Debrief — unpack your notes with AI'),
  (Icons.translate_outlined,     'Greek & Hebrew Explorer'),
  (Icons.auto_awesome_outlined,  'Unlimited reading plans'),
];

// ── Feature row ───────────────────────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.warmWhite,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Plan tile ─────────────────────────────────────────────────────────────────

class _PlanTile extends StatelessWidget {
  final ProductDetails product;
  final bool selected;
  final String? badge;
  final VoidCallback onTap;

  const _PlanTile({
    required this.product,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold.withOpacity(0.12) : AppColors.cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Radio circle
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.gold : AppColors.textMuted,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 10, height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.gold,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title.replaceAll(RegExp(r'\s*\(.*\)'), ''),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.warmWhite,
                    ),
                  ),
                  Text(
                    product.description,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  product.price,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.warmWhite,
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        color: Colors.black,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mock plan tile (screenshot only) ─────────────────────────────────────────

class _MockPlanTile extends StatelessWidget {
  final String title;
  final String description;
  final String price;
  final bool selected;
  final String? badge;
  final VoidCallback onTap;

  const _MockPlanTile({
    required this.title,
    required this.description,
    required this.price,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold.withOpacity(0.12) : AppColors.cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.gold : AppColors.textMuted,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 10, height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.gold,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.warmWhite)),
                  Text(description, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(price, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.warmWhite)),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(20)),
                    child: Text(badge!, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 10, color: Colors.black)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helper: show paywall ──────────────────────────────────────────────────────

Future<void> showPaywall(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.black,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const PaywallScreen(),
  );
}
