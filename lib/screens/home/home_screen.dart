import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/badge_definitions.dart';
import '../../core/services/badge_service.dart';
import '../../core/services/plan_service.dart';
import '../../models/user_profile.dart';
import '../plans/reading_plans_screen.dart' show activePlanProvider;
import '../coach/coach_overlay.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

/// Returns true if the user has already completed onboarding questions.
/// Checks SharedPreferences first (fast), falls back to Firestore.
final onboardingCheckProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  // Local flag set when questions are completed — avoids Firestore round-trip
  if (prefs.getBool('onboarding_questions_complete') == true) return true;

  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return true;
  final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
  final complete = doc.data()?['onboardingComplete'] == true;
  if (complete) {
    // Cache it locally so we don't hit Firestore on every launch
    await prefs.setBool('onboarding_questions_complete', true);
  }
  return complete;
});

final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((s) => s.exists ? UserProfile.fromFirestore(s.data()!, uid) : null);
});

final todayVerseProvider = FutureProvider<Map<String, String>?>((ref) async {
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final snap = await FirebaseFirestore.instance.collection('dailycache').doc(today).get();
  if (!snap.exists) return null;
  final fv = snap.data()?['focusVerse'] as Map<String, dynamic>?;
  if (fv == null) return null;
  return {'text': fv['text'] as String? ?? '', 'reference': fv['reference'] as String? ?? ''};
});

final continueReadingProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final book = prefs.getString('reader_last_book');
  final chapter = prefs.getInt('reader_last_chapter');
  if (book == null) return null;
  return {'book': book, 'chapter': chapter ?? 1};
});

final recentNotesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('notes')
      .doc(uid)
      .collection('entries')
      .orderBy('createdAt', descending: true)
      .limit(3)
      .snapshots()
      .map((s) => s.docs.map((d) {
            final data = d.data();
            return {
              'id': d.id,
              'title': data['title'] as String? ?? 'Untitled',
              'type': data['type'] as String? ?? 'manual',
              'content': data['content'] as String? ?? data['overview'] as String? ?? '',
              'passage': data['passage'] as String?,
              'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            };
          }).toList());
});

final liveStatsProvider = StreamProvider<Map<String, int>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value({});
  // Count notes and highlights in real time
  final notesStream = FirebaseFirestore.instance
      .collection('notes').doc(uid).collection('entries').snapshots();
  final highlightsStream = FirebaseFirestore.instance
      .collection('highlights').doc(uid).collection('verses').snapshots();

  return notesStream.asyncMap((notesSnap) async {
    final hlSnap = await FirebaseFirestore.instance
        .collection('highlights').doc(uid).collection('verses').get();
    final notes = notesSnap.docs;
    final aiStudies = notes.where((d) => (d.data()['type'] as String?) == 'aiStudy').length;
    return {
      'totalNotes': notes.length,
      'aiStudies': aiStudies,
      'highlights': hlSnap.docs.where((d) => d.id.contains('_')).length,
    };
  });
});

final groupActivityProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return [];

  // Groups where user is a member
  final groupsSnap = await FirebaseFirestore.instance
      .collection('groups')
      .where('memberIds', arrayContains: uid)
      .limit(10)
      .get();

  if (groupsSnap.docs.isEmpty) return [];

  final items = <Map<String, dynamic>>[];

  for (final groupDoc in groupsSnap.docs) {
    final groupData = groupDoc.data();
    final groupName = groupData['name'] as String? ?? 'Group';

    final feedSnap = await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupDoc.id)
        .collection('feed')
        .orderBy('createdAt', descending: true)
        .limit(3)
        .get();

    for (final doc in feedSnap.docs) {
      final d = doc.data();
      items.add({
        ...d,
        'id': doc.id,
        'groupId': groupDoc.id,
        'groupName': groupName,
      });
    }
  }

  items.sort((a, b) {
    final ta = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
    final tb = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
    return tb.compareTo(ta);
  });

  return items.take(5).toList();
});

final earnedBadgesProvider = StreamProvider<Map<String, DateTime>>((ref) {
  return BadgeService().earnedBadgesStream();
});

/// Parses a human reference like "John 3:16" or "1 Corinthians 13:4"
/// into {book: 'jhn', chapter: 3}. Returns null if unparseable.
Map<String, dynamic>? _parseReference(String reference) {
  final match = RegExp(r'^(.+?)\s+(\d+)(?::\d+)?$').firstMatch(reference.trim());
  if (match == null) return null;
  final bookName = match.group(1)!.trim();
  final chapter  = int.tryParse(match.group(2)!) ?? 1;
  final lower = bookName.toLowerCase();

  for (final entry in _bookNames.entries) {
    final mapName = entry.value.toLowerCase();
    // Exact match, or singular/plural variants (e.g. "Psalm" ↔ "Psalms")
    if (mapName == lower || mapName == '${lower}s' || '${mapName}s' == lower) {
      return {'book': entry.key, 'chapter': chapter};
    }
  }
  // Fallback: startsWith match (handles abbreviations or minor format differences)
  for (final entry in _bookNames.entries) {
    final mapName = entry.value.toLowerCase();
    if (mapName.startsWith(lower) || lower.startsWith(mapName)) {
      return {'book': entry.key, 'chapter': chapter};
    }
  }
  return null;
}

// Book ID → display name
const _bookNames = {
  'gen':'Genesis','exo':'Exodus','lev':'Leviticus','num':'Numbers','deu':'Deuteronomy',
  'jos':'Joshua','jdg':'Judges','rut':'Ruth','1sa':'1 Samuel','2sa':'2 Samuel',
  '1ki':'1 Kings','2ki':'2 Kings','1ch':'1 Chronicles','2ch':'2 Chronicles',
  'ezr':'Ezra','neh':'Nehemiah','est':'Esther','job':'Job','psa':'Psalms',
  'pro':'Proverbs','ecc':'Ecclesiastes','sng':'Song of Solomon','isa':'Isaiah',
  'jer':'Jeremiah','lam':'Lamentations','ezk':'Ezekiel','dan':'Daniel',
  'hos':'Hosea','jol':'Joel','amo':'Amos','oba':'Obadiah','jon':'Jonah',
  'mic':'Micah','nam':'Nahum','hab':'Habakkuk','zep':'Zephaniah','hag':'Haggai',
  'zec':'Zechariah','mal':'Malachi','mat':'Matthew','mrk':'Mark','luk':'Luke',
  'jhn':'John','act':'Acts','rom':'Romans','1co':'1 Corinthians','2co':'2 Corinthians',
  'gal':'Galatians','eph':'Ephesians','php':'Philippians','col':'Colossians',
  '1th':'1 Thessalonians','2th':'2 Thessalonians','1ti':'1 Timothy','2ti':'2 Timothy',
  'tit':'Titus','phm':'Philemon','heb':'Hebrews','jas':'James',
  '1pe':'1 Peter','2pe':'2 Peter','1jn':'1 John','2jn':'2 John','3jn':'3 John',
  'jud':'Jude','rev':'Revelation',
};

// ── Screen ────────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _showCoach = false;
  bool _coachChecked = false;

  @override
  void initState() {
    super.initState();
    _checkCoach();
  }

  Future<void> _checkCoach() async {
    final show = await shouldShowCoach();
    if (mounted && show) {
      // Small delay so home screen renders first
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _showCoach = true);
    }
    if (mounted) setState(() => _coachChecked = true);
  }

  @override
  Widget build(BuildContext context) {
    // Redirect new users to onboarding questions on first sign-in
    ref.listen(onboardingCheckProvider, (_, next) {
      next.whenData((complete) {
        if (!complete) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/onboarding-questions');
          });
        }
      });
    });

    final profileAsync       = ref.watch(userProfileProvider);
    final verseAsync         = ref.watch(todayVerseProvider);
    final continueAsync      = ref.watch(continueReadingProvider);
    final recentNotesAsync   = ref.watch(recentNotesProvider);
    final liveStatsAsync     = ref.watch(liveStatsProvider);
    final groupActivityAsync = ref.watch(groupActivityProvider);
    final earnedBadgesAsync  = ref.watch(earnedBadgesProvider);

    final scaffold = Scaffold(
      body: CustomScrollView(
        slivers: [

          // ── App Bar ────────────────────────────────────────────────────────
          SliverAppBar(
            elevation: 0,
            pinned: true,
            title: Row(children: [
              Text('Dig Deeper',
                style: TextStyle(fontFamily: 'Lora', fontSize: 22,
                  fontWeight: FontWeight.bold, color: AppColors.label(context))),
              const Spacer(),
              profileAsync.when(
                data: (p) => GestureDetector(
                  onTap: () => context.go('/profile'),
                  child: _Avatar(url: p?.avatarUrl, name: p?.name ?? ''),
                ),
                loading: () => const SizedBox(width: 36, height: 36),
                error: (_, __) => const SizedBox(),
              ),
            ]),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 4),

                // ── Greeting ───────────────────────────────────────────────
                profileAsync.when(
                  data: (p) => _Greeting(name: p?.name ?? 'Friend'),
                  loading: () => const SizedBox(height: 44),
                  error: (_, __) => const _Greeting(name: 'Friend'),
                ),

                const SizedBox(height: 20),

                // ── Verse of the Day ───────────────────────────────────────
                verseAsync.when(
                  data: (v) {
                    final verseRef = v?['reference'] ?? 'Psalm 119:105';
                    final extra = _parseReference(verseRef);
                    return _VerseCard(
                      text: v?['text'] ?? 'Your word is a lamp to my feet and a light to my path.',
                      reference: verseRef,
                      onStudy: () => context.go('/study', extra: extra),
                    );
                  },
                  loading: () => const _ShimmerBox(height: 200, radius: 18),
                  error: (_, __) => _VerseCard(
                    text: 'Your word is a lamp to my feet and a light to my path.',
                    reference: 'Psalm 119:105',
                    onStudy: () => context.go('/study',
                        extra: _parseReference('Psalm 119:105')),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Today section: Continue Reading + New AI Study ─────────
                _SectionHeader(title: 'Today'),
                const SizedBox(height: 12),
                Row(children: [
                  // Continue Reading
                  Expanded(
                    child: continueAsync.when(
                      data: (cr) => _TodayCard(
                        icon: Icons.bookmark_rounded,
                        topLabel: 'Continue Reading',
                        mainText: cr != null
                            ? '${_bookNames[cr['book']] ?? cr['book']} ${cr['chapter']}'
                            : 'Start Reading',
                        subText: cr != null ? 'Pick up where you left off' : 'Open the Bible reader',
                        onTap: () => context.go('/reader',
                          extra: cr != null
                              ? {'book': cr['book'], 'chapter': cr['chapter']}
                              : null),
                      ),
                      loading: () => const _ShimmerBox(height: 110, radius: 14),
                      error: (_, __) => _TodayCard(
                        icon: Icons.bookmark_rounded,
                        topLabel: 'Continue Reading',
                        mainText: 'Start Reading',
                        subText: 'Open the Bible reader',
                        onTap: () => context.go('/reader'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // New AI Study
                  Expanded(
                    child: _TodayCard(
                      icon: Icons.psychology_outlined,
                      topLabel: 'AI Study',
                      mainText: 'New Session',
                      subText: 'Dive deep into a passage',
                      onTap: () => context.go('/study'),
                      accent: true,
                    ),
                  ),
                ]),

                const SizedBox(height: 28),

                // ── Live Stats ─────────────────────────────────────────────
                liveStatsAsync.when(
                  data: (stats) => _StatsRow(stats: stats),
                  loading: () => const _ShimmerBox(height: 80, radius: 14),
                  error: (_, __) => const SizedBox(),
                ),

                const SizedBox(height: 28),

                // ── Recent Notes ───────────────────────────────────────────
                recentNotesAsync.when(
                  data: (notes) => notes.isEmpty
                    ? const SizedBox()
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _SectionHeader(
                          title: 'Recent Notes',
                          actionLabel: 'See all',
                          onAction: () => context.go('/notes'),
                        ),
                        const SizedBox(height: 12),
                        ...notes.map((n) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _NotePreviewCard(note: n,
                            onTap: () => context.go('/notes')),
                        )),
                      ]),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),

                // ── Group Activity Feed ────────────────────────────────────
                groupActivityAsync.when(
                  data: (feed) => feed.isEmpty
                    ? const SizedBox()
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const SizedBox(height: 28),
                        _SectionHeader(
                          title: 'Group Activity',
                          actionLabel: 'See all',
                          onAction: () => context.go('/groups'),
                        ),
                        const SizedBox(height: 12),
                        ...feed.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _GroupFeedCard(
                            item: item,
                            onTap: () => context.go('/groups'),
                          ),
                        )),
                      ]),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),

                // ── Reading Plan ──────────────────────────────────────────
                ref.watch(activePlanProvider).when(
                  data: (active) {
                    final hasActivePlan = active != null && !active.isComplete;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeader(
                          title: 'Reading Plan',
                          actionLabel: 'Browse',
                          onAction: () => context.go('/plans'),
                        ),
                        const SizedBox(height: 12),
                        hasActivePlan
                          ? _PlanContinueCard(active: active!)
                          : _PlanBrowseCard(),
                        const SizedBox(height: 28),
                      ],
                    );
                  },
                  loading: () => const SizedBox(),
                  error: (_, __) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                        title: 'Reading Plan',
                        actionLabel: 'Browse',
                        onAction: () => context.go('/plans'),
                      ),
                      const SizedBox(height: 12),
                      _PlanBrowseCard(),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),

                // ── Badges ────────────────────────────────────────────────
                earnedBadgesAsync.when(
                  data: (earned) => _BadgesSection(earnedMap: earned),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );

    // Wrap with coach overlay for first-time users
    if (!_showCoach) return scaffold;

    return Stack(
      children: [
        scaffold,
        CoachOverlay(
          onDone: () => setState(() => _showCoach = false),
        ),
      ],
    );
  }
}

// ── Greeting ──────────────────────────────────────────────────────────────────

class _Greeting extends StatelessWidget {
  final String name;
  const _Greeting({required this.name});

  String get _timeGreeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$_timeGreeting, ${name.split(' ').first}',
        style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.sublabel(context))),
      const SizedBox(height: 2),
      Text('What are you studying today?',
        style: TextStyle(fontFamily: 'Lora', fontSize: 22,
          fontWeight: FontWeight.bold, color: AppColors.label(context), height: 1.25)),
    ],
  );
}

// ── Verse of the Day ──────────────────────────────────────────────────────────

// 20 background images, one per asset
const _verseBgCount = 20;

String _dailyVerseBg() {
  final now = DateTime.now();
  // Day-of-year so the image changes each day and cycles through all 20
  final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
  final index = (dayOfYear % _verseBgCount) + 1;
  return 'assets/images/verse_bg_${index.toString().padLeft(2, '0')}.jpg';
}

class _VerseCard extends StatelessWidget {
  final String text;
  final String reference;
  final VoidCallback onStudy;
  const _VerseCard({required this.text, required this.reference, required this.onStudy});

  @override
  Widget build(BuildContext context) {
    final bgAsset = _dailyVerseBg();
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 200,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Background image ───────────────────────────────────────────
            Image.asset(
              bgAsset,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: AppColors.cardBg(context)),
            ),

            // ── Dark gradient overlay (top + bottom) ──────────────────────
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.45),
                    Colors.black.withOpacity(0.15),
                    Colors.black.withOpacity(0.65),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),

            // ── Content ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label
                  Row(children: [
                    Icon(Icons.auto_awesome, size: 11, color: AppColors.gold),
                    const SizedBox(width: 6),
                    Text(
                      'VERSE OF THE DAY',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ]),

                  const SizedBox(height: 10),

                  // Verse text
                  Expanded(
                    child: Text(
                      '"$text"',
                      style: TextStyle(
                        fontFamily: 'Lora',
                        fontSize: 15,
                        color: Colors.white,
                        height: 1.6,
                        fontStyle: FontStyle.italic,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
                        ],
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Reference + Study button
                  Row(children: [
                    Expanded(
                      child: Text(
                        '— $reference',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: onStudy,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Study This',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Today Cards ───────────────────────────────────────────────────────────────

class _TodayCard extends StatelessWidget {
  final IconData icon;
  final String topLabel;
  final String mainText;
  final String subText;
  final VoidCallback onTap;
  final bool accent;

  const _TodayCard({
    required this.icon,
    required this.topLabel,
    required this.mainText,
    required this.subText,
    required this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent ? AppColors.gold.withOpacity(0.08) : AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent ? AppColors.gold.withOpacity(0.35) : AppColors.divider(context)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: AppColors.gold.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.gold, size: 20),
        ),
        const SizedBox(height: 12),
        Text(topLabel,
          style: TextStyle(fontFamily: 'Inter', fontSize: 10,
            fontWeight: FontWeight.w600, color: AppColors.gold, letterSpacing: 0.5)),
        const SizedBox(height: 3),
        Text(mainText,
          style: TextStyle(fontFamily: 'Inter', fontSize: 15,
            fontWeight: FontWeight.w700, color: AppColors.label(context)),
          maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        Text(subText,
          style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.sublabel(context)),
          maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
    ),
  );
}

// ── Live Stats Row ────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final Map<String, int> stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    decoration: BoxDecoration(
      color: AppColors.cardBg(context),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.divider(context)),
    ),
    child: Row(children: [
      _StatItem(value: '${stats['totalNotes'] ?? 0}',  label: 'Notes',      icon: Icons.edit_note),
      _Divider(),
      _StatItem(value: '${stats['aiStudies'] ?? 0}',   label: 'AI Studies', icon: Icons.psychology),
      _Divider(),
      _StatItem(value: '${stats['highlights'] ?? 0}',  label: 'Highlights', icon: Icons.highlight),
    ]),
  );
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  const _StatItem({required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Icon(icon, size: 16, color: AppColors.gold),
      const SizedBox(height: 6),
      Text(value,
        style: TextStyle(fontFamily: 'Inter', fontSize: 22,
          fontWeight: FontWeight.bold, color: AppColors.label(context))),
      const SizedBox(height: 2),
      Text(label,
        style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.sublabel(context))),
    ]),
  );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 50, color: AppColors.divider(context));
}

// ── Note Preview Card ─────────────────────────────────────────────────────────

class _NotePreviewCard extends StatelessWidget {
  final Map<String, dynamic> note;
  final VoidCallback onTap;
  const _NotePreviewCard({required this.note, required this.onTap});

  IconData get _typeIcon {
    switch (note['type'] as String?) {
      case 'aiStudy': return Icons.psychology_outlined;
      case 'sermon':  return Icons.church_outlined;
      default:        return Icons.edit_note_outlined;
    }
  }

  String get _preview {
    final c = (note['content'] as String? ?? '').trim();
    if (c.isEmpty) return note['passage'] as String? ?? '';
    return c.length > 80 ? '${c.substring(0, 80)}…' : c;
  }

  String get _timeAgo {
    final dt = note['createdAt'] as DateTime;
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider(context)),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppColors.gold.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_typeIcon, color: AppColors.gold, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(note['title'] as String? ?? 'Untitled',
              style: TextStyle(fontFamily: 'Inter', fontSize: 13,
                fontWeight: FontWeight.w600, color: AppColors.label(context)),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            if (_preview.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(_preview,
                style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                  color: AppColors.sublabel(context), height: 1.4),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ]),
        ),
        const SizedBox(width: 8),
        Text(_timeAgo,
          style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textDim)),
      ]),
    ),
  );
}

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title,
        style: TextStyle(fontFamily: 'Inter', fontSize: 16,
          fontWeight: FontWeight.w700, color: AppColors.label(context))),
      if (actionLabel != null)
        GestureDetector(
          onTap: onAction,
          child: Text(actionLabel!,
            style: TextStyle(fontFamily: 'Inter', fontSize: 13,
              color: AppColors.gold, fontWeight: FontWeight.w600)),
        ),
    ],
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String? url;
  final String name;
  const _Avatar({this.url, required this.name});

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 18,
    backgroundColor: AppColors.gold.withOpacity(0.2),
    backgroundImage: url != null ? NetworkImage(url!) : null,
    child: url == null
        ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(color: AppColors.gold, fontFamily: 'Inter',
              fontWeight: FontWeight.w700, fontSize: 14))
        : null,
  );
}

class _ShimmerBox extends StatelessWidget {
  final double height;
  final double radius;
  const _ShimmerBox({required this.height, required this.radius});

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: AppColors.cardBg(context),
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

// ── Group Feed Card ───────────────────────────────────────────────────────────

class _GroupFeedCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  const _GroupFeedCard({required this.item, required this.onTap});

  IconData get _icon {
    switch (item['type'] as String?) {
      case 'verse_share': return Icons.menu_book_outlined;
      case 'prayer':      return Icons.volunteer_activism_outlined;
      case 'study':       return Icons.psychology_outlined;
      case 'question':    return Icons.help_outline;
      case 'note':        return Icons.edit_note_outlined;
      default:            return Icons.group_outlined;
    }
  }

  String get _timeAgo {
    final ts = item['createdAt'];
    if (ts == null) return '';
    final dt = ts is Timestamp ? ts.toDate() : ts as DateTime;
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    if (diff.inDays == 1)    return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final authorName  = item['authorName'] as String? ?? 'Someone';
    final groupName   = item['groupName']  as String? ?? 'Group';
    final content     = item['content']    as String? ?? '';
    final commentCount = item['commentCount'] as int? ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBg(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider(context)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon, color: AppColors.gold, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(groupName,
                    style: TextStyle(fontFamily: 'Inter', fontSize: 10,
                      fontWeight: FontWeight.w700, color: AppColors.gold)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(authorName,
                    style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                      fontWeight: FontWeight.w600, color: AppColors.label(context)),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Text(_timeAgo,
                  style: TextStyle(fontFamily: 'Inter', fontSize: 11,
                    color: AppColors.textDim)),
              ]),
              if (content.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(content.length > 100 ? '${content.substring(0, 100)}…' : content,
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                    color: AppColors.sublabel(context), height: 1.45),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              if (commentCount > 0) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.chat_bubble_outline, size: 12, color: AppColors.textDim),
                  const SizedBox(width: 4),
                  Text('$commentCount ${commentCount == 1 ? 'reply' : 'replies'}',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 11,
                      color: AppColors.textDim)),
                ]),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}


// ── Badges section ────────────────────────────────────────────────────────────

class _BadgesSection extends StatelessWidget {
  final Map<String, DateTime> earnedMap;
  const _BadgesSection({required this.earnedMap});

  void _showAllBadges(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AllBadgesSheet(earnedMap: earnedMap),
    );
  }

  @override
  Widget build(BuildContext context) {
    final earnedBadges = kAllBadges.where((b) => earnedMap.containsKey(b.id)).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 28),
      Row(children: [
        Text('Badges',
          style: TextStyle(fontFamily: 'Lora', fontSize: 18,
            fontWeight: FontWeight.bold, color: AppColors.label(context))),
        const Spacer(),
        GestureDetector(
          onTap: () => _showAllBadges(context),
          child: Text('View All',
            style: TextStyle(fontFamily: 'Inter', fontSize: 13,
              fontWeight: FontWeight.w600, color: AppColors.gold)),
        ),
      ]),
      const SizedBox(height: 16),

      if (earnedBadges.isEmpty)
        GestureDetector(
          onTap: () => _showAllBadges(context),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.cardBg(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider(context)),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.military_tech_outlined,
                  color: AppColors.gold, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('No badges yet',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 14,
                      fontWeight: FontWeight.w600, color: AppColors.label(context))),
                  SizedBox(height: 2),
                  Text('Complete a study to earn your first badge.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                      color: AppColors.sublabel(context))),
                ]),
              ),
              Icon(Icons.chevron_right, color: AppColors.textDim, size: 18),
            ]),
          ),
        )
      else
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: earnedBadges.length + 1, // +1 for View All tile
            separatorBuilder: (_, __) => const SizedBox(width: 18),
            itemBuilder: (_, i) {
              if (i == earnedBadges.length) {
                return _ViewAllCircle(onTap: () => _showAllBadges(context));
              }
              final badge = earnedBadges[i];
              return _BadgeCircle(
                badge: badge,
                earned: true,
                earnedAt: earnedMap[badge.id],
                onTap: () => _showBadgeDetail(context, badge, earnedMap[badge.id]),
              );
            },
          ),
        ),
    ]);
  }

  void _showBadgeDetail(BuildContext context, BadgeDef badge, DateTime? earnedAt) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _BadgeDetailSheet(badge: badge, earnedAt: earnedAt),
    );
  }
}

// ── Free-floating badge circle ────────────────────────────────────────────────

class _BadgeCircle extends StatelessWidget {
  final BadgeDef badge;
  final bool earned;
  final DateTime? earnedAt;
  final VoidCallback? onTap;
  const _BadgeCircle({
    required this.badge,
    required this.earned,
    this.earnedAt,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = earned ? badge.color : AppColors.textDim;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 88,
        child: Column(children: [
          // Badge art circle — glowing when earned
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(earned ? 0.14 : 0.07),
              boxShadow: earned
                ? [BoxShadow(
                    color: color.withOpacity(0.35),
                    blurRadius: 16,
                    spreadRadius: 2,
                  )]
                : null,
              border: Border.all(
                color: color.withOpacity(earned ? 0.5 : 0.2),
                width: earned ? 2 : 1,
              ),
            ),
            child: badge.assetPath != null
              ? ClipOval(child: Image.asset(badge.assetPath!, fit: BoxFit.cover))
              : earned
                ? Icon(badge.icon, color: color, size: 36)
                : Stack(alignment: Alignment.center, children: [
                    Icon(badge.icon, color: AppColors.textDim.withOpacity(0.3), size: 36),
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.cardBg(context),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.divider(context)),
                      ),
                      child: Icon(Icons.lock, color: AppColors.textDim, size: 13),
                    ),
                  ]),
          ),
          const SizedBox(height: 8),
          Text(
            badge.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: earned ? AppColors.label(context) : AppColors.textDim,
              height: 1.3,
            ),
          ),
        ]),
      ),
    );
  }
}

class _ViewAllCircle extends StatelessWidget {
  final VoidCallback onTap;
  const _ViewAllCircle({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: SizedBox(
      width: 80,
      child: Column(children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.cardBg(context),
            border: Border.all(color: AppColors.divider(context)),
          ),
          child: Icon(Icons.grid_view_rounded,
            color: AppColors.sublabel(context), size: 28),
        ),
        const SizedBox(height: 8),
        Text('View All',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Inter', fontSize: 11,
            fontWeight: FontWeight.w600, color: AppColors.sublabel(context))),
      ]),
    ),
  );
}

// ── Badge Detail Modal ────────────────────────────────────────────────────────

class _BadgeDetailSheet extends StatelessWidget {
  final BadgeDef badge;
  final DateTime? earnedAt;
  const _BadgeDetailSheet({required this.badge, this.earnedAt});

  String _formatDate(DateTime dt) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final earned = earnedAt != null;
    final color = earned ? badge.color : AppColors.textDim;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 28),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: earned ? badge.color.withOpacity(0.25) : AppColors.divider(context)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 10),
        // Handle
        Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: AppColors.divider(context), borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 28),

        // Large badge art
        Container(
          width: 120, height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(earned ? 0.14 : 0.07),
            boxShadow: earned
              ? [BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 30,
                  spreadRadius: 4,
                )]
              : null,
            border: Border.all(
              color: color.withOpacity(earned ? 0.5 : 0.2),
              width: earned ? 2.5 : 1.5,
            ),
          ),
          child: badge.assetPath != null
            ? ClipOval(child: Image.asset(badge.assetPath!, fit: BoxFit.cover))
            : earned
              ? Icon(badge.icon, color: color, size: 56)
              : Stack(alignment: Alignment.center, children: [
                  Icon(badge.icon, color: AppColors.textDim.withOpacity(0.3), size: 56),
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.cardBg(context), shape: BoxShape.circle,
                      border: Border.all(color: AppColors.divider(context))),
                    child: Icon(Icons.lock, color: AppColors.textDim, size: 18),
                  ),
                ]),
        ),

        const SizedBox(height: 20),

        // Badge name
        Text(badge.name,
          style: TextStyle(fontFamily: 'Lora', fontSize: 22,
            fontWeight: FontWeight.bold, color: AppColors.label(context))),

        const SizedBox(height: 6),

        // Earned status
        if (earned) ...[
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.check_circle, color: color, size: 14),
            const SizedBox(width: 5),
            Text(
              'Earned on ${_formatDate(earnedAt!)}',
              style: TextStyle(fontFamily: 'Inter', fontSize: 13,
                fontWeight: FontWeight.w600, color: color),
            ),
          ]),
        ] else ...[
          Text('Not yet earned',
            style: TextStyle(fontFamily: 'Inter', fontSize: 13,
              color: AppColors.sublabel(context))),
        ],

        const SizedBox(height: 20),
        Divider(color: AppColors.divider(context), height: 1, indent: 24, endIndent: 24),
        const SizedBox(height: 20),

        // Requirements
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('HOW TO EARN',
              style: TextStyle(fontFamily: 'Inter', fontSize: 10,
                fontWeight: FontWeight.w700, color: AppColors.textDim,
                letterSpacing: 1.2)),
            const SizedBox(height: 8),
            Text(badge.howToEarn,
              style: TextStyle(fontFamily: 'Inter', fontSize: 15,
                color: AppColors.label(context), height: 1.6)),
          ]),
        ),

        const SizedBox(height: 28),

        // Dismiss
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.cardElevated(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text('Close',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 14,
                    fontWeight: FontWeight.w600, color: AppColors.sublabel(context))),
              ),
            ),
          ),
        ),

        SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
      ]),
    );
  }
}

// ── All Badges Sheet ──────────────────────────────────────────────────────────

class _AllBadgesSheet extends StatefulWidget {
  final Map<String, DateTime> earnedMap;
  const _AllBadgesSheet({required this.earnedMap});

  @override
  State<_AllBadgesSheet> createState() => _AllBadgesSheetState();
}

class _AllBadgesSheetState extends State<_AllBadgesSheet> {
  BadgeDef? _selected;

  @override
  Widget build(BuildContext context) {
    final earnedMap = widget.earnedMap;
    final earnedList = kAllBadges.where((b) => earnedMap.containsKey(b.id)).toList();
    final lockedList = kAllBadges.where((b) => !earnedMap.containsKey(b.id)).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        // ── Detail view ────────────────────────────────────────────────────────
        if (_selected != null) {
          final badge = _selected!;
          final earnedAt = earnedMap[badge.id];
          final earned = earnedAt != null;
          final color = earned ? badge.color : AppColors.textDim;

          String formatDate(DateTime dt) {
            const months = [
              'Jan','Feb','Mar','Apr','May','Jun',
              'Jul','Aug','Sep','Oct','Nov','Dec',
            ];
            return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
          }

          return SingleChildScrollView(
            controller: scrollController,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 10),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider(context), borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 8),

              // Back button
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _selected = null),
                    icon: Icon(Icons.arrow_back_ios_new_rounded, size: 14,
                      color: AppColors.sublabel(context)),
                    label: Text('All Badges',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 14,
                        color: AppColors.sublabel(context))),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6)),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Large badge art
              Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(earned ? 0.14 : 0.07),
                  boxShadow: earned
                    ? [BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 30,
                        spreadRadius: 4,
                      )]
                    : null,
                  border: Border.all(
                    color: color.withOpacity(earned ? 0.5 : 0.2),
                    width: earned ? 2.5 : 1.5,
                  ),
                ),
                child: badge.assetPath != null
                  ? ClipOval(child: Image.asset(badge.assetPath!, fit: BoxFit.cover))
                  : earned
                    ? Icon(badge.icon, color: color, size: 56)
                    : Stack(alignment: Alignment.center, children: [
                        Icon(badge.icon, color: AppColors.textDim.withOpacity(0.3), size: 56),
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.cardBg(context), shape: BoxShape.circle,
                            border: Border.all(color: AppColors.divider(context))),
                          child: Icon(Icons.lock, color: AppColors.textDim, size: 18),
                        ),
                      ]),
              ),

              const SizedBox(height: 20),

              Text(badge.name,
                style: TextStyle(fontFamily: 'Lora', fontSize: 22,
                  fontWeight: FontWeight.bold, color: AppColors.label(context))),

              const SizedBox(height: 6),

              if (earned) ...[
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.check_circle, color: color, size: 14),
                  const SizedBox(width: 5),
                  Text(
                    'Earned on ${formatDate(earnedAt)}',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 13,
                      fontWeight: FontWeight.w600, color: color),
                  ),
                ]),
              ] else ...[
                Text('Not yet earned',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 13,
                    color: AppColors.sublabel(context))),
              ],

              const SizedBox(height: 20),
              Divider(color: AppColors.divider(context), height: 1, indent: 24, endIndent: 24),
              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('HOW TO EARN',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 10,
                      fontWeight: FontWeight.w700, color: AppColors.textDim,
                      letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  Text(badge.howToEarn,
                    style: TextStyle(fontFamily: 'Inter', fontSize: 15,
                      color: AppColors.label(context), height: 1.6)),
                ]),
              ),

              SizedBox(height: MediaQuery.of(context).padding.bottom + 28),
            ]),
          );
        }

        // ── List view ──────────────────────────────────────────────────────────
        return Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider(context), borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Row(children: [
              Text('All Badges',
                style: TextStyle(fontFamily: 'Lora', fontSize: 20,
                  fontWeight: FontWeight.bold, color: AppColors.label(context))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${earnedList.length} / ${kAllBadges.length}',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                    fontWeight: FontWeight.w700, color: AppColors.gold),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                earnedList.isEmpty
                  ? 'Complete studies and explore to unlock badges.'
                  : 'Tap any badge to see details.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 13,
                  color: AppColors.sublabel(context)),
              ),
            ),
          ),
          Divider(height: 1, color: AppColors.divider(context)),

          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              children: [
                if (earnedList.isNotEmpty) ...[
                  _SheetLabel(label: 'EARNED — ${earnedList.length}'),
                  const SizedBox(height: 16),
                  _BadgeWrapGrid(
                    badges: earnedList,
                    earnedMap: earnedMap,
                    onTap: (b) => setState(() => _selected = b),
                  ),
                  const SizedBox(height: 32),
                ],
                if (lockedList.isNotEmpty) ...[
                  _SheetLabel(label: 'LOCKED — ${lockedList.length}'),
                  const SizedBox(height: 16),
                  _BadgeWrapGrid(
                    badges: lockedList,
                    earnedMap: earnedMap,
                    onTap: (b) => setState(() => _selected = b),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ]);
      },
    );
  }
}

class _SheetLabel extends StatelessWidget {
  final String label;
  const _SheetLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(label,
    style: TextStyle(fontFamily: 'Inter', fontSize: 10,
      fontWeight: FontWeight.w700, color: AppColors.textDim, letterSpacing: 1.2));
}

/// Wrapping grid of free-floating badge circles (3 per row).
class _BadgeWrapGrid extends StatelessWidget {
  final List<BadgeDef> badges;
  final Map<String, DateTime> earnedMap;
  final void Function(BadgeDef) onTap;
  const _BadgeWrapGrid({required this.badges, required this.earnedMap, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 20,
      children: badges.map((b) {
        final earned = earnedMap.containsKey(b.id);
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 40 - 24) / 3,
          child: _BadgeCircle(
            badge: b,
            earned: earned,
            earnedAt: earnedMap[b.id],
            onTap: () => onTap(b),
          ),
        );
      }).toList(),
    );
  }
}

// ── Plan Continue Card (home screen) ──────────────────────────────────────────

class _PlanContinueCard extends ConsumerWidget {
  final ActivePlanState active;
  const _PlanContinueCard({required this.active});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysLeft = active.plan.durationDays - active.completedDays.length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 0),
      Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold.withOpacity(0.25)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(active.plan.title,
                  style: TextStyle(fontFamily: 'Lora', fontSize: 16,
                    fontWeight: FontWeight.bold, color: AppColors.label(context))),
                const SizedBox(height: 3),
                Text(
                  'Day ${active.currentDay} of ${active.plan.durationDays}  ·  $daysLeft days left',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                    color: AppColors.sublabel(context)),
                ),
              ]),
            ),
          ]),

          const SizedBox(height: 12),

          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: active.progressFraction,
              minHeight: 4,
              backgroundColor: AppColors.divider(context),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
            ),
          ),

          const SizedBox(height: 14),

          // Today's passage label
          Text(active.todayPassage.label,
            style: TextStyle(fontFamily: 'Inter', fontSize: 13,
              color: AppColors.sublabel(context))),

          const SizedBox(height: 12),

          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => context.go('/reader', extra: {
                  'book': active.todayPassage.bookId,
                  'chapter': active.todayPassage.chapter,
                }),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.cardElevated(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text('Read',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 13,
                        fontWeight: FontWeight.w600, color: AppColors.label(context))),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final isLast = active.currentDay >= active.plan.durationDays;
                  await PlanService().markDayComplete(active.planId);
                  // StreamProvider updates automatically — no invalidate needed
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(isLast
                        ? '🎉 Plan complete!'
                        : 'Day ${active.currentDay} complete!'),
                      backgroundColor: AppColors.cardElevated(context),
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                },
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text('Mark Complete',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 13,
                        fontWeight: FontWeight.w600, color: AppColors.black)),
                  ),
                ),
              ),
            ),
          ]),
        ]),
      ),
    ]);
  }
}

// ── Plan Browse Card (shown when no active plan) ───────────────────────────────

class _PlanBrowseCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('READING PLAN',
        style: TextStyle(fontFamily: 'Inter', fontSize: 10,
          fontWeight: FontWeight.w700, color: AppColors.textDim,
          letterSpacing: 1.2)),
      const SizedBox(height: 10),
      GestureDetector(
        onTap: () => context.go('/plans'),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider(context)),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.menu_book_rounded,
                color: AppColors.gold, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Start a Reading Plan',
                  style: TextStyle(fontFamily: 'Lora', fontSize: 15,
                    fontWeight: FontWeight.bold, color: AppColors.label(context))),
                SizedBox(height: 3),
                Text('Romans, Psalms, the Sermon on the Mount and more',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                    color: AppColors.sublabel(context))),
              ]),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
              color: AppColors.textDim, size: 22),
          ]),
        ),
      ),
    ]);
  }
}
