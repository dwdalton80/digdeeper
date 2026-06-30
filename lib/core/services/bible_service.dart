import 'package:cloud_firestore/cloud_firestore.dart';

class BibleVerse {
  final String reference;
  final String text;
  final int verseNumber;
  final String bookId;
  final int chapterNumber;

  const BibleVerse({
    required this.reference,
    required this.text,
    required this.verseNumber,
    required this.bookId,
    required this.chapterNumber,
  });

  factory BibleVerse.fromFirestore(Map<String, dynamic> data) {
    return BibleVerse(
      reference: data['reference'] as String? ?? '',
      text: data['text'] as String? ?? '',
      verseNumber: (data['verseNumber'] as num?)?.toInt() ?? 0,
      bookId: data['bookId'] as String? ?? '',
      chapterNumber: (data['chapterNumber'] as num?)?.toInt() ?? 0,
    );
  }
}

class BibleService {
  final _firestore = FirebaseFirestore.instance;

  /// Fetch all verses for a chapter, ordered by verse number.
  /// Path: /bible/{version}/books/{bookId}/chapters/{chapterId}/verses
  Future<List<BibleVerse>> getChapter({
    required String version,
    required String bookId,
    required int chapter,
  }) async {
    final snapshot = await _firestore
        .collection('bible')
        .doc(version)
        .collection('books')
        .doc(bookId)
        .collection('chapters')
        .doc(chapter.toString())
        .collection('verses')
        .orderBy('verseNumber')
        .get();

    return snapshot.docs
        .map((d) => BibleVerse.fromFirestore(d.data()))
        .toList();
  }

  /// Fetch a passage range within a chapter.
  Future<List<BibleVerse>> getPassage({
    required String version,
    required String bookId,
    required int chapter,
    required int startVerse,
    required int endVerse,
  }) async {
    final snapshot = await _firestore
        .collection('bible')
        .doc(version)
        .collection('books')
        .doc(bookId)
        .collection('chapters')
        .doc(chapter.toString())
        .collection('verses')
        .where('verseNumber', isGreaterThanOrEqualTo: startVerse)
        .where('verseNumber', isLessThanOrEqualTo: endVerse)
        .orderBy('verseNumber')
        .get();

    return snapshot.docs
        .map((d) => BibleVerse.fromFirestore(d.data()))
        .toList();
  }

  /// Fetch a single verse.
  Future<BibleVerse?> getVerse({
    required String version,
    required String bookId,
    required int chapter,
    required int verse,
  }) async {
    final doc = await _firestore
        .collection('bible')
        .doc(version)
        .collection('books')
        .doc(bookId)
        .collection('chapters')
        .doc(chapter.toString())
        .collection('verses')
        .doc(verse.toString())
        .get();

    if (!doc.exists) return null;
    return BibleVerse.fromFirestore(doc.data()!);
  }

  /// Fetch the same chapter in two versions for side-by-side comparison.
  Future<Map<String, List<BibleVerse>>> getChapterMultiVersion({
    required List<String> versions,
    required String bookId,
    required int chapter,
  }) async {
    final results = await Future.wait(
      versions.map((v) => getChapter(version: v, bookId: bookId, chapter: chapter)),
    );
    return Map.fromIterables(versions, results);
  }

  /// Build a plain-text passage string for passing to the Claude API prompt.
  /// Includes surrounding context verses for better AI understanding.
  String buildPassageContext({
    required List<BibleVerse> verses,
    int? startVerse,
    int? endVerse,
    int contextVerses = 3,
  }) {
    final buffer = StringBuffer();
    for (final verse in verses) {
      final inRange = startVerse == null ||
          (verse.verseNumber >= (startVerse - contextVerses) &&
           verse.verseNumber <= ((endVerse ?? startVerse) + contextVerses));
      if (inRange) {
        buffer.writeln('${verse.verseNumber}. ${verse.text}');
      }
    }
    return buffer.toString().trim();
  }
}
