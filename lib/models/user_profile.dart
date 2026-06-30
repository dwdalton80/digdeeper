import 'package:cloud_firestore/cloud_firestore.dart';

enum StudyLevel { newBeliever, growing, mature, scholar }
enum StudyLens { devotional, theological, historical, pastoral, originalLanguage }
enum StudyMethod { inductive, soap, swedish, lectioDivina, wordStudy, none }

class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String? avatarUrl;
  final StudyLevel studyLevel;
  final String defaultVersion;
  final StudyLens defaultLens;
  final StudyMethod defaultMethod;
  final List<String> studyGoals;
  final bool isPremium;
  final String? churchId;
  final DateTime lastActiveDate;
  final Map<String, int> stats;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.studyLevel,
    required this.defaultVersion,
    required this.defaultLens,
    required this.defaultMethod,
    required this.studyGoals,
    required this.isPremium,
    this.churchId,
    required this.lastActiveDate,
    required this.stats,
  });

  factory UserProfile.fromFirestore(Map<String, dynamic> data, String uid) {
    final profile = data['profile'] as Map<String, dynamic>? ?? {};
    final prefs = data['preferences'] as Map<String, dynamic>? ?? {};
    final statsData = data['stats'] as Map<String, dynamic>? ?? {};

    return UserProfile(
      uid: uid,
      name: profile['name'] as String? ?? 'Friend',
      email: profile['email'] as String? ?? '',
      avatarUrl: profile['avatarUrl'] as String?,
      studyLevel: StudyLevel.values.firstWhere(
        (e) => e.name == (profile['studyLevel'] as String?),
        orElse: () => StudyLevel.growing,
      ),
      defaultVersion: prefs['version'] as String? ?? 'niv',
      defaultLens: StudyLens.values.firstWhere(
        (e) => e.name == (prefs['defaultLens'] as String?),
        orElse: () => StudyLens.devotional,
      ),
      defaultMethod: StudyMethod.values.firstWhere(
        (e) => e.name == (prefs['defaultMethod'] as String?),
        orElse: () => StudyMethod.none,
      ),
      studyGoals: List<String>.from(prefs['studyGoals'] as List? ?? []),
      isPremium: profile['isPremium'] as bool? ?? false,
      churchId: profile['churchId'] as String?,
      lastActiveDate: (profile['lastActiveDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      stats: Map<String, int>.from(statsData.map(
        (k, v) => MapEntry(k, (v as num).toInt()),
      )),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'email': email,
    'avatarUrl': avatarUrl,
    'studyLevel': studyLevel.name,
    'isPremium': isPremium,
    'churchId': churchId,
    'lastActiveDate': Timestamp.fromDate(lastActiveDate),
  };

  UserProfile copyWith({
    String? name,
    String? avatarUrl,
    StudyLevel? studyLevel,
    String? defaultVersion,
    StudyLens? defaultLens,
    StudyMethod? defaultMethod,
    List<String>? studyGoals,
    bool? isPremium,
    String? churchId,
    DateTime? lastActiveDate,
    Map<String, int>? stats,
  }) {
    return UserProfile(
      uid: uid,
      name: name ?? this.name,
      email: email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      studyLevel: studyLevel ?? this.studyLevel,
      defaultVersion: defaultVersion ?? this.defaultVersion,
      defaultLens: defaultLens ?? this.defaultLens,
      defaultMethod: defaultMethod ?? this.defaultMethod,
      studyGoals: studyGoals ?? this.studyGoals,
      isPremium: isPremium ?? this.isPremium,
      churchId: churchId ?? this.churchId,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      stats: stats ?? this.stats,
    );
  }
}
