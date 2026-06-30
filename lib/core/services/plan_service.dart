import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/plan_definitions.dart';

/// Tracks which reading plan the user is on and their daily progress.
///
/// Firestore path: userPlans/{uid}/active/{planId}
/// Doc fields:
///   planId        : String
///   currentDay    : int   (1-based; day they're currently on)
///   startedAt     : Timestamp
///   completedDays : List<int>  (1-based day numbers marked complete)
///   completedAt   : Timestamp? (set when currentDay > durationDays)
class ActivePlanState {
  final String planId;
  final PlanDef plan;
  final int currentDay;       // 1-based
  final Set<int> completedDays;
  final DateTime startedAt;
  final bool isComplete;

  const ActivePlanState({
    required this.planId,
    required this.plan,
    required this.currentDay,
    required this.completedDays,
    required this.startedAt,
    required this.isComplete,
  });

  PlanPassage get todayPassage => plan.passages[currentDay - 1];

  double get progressFraction =>
      completedDays.length / plan.durationDays;
}

class PlanService {
  static final PlanService _instance = PlanService._();
  PlanService._();
  factory PlanService() => _instance;

  final _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _activeRef {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('userPlans').doc(uid).collection('active');
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Stream of the user's current active plan, or null if none.
  Stream<ActivePlanState?> activePlanStream() {
    final ref = _activeRef;
    if (ref == null) return Stream.value(null);

    return ref.snapshots().map((snap) {
      // Only look at the most recently started plan (there should be ≤1 active)
      if (snap.docs.isEmpty) return null;

      // Pick the doc with the latest startedAt (avoid reduce — Firestore type issue)
      var latest = snap.docs.first;
      for (final doc in snap.docs.skip(1)) {
        final latestTs = latest.data()['startedAt'] as Timestamp?;
        final docTs    = doc.data()['startedAt'] as Timestamp?;
        if (docTs != null &&
            (latestTs == null || docTs.compareTo(latestTs) > 0)) {
          latest = doc;
        }
      }

      return _docToState(latest);
    });
  }

  /// One-shot fetch of the active plan.
  Future<ActivePlanState?> getActivePlan() async {
    final ref = _activeRef;
    if (ref == null) return null;
    final snap = await ref.get();
    if (snap.docs.isEmpty) return null;
    var latest = snap.docs.first;
    for (final doc in snap.docs.skip(1)) {
      final latestTs = latest.data()['startedAt'] as Timestamp?;
      final docTs    = doc.data()['startedAt'] as Timestamp?;
      if (docTs != null &&
          (latestTs == null || docTs.compareTo(latestTs) > 0)) {
        latest = doc;
      }
    }
    return _docToState(latest);
  }

  ActivePlanState? _docToState(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return null;
    final planId = data['planId'] as String? ?? doc.id;
    final plan = planById(planId);
    if (plan == null) return null;

    final currentDay = (data['currentDay'] as int?) ?? 1;
    final completedRaw = (data['completedDays'] as List?)?.cast<int>() ?? [];
    final completedDays = completedRaw.toSet();
    final ts = data['startedAt'] as Timestamp?;
    final startedAt = ts?.toDate() ?? DateTime.now();
    final isComplete = currentDay > plan.durationDays;

    return ActivePlanState(
      planId: planId,
      plan: plan,
      currentDay: currentDay.clamp(1, plan.durationDays),
      completedDays: completedDays,
      startedAt: startedAt,
      isComplete: isComplete,
    );
  }

  // ── Write ──────────────────────────────────────────────────────────────────

  /// Start a new plan. Abandons any existing active plan first.
  Future<void> startPlan(String planId) async {
    final ref = _activeRef;
    if (ref == null) return;

    // Clear all existing active docs
    final existing = await ref.get();
    final batch = _db.batch();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    // Write new plan doc
    batch.set(ref.doc(planId), {
      'planId': planId,
      'currentDay': 1,
      'startedAt': FieldValue.serverTimestamp(),
      'completedDays': [],
    });
    await batch.commit();
  }

  /// Mark the current day complete and advance to the next day.
  Future<void> markDayComplete(String planId) async {
    final ref = _activeRef;
    if (ref == null) return;

    final doc = ref.doc(planId);
    final snap = await doc.get();
    if (!snap.exists) return;

    final data = snap.data()!;
    final currentDay = (data['currentDay'] as int?) ?? 1;
    final plan = planById(planId);
    if (plan == null) return;

    final nextDay = currentDay + 1;
    final Map<String, dynamic> update = {
      'completedDays': FieldValue.arrayUnion([currentDay]),
      'currentDay': nextDay,
    };

    // Mark as completed if we just finished the last day
    if (nextDay > plan.durationDays) {
      update['completedAt'] = FieldValue.serverTimestamp();
    }

    await doc.update(update);
  }

  /// Abandon the active plan entirely.
  Future<void> abandonPlan(String planId) async {
    final ref = _activeRef;
    if (ref == null) return;
    await ref.doc(planId).delete();
  }
}
