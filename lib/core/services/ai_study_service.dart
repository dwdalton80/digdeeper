import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Result of an AI study session.
class AiStudyResult {
  final String passage;        // e.g. "John 3:1-21"
  final String method;         // e.g. "SOAP"
  final String overview;
  final List<String> observations;
  final String interpretation;
  final List<String> applicationPoints;
  final List<String> reflectionQuestions;
  final String prayerPrompt;
  final DateTime generatedAt;

  const AiStudyResult({
    required this.passage,
    required this.method,
    required this.overview,
    required this.observations,
    required this.interpretation,
    required this.applicationPoints,
    required this.reflectionQuestions,
    required this.prayerPrompt,
    required this.generatedAt,
  });

  factory AiStudyResult.fromMap(Map<String, dynamic> data) => AiStudyResult(
    passage:             data['passage'] as String? ?? '',
    method:              data['method'] as String? ?? '',
    overview:            data['overview'] as String? ?? '',
    observations:        List<String>.from(data['observations'] as List? ?? []),
    interpretation:      data['interpretation'] as String? ?? '',
    applicationPoints:   List<String>.from(data['applicationPoints'] as List? ?? []),
    reflectionQuestions: List<String>.from(data['reflectionQuestions'] as List? ?? []),
    prayerPrompt:        data['prayerPrompt'] as String? ?? '',
    generatedAt:         (data['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'passage':             passage,
    'method':              method,
    'overview':            overview,
    'observations':        observations,
    'interpretation':      interpretation,
    'applicationPoints':   applicationPoints,
    'reflectionQuestions': reflectionQuestions,
    'prayerPrompt':        prayerPrompt,
    'generatedAt':         Timestamp.fromDate(generatedAt),
  };
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  const ChatMessage({required this.text, required this.isUser, required this.timestamp});
}

class AiStudyService {
  final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Cache is handled server-side in the Cloud Function (admin SDK bypasses rules).
  /// This is a no-op kept for API compatibility.
  Future<AiStudyResult?> getCachedStudy(String bookId, int chapter, String method) async {
    return null; // Cloud Function handles its own 7-day cache
  }

  /// Generates a new AI study via Cloud Function.
  Future<AiStudyResult> generateStudy({
    required String bookId,
    required String bookName,
    required int chapter,
    required String version,
    required String method,
    required String passageText,
  }) async {
    final callable = _functions.httpsCallable(
      'generateDigDeeperStudyFn',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );
    final response = await callable.call({
      'bookId':      bookId,
      'bookName':    bookName,
      'chapter':     chapter,
      'version':     version,
      'method':      method,
      'passageText': passageText,
    });

    final data = Map<String, dynamic>.from(response.data as Map);
    return AiStudyResult.fromMap({
      ...data,
      'passage': '$bookName $chapter',
      'method': method,
      'generatedAt': Timestamp.now(),
    });
  }

  /// Asks a follow-up question about the current passage.
  Future<String> askQuestion({
    required String question,
    required String passageText,
    required String passage,
    required List<ChatMessage> history,
  }) async {
    final callable = _functions.httpsCallable(
      'askDigDeeperQuestionFn',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );
    final response = await callable.call({
      'question':    question,
      'passageText': passageText,
      'passage':     passage,
      'history':     history
          .take(6)
          .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
          .toList(),
    });
    final data = Map<String, dynamic>.from(response.data as Map);
    return data['answer'] as String? ?? 'Unable to get a response. Please try again.';
  }

  /// Saves a study session to the user's notes/journal.
  Future<void> saveToNotes(AiStudyResult study) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('notes')
        .doc(uid)
        .collection('entries')
        .add({
      'title': 'Study: ${study.passage}',
      'type': 'aiStudy',
      'passage': study.passage,
      'method': study.method,
      'overview': study.overview,
      'applicationPoints': study.applicationPoints,
      'reflectionQuestions': study.reflectionQuestions,
      'prayerPrompt': study.prayerPrompt,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
