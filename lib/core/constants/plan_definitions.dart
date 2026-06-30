/// Hardcoded reading plan definitions.
/// Progress is stored in Firestore; these definitions never change at runtime.

class PlanPassage {
  final String bookId;
  final int chapter;
  final String label; // e.g. "Romans 1"

  const PlanPassage({
    required this.bookId,
    required this.chapter,
    required this.label,
  });
}

class PlanDef {
  final String id;
  final String title;
  final String subtitle;   // short hook line
  final String description;
  final int durationDays;
  final List<PlanPassage> passages; // one per day, length == durationDays
  final String? imagePath; // optional thumbnail asset

  const PlanDef({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.durationDays,
    required this.passages,
    this.imagePath,
  });
}

// ── Plans ──────────────────────────────────────────────────────────────────────

const kAllPlans = <PlanDef>[

  // 1. Sermon on the Mount — 7 days
  PlanDef(
    id: 'sermon_on_the_mount',
    imagePath: 'assets/images/plans/plan_sermon_on_the_mount.jpg',
    title: 'Sermon on the Mount',
    subtitle: '7 days · Matthew 5–7',
    description:
        'Sit with Jesus\'s most famous teaching. One chapter at a time, '
        'unpacking what the Kingdom life actually looks like.',
    durationDays: 7,
    passages: [
      PlanPassage(bookId: 'mat', chapter: 5, label: 'Matthew 5'),
      PlanPassage(bookId: 'mat', chapter: 5, label: 'Matthew 5 (continued)'),
      PlanPassage(bookId: 'mat', chapter: 6, label: 'Matthew 6'),
      PlanPassage(bookId: 'mat', chapter: 6, label: 'Matthew 6 (continued)'),
      PlanPassage(bookId: 'mat', chapter: 7, label: 'Matthew 7'),
      PlanPassage(bookId: 'mat', chapter: 7, label: 'Matthew 7 (continued)'),
      PlanPassage(bookId: 'mat', chapter: 5, label: 'Review — Matthew 5'),
    ],
  ),

  // 2. Psalms of Ascent — 15 days
  PlanDef(
    id: 'psalms_of_ascent',
    imagePath: 'assets/images/plans/plan_psalms_of_ascent.jpg',
    title: 'Psalms of Ascent',
    subtitle: '15 days · Psalms 120–134',
    description:
        'These 15 psalms were sung by pilgrims travelling to Jerusalem. '
        'One psalm a day — short, honest, and surprisingly modern.',
    durationDays: 15,
    passages: [
      PlanPassage(bookId: 'psa', chapter: 120, label: 'Psalm 120'),
      PlanPassage(bookId: 'psa', chapter: 121, label: 'Psalm 121'),
      PlanPassage(bookId: 'psa', chapter: 122, label: 'Psalm 122'),
      PlanPassage(bookId: 'psa', chapter: 123, label: 'Psalm 123'),
      PlanPassage(bookId: 'psa', chapter: 124, label: 'Psalm 124'),
      PlanPassage(bookId: 'psa', chapter: 125, label: 'Psalm 125'),
      PlanPassage(bookId: 'psa', chapter: 126, label: 'Psalm 126'),
      PlanPassage(bookId: 'psa', chapter: 127, label: 'Psalm 127'),
      PlanPassage(bookId: 'psa', chapter: 128, label: 'Psalm 128'),
      PlanPassage(bookId: 'psa', chapter: 129, label: 'Psalm 129'),
      PlanPassage(bookId: 'psa', chapter: 130, label: 'Psalm 130'),
      PlanPassage(bookId: 'psa', chapter: 131, label: 'Psalm 131'),
      PlanPassage(bookId: 'psa', chapter: 132, label: 'Psalm 132'),
      PlanPassage(bookId: 'psa', chapter: 133, label: 'Psalm 133'),
      PlanPassage(bookId: 'psa', chapter: 134, label: 'Psalm 134'),
    ],
  ),

  // 3. 30 Days in Romans — 30 days
  PlanDef(
    id: 'thirty_days_romans',
    imagePath: 'assets/images/plans/plan_thirty_days_romans.jpg',
    title: '30 Days in Romans',
    subtitle: '30 days · Romans 1–16',
    description:
        'Paul\'s deepest letter — grace, faith, Israel, and how to live together. '
        'Two readings per chapter let you slow down where it counts.',
    durationDays: 30,
    passages: [
      PlanPassage(bookId: 'rom', chapter: 1,  label: 'Romans 1'),
      PlanPassage(bookId: 'rom', chapter: 1,  label: 'Romans 1 (reflect)'),
      PlanPassage(bookId: 'rom', chapter: 2,  label: 'Romans 2'),
      PlanPassage(bookId: 'rom', chapter: 2,  label: 'Romans 2 (reflect)'),
      PlanPassage(bookId: 'rom', chapter: 3,  label: 'Romans 3'),
      PlanPassage(bookId: 'rom', chapter: 3,  label: 'Romans 3 (reflect)'),
      PlanPassage(bookId: 'rom', chapter: 4,  label: 'Romans 4'),
      PlanPassage(bookId: 'rom', chapter: 4,  label: 'Romans 4 (reflect)'),
      PlanPassage(bookId: 'rom', chapter: 5,  label: 'Romans 5'),
      PlanPassage(bookId: 'rom', chapter: 5,  label: 'Romans 5 (reflect)'),
      PlanPassage(bookId: 'rom', chapter: 6,  label: 'Romans 6'),
      PlanPassage(bookId: 'rom', chapter: 6,  label: 'Romans 6 (reflect)'),
      PlanPassage(bookId: 'rom', chapter: 7,  label: 'Romans 7'),
      PlanPassage(bookId: 'rom', chapter: 7,  label: 'Romans 7 (reflect)'),
      PlanPassage(bookId: 'rom', chapter: 8,  label: 'Romans 8'),
      PlanPassage(bookId: 'rom', chapter: 8,  label: 'Romans 8 (reflect)'),
      PlanPassage(bookId: 'rom', chapter: 9,  label: 'Romans 9'),
      PlanPassage(bookId: 'rom', chapter: 10, label: 'Romans 10'),
      PlanPassage(bookId: 'rom', chapter: 11, label: 'Romans 11'),
      PlanPassage(bookId: 'rom', chapter: 11, label: 'Romans 11 (reflect)'),
      PlanPassage(bookId: 'rom', chapter: 12, label: 'Romans 12'),
      PlanPassage(bookId: 'rom', chapter: 12, label: 'Romans 12 (reflect)'),
      PlanPassage(bookId: 'rom', chapter: 13, label: 'Romans 13'),
      PlanPassage(bookId: 'rom', chapter: 14, label: 'Romans 14'),
      PlanPassage(bookId: 'rom', chapter: 15, label: 'Romans 15'),
      PlanPassage(bookId: 'rom', chapter: 15, label: 'Romans 15 (reflect)'),
      PlanPassage(bookId: 'rom', chapter: 16, label: 'Romans 16'),
      PlanPassage(bookId: 'rom', chapter: 8,  label: 'Review — Romans 8'),
      PlanPassage(bookId: 'rom', chapter: 12, label: 'Review — Romans 12'),
      PlanPassage(bookId: 'rom', chapter: 1,  label: 'Review — Romans 1'),
    ],
  ),

  // 4. Life of David — 21 days
  PlanDef(
    id: 'life_of_david',
    imagePath: 'assets/images/plans/plan_life_of_david.jpg',
    title: 'The Life of David',
    subtitle: '21 days · Samuel & Psalms',
    description:
        'Shepherd, warrior, king, poet. Follow David\'s story across '
        '1 Samuel and the Psalms he wrote in its shadow.',
    durationDays: 21,
    passages: [
      PlanPassage(bookId: '1sa', chapter: 16, label: '1 Samuel 16 — Chosen'),
      PlanPassage(bookId: '1sa', chapter: 17, label: '1 Samuel 17 — Goliath'),
      PlanPassage(bookId: 'psa', chapter: 23, label: 'Psalm 23'),
      PlanPassage(bookId: '1sa', chapter: 18, label: '1 Samuel 18 — Jonathan'),
      PlanPassage(bookId: '1sa', chapter: 19, label: '1 Samuel 19 — Fugitive'),
      PlanPassage(bookId: 'psa', chapter: 34, label: 'Psalm 34'),
      PlanPassage(bookId: '1sa', chapter: 24, label: '1 Samuel 24 — Saul\'s life spared'),
      PlanPassage(bookId: 'psa', chapter: 57, label: 'Psalm 57'),
      PlanPassage(bookId: '2sa', chapter: 5,  label: '2 Samuel 5 — King'),
      PlanPassage(bookId: '2sa', chapter: 6,  label: '2 Samuel 6 — The Ark'),
      PlanPassage(bookId: 'psa', chapter: 24, label: 'Psalm 24'),
      PlanPassage(bookId: '2sa', chapter: 7,  label: '2 Samuel 7 — The Covenant'),
      PlanPassage(bookId: 'psa', chapter: 89, label: 'Psalm 89'),
      PlanPassage(bookId: '2sa', chapter: 11, label: '2 Samuel 11 — The Fall'),
      PlanPassage(bookId: '2sa', chapter: 12, label: '2 Samuel 12 — Nathan'),
      PlanPassage(bookId: 'psa', chapter: 51, label: 'Psalm 51 — Repentance'),
      PlanPassage(bookId: '2sa', chapter: 22, label: '2 Samuel 22 — Song of David'),
      PlanPassage(bookId: 'psa', chapter: 18, label: 'Psalm 18'),
      PlanPassage(bookId: '1ki', chapter: 2,  label: '1 Kings 2 — Final words'),
      PlanPassage(bookId: 'psa', chapter: 16, label: 'Psalm 16'),
      PlanPassage(bookId: 'psa', chapter: 22, label: 'Psalm 22 — The suffering servant'),
    ],
  ),

  // 5. Letters of Paul — 28 days
  PlanDef(
    id: 'letters_of_paul',
    imagePath: 'assets/images/plans/plan_letters_of_paul.jpg',
    title: 'Letters of Paul',
    subtitle: '28 days · Galatians · Ephesians · Philippians · Colossians',
    description:
        'Four of Paul\'s most personal letters — grace over law, '
        'identity in Christ, joy in suffering, and the supremacy of Jesus.',
    durationDays: 28,
    passages: [
      // Galatians (6 chapters → 7 days)
      PlanPassage(bookId: 'gal', chapter: 1, label: 'Galatians 1'),
      PlanPassage(bookId: 'gal', chapter: 2, label: 'Galatians 2'),
      PlanPassage(bookId: 'gal', chapter: 3, label: 'Galatians 3'),
      PlanPassage(bookId: 'gal', chapter: 3, label: 'Galatians 3 (reflect)'),
      PlanPassage(bookId: 'gal', chapter: 4, label: 'Galatians 4'),
      PlanPassage(bookId: 'gal', chapter: 5, label: 'Galatians 5'),
      PlanPassage(bookId: 'gal', chapter: 6, label: 'Galatians 6'),
      // Ephesians (6 chapters → 7 days)
      PlanPassage(bookId: 'eph', chapter: 1, label: 'Ephesians 1'),
      PlanPassage(bookId: 'eph', chapter: 2, label: 'Ephesians 2'),
      PlanPassage(bookId: 'eph', chapter: 2, label: 'Ephesians 2 (reflect)'),
      PlanPassage(bookId: 'eph', chapter: 3, label: 'Ephesians 3'),
      PlanPassage(bookId: 'eph', chapter: 4, label: 'Ephesians 4'),
      PlanPassage(bookId: 'eph', chapter: 5, label: 'Ephesians 5'),
      PlanPassage(bookId: 'eph', chapter: 6, label: 'Ephesians 6'),
      // Philippians (4 chapters → 7 days)
      PlanPassage(bookId: 'php', chapter: 1, label: 'Philippians 1'),
      PlanPassage(bookId: 'php', chapter: 1, label: 'Philippians 1 (reflect)'),
      PlanPassage(bookId: 'php', chapter: 2, label: 'Philippians 2'),
      PlanPassage(bookId: 'php', chapter: 2, label: 'Philippians 2 (reflect)'),
      PlanPassage(bookId: 'php', chapter: 3, label: 'Philippians 3'),
      PlanPassage(bookId: 'php', chapter: 3, label: 'Philippians 3 (reflect)'),
      PlanPassage(bookId: 'php', chapter: 4, label: 'Philippians 4'),
      // Colossians (4 chapters → 7 days)
      PlanPassage(bookId: 'col', chapter: 1, label: 'Colossians 1'),
      PlanPassage(bookId: 'col', chapter: 1, label: 'Colossians 1 (reflect)'),
      PlanPassage(bookId: 'col', chapter: 2, label: 'Colossians 2'),
      PlanPassage(bookId: 'col', chapter: 2, label: 'Colossians 2 (reflect)'),
      PlanPassage(bookId: 'col', chapter: 3, label: 'Colossians 3'),
      PlanPassage(bookId: 'col', chapter: 3, label: 'Colossians 3 (reflect)'),
      PlanPassage(bookId: 'col', chapter: 4, label: 'Colossians 4'),
    ],
  ),
];

/// Look up a plan by ID.
PlanDef? planById(String id) {
  try {
    return kAllPlans.firstWhere((p) => p.id == id);
  } catch (_) {
    return null;
  }
}
