import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import '../../core/constants/colors.dart';
import '../../core/services/streak_service.dart';
import '../../core/services/typography_service.dart';
import '../../core/services/theme_service.dart';
import '../home/home_screen.dart' show userProfileProvider;
import '../../core/providers/subscription_provider.dart';

// ── Providers ──────────────────────────────────────────────────────────────────

final _streakProvider = StreamProvider<StreakData>((ref) {
  return StreakService().streakStream();
});

final _translationProvider = StateProvider<String>((ref) => 'kjv');

// ── Screen ─────────────────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _linguisticTooltips = true;
  bool _dailyReminders     = true;
  String _version          = '1.0.0';
  DateTime? _lastSynced;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final lastSyncMs = prefs.getInt('last_sync_ms');
    setState(() {
      _linguisticTooltips = prefs.getBool('linguisticTooltips') ?? true;
      _dailyReminders     = prefs.getBool('dailyReminders')     ?? true;
      _lastSynced = lastSyncMs != null
          ? DateTime.fromMillisecondsSinceEpoch(lastSyncMs)
          : null;
    });
  }

  Future<void> _forceSync() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _syncing) return;
    setState(() => _syncing = true);
    try {
      // Force a server-side fetch to refresh local Firestore cache
      await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .get(const GetOptions(source: Source.server));
      await FirebaseFirestore.instance
          .collection('notes').doc(uid).collection('entries')
          .get(const GetOptions(source: Source.server));
      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_sync_ms', now.millisecondsSinceEpoch);
      if (mounted) setState(() { _lastSynced = now; _syncing = false; });
    } catch (_) {
      if (mounted) setState(() => _syncing = false);
    }
  }

  String get _syncSubtitle {
    if (_syncing) return 'Syncing…';
    if (_lastSynced == null) return 'Synced via Firebase';
    final diff = DateTime.now().difference(_lastSynced!);
    if (diff.inSeconds < 60)  return 'Synced just now';
    if (diff.inMinutes < 60)  return 'Synced ${diff.inMinutes}m ago';
    if (diff.inHours < 24)    return 'Synced ${diff.inHours}h ago';
    return 'Synced ${diff.inDays}d ago';
  }

  Future<void> _saveTooltips(bool val) async {
    setState(() => _linguisticTooltips = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('linguisticTooltips', val);
  }

  Future<void> _saveReminders(bool val) async {
    setState(() => _dailyReminders = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dailyReminders', val);

    // Write to Firestore — Cloud Function sendDigDeeperMorning reads this
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).update(
          {'preferences.focusCompanion': val},
        );
        debugPrint('[Profile] focusCompanion=$val written to Firestore');
      } catch (e) {
        debugPrint('[Profile] focusCompanion write ERROR: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final streakAsync  = ref.watch(_streakProvider);
    final user         = FirebaseAuth.instance.currentUser;

    final name = profileAsync.valueOrNull?.name
        ?? user?.displayName
        ?? 'Friend';
    final studyLevel = profileAsync.valueOrNull?.studyLevel;
    final levelLabel = studyLevel != null ? _levelLabel(studyLevel.name) : 'Growing';

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          // ── Top bar ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(children: [
              Text('Settings',
                style: TextStyle(fontFamily: 'Lora', fontSize: 28,
                  fontWeight: FontWeight.bold, color: AppColors.label(context))),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close_rounded,
                  color: AppColors.sublabel(context), size: 24),
                onPressed: () => context.go('/home'),
              ),
            ]),
          ),

          // ── Scrollable body ─────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              children: [

                // ── User header ────────────────────────────────────────────────
                _UserHeader(
                  name: name,
                  levelLabel: levelLabel,
                  isPremium: ref.watch(isProProvider),
                  avatarUrl: profileAsync.valueOrNull?.avatarUrl,
                  onEdit: () => _showEditSheet(context, name,
                    profileAsync.valueOrNull?.avatarUrl),
                ),
                const SizedBox(height: 20),

                // ── Streak card ────────────────────────────────────────────────
                streakAsync.when(
                  data:    (s) => _StreakCard(streak: s),
                  loading: () => _StreakCard(streak: StreakData.empty),
                  error:   (_, __) => _StreakCard(streak: StreakData.empty),
                ),
                const SizedBox(height: 28),

                // ── Reading Experience ─────────────────────────────────────────
                _SectionHeader('READING EXPERIENCE'),
                const SizedBox(height: 8),
                _SettingsCard(items: [
                  _SettingsRow(
                    icon: Icons.menu_book_outlined,
                    title: 'Default Translation',
                    subtitle: _translationLabel(
                      profileAsync.valueOrNull?.defaultVersion ?? 'kjv'),
                    onTap: () => _pickTranslation(context,
                      profileAsync.valueOrNull?.defaultVersion ?? 'kjv'),
                  ),
                  _SettingsRow(
                    icon: Icons.text_fields_rounded,
                    title: 'Typography',
                    subtitle: 'Size, serif style',
                    onTap: () => _showTypographySheet(context),
                  ),
                  _SettingsRow(
                    icon: Icons.translate_rounded,
                    title: 'Linguistic Tooltips',
                    subtitle: 'Show Greek/Hebrew',
                    trailing: _GoldSwitch(
                      value: _linguisticTooltips,
                      onChanged: _saveTooltips,
                    ),
                  ),
                ]),
                const SizedBox(height: 24),

                // ── Account & Sync ─────────────────────────────────────────────
                _SectionHeader('ACCOUNT & SYNC'),
                const SizedBox(height: 8),
                _SettingsCard(items: [
                  _SettingsRow(
                    icon: Icons.cloud_done_outlined,
                    title: 'Cloud Backup',
                    subtitle: _syncSubtitle,
                    trailing: _syncing
                      ? SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.gold))
                      : Icon(Icons.sync_rounded,
                          color: AppColors.sublabel(context), size: 20),
                    onTap: _forceSync,
                  ),
                  _SettingsRow(
                    icon: Icons.groups_outlined,
                    title: 'My Groups',
                    subtitle: 'View and manage groups',
                    onTap: () => context.go('/groups'),
                  ),
                ]),
                const SizedBox(height: 24),

                // ── Preferences ────────────────────────────────────────────────
                _SectionHeader('PREFERENCES'),
                const SizedBox(height: 8),
                _SettingsCard(items: [
                  ListenableBuilder(
                    listenable: ThemeService(),
                    builder: (_, __) => _SettingsRow(
                      icon: ThemeService().isDark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                      title: 'Dark Mode',
                      subtitle: ThemeService().isDark ? 'Dark' : 'Light',
                      trailing: _GoldSwitch(
                        value: ThemeService().isDark,
                        onChanged: (val) => ThemeService().setDark(val),
                      ),
                    ),
                  ),
                  _SettingsRow(
                    icon: Icons.notifications_outlined,
                    title: 'Daily Reminders',
                    subtitle: _dailyReminders ? 'Enabled' : 'Disabled',
                    trailing: _GoldSwitch(
                      value: _dailyReminders,
                      onChanged: _saveReminders,
                    ),
                  ),
                ]),
                const SizedBox(height: 24),

                // ── Support ────────────────────────────────────────────────────
                _SectionHeader('SUPPORT'),
                const SizedBox(height: 8),
                _SettingsCard(items: [
                  _SettingsRow(
                    icon: Icons.help_outline_rounded,
                    title: 'Help Center',
                    subtitle: 'Get support',
                    onTap: () => _launchUrl(
                      'mailto:support@digdeeper.app?subject=Dig%20Deeper%20Support'),
                  ),
                  _SettingsRow(
                    icon: Icons.star_outline_rounded,
                    title: 'Rate Dig Deeper',
                    subtitle: 'Leave a review',
                    onTap: _rateApp,
                  ),
                  _SettingsRow(
                    icon: Icons.info_outline_rounded,
                    title: 'About',
                    subtitle: 'Version $_version',
                    onTap: () => _showAbout(context),
                  ),
                ]),
                const SizedBox(height: 32),

                // ── Sign out ───────────────────────────────────────────────────
                GestureDetector(
                  onTap: () => _confirmSignOut(context),
                  child: Center(
                    child: Text('Sign Out',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 16,
                        fontWeight: FontWeight.w600, color: AppColors.gold)),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _showTypographySheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _TypographySheet(),
    );
  }

  Future<void> _showEditSheet(
      BuildContext context, String currentName, String? currentAvatarUrl) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _EditProfileSheet(
        currentName: currentName,
        currentAvatarUrl: currentAvatarUrl,
      ),
    );
  }

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Coming soon'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 1),
    ));
  }

  Future<void> _pickTranslation(BuildContext context, String current) async {
    final options = {
      'kjv': 'KJV — King James Version',
      'niv': 'NIV — New International Version',
      'csb': 'CSB — Christian Standard Bible',
      'asv': 'ASV — American Standard Version',
    };
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        decoration: BoxDecoration(
          color: AppColors.cardBg(context),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
            decoration: BoxDecoration(color: AppColors.divider(context),
              borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Default Translation',
            style: TextStyle(fontFamily: 'Lora', fontSize: 18,
              fontWeight: FontWeight.bold, color: AppColors.label(context))),
          const SizedBox(height: 12),
          ...options.entries.map((e) {
            final parts = e.value.split(' — ');
            final abbr  = parts[0];
            final full  = parts.length > 1 ? parts[1] : '';
            final selected = e.key == current;
            return Material(
              color: Colors.transparent,
              child: ListTile(
                title: Text(abbr,
                  style: TextStyle(fontFamily: 'Inter', fontSize: 16,
                    color: AppColors.label(context),
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                subtitle: Text(full,
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                    color: AppColors.sublabel(context))),
                trailing: selected
                  ? Icon(Icons.check_rounded, color: AppColors.gold)
                  : null,
                onTap: () async {
                  Navigator.of(sheetCtx).pop();
                  await _saveTranslation(e.key);
                },
              ),
            );
          }),
        ]),
      ),
    );
  }

  Future<void> _saveTranslation(String version) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'preferences': {'version': version},
    }, SetOptions(merge: true));
  }

  Future<void> _rateApp() async {
    final review = InAppReview.instance;
    if (await review.isAvailable()) {
      await review.requestReview();
    } else {
      await review.openStoreListing(appStoreId: 'YOUR_APP_STORE_ID');
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Dig Deeper',
          style: TextStyle(fontFamily: 'Lora', color: AppColors.label(context))),
        content: Text(
          'Version $_version\n\nDeep Scripture study powered by AI.',
          style: TextStyle(fontFamily: 'Inter', color: AppColors.sublabel(context),
            fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text('Close',
              style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign out?',
          style: TextStyle(fontFamily: 'Lora', color: AppColors.label(context))),
        content: Text('You can sign back in at any time.',
          style: TextStyle(fontFamily: 'Inter', color: AppColors.sublabel(context),
            fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text('Cancel',
              style: TextStyle(color: AppColors.sublabel(context))),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text('Sign Out',
              style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _translationLabel(String key) {
    const labels = {'kjv': 'KJV', 'niv': 'NIV', 'csb': 'CSB', 'asv': 'ASV'};
    return 'Current: ${labels[key] ?? key.toUpperCase()}';
  }

  String _levelLabel(String name) {
    const labels = {
      'newBeliever': 'New Believer',
      'growing':     'Growing',
      'mature':      'Mature',
      'scholar':     'Scholar',
    };
    return labels[name] ?? name;
  }
}

// ── Typography Sheet ──────────────────────────────────────────────────────────

class _TypographySheet extends StatefulWidget {
  const _TypographySheet();

  @override
  State<_TypographySheet> createState() => _TypographySheetState();
}

class _TypographySheetState extends State<_TypographySheet> {
  late TypographySize    _size;
  late TypographyFont    _font;
  late TypographySpacing _spacing;

  @override
  void initState() {
    super.initState();
    final p = TypographyService().prefs;
    _size    = p.size;
    _font    = p.font;
    _spacing = p.spacing;
  }

  @override
  Widget build(BuildContext context) {
    // Live preview prefs from current selections
    final preview = TypographyPrefs(size: _size, font: _font, spacing: _spacing);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(width: 36, height: 4,
          decoration: BoxDecoration(color: AppColors.divider(context),
            borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),

        Text('Typography',
          style: TextStyle(fontFamily: 'Lora', fontSize: 20,
            fontWeight: FontWeight.bold, color: AppColors.label(context))),
        const SizedBox(height: 20),

        // ── Preview ──────────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider(context)),
          ),
          child: Text(
            '"In the beginning God created the heavens and the earth." — Genesis 1:1',
            style: TextStyle(
              fontFamily: preview.fontFamily,
              fontSize: preview.fontSize,
              color: AppColors.label(context),
              height: preview.lineHeight,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── Font Size ─────────────────────────────────────────────────────────
        _SheetLabel('Font Size'),
        const SizedBox(height: 8),
        Row(children: TypographySize.values.map((s) {
          final selected = s == _size;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _size = s),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.gold.withOpacity(0.15) : AppColors.cardElevated(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? AppColors.gold : AppColors.divider(context)),
                ),
                child: Column(children: [
                  Text(_sizeSample(s),
                    style: TextStyle(
                      fontFamily: 'Lora',
                      fontSize: _sampleSize(s),
                      color: selected ? AppColors.gold : AppColors.label(context),
                      fontWeight: FontWeight.bold,
                    )),
                  const SizedBox(height: 2),
                  Text(_sizeShortLabel(s),
                    style: TextStyle(fontFamily: 'Inter', fontSize: 10,
                      color: selected ? AppColors.gold : AppColors.sublabel(context))),
                ]),
              ),
            ),
          );
        }).toList()),
        const SizedBox(height: 20),

        // ── Font Style ────────────────────────────────────────────────────────
        _SheetLabel('Font Style'),
        const SizedBox(height: 8),
        Row(children: TypographyFont.values.map((f) {
          final selected = f == _font;
          final label    = f == TypographyFont.serif ? 'Serif' : 'Sans-Serif';
          final family   = f == TypographyFont.serif ? 'Lora'  : 'Inter';
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _font = f),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? AppColors.gold.withOpacity(0.15) : AppColors.cardElevated(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? AppColors.gold : AppColors.divider(context)),
                ),
                child: Column(children: [
                  Text('Aa',
                    style: TextStyle(fontFamily: family, fontSize: 22,
                      color: selected ? AppColors.gold : AppColors.label(context),
                      fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(label,
                    style: TextStyle(fontFamily: 'Inter', fontSize: 11,
                      color: selected ? AppColors.gold : AppColors.sublabel(context))),
                ]),
              ),
            ),
          );
        }).toList()),
        const SizedBox(height: 20),

        // ── Line Spacing ──────────────────────────────────────────────────────
        _SheetLabel('Line Spacing'),
        const SizedBox(height: 8),
        Row(children: TypographySpacing.values.map((sp) {
          final selected = sp == _spacing;
          final labels   = ['Compact', 'Normal', 'Spacious'];
          final icons    = [
            Icons.density_small_rounded,
            Icons.density_medium_rounded,
            Icons.density_large_rounded,
          ];
          final label = labels[sp.index];
          final icon  = icons[sp.index];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _spacing = sp),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? AppColors.gold.withOpacity(0.15) : AppColors.cardElevated(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? AppColors.gold : AppColors.divider(context)),
                ),
                child: Column(children: [
                  Icon(icon,
                    color: selected ? AppColors.gold : AppColors.label(context),
                    size: 22),
                  const SizedBox(height: 4),
                  Text(label,
                    style: TextStyle(fontFamily: 'Inter', fontSize: 11,
                      color: selected ? AppColors.gold : AppColors.sublabel(context))),
                ]),
              ),
            ),
          );
        }).toList()),
        const SizedBox(height: 28),

        // ── Apply ─────────────────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _apply,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('Apply',
              style: TextStyle(fontFamily: 'Inter', fontSize: 16,
                fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }

  Future<void> _apply() async {
    final svc = TypographyService();
    await svc.setSize(_size);
    await svc.setFont(_font);
    await svc.setSpacing(_spacing);
    if (mounted) Navigator.of(context).pop();
  }

  String _sizeSample(TypographySize s) => 'Aa';
  double _sampleSize(TypographySize s) {
    switch (s) {
      case TypographySize.small:  return 14;
      case TypographySize.medium: return 17;
      case TypographySize.large:  return 21;
      case TypographySize.xl:     return 25;
    }
  }
  String _sizeShortLabel(TypographySize s) {
    switch (s) {
      case TypographySize.small:  return 'Small';
      case TypographySize.medium: return 'Medium';
      case TypographySize.large:  return 'Large';
      case TypographySize.xl:     return 'XL';
    }
  }
}

class _SheetLabel extends StatelessWidget {
  final String text;
  const _SheetLabel(this.text);
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Text(text,
      style: TextStyle(fontFamily: 'Inter', fontSize: 12,
        fontWeight: FontWeight.w600, color: AppColors.sublabel(context),
        letterSpacing: 0.5)),
  );
}

// ── User Header ───────────────────────────────────────────────────────────────

class _UserHeader extends StatelessWidget {
  final String name;
  final String levelLabel;
  final bool isPremium;
  final String? avatarUrl;
  final VoidCallback onEdit;

  const _UserHeader({
    required this.name,
    required this.levelLabel,
    required this.isPremium,
    required this.onEdit,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    return Row(children: [
      // Avatar
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(shape: BoxShape.circle,
          color: Color(0xFF8A7040)),
        clipBehavior: Clip.hardEdge,
        child: avatarUrl != null && avatarUrl!.isNotEmpty
          ? Image.network(avatarUrl!, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _InitialsWidget(initials: initials))
          : _InitialsWidget(initials: initials),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
            style: TextStyle(fontFamily: 'Lora', fontSize: 20,
              fontWeight: FontWeight.bold, color: AppColors.label(context))),
          const SizedBox(height: 4),
          Row(children: [
            // Premium / Free badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isPremium
                  ? AppColors.gold.withOpacity(0.15)
                  : AppColors.divider(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isPremium
                    ? AppColors.gold.withOpacity(0.5)
                    : AppColors.textDim.withOpacity(0.3),
                ),
              ),
              child: Text(
                isPremium ? 'Premium Member' : 'Free',
                style: TextStyle(
                  fontFamily: 'Inter', fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isPremium ? AppColors.gold : AppColors.sublabel(context),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text('· $levelLabel',
              style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                color: AppColors.sublabel(context))),
          ]),
        ]),
      ),
      // Edit button
      GestureDetector(
        onTap: onEdit,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppColors.cardElevated(context),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.edit_note_rounded,
            color: AppColors.gold, size: 22),
        ),
      ),
    ]);
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class _InitialsWidget extends StatelessWidget {
  final String initials;
  const _InitialsWidget({required this.initials});
  @override
  Widget build(BuildContext context) => Center(
    child: Text(initials,
      style: TextStyle(fontFamily: 'Inter', fontSize: 22,
        fontWeight: FontWeight.bold, color: AppColors.label(context))));
}

// ── Edit Profile Sheet ────────────────────────────────────────────────────────

class _EditProfileSheet extends StatefulWidget {
  final String currentName;
  final String? currentAvatarUrl;

  const _EditProfileSheet({
    required this.currentName,
    this.currentAvatarUrl,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  File? _pickedImage;
  String? _previewUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl   = TextEditingController(text: widget.currentName);
    _previewUrl = widget.currentAvatarUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() {
      _pickedImage = File(picked.path);
      _previewUrl  = null; // show local file instead
    });
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final newName = _nameCtrl.text.trim();
    if (newName.isEmpty) return;

    setState(() => _saving = true);
    try {
      String? avatarUrl = widget.currentAvatarUrl;

      // Upload image if changed
      if (_pickedImage != null) {
        final ref = FirebaseStorage.instance
            .ref('avatars/$uid/profile.jpg');
        await ref.putFile(_pickedImage!);
        avatarUrl = await ref.getDownloadURL();
      }

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
        'profile': {
          'name':      newName,
          'avatarUrl': avatarUrl,
        },
      }, SetOptions(merge: true));

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not save: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = _initials(_nameCtrl.text.isEmpty
        ? widget.currentName : _nameCtrl.text);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        decoration: BoxDecoration(
          color: AppColors.cardBg(context),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Container(width: 36, height: 4,
            decoration: BoxDecoration(color: AppColors.divider(context),
              borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),

          Text('Edit Profile',
            style: TextStyle(fontFamily: 'Lora', fontSize: 20,
              fontWeight: FontWeight.bold, color: AppColors.label(context))),
          const SizedBox(height: 24),

          // Avatar picker
          GestureDetector(
            onTap: _pickedImage == null ? _pickImage : null,
            child: Stack(alignment: Alignment.bottomRight, children: [
              Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF8A7040),
                  border: Border.all(color: AppColors.gold.withOpacity(0.4),
                    width: 2),
                ),
                clipBehavior: Clip.hardEdge,
                child: _pickedImage != null
                  ? Image.file(_pickedImage!, fit: BoxFit.cover)
                  : (_previewUrl != null && _previewUrl!.isNotEmpty
                    ? Image.network(_previewUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                          Center(child: Text(initials,
                            style: TextStyle(fontFamily: 'Inter',
                              fontSize: 28, fontWeight: FontWeight.bold,
                              color: AppColors.label(context)))))
                    : Center(child: Text(initials,
                        style: TextStyle(fontFamily: 'Inter',
                          fontSize: 28, fontWeight: FontWeight.bold,
                          color: AppColors.label(context))))),
              ),
              // Camera badge
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.gold,
                  ),
                  child: Icon(Icons.camera_alt_rounded,
                    color: AppColors.black, size: 15),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // Name field
          TextField(
            controller: _nameCtrl,
            style: TextStyle(fontFamily: 'Inter', fontSize: 16,
              color: AppColors.label(context)),
            decoration: InputDecoration(
              labelText: 'Display Name',
              labelStyle: TextStyle(fontFamily: 'Inter',
                color: AppColors.sublabel(context)),
              filled: true,
              fillColor: AppColors.cardElevated(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.gold),
              ),
            ),
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}), // refresh initials preview
          ),
          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
                disabledBackgroundColor: AppColors.goldMuted,
              ),
              child: _saving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2,
                      color: AppColors.black))
                : Text('Save',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2 && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ── Streak Card ───────────────────────────────────────────────────────────────

class _StreakCard extends StatelessWidget {
  final StreakData streak;
  const _StreakCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withOpacity(0.45)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(children: [
          Icon(Icons.local_fire_department_rounded,
            color: AppColors.gold, size: 20),
          const SizedBox(width: 6),
          Text('Study Streak',
            style: TextStyle(fontFamily: 'Inter', fontSize: 15,
              fontWeight: FontWeight.w600, color: AppColors.label(context))),
          const Spacer(),
          Text('${streak.current} ${streak.current == 1 ? 'Day' : 'Days'}',
            style: TextStyle(fontFamily: 'Inter', fontSize: 15,
              fontWeight: FontWeight.bold, color: AppColors.gold)),
        ]),
        const SizedBox(height: 16),
        // Stats row
        Row(children: [
          _StatCol(value: streak.current, label: 'Current'),
          _vDivider(context),
          _StatCol(value: streak.best,    label: 'Best'),
          _vDivider(context),
          _StatCol(value: streak.total,   label: 'Total'),
        ]),
        const SizedBox(height: 16),
        // 7-day dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(7, (i) {
            final filled = streak.recentDays.length > i && streak.recentDays[i];
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 5,
                decoration: BoxDecoration(
                  color: filled
                    ? AppColors.gold
                    : AppColors.gold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
      ]),
    );
  }

  Widget _vDivider(BuildContext context) => Container(
    width: 1, height: 40, color: AppColors.divider(context),
    margin: const EdgeInsets.symmetric(horizontal: 8));
}

class _StatCol extends StatelessWidget {
  final int value;
  final String label;
  const _StatCol({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Text('$value',
        style: TextStyle(fontFamily: 'Inter', fontSize: 26,
          fontWeight: FontWeight.bold, color: AppColors.gold)),
      const SizedBox(height: 2),
      Text(label,
        style: TextStyle(fontFamily: 'Inter', fontSize: 11,
          color: AppColors.sublabel(context))),
    ]),
  );
}

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) => Text(label,
    style: TextStyle(fontFamily: 'Inter', fontSize: 11,
      fontWeight: FontWeight.w700, color: AppColors.gold,
      letterSpacing: 1.2));
}

// ── Settings Card ─────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final List<Widget> items;
  const _SettingsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: List.generate(items.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Divider(height: 1, color: AppColors.divider(context).withOpacity(0.6),
              indent: 56);
          }
          return items[i ~/ 2];
        }),
      ),
    );
  }
}

// ── Settings Row ──────────────────────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(children: [
          // Icon square
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.gold, size: 18),
          ),
          const SizedBox(width: 12),
          // Text
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                style: TextStyle(fontFamily: 'Inter', fontSize: 15,
                  fontWeight: FontWeight.w500, color: AppColors.label(context))),
              const SizedBox(height: 1),
              Text(subtitle,
                style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                  color: AppColors.sublabel(context))),
            ]),
          ),
          const SizedBox(width: 8),
          // Trailing
          trailing ?? (onTap != null
            ? Icon(Icons.chevron_right_rounded,
                color: AppColors.textDim, size: 20)
            : const SizedBox.shrink()),
        ]),
      ),
    );
  }
}

// ── Gold Switch ───────────────────────────────────────────────────────────────

class _GoldSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _GoldSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Transform.scale(
    scale: 0.85,
    child: Switch(
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.gold,
      activeTrackColor: AppColors.gold.withOpacity(0.35),
      inactiveThumbColor: AppColors.textDim,
      inactiveTrackColor: AppColors.divider(context),
    ),
  );
}
