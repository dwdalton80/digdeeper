import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/bible_constants.dart';
import '../../core/services/bible_service.dart';
import '../../core/services/badge_service.dart';
import '../../core/services/typography_service.dart';

// ── Chapter counts ────────────────────────────────────────────────────────────

const Map<String, int> kChapterCounts = {
  'gen':50,'exo':40,'lev':27,'num':36,'deu':34,'jos':24,'jdg':21,'rut':4,
  '1sa':31,'2sa':24,'1ki':22,'2ki':25,'1ch':29,'2ch':36,'ezr':10,'neh':13,
  'est':10,'job':42,'psa':150,'pro':31,'ecc':12,'sng':8,'isa':66,'jer':52,
  'lam':5,'ezk':48,'dan':12,'hos':14,'jol':3,'amo':9,'oba':1,'jon':4,
  'mic':7,'nam':3,'hab':3,'zep':3,'hag':2,'zec':14,'mal':4,
  'mat':28,'mrk':16,'luk':24,'jhn':21,'act':28,'rom':16,'1co':16,'2co':13,
  'gal':6,'eph':6,'php':4,'col':4,'1th':5,'2th':3,'1ti':6,'2ti':4,
  'tit':3,'phm':1,'heb':13,'jas':5,'1pe':5,'2pe':3,'1jn':5,'2jn':1,
  '3jn':1,'jud':1,'rev':22,
};

// Old vs New Testament book IDs
final _oldTestament = [
  'gen','exo','lev','num','deu','jos','jdg','rut','1sa','2sa','1ki','2ki',
  '1ch','2ch','ezr','neh','est','job','psa','pro','ecc','sng','isa','jer',
  'lam','ezk','dan','hos','jol','amo','oba','jon','mic','nam','hab','zep',
  'hag','zec','mal',
];
final _newTestament = [
  'mat','mrk','luk','jhn','act','rom','1co','2co','gal','eph','php','col',
  '1th','2th','1ti','2ti','tit','phm','heb','jas','1pe','2pe','1jn','2jn',
  '3jn','jud','rev',
];

// ── View state ────────────────────────────────────────────────────────────────

enum _View { explorer, chapterPicker, reading }

// ── Screen ────────────────────────────────────────────────────────────────────

class ReaderScreen extends StatefulWidget {
  final String? initialBook;
  final int? initialChapter;
  final String? initialVersion;

  const ReaderScreen({
    super.key,
    this.initialBook,
    this.initialChapter,
    this.initialVersion,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  _View _view = _View.explorer;
  String _version = 'kjv';
  String _bookId = 'jhn';
  int _chapter = 3;
  bool _showOT = true; // true = Old Testament filter, false = NT
  String _search = '';
  final _searchCtrl = TextEditingController();
  final _bibleService = BibleService();

  @override
  void initState() {
    super.initState();
    _version = widget.initialVersion ?? 'kjv';
    if (widget.initialBook != null) {
      _bookId  = widget.initialBook!;
      _chapter = widget.initialChapter ?? 1;
      _view    = _View.reading;
    } else {
      _restorePosition();
    }
    _searchCtrl.addListener(() => setState(() => _search = _searchCtrl.text.toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _restorePosition() async {
    final prefs = await SharedPreferences.getInstance();
    final book  = prefs.getString('reader_last_book');
    final ch    = prefs.getInt('reader_last_chapter');
    if (book != null && mounted) {
      setState(() {
        _bookId  = book;
        _chapter = ch ?? 1;
      });
    }
  }

  Future<void> _savePosition() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reader_last_book', _bookId);
    await prefs.setInt('reader_last_chapter', _chapter);
  }

  void _openBook(String bookId) {
    setState(() {
      _bookId = bookId;
      _view   = _View.chapterPicker;
    });
  }

  void _openChapter(int ch) {
    setState(() {
      _chapter = ch;
      _view    = _View.reading;
    });
    _savePosition();
  }

  void _back() {
    setState(() {
      _view = _view == _View.reading ? _View.chapterPicker : _View.explorer;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: switch (_view) {
              _View.explorer      => _ExplorerView(
                  key: const ValueKey('explorer'),
                  searchCtrl: _searchCtrl,
                  search: _search,
                  showOT: _showOT,
                  onToggleOT: (v) => setState(() => _showOT = v),
                  onBookTap: _openBook,
                  currentBookId: _bookId,
                  currentChapter: _chapter,
                  onResume: () => setState(() => _view = _View.reading),
                ),
              _View.chapterPicker => _ChapterPickerView(
                  key: const ValueKey('chapters'),
                  bookId: _bookId,
                  currentChapter: _chapter,
                  onBack: _back,
                  onChapterTap: _openChapter,
                  onResume: () => setState(() => _view = _View.reading),
                ),
              _View.reading       => _ReadingView(
                  key: ValueKey('reading-$_bookId-$_chapter-$_version'),
                  bookId: _bookId,
                  chapter: _chapter,
                  version: _version,
                  bibleService: _bibleService,
                  onBack: _back,
                  onVersionChange: (v) => setState(() => _version = v),
                  onPrevChapter: _chapter > 1
                      ? () => _openChapter(_chapter - 1)
                      : null,
                  onNextChapter: _chapter < (kChapterCounts[_bookId] ?? 1)
                      ? () => _openChapter(_chapter + 1)
                      : null,
                ),
            },
          ),
        ),
      ),
    );
  }
}

// ── Explorer View ─────────────────────────────────────────────────────────────

class _ExplorerView extends StatelessWidget {
  final TextEditingController searchCtrl;
  final String search;
  final bool showOT;
  final ValueChanged<bool> onToggleOT;
  final ValueChanged<String> onBookTap;
  final String currentBookId;
  final int currentChapter;
  final VoidCallback onResume;

  const _ExplorerView({
    super.key,
    required this.searchCtrl,
    required this.search,
    required this.showOT,
    required this.onToggleOT,
    required this.onBookTap,
    required this.currentBookId,
    required this.currentChapter,
    required this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    final allBooks = showOT ? _oldTestament : _newTestament;
    final filtered = search.isEmpty
        ? allBooks
        : allBooks.where((id) {
            final name = kBookNames[id] ?? '';
            return name.toLowerCase().contains(search);
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bible Explorer',
                style: TextStyle(
                  fontFamily: 'Lora',
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.label(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Search and navigate the Word',
                style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.sublabel(context)),
              ),
              const SizedBox(height: 16),

              // Search bar
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.cardBg(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider(context)),
                ),
                child: TextField(
                  controller: searchCtrl,
                  style: TextStyle(color: AppColors.label(context), fontFamily: 'Inter', fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search books, verses, or topics...',
                    hintStyle: TextStyle(color: AppColors.textDim, fontFamily: 'Inter', fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: AppColors.sublabel(context), size: 18),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // OT / NT toggle pills
              Row(
                children: [
                  _FilterPill(
                    label: 'Old Testament',
                    selected: showOT,
                    onTap: () => onToggleOT(true),
                  ),
                  const SizedBox(width: 8),
                  _FilterPill(
                    label: 'New Testament',
                    selected: !showOT,
                    onTap: () => onToggleOT(false),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),

        // Resume reading banner
        if (currentBookId.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: GestureDetector(
              onTap: onResume,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.bookmark, color: AppColors.gold, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Continue Reading  •  ${kBookNames[currentBookId] ?? currentBookId} $currentChapter',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppColors.gold, size: 18),
                  ],
                ),
              ),
            ),
          ),

        // Book list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final id   = filtered[i];
              final name = kBookNames[id] ?? id;
              final abbr = id.length <= 3
                  ? id.substring(0, 2).toUpperCase()
                  : id.substring(0, 2).toUpperCase();
              final chapters = kChapterCounts[id] ?? 1;
              return _BookRow(
                abbr: abbr,
                name: name,
                chapters: chapters,
                onTap: () => onBookTap(id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterPill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold : AppColors.cardBg(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.gold : AppColors.divider(context)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.black : AppColors.sublabel(context),
          ),
        ),
      ),
    );
  }
}

class _BookRow extends StatelessWidget {
  final String abbr;
  final String name;
  final int chapters;
  final VoidCallback onTap;
  const _BookRow({required this.abbr, required this.name, required this.chapters, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.cardElevated(context),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                abbr,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(
                    fontFamily: 'Inter', fontSize: 15,
                    fontWeight: FontWeight.w600, color: AppColors.label(context),
                  )),
                  Text('$chapters Chapters', style: TextStyle(
                    fontFamily: 'Inter', fontSize: 12, color: AppColors.sublabel(context),
                  )),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textDim, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Chapter Picker View ───────────────────────────────────────────────────────

class _ChapterPickerView extends StatelessWidget {
  final String bookId;
  final int currentChapter;
  final VoidCallback onBack;
  final ValueChanged<int> onChapterTap;
  final VoidCallback onResume;
  const _ChapterPickerView({
    super.key,
    required this.bookId,
    required this.currentChapter,
    required this.onBack,
    required this.onChapterTap,
    required this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    final name     = kBookNames[bookId] ?? bookId;
    final chapters = kChapterCounts[bookId] ?? 1;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios, color: AppColors.label(context), size: 20),
                onPressed: onBack,
              ),
              Text(
                name,
                style: TextStyle(
                  fontFamily: 'Lora',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.label(context),
                ),
              ),
            ],
          ),
        ),
        // Resume banner (only when viewing same book)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: GestureDetector(
            onTap: onResume,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gold.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.bookmark, color: AppColors.gold, size: 15),
                  const SizedBox(width: 8),
                  Text(
                    'Return to Chapter $currentChapter',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gold,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: AppColors.gold, size: 16),
                ],
              ),
            ),
          ),
        ),

        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemCount: chapters,
            itemBuilder: (_, i) {
              final ch = i + 1;
              final isCurrent = ch == currentChapter;
              return GestureDetector(
                onTap: () => onChapterTap(ch),
                child: Container(
                  decoration: BoxDecoration(
                    color: isCurrent ? AppColors.gold : AppColors.cardBg(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isCurrent ? AppColors.gold : AppColors.divider(context),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$ch',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isCurrent ? AppColors.black : AppColors.label(context),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Reading View ──────────────────────────────────────────────────────────────

class _ReadingView extends StatefulWidget {
  final String bookId;
  final int chapter;
  final String version;
  final BibleService bibleService;
  final VoidCallback onBack;
  final ValueChanged<String> onVersionChange;
  final VoidCallback? onPrevChapter;
  final VoidCallback? onNextChapter;

  const _ReadingView({
    super.key,
    required this.bookId,
    required this.chapter,
    required this.version,
    required this.bibleService,
    required this.onBack,
    required this.onVersionChange,
    required this.onPrevChapter,
    required this.onNextChapter,
  });

  @override
  State<_ReadingView> createState() => _ReadingViewState();
}

// Highlight color definitions
const _highlightColors = {
  'yellow': Color(0xFFFFF176),
  'green':  Color(0xFFA5D6A7),
  'blue':   Color(0xFF90CAF9),
  'pink':   Color(0xFFF48FB1),
};

class _ReadingViewState extends State<_ReadingView> {
  List<BibleVerse>? _verses;
  bool _loading = true;
  String? _error;
  // verseKey → color name
  final Map<String, String> _highlights = {};
  // Multi-select state
  final Set<int> _selectedVerseNums = {};

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  String _verseKey(int verseNum) =>
      '${widget.bookId}_${widget.chapter}_$verseNum';

  @override
  void initState() {
    super.initState();
    _loadChapter();
    _loadHighlights();
  }

  Future<void> _loadChapter() async {
    setState(() { _loading = true; _error = null; });
    try {
      final verses = await widget.bibleService.getChapter(
        version: widget.version,
        bookId:  widget.bookId,
        chapter: widget.chapter,
      );
      if (mounted) setState(() { _verses = verses; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load chapter.'; _loading = false; });
    }
  }

  Future<void> _loadHighlights() async {
    if (_uid.isEmpty) return;
    final snap = await FirebaseFirestore.instance
        .collection('highlights')
        .doc(_uid)
        .collection('verses')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: '${widget.bookId}_${widget.chapter}_')
        .where(FieldPath.documentId, isLessThan: '${widget.bookId}_${widget.chapter}_z')
        .get();
    if (!mounted) return;
    final map = <String, String>{};
    for (final doc in snap.docs) {
      final color = doc.data()['color'] as String?;
      if (color != null) map[doc.id] = color;
    }
    setState(() => _highlights.addAll(map));
  }

  Future<void> _toggleHighlight(BibleVerse verse, String colorName) async {
    if (_uid.isEmpty) return;
    final key = _verseKey(verse.verseNumber);
    final ref = FirebaseFirestore.instance
        .collection('highlights').doc(_uid)
        .collection('verses').doc(key);

    if (_highlights[key] == colorName) {
      // Same color → clear
      await ref.delete();
      setState(() => _highlights.remove(key));
    } else {
      // Set new color
      await ref.set({
        'color': colorName,
        'bookId': widget.bookId,
        'chapter': widget.chapter,
        'verseNumber': verse.verseNumber,
        'reference': verse.reference,
        'text': verse.text,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      setState(() => _highlights[key] = colorName);
      BadgeService().onVerseHighlighted(); // fire-and-forget
    }
  }

  List<BibleVerse> get _selectedVerses =>
      (_verses ?? []).where((v) => _selectedVerseNums.contains(v.verseNumber)).toList();

  void _tapVerse(BibleVerse verse) {
    setState(() {
      if (_selectedVerseNums.contains(verse.verseNumber)) {
        _selectedVerseNums.remove(verse.verseNumber);
      } else {
        _selectedVerseNums.add(verse.verseNumber);
      }
    });
  }

  void _dismissPanel() => setState(() => _selectedVerseNums.clear());

  /// Returns the common highlight color if ALL selected verses share one, else null.
  String? get _commonHighlight {
    final sel = _selectedVerses;
    if (sel.isEmpty) return null;
    final first = _highlights[_verseKey(sel.first.verseNumber)];
    if (first == null) return null;
    return sel.every((v) => _highlights[_verseKey(v.verseNumber)] == first) ? first : null;
  }

  /// Applies or clears a highlight on ALL currently selected verses.
  Future<void> _highlightSelected(String colorName) async {
    final sel = _selectedVerses;
    // If all selected already have this color → clear; otherwise set
    final allMatch = sel.every((v) => _highlights[_verseKey(v.verseNumber)] == colorName);
    if (allMatch) {
      // Clear all
      for (final verse in sel) {
        final key = _verseKey(verse.verseNumber);
        await FirebaseFirestore.instance
            .collection('highlights').doc(_uid)
            .collection('verses').doc(key)
            .delete();
        if (mounted) setState(() => _highlights.remove(key));
      }
    } else {
      // Set color on all
      for (final verse in sel) {
        final key = _verseKey(verse.verseNumber);
        await FirebaseFirestore.instance
            .collection('highlights').doc(_uid)
            .collection('verses').doc(key)
            .set({
          'color': colorName,
          'bookId': widget.bookId,
          'chapter': widget.chapter,
          'verseNumber': verse.verseNumber,
          'reference': verse.reference,
          'text': verse.text,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (mounted) setState(() => _highlights[key] = colorName);
      }
      BadgeService().onVerseHighlighted(); // award "Marked" badge
    }
  }

  void _copySelected() {
    final sel = _selectedVerses;
    final text = sel.map((v) => '${v.verseNumber} ${v.text}').join('\n');
    final ref = sel.length == 1
        ? sel.first.reference
        : '${sel.first.reference}–${sel.last.verseNumber}';
    Clipboard.setData(ClipboardData(text: '"$text"\n— $ref'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${sel.length} verse${sel.length > 1 ? 's' : ''} copied'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareSelected() {
    final sel = _selectedVerses;
    final text = sel.map((v) => '${v.verseNumber} ${v.text}').join('\n');
    final ref = sel.length == 1
        ? sel.first.reference
        : '${sel.first.reference}–${sel.last.verseNumber}';
    Share.share('"$text"\n— $ref\n\nShared from Dig Deeper');
  }

  Future<void> _addSelectedToNotes() async {
    final sel = _selectedVerses;
    final text = sel.map((v) => v.text).join(' ');
    final ref = sel.length == 1
        ? sel.first.reference
        : '${sel.first.reference}–${sel.last.verseNumber}';

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance
          .collection('notes')
          .doc(uid)
          .collection('entries')
          .add({
        'title': ref,
        'content': '"$text"',
        'type': 'manual',
        'passage': ref,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    _dismissPanel();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$ref added to Notes'),
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'View',
            textColor: AppColors.gold,
            onPressed: () => context.go('/notes'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookName = kBookNames[widget.bookId] ?? widget.bookId;
    final versions = kSupportedVersions;

    return Column(
      children: [
        // ── Top bar ─────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.menu_book_outlined, color: AppColors.gold, size: 22),
                onPressed: widget.onBack,
                tooltip: 'Books',
              ),
              Expanded(
                child: GestureDetector(
                  onTap: widget.onBack,
                  child: Column(
                    children: [
                      Text(
                        '$bookName ${widget.chapter}',
                        style: TextStyle(
                          fontFamily: 'Lora',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.label(context),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            kVersionLabels[widget.version] ?? widget.version.toUpperCase(),
                            style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.sublabel(context)),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.expand_more, size: 14, color: AppColors.sublabel(context)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
        ),

        // ── Version tabs ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              ...versions.map((v) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => widget.onVersionChange(v),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: widget.version == v ? AppColors.gold : AppColors.cardBg(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: widget.version == v ? AppColors.gold : AppColors.divider(context),
                      ),
                    ),
                    child: Text(
                      v.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: widget.version == v ? AppColors.black : AppColors.sublabel(context),
                      ),
                    ),
                  ),
                ),
              )),
            ],
          ),
        ),

        const SizedBox(height: 4),
        Divider(color: AppColors.divider(context), height: 1),

        // ── Verse content + floating panel ───────────────────────────────────
        Expanded(
          child: Stack(
            children: [
              // Verse list
              _loading
                  ? Center(child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2))
                  : _error != null
                      ? Center(child: Text(_error!, style: TextStyle(color: AppColors.sublabel(context))))
                      : _verses == null || _verses!.isEmpty
                          ? Center(child: Text('No verses found.', style: TextStyle(color: AppColors.sublabel(context))))
                          : ListView.separated(
                              // Extra bottom padding when floating panel is visible
                              padding: EdgeInsets.fromLTRB(20, 16, 20, _selectedVerseNums.isNotEmpty ? 200 : 40),
                              itemCount: _verses!.length,
                              separatorBuilder: (_, __) => Divider(color: AppColors.divider(context), height: 24),
                              itemBuilder: (_, i) {
                                final v = _verses![i];
                                final key = _verseKey(v.verseNumber);
                                final hlColorName = _highlights[key];
                                final hlColor = hlColorName != null
                                    ? _highlightColors[hlColorName]
                                    : null;
                                final isSelected = _selectedVerseNums.contains(v.verseNumber);
                                return GestureDetector(
                                  onTap: () => _tapVerse(v),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.gold.withOpacity(0.08)
                                          : hlColor != null
                                              ? hlColor.withOpacity(0.18)
                                              : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: isSelected
                                          ? Border.all(color: AppColors.gold.withOpacity(0.4), width: 1)
                                          : null,
                                    ),
                                    padding: (hlColor != null || isSelected)
                                        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                                        : EdgeInsets.zero,
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: 28,
                                          child: Text(
                                            '${v.verseNumber}',
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: isSelected ? AppColors.gold : (hlColor ?? AppColors.gold),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: ListenableBuilder(
                                            listenable: TypographyService(),
                                            builder: (_, __) {
                                              final typo = TypographyService().prefs;
                                              return Text(
                                                v.text,
                                                style: TextStyle(
                                                  fontFamily: typo.fontFamily,
                                                  fontSize: typo.fontSize,
                                                  color: AppColors.label(context),
                                                  height: typo.lineHeight,
                                                  decoration: hlColor != null
                                                      ? TextDecoration.underline
                                                      : TextDecoration.none,
                                                  decorationColor: hlColor,
                                                  decorationThickness: 1.5,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),

              // ── Floating verse action panel ─────────────────────────────────
              if (_selectedVerseNums.isNotEmpty)
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: _FloatingVersePanel(
                    selectedVerses: _selectedVerses,
                    currentHighlight: _commonHighlight,
                    highlights: _highlights,
                    verseKey: _verseKey,
                    onHighlight: _highlightSelected,
                    onAddToNotes: _addSelectedToNotes,
                    onCopy: _copySelected,
                    onShare: _shareSelected,
                    onDismiss: _dismissPanel,
                  ),
                ),
            ],
          ),
        ),

        // ── Chapter nav ──────────────────────────────────────────────────────
        Container(
          color: AppColors.black,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: widget.onPrevChapter,
                child: Opacity(
                  opacity: widget.onPrevChapter != null ? 1 : 0.3,
                  child: Row(
                    children: [
                      Icon(Icons.chevron_left, color: AppColors.gold),
                      Text(
                        'Previous',
                        style: TextStyle(
                          fontFamily: 'Inter', fontSize: 14,
                          color: AppColors.gold, fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                'Chapter ${widget.chapter}',
                style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.sublabel(context)),
              ),
              GestureDetector(
                onTap: widget.onNextChapter,
                child: Opacity(
                  opacity: widget.onNextChapter != null ? 1 : 0.3,
                  child: Row(
                    children: [
                      Text(
                        'Next',
                        style: TextStyle(
                          fontFamily: 'Inter', fontSize: 14,
                          color: AppColors.gold, fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(Icons.chevron_right, color: AppColors.gold),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Floating Verse Panel (stays visible while scrolling) ─────────────────────

class _FloatingVersePanel extends StatelessWidget {
  final List<BibleVerse> selectedVerses;
  final String? currentHighlight;
  final Map<String, String> highlights;
  final String Function(int) verseKey;
  final void Function(String color) onHighlight;
  final VoidCallback onAddToNotes;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onDismiss;

  const _FloatingVersePanel({
    required this.selectedVerses,
    required this.currentHighlight,
    required this.highlights,
    required this.verseKey,
    required this.onHighlight,
    required this.onAddToNotes,
    required this.onCopy,
    required this.onShare,
    required this.onDismiss,
  });

  String get _headerLabel {
    if (selectedVerses.isEmpty) return '';
    if (selectedVerses.length == 1) return selectedVerses.first.reference;
    final first = selectedVerses.first;
    final last = selectedVerses.last;
    // Same reference book + chapter
    final parts = first.reference.split(':');
    final bookChapter = parts.first;
    return '$bookChapter:${first.verseNumber}–${last.verseNumber}  (${selectedVerses.length} verses)';
  }

  String get _previewText {
    if (selectedVerses.isEmpty) return '';
    if (selectedVerses.length == 1) return selectedVerses.first.text;
    return selectedVerses.map((v) => '${v.verseNumber} ${v.text}').join('  ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.divider(context))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: reference + close
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _headerLabel,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onDismiss,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.cardElevated(context),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, size: 16, color: AppColors.sublabel(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _previewText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Lora',
                  fontSize: 13,
                  color: AppColors.sublabel(context),
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),

              // Highlight colors + action icons on same row
              Row(
                children: [
                  // Color pickers
                  ..._highlightColors.entries.map((e) {
                    // allActive: every selected verse has this color
                    final allActive = selectedVerses.isNotEmpty &&
                        selectedVerses.every((v) => highlights[verseKey(v.verseNumber)] == e.key);
                    // someActive: at least one selected verse has this color
                    final someActive = selectedVerses.any((v) => highlights[verseKey(v.verseNumber)] == e.key);
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () => onHighlight(e.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: e.value,
                            shape: BoxShape.circle,
                            border: allActive
                                ? Border.all(color: AppColors.label(context), width: 2.5)
                                : someActive
                                    ? Border.all(color: AppColors.label(context).withOpacity(0.4), width: 2)
                                    : Border.all(color: Colors.transparent, width: 2.5),
                          ),
                          child: allActive
                              ? Icon(Icons.check, size: 14, color: Colors.black54)
                              : someActive
                                  ? Icon(Icons.remove, size: 12, color: Colors.black38)
                                  : null,
                        ),
                      ),
                    );
                  }),

                  const Spacer(),

                  // Action icon buttons
                  _PanelIconBtn(icon: Icons.edit_note_outlined, label: 'Notes', onTap: onAddToNotes),
                  const SizedBox(width: 12),
                  _PanelIconBtn(icon: Icons.copy_outlined,      label: 'Copy',  onTap: onCopy),
                  const SizedBox(width: 12),
                  _PanelIconBtn(icon: Icons.share_outlined,     label: 'Share', onTap: onShare),
                ],
              ),
              const SizedBox(height: 8),

              // Hint: tap to add/remove verses
              Text(
                'Tap verses to add or remove from selection',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: AppColors.textDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelIconBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PanelIconBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.gold, size: 22),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              color: AppColors.sublabel(context),
            ),
          ),
        ],
      ),
    );
  }
}

