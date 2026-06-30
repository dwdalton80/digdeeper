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

  // 6. Who Am I? — 7 days on identity
  PlanDef(
    id: 'who_am_i',
    imagePath: 'assets/images/plans/plan_who_am_i.jpg',
    title: 'Who Am I?',
    subtitle: '7 days · Identity in Christ',
    description:
        'The most important question you\'ll answer. Seven passages that cut '
        'through every label the world puts on you and show you who God says you are.',
    durationDays: 7,
    passages: [
      PlanPassage(bookId: 'gen', chapter: 1,  label: 'Genesis 1 — Made in His image'),
      PlanPassage(bookId: 'psa', chapter: 139, label: 'Psalm 139 — Fearfully made'),
      PlanPassage(bookId: 'jer', chapter: 1,  label: 'Jeremiah 1 — Called before you were born'),
      PlanPassage(bookId: 'eph', chapter: 1,  label: 'Ephesians 1 — Every spiritual blessing'),
      PlanPassage(bookId: 'rom', chapter: 8,  label: 'Romans 8 — Children of God'),
      PlanPassage(bookId: 'gal', chapter: 3,  label: 'Galatians 3 — Heirs of the promise'),
      PlanPassage(bookId: '1pe', chapter: 2,  label: '1 Peter 2 — Chosen and royal'),
    ],
  ),

  // 7. Peace Over Anxiety — 10 days
  PlanDef(
    id: 'peace_over_anxiety',
    imagePath: 'assets/images/plans/plan_peace_over_anxiety.jpg',
    title: 'Peace Over Anxiety',
    subtitle: '10 days · Rest & Trust',
    description:
        'When everything feels uncertain — school, work, relationships, the future — '
        'the Bible speaks directly into it. Ten readings to trade anxious thoughts for genuine peace.',
    durationDays: 10,
    passages: [
      PlanPassage(bookId: 'php', chapter: 4,  label: 'Philippians 4 — Don\'t be anxious'),
      PlanPassage(bookId: 'mat', chapter: 6,  label: 'Matthew 6 — Don\'t worry'),
      PlanPassage(bookId: 'psa', chapter: 46, label: 'Psalm 46 — God is our refuge'),
      PlanPassage(bookId: 'isa', chapter: 41, label: 'Isaiah 41 — Do not fear'),
      PlanPassage(bookId: 'psa', chapter: 23, label: 'Psalm 23 — The Good Shepherd'),
      PlanPassage(bookId: 'jhn', chapter: 14, label: 'John 14 — Troubled hearts'),
      PlanPassage(bookId: '1pe', chapter: 5,  label: '1 Peter 5 — Cast your anxiety'),
      PlanPassage(bookId: 'psa', chapter: 131, label: 'Psalm 131 — Calm and quiet'),
      PlanPassage(bookId: 'heb', chapter: 4,  label: 'Hebrews 4 — Approach the throne'),
      PlanPassage(bookId: 'rom', chapter: 8,  label: 'Romans 8 — Nothing separates us'),
    ],
  ),

  // 8. Wisdom for Real Life — 14 days in Proverbs
  PlanDef(
    id: 'wisdom_real_life',
    imagePath: 'assets/images/plans/plan_wisdom_real_life.jpg',
    title: 'Wisdom for Real Life',
    subtitle: '14 days · Proverbs',
    description:
        'Money. Friendship. Decisions. Relationships. Your words. Your reputation. '
        'Proverbs covers everything you\'re navigating right now — one sharp chapter at a time.',
    durationDays: 14,
    passages: [
      PlanPassage(bookId: 'pro', chapter: 1,  label: 'Proverbs 1 — Why wisdom matters'),
      PlanPassage(bookId: 'pro', chapter: 2,  label: 'Proverbs 2 — Seek it like silver'),
      PlanPassage(bookId: 'pro', chapter: 3,  label: 'Proverbs 3 — Trust, don\'t lean on yourself'),
      PlanPassage(bookId: 'pro', chapter: 4,  label: 'Proverbs 4 — Guard your heart'),
      PlanPassage(bookId: 'pro', chapter: 5,  label: 'Proverbs 5 — Purity and boundaries'),
      PlanPassage(bookId: 'pro', chapter: 10, label: 'Proverbs 10 — Words and work'),
      PlanPassage(bookId: 'pro', chapter: 12, label: 'Proverbs 12 — Integrity over image'),
      PlanPassage(bookId: 'pro', chapter: 13, label: 'Proverbs 13 — Money and friendship'),
      PlanPassage(bookId: 'pro', chapter: 15, label: 'Proverbs 15 — Soft answers'),
      PlanPassage(bookId: 'pro', chapter: 16, label: 'Proverbs 16 — Plans and pride'),
      PlanPassage(bookId: 'pro', chapter: 17, label: 'Proverbs 17 — True friendship'),
      PlanPassage(bookId: 'pro', chapter: 20, label: 'Proverbs 20 — Honesty and decisions'),
      PlanPassage(bookId: 'pro', chapter: 22, label: 'Proverbs 22 — Your reputation'),
      PlanPassage(bookId: 'pro', chapter: 31, label: 'Proverbs 31 — Character that lasts'),
    ],
  ),

  // 9. Mark: The Real Jesus — 16 days
  PlanDef(
    id: 'mark_real_jesus',
    imagePath: 'assets/images/plans/plan_mark_real_jesus.jpg',
    title: 'Mark: The Real Jesus',
    subtitle: '16 days · Gospel of Mark',
    description:
        'The fastest gospel — no long speeches, just action. Mark writes like a '
        'documentary: who Jesus actually is, what he actually does, and why it '
        'changes everything. One chapter a day.',
    durationDays: 16,
    passages: [
      PlanPassage(bookId: 'mrk', chapter: 1,  label: 'Mark 1 — Baptism & first miracles'),
      PlanPassage(bookId: 'mrk', chapter: 2,  label: 'Mark 2 — Healing & controversy'),
      PlanPassage(bookId: 'mrk', chapter: 3,  label: 'Mark 3 — Crowds & calling'),
      PlanPassage(bookId: 'mrk', chapter: 4,  label: 'Mark 4 — Parables & a storm'),
      PlanPassage(bookId: 'mrk', chapter: 5,  label: 'Mark 5 — Demons, death & healing'),
      PlanPassage(bookId: 'mrk', chapter: 6,  label: 'Mark 6 — Rejection & 5,000 fed'),
      PlanPassage(bookId: 'mrk', chapter: 7,  label: 'Mark 7 — Clean and unclean'),
      PlanPassage(bookId: 'mrk', chapter: 8,  label: 'Mark 8 — Who do you say I am?'),
      PlanPassage(bookId: 'mrk', chapter: 9,  label: 'Mark 9 — Transfiguration'),
      PlanPassage(bookId: 'mrk', chapter: 10, label: 'Mark 10 — Wealth, power & service'),
      PlanPassage(bookId: 'mrk', chapter: 11, label: 'Mark 11 — Into Jerusalem'),
      PlanPassage(bookId: 'mrk', chapter: 12, label: 'Mark 12 — Hard questions'),
      PlanPassage(bookId: 'mrk', chapter: 13, label: 'Mark 13 — The end of the age'),
      PlanPassage(bookId: 'mrk', chapter: 14, label: 'Mark 14 — Betrayal & arrest'),
      PlanPassage(bookId: 'mrk', chapter: 15, label: 'Mark 15 — The cross'),
      PlanPassage(bookId: 'mrk', chapter: 16, label: 'Mark 16 — He is risen'),
    ],
  ),

  // 10. Love & Relationships God's Way — 7 days
  PlanDef(
    id: 'love_and_relationships',
    imagePath: 'assets/images/plans/plan_love_and_relationships.jpg',
    title: 'Love & Relationships',
    subtitle: '7 days · Dating · Friendship · Love',
    description:
        'What does God actually say about love, attraction, dating, and friendship? '
        'Seven honest passages that go deeper than rules and get to the heart of connection.',
    durationDays: 7,
    passages: [
      PlanPassage(bookId: 'gen', chapter: 2,  label: 'Genesis 2 — Made for connection'),
      PlanPassage(bookId: 'rut', chapter: 1,  label: 'Ruth 1 — Loyalty that costs something'),
      PlanPassage(bookId: '1co', chapter: 13, label: '1 Corinthians 13 — What love really is'),
      PlanPassage(bookId: 'pro', chapter: 27, label: 'Proverbs 27 — Iron sharpens iron'),
      PlanPassage(bookId: 'sng', chapter: 2,  label: 'Song of Solomon 2 — Desire & beauty'),
      PlanPassage(bookId: 'eph', chapter: 5,  label: 'Ephesians 5 — Sacrificial love'),
      PlanPassage(bookId: '1jn', chapter: 4,  label: '1 John 4 — God is love'),
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
