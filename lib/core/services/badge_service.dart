import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/badge_definitions.dart';

/// Manages earning and loading Dig Deeper badges.
///
/// Badges are stored at: digdeeperBadges/{uid}/earned/{badgeId}
/// This collection is client-writable (Firestore rules updated accordingly).
class BadgeService {
  static final BadgeService _instance = BadgeService._();
  BadgeService._();
  factory BadgeService() => _instance;

  final _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _earnedRef {
    final uid = _uid;
    if (uid == null) return null;
    return _db
        .collection('digdeeperBadges')
        .doc(uid)
        .collection('earned');
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Stream of earned badges: badgeId → earnedAt date.
  Stream<Map<String, DateTime>> earnedBadgesStream() {
    final ref = _earnedRef;
    if (ref == null) return Stream.value({});
    return ref.snapshots().map((snap) {
      final map = <String, DateTime>{};
      for (final doc in snap.docs) {
        final ts = doc.data()['earnedAt'];
        map[doc.id] = ts is Timestamp ? ts.toDate() : DateTime.now();
      }
      return map;
    });
  }

  /// One-shot fetch of earned badge IDs (internal use).
  Future<Set<String>> getEarnedBadgeIds() async {
    final ref = _earnedRef;
    if (ref == null) return {};
    final snap = await ref.get();
    return snap.docs.map((d) => d.id).toSet();
  }

  // ── Award ──────────────────────────────────────────────────────────────────

  /// Awards a badge if not already earned. Silent no-op if already earned.
  Future<void> award(String badgeId) async {
    final ref = _earnedRef;
    if (ref == null) { print('[BadgeService] award($badgeId): no uid'); return; }
    try {
      final doc = ref.doc(badgeId);
      final existing = await doc.get();
      if (existing.exists) { print('[BadgeService] $badgeId already earned'); return; }
      await doc.set({'earnedAt': FieldValue.serverTimestamp()});
      print('[BadgeService] awarded $badgeId ✓');
    } catch (e) {
      print('[BadgeService] award($badgeId) ERROR: $e');
    }
  }

  /// Called after a study session completes.
  /// Pass the method name and the book id so we can track explorer progress.
  Future<void> onStudyCompleted({
    required String method,
    required String bookId,
  }) async {
    final ref = _earnedRef;
    if (ref == null) return;

    final earned = await getEarnedBadgeIds();

    // First Step
    if (!earned.contains('first_step')) await award('first_step');

    // Word Seeker / Lexicon
    if (method == 'wordStudy') {
      if (!earned.contains('word_seeker')) await award('word_seeker');

      // Count word studies for Lexicon
      if (!earned.contains('lexicon')) {
        final count = await _countStudiesOfMethod('wordStudy');
        if (count >= 5) await award('lexicon');
      }
    }

    // Deep Roots (5 studies) / Devoted (25 studies)
    if (!earned.contains('devoted')) {
      final total = await _countTotalStudies();
      if (total >= 25) {
        await award('devoted');
        await award('deep_roots'); // implies 5 already
      } else if (total >= 5 && !earned.contains('deep_roots')) {
        await award('deep_roots');
      }
    }

    // Explorer: studies in 5 different books
    if (!earned.contains('explorer')) {
      await _recordStudiedBook(bookId);
      final books = await _studiedBooks();
      if (books.length >= 5) await award('explorer');
    }
  }

  /// Called when the user saves a note.
  Future<void> onNoteSaved() async {
    final earned = await getEarnedBadgeIds();
    if (!earned.contains('scribe')) await award('scribe');

    if (!earned.contains('chronicler')) {
      final count = await _countNotes();
      if (count >= 10) await award('chronicler');
    }
  }

  /// Called when the user highlights a verse.
  Future<void> onVerseHighlighted() async {
    final earned = await getEarnedBadgeIds();
    if (!earned.contains('marked')) await award('marked');
  }

  /// Called when the user posts in a group feed.
  Future<void> onGroupPost() async {
    final earned = await getEarnedBadgeIds();
    if (!earned.contains('iron_sharpens')) await award('iron_sharpens');
  }

  /// Called when the user adds a prayer request in a group.
  Future<void> onPrayerRequest() async {
    final earned = await getEarnedBadgeIds();
    if (!earned.contains('prayer_warrior')) await award('prayer_warrior');
  }

  /// Called with the user's current streak count (e.g. after each study).
  Future<void> onStreakUpdated(int streakDays) async {
    if (streakDays >= 7) {
      final earned = await getEarnedBadgeIds();
      if (!earned.contains('seven_days')) await award('seven_days');
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<int> _countTotalStudies() async {
    final uid = _uid;
    if (uid == null) return 0;
    final snap = await _db
        .collection('notes')
        .doc(uid)
        .collection('entries')
        .where('type', isEqualTo: 'aiStudy')
        .get();
    return snap.docs.length;
  }

  Future<int> _countStudiesOfMethod(String method) async {
    final uid = _uid;
    if (uid == null) return 0;
    final snap = await _db
        .collection('notes')
        .doc(uid)
        .collection('entries')
        .where('type', isEqualTo: 'aiStudy')
        .where('method', isEqualTo: method)
        .get();
    return snap.docs.length;
  }

  Future<int> _countNotes() async {
    final uid = _uid;
    if (uid == null) return 0;
    final snap = await _db
        .collection('notes')
        .doc(uid)
        .collection('entries')
        .get();
    return snap.docs.length;
  }

  Future<void> _recordStudiedBook(String bookId) async {
    final uid = _uid;
    if (uid == null) return;
    await _db
        .collection('digdeeperBadges')
        .doc(uid)
        .set({'studiedBooks': FieldValue.arrayUnion([bookId])},
          SetOptions(merge: true));
  }

  Future<Set<String>> _studiedBooks() async {
    final uid = _uid;
    if (uid == null) return {};
    final doc = await _db.collection('digdeeperBadges').doc(uid).get();
    final list = (doc.data()?['studiedBooks'] as List?)?.cast<String>() ?? [];
    return list.toSet();
  }
}
