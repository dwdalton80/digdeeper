/// Shared Bible book name → Firestore book ID map.
/// Used to build Firestore paths: /bible/{version}/books/{bookId}/chapters/{ch}/verses/{v}
const Map<String, String> kBookIds = {
  'Genesis': 'gen', 'Exodus': 'exo', 'Leviticus': 'lev', 'Numbers': 'num',
  'Deuteronomy': 'deu', 'Joshua': 'jos', 'Judges': 'jdg', 'Ruth': 'rut',
  '1 Samuel': '1sa', '2 Samuel': '2sa', '1 Kings': '1ki', '2 Kings': '2ki',
  '1 Chronicles': '1ch', '2 Chronicles': '2ch', 'Ezra': 'ezr', 'Nehemiah': 'neh',
  'Esther': 'est', 'Job': 'job', 'Psalms': 'psa', 'Psalm': 'psa', 'Proverbs': 'pro',
  'Ecclesiastes': 'ecc', 'Song of Solomon': 'sng', 'Isaiah': 'isa',
  'Jeremiah': 'jer', 'Lamentations': 'lam', 'Ezekiel': 'ezk', 'Daniel': 'dan',
  'Hosea': 'hos', 'Joel': 'jol', 'Amos': 'amo', 'Obadiah': 'oba',
  'Jonah': 'jon', 'Micah': 'mic', 'Nahum': 'nam', 'Habakkuk': 'hab',
  'Zephaniah': 'zep', 'Haggai': 'hag', 'Zechariah': 'zec', 'Malachi': 'mal',
  'Matthew': 'mat', 'Mark': 'mrk', 'Luke': 'luk', 'John': 'jhn',
  'Acts': 'act', 'Romans': 'rom', '1 Corinthians': '1co', '2 Corinthians': '2co',
  'Galatians': 'gal', 'Ephesians': 'eph', 'Philippians': 'php', 'Colossians': 'col',
  '1 Thessalonians': '1th', '2 Thessalonians': '2th', '1 Timothy': '1ti',
  '2 Timothy': '2ti', 'Titus': 'tit', 'Philemon': 'phm', 'Hebrews': 'heb',
  'James': 'jas', '1 Peter': '1pe', '2 Peter': '2pe', '1 John': '1jn',
  '2 John': '2jn', '3 John': '3jn', 'Jude': 'jud', 'Revelation': 'rev',
};

/// Reverse map: bookId → display name
const Map<String, String> kBookNames = {
  'gen': 'Genesis', 'exo': 'Exodus', 'lev': 'Leviticus', 'num': 'Numbers',
  'deu': 'Deuteronomy', 'jos': 'Joshua', 'jdg': 'Judges', 'rut': 'Ruth',
  '1sa': '1 Samuel', '2sa': '2 Samuel', '1ki': '1 Kings', '2ki': '2 Kings',
  '1ch': '1 Chronicles', '2ch': '2 Chronicles', 'ezr': 'Ezra', 'neh': 'Nehemiah',
  'est': 'Esther', 'job': 'Job', 'psa': 'Psalms', 'pro': 'Proverbs',
  'ecc': 'Ecclesiastes', 'sng': 'Song of Solomon', 'isa': 'Isaiah',
  'jer': 'Jeremiah', 'lam': 'Lamentations', 'ezk': 'Ezekiel', 'dan': 'Daniel',
  'hos': 'Hosea', 'jol': 'Joel', 'amo': 'Amos', 'oba': 'Obadiah',
  'jon': 'Jonah', 'mic': 'Micah', 'nam': 'Nahum', 'hab': 'Habakkuk',
  'zep': 'Zephaniah', 'hag': 'Haggai', 'zec': 'Zechariah', 'mal': 'Malachi',
  'mat': 'Matthew', 'mrk': 'Mark', 'luk': 'Luke', 'jhn': 'John',
  'act': 'Acts', 'rom': 'Romans', '1co': '1 Corinthians', '2co': '2 Corinthians',
  'gal': 'Galatians', 'eph': 'Ephesians', 'php': 'Philippians', 'col': 'Colossians',
  '1th': '1 Thessalonians', '2th': '2 Thessalonians', '1ti': '1 Timothy',
  '2ti': '2 Timothy', 'tit': 'Titus', 'phm': 'Philemon', 'heb': 'Hebrews',
  'jas': 'James', '1pe': '1 Peter', '2pe': '2 Peter', '1jn': '1 John',
  '2jn': '2 John', '3jn': '3 John', 'jud': 'Jude', 'rev': 'Revelation',
};

/// Supported Bible versions in Firestore
const List<String> kSupportedVersions = ['kjv', 'niv', 'csb', 'asv'];

const Map<String, String> kVersionLabels = {
  'kjv': 'KJV',
  'niv': 'NIV',
  'csb': 'CSB',
  'asv': 'ASV',
};
