import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Streak data snapshot.
class StreakData {
  final int current;
  final int best;
  final int total;

  /// Which of the last 7 days had study activity.
  /// Index 0 = 6 days ago, index 6 = today.
  final List<bool> recentDays;

  const StreakData({
    required this.current,
    required this.best,
    required this.total,
    required this.recentDays,
  });

  static StreakData get empty => const StreakData(
    current: 0,
    best: 0,
    total: 0,
    recentDays: [false, false, false, false, false, false, false],
  );
}

class StreakService {
  static final StreakService _instance = StreakService._();
  StreakService._();
  factory StreakService() => _instance;

  final _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _doc {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid);
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  Stream<StreakData> streakStream() {
    final doc = _doc;
    if (doc == null) return Stream.value(StreakData.empty);

    return doc.snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return StreakData.empty;
      return _parse(data);
    });
  }

  Future<StreakData> getStreak() async {
    final doc = _doc;
    if (doc == null) return StreakData.empty;
    final snap = await doc.get();
    if (!snap.exists) return StreakData.empty;
    return _parse(snap.data()!);
  }

  StreakData _parse(Map<String, dynamic> data) {
    final sd = data['streakData'] as Map<String, dynamic>? ?? {};
    final current  = (sd['current']  as int?) ?? 0;
    final best     = (sd['best']     as int?) ?? 0;
    final total    = (sd['total']    as int?) ?? 0;
    final rawDates = (sd['recentDates'] as List?)?.cast<String>() ?? [];

    // Build 7-day bool array (index 0 = 6 days ago, index 6 = today)
    final today = _todayStr();
    final recentDays = List.generate(7, (i) {
      final date = _dateStr(DateTime.now().subtract(Duration(days: 6 - i)));
      return rawDates.contains(date);
    });
    // Ensure today's slot reflects actual activity
    if (rawDates.contains(today)) recentDays[6] = true;

    return StreakData(
      current: current,
      best: best,
      total: total,
      recentDays: recentDays,
    );
  }

  // ── Write ──────────────────────────────────────────────────────────────────

  /// Call after any study session completes.
  Future<void> recordStudy() async {
    final doc = _doc;
    if (doc == null) return;

    try {
      final today     = _todayStr();
      final yesterday = _dateStr(DateTime.now().subtract(const Duration(days: 1)));

      await _db.runTransaction((tx) async {
        final snap = await tx.get(doc);
        final data = snap.data() ?? {};
        final sd   = Map<String, dynamic>.from(
          (data['streakData'] as Map?) ?? {});

        final lastDate = sd['lastDate'] as String?;

        // Skip if already studied today
        if (lastDate == today) return;

        // Streak logic
        int current = (sd['current'] as int?) ?? 0;
        if (lastDate == yesterday) {
          current += 1; // Extend streak
        } else {
          current = 1; // Start new streak
        }

        final best  = ((sd['best']  as int?) ?? 0).clamp(current, 9999);
        final total = ((sd['total'] as int?) ?? 0) + 1;

        // Keep recent dates — last 7 days only
        final recentDates = List<String>.from(
          (sd['recentDates'] as List?)?.cast<String>() ?? []);
        recentDates.add(today);
        // Prune dates older than 7 days
        final cutoff = _dateStr(
          DateTime.now().subtract(const Duration(days: 6)));
        recentDates.removeWhere((d) => d.compareTo(cutoff) < 0);
        // Deduplicate
        final uniqueDates = recentDates.toSet().toList()..sort();

        tx.set(doc, {
          'streakData': {
            'current':     current,
            'best':        best,
            'total':       total,
            'lastDate':    today,
            'recentDates': uniqueDates,
          },
        }, SetOptions(merge: true));
      });

      // Also notify BadgeService for streak badges
      final updated = await getStreak();
      BadgeService_streak().notify(updated.current);
    } catch (e) {
      // Fire-and-forget — swallow errors
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _todayStr() => _dateStr(DateTime.now());

  String _dateStr(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}

/// Thin shim so streak_service.dart doesn't circularly import badge_service.dart.
class BadgeService_streak {
  void notify(int streak) {
    if (streak >= 7) {
      // Inline award — avoids import cycle
      _awardStreakBadge();
    }
  }

  Future<void> _awardStreakBadge() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('digdeeperBadges')
          .doc(uid)
          .collection('earned')
          .doc('seven_days')
          .set({
        'earnedAt': FieldValue.serverTimestamp(),
        'badgeId':  'seven_days',
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}
