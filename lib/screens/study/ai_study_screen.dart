import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/bible_constants.dart';
import '../../core/providers/subscription_provider.dart';
import '../../core/services/ai_study_service.dart';
import '../../core/services/badge_service.dart';
import '../../core/services/streak_service.dart';
import '../../core/services/bible_service.dart';
import '../../models/user_profile.dart';
import '../home/home_screen.dart' show userProfileProvider;
import '../paywall/compare_screen.dart';
import '../paywall/paywall_screen.dart';

// ── Study method meta ─────────────────────────────────────────────────────────

class _MethodMeta {
  final StudyMethod method;
  final String label;        // Friendly display name
  final String methodTag;    // Technical method name (shown small)
  final String subtitle;     // Plain-English description
  final String timeEstimate;
  final IconData icon;
  final Color accentColor;
  final bool recommended;
  const _MethodMeta({
    required this.method,
    required this.label,
    required this.methodTag,
    required this.subtitle,
    required this.timeEstimate,
    required this.icon,
    required this.accentColor,
    this.recommended = false,
  });
}

const _methods = [
  _MethodMeta(
    method: StudyMethod.soap,
    label: 'Read & Reflect',
    methodTag: 'SOAP',
    subtitle: 'A guided four-step journey: from the text to your life.',
    timeEstimate: '~10 min',
    icon: Icons.edit_note_outlined,
    accentColor: Color(0xFFE8B84B),
    recommended: true,
  ),
  _MethodMeta(
    method: StudyMethod.inductive,
    label: 'Discover',
    methodTag: 'Inductive',
    subtitle: 'Ask what the passage says, what it means, and what it changes.',
    timeEstimate: '~15 min',
    icon: Icons.explore_outlined,
    accentColor: Color(0xFF5B8AF5),
  ),
  _MethodMeta(
    method: StudyMethod.swedish,
    label: 'Mark It',
    methodTag: 'Swedish Method',
    subtitle: 'Circle what hits you, flag what confuses you, highlight gold for others.',
    timeEstimate: '~5 min',
    icon: Icons.draw_outlined,
    accentColor: Color(0xFF4CAF50),
  ),
  _MethodMeta(
    method: StudyMethod.lectioDivina,
    label: 'Slow Down',
    methodTag: 'Lectio Divina',
    subtitle: 'Read it slowly. Sit with it. Let it become a prayer.',
    timeEstimate: '~15 min',
    icon: Icons.self_improvement_outlined,
    accentColor: Color(0xFF9C6FE0),
  ),
  _MethodMeta(
    method: StudyMethod.wordStudy,
    label: 'Word Study',
    methodTag: 'Greek · Hebrew',
    subtitle: 'Unpack the original Greek or Hebrew meaning behind key words.',
    timeEstimate: '~10 min',
    icon: Icons.translate_outlined,
    accentColor: Color(0xFF26A69A),
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────

enum _StudyView { setup, loading, study }

class AiStudyScreen extends ConsumerStatefulWidget {
  final String? initialBook;
  final int? initialChapter;
  const AiStudyScreen({super.key, this.initialBook, this.initialChapter});

  @override
  ConsumerState<AiStudyScreen> createState() => _AiStudyScreenState();
}

class _AiStudyScreenState extends ConsumerState<AiStudyScreen> {
  final _service  = AiStudyService();
  final _bible    = BibleService();

  _StudyView _view = _StudyView.setup;

  // Setup state
  String _bookId  = 'jhn';
  int    _chapter = 3;
  StudyMethod _method = StudyMethod.soap;

  // Study state
  AiStudyResult? _result;
  String? _error;
  bool _saved = false;
  bool _linguisticEnabled = true; // read from SharedPreferences

  // Chat state
  final List<ChatMessage> _chat = [];
  final _chatController = TextEditingController();
  bool _chatLoading = false;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadLastPosition();
    _loadLinguisticPref();
  }

  Future<void> _loadLinguisticPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final enabled = prefs.getBool('linguisticTooltips') ?? true;
    setState(() {
      _linguisticEnabled = enabled;
      // If word study was selected but is now hidden, reset to SOAP
      if (!enabled && _method == StudyMethod.wordStudy) {
        _method = StudyMethod.soap;
      }
    });
  }

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLastPosition() async {
    if (widget.initialBook != null) {
      setState(() {
        _bookId  = widget.initialBook!;
        _chapter = widget.initialChapter ?? 1;
      });
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _bookId  = prefs.getString('reader_last_book')  ?? 'jhn';
      _chapter = prefs.getInt('reader_last_chapter')  ?? 3;
    });
  }

  String get _bookName => kBookNames[_bookId] ?? _bookId;

  _MethodMeta get _currentMethodMeta =>
      _methods.firstWhere((m) => m.method == _method,
          orElse: () => _methods.first);

  Future<void> _startStudy() async {
    if (!ref.read(isProProvider)) {
      await showCompareScreen(context);
      return;
    }
    setState(() { _view = _StudyView.loading; _error = null; });

    try {
      // Check cache first
      final cached = await _service.getCachedStudy(_bookId, _chapter, _method.name);
      if (cached != null) {
        setState(() { _result = cached; _view = _StudyView.study; });
        return;
      }

      // Load passage text for context (cap at 3000 chars to avoid function timeout)
      final verses = await _bible.getChapter(
        version: 'niv',
        bookId: _bookId,
        chapter: _chapter,
      );
      final fullText = verses
          .map((v) => '${v.verseNumber} ${v.text}')
          .join('\n');
      final passageText = fullText.length > 3000
          ? '${fullText.substring(0, 3000)}...'
          : fullText;

      final result = await _service.generateStudy(
        bookId:      _bookId,
        bookName:    _bookName,
        chapter:     _chapter,
        version:     'niv',
        method:      _method.name,
        passageText: passageText,
      );

      if (mounted) setState(() { _result = result; _view = _StudyView.study; });

      // Award badges for completing a study (fire-and-forget)
      BadgeService().onStudyCompleted(method: _method.name, bookId: _bookId);
      StreakService().recordStudy(); // fire-and-forget

    } catch (e) {
      debugPrint('AI Study error: $e');
      if (mounted) setState(() {
        _error = 'Error: $e';
        _view = _StudyView.setup;
      });
    }
  }

  Future<void> _sendQuestion() async {
    final q = _chatController.text.trim();
    if (q.isEmpty || _chatLoading || _result == null) return;
    _chatController.clear();

    setState(() {
      _chat.add(ChatMessage(text: q, isUser: true, timestamp: DateTime.now()));
      _chatLoading = true;
    });
    _scrollToBottom();

    try {
      final answer = await _service.askQuestion(
        question:    q,
        passageText: _result!.overview, // send overview as context
        passage:     _result!.passage,
        history:     _chat,
      );
      if (mounted) {
        setState(() {
          _chat.add(ChatMessage(text: answer, isUser: false, timestamp: DateTime.now()));
          _chatLoading = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() {
        _chat.add(ChatMessage(
          text: 'Sorry, I couldn\'t answer that. Please try again.',
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _chatLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _saveToNotes() async {
    if (_result == null || _saved) return;
    await _service.saveToNotes(_result!);
    if (mounted) {
      setState(() => _saved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Study saved to Notes')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_view) {
      _StudyView.setup   => _buildSetup(),
      _StudyView.loading => _buildLoading(),
      _StudyView.study   => _buildStudy(),
    };
  }

  // ── Setup Screen ─────────────────────────────────────────────────────────────

  Widget _buildSetup() {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'AI Study',
          style: TextStyle(
            fontFamily: 'Lora',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.label(context),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Text(_error!,
                style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.error)),
            ),
            const SizedBox(height: 20),
          ],

          // ── Passage ─────────────────────────────────────────────────────────
          _SectionLabel(label: 'PASSAGE'),
          const SizedBox(height: 12),
          _PassagePicker(
            bookId: _bookId,
            chapter: _chapter,
            onChanged: (b, c) => setState(() { _bookId = b; _chapter = c; }),
          ),

          const SizedBox(height: 32),

          // ── Study Method ─────────────────────────────────────────────────────
          _SectionLabel(label: 'HOW DO YOU WANT TO STUDY?'),
          const SizedBox(height: 12),
          ..._methods
            .where((m) => m.method != StudyMethod.wordStudy || _linguisticEnabled)
            .map((m) => _MethodCard(
              meta: m,
              isSelected: _method == m.method,
              onTap: () => setState(() => _method = m.method),
            )),

          const SizedBox(height: 32),

          // ── Begin button ─────────────────────────────────────────────────────
          GestureDetector(
            onTap: _startStudy,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  'Begin Study — $_bookName $_chapter',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.black,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Loading Screen ────────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _PulsingFlame(),
            const SizedBox(height: 28),
            Text(
              'Studying $_bookName $_chapter',
              style: TextStyle(
                fontFamily: 'Lora',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.label(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Using ${_currentMethodMeta.label}…',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.sublabel(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Study Screen ──────────────────────────────────────────────────────────────

  Widget _buildStudy() {
    final r = _result!;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.label(context)),
          onPressed: () => setState(() {
            _view = _StudyView.setup;
            _chat.clear();
            _saved = false;
          }),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r.passage,
              style: TextStyle(
                fontFamily: 'Lora',
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.label(context),
              ),
            ),
            Text(
              _currentMethodMeta.methodTag,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: _currentMethodMeta.accentColor,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _saved ? Icons.bookmark : Icons.bookmark_outline,
              color: _saved ? AppColors.gold : AppColors.sublabel(context),
            ),
            onPressed: _saveToNotes,
            tooltip: 'Save to Notes',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Scrollable study content + chat ────────────────────────────────
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              children: [
                // Overview
                _StudySection(
                  icon: Icons.auto_stories_outlined,
                  title: 'Overview',
                  child: Text(
                    r.overview,
                    style: TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 15,
                      color: AppColors.label(context),
                      height: 1.7,
                    ),
                  ),
                ),

                // Observations (relabeled for word study)
                if (r.observations.isNotEmpty)
                  _StudySection(
                    icon: r.method == 'wordStudy' ? Icons.translate_outlined : Icons.visibility_outlined,
                    title: r.method == 'wordStudy' ? 'Key Words' : 'Key Observations',
                    child: Column(
                      children: r.observations.asMap().entries.map((e) =>
                        _BulletPoint(number: e.key + 1, text: e.value),
                      ).toList(),
                    ),
                  ),

                // Interpretation (relabeled for word study)
                _StudySection(
                  icon: r.method == 'wordStudy' ? Icons.history_edu_outlined : Icons.lightbulb_outlined,
                  title: r.method == 'wordStudy' ? 'Original Meaning' : 'Interpretation',
                  child: Text(
                    r.interpretation,
                    style: TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 15,
                      color: AppColors.label(context),
                      height: 1.7,
                    ),
                  ),
                ),

                // Application
                if (r.applicationPoints.isNotEmpty)
                  _StudySection(
                    icon: Icons.directions_walk_outlined,
                    title: 'Application',
                    child: Column(
                      children: r.applicationPoints.asMap().entries.map((e) =>
                        _BulletPoint(number: e.key + 1, text: e.value),
                      ).toList(),
                    ),
                  ),

                // Reflection Questions
                if (r.reflectionQuestions.isNotEmpty)
                  _StudySection(
                    icon: Icons.help_outline,
                    title: 'Reflection Questions',
                    child: Column(
                      children: r.reflectionQuestions.asMap().entries.map((e) =>
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                margin: const EdgeInsets.only(right: 10, top: 1),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.gold, width: 1.5),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${e.key + 1}',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.gold,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  e.value,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    color: AppColors.label(context),
                                    height: 1.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).toList(),
                    ),
                  ),

                // Prayer Prompt
                if (r.prayerPrompt.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 8),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.volunteer_activism, size: 14, color: AppColors.gold),
                            const SizedBox(width: 6),
                            Text(
                              'PRAYER',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.gold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          r.prayerPrompt,
                          style: TextStyle(
                            fontFamily: 'Lora',
                            fontSize: 15,
                            color: AppColors.label(context),
                            height: 1.7,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Chat messages ──────────────────────────────────────────────
                if (_chat.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Divider(color: AppColors.divider(context)),
                  const SizedBox(height: 12),
                  const _SectionLabel(label: 'QUESTIONS'),
                  const SizedBox(height: 12),
                  ..._chat.map((m) => _ChatBubble(message: m)),
                ],

                if (_chatLoading)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        _TypingDots(),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),
              ],
            ),
          ),

          // ── Question input bar ─────────────────────────────────────────────
          _QuestionInput(
            controller: _chatController,
            loading: _chatLoading,
            onSend: _sendQuestion,
          ),
        ],
      ),
    );
  }
}

// ── Setup sub-widgets ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(
      fontFamily: 'Inter',
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: AppColors.textDim,
      letterSpacing: 1.4,
    ),
  );
}

// OT / NT book lists in canonical order
const _oldTestamentIds = [
  'gen','exo','lev','num','deu','jos','jdg','rut','1sa','2sa','1ki','2ki',
  '1ch','2ch','ezr','neh','est','job','psa','pro','ecc','sng','isa','jer',
  'lam','ezk','dan','hos','jol','amo','oba','jon','mic','nam','hab','zep',
  'hag','zec','mal',
];
const _newTestamentIds = [
  'mat','mrk','luk','jhn','act','rom','1co','2co','gal','eph','php','col',
  '1th','2th','1ti','2ti','tit','phm','heb','jas','1pe','2pe','1jn','2jn',
  '3jn','jud','rev',
];

class _PassagePicker extends StatelessWidget {
  final String bookId;
  final int chapter;
  final void Function(String bookId, int chapter) onChanged;
  const _PassagePicker({required this.bookId, required this.chapter, required this.onChanged});

  void _openPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _BookChapterSheet(
        bookId: bookId,
        chapter: chapter,
        onSelected: (b, c) {
          Navigator.pop(context);
          onChanged(b, c);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookName = kBookNames[bookId] ?? bookId;
    return GestureDetector(
      onTap: () => _openPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBg(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider(context)),
        ),
        child: Row(
          children: [
            Icon(Icons.menu_book_outlined, color: AppColors.gold, size: 18),
            const SizedBox(width: 12),
            Text(
              '$bookName $chapter',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.label(context),
              ),
            ),
            const Spacer(),
            Text(
              'Change',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: AppColors.gold,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookChapterSheet extends StatefulWidget {
  final String bookId;
  final int chapter;
  final void Function(String bookId, int chapter) onSelected;
  const _BookChapterSheet({required this.bookId, required this.chapter, required this.onSelected});

  @override
  State<_BookChapterSheet> createState() => _BookChapterSheetState();
}

class _BookChapterSheetState extends State<_BookChapterSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late String _selectedBook;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedBook = widget.bookId;
    final isNT = _newTestamentIds.contains(widget.bookId);
    _tabs = TabController(length: 2, vsync: this, initialIndex: isNT ? 1 : 0);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<String> _filtered(List<String> ids) {
    if (_search.isEmpty) return ids;
    return ids.where((id) {
      final name = kBookNames[id] ?? id;
      return name.toLowerCase().contains(_search.toLowerCase());
    }).toList();
  }

  Widget _buildBookList(List<String> ids) {
    final filtered = _filtered(ids);
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('No books found', style: TextStyle(color: AppColors.sublabel(context))),
        ),
      );
    }
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final id = filtered[i];
        final name = kBookNames[id] ?? id;
        final isSel = id == _selectedBook;
        return Material(
          color: Colors.transparent,
          child: ListTile(
          dense: true,
          title: Text(
            name,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: isSel ? FontWeight.w700 : FontWeight.w400,
              color: isSel ? AppColors.gold : AppColors.label(context),
            ),
          ),
          trailing: isSel
              ? Icon(Icons.check, color: AppColors.gold, size: 18)
              : Text(
                  '${kChapterCounts[id] ?? 1} ch',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.textDim,
                  ),
                ),
          onTap: () {
            final chapters = kChapterCounts[id] ?? 1;
            if (chapters == 1) {
              // Single-chapter books: select immediately
              widget.onSelected(id, 1);
            } else {
              setState(() => _selectedBook = id);
            }
          },
        ));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final chapters = kChapterCounts[_selectedBook] ?? 1;
    final bookName = kBookNames[_selectedBook] ?? _selectedBook;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(
              children: [
                Text(
                  'Choose Passage',
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.label(context),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close, color: AppColors.sublabel(context), size: 20),
                ),
              ],
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v),
              style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.label(context)),
              decoration: InputDecoration(
                hintText: 'Search books…',
                hintStyle: TextStyle(color: AppColors.textDim, fontFamily: 'Inter', fontSize: 14),
                prefixIcon: Icon(Icons.search, color: AppColors.textDim, size: 18),
                filled: true,
                fillColor: AppColors.cardElevated(context),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // OT / NT tabs
          TabBar(
            controller: _tabs,
            labelColor: AppColors.gold,
            unselectedLabelColor: AppColors.sublabel(context),
            indicatorColor: AppColors.gold,
            labelStyle: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600),
            tabs: const [Tab(text: 'Old Testament'), Tab(text: 'New Testament')],
          ),
          // Book list
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _buildBookList(_oldTestamentIds),
                _buildBookList(_newTestamentIds),
              ],
            ),
          ),
          // Chapter picker (only shown when book has >1 chapter)
          if (chapters > 1) ...[
            Divider(color: AppColors.divider(context), height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Text(
                    '$bookName — Chapter',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.label(context),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 56,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                itemCount: chapters,
                itemBuilder: (_, i) {
                  final ch = i + 1;
                  final isSel = ch == widget.chapter && _selectedBook == widget.bookId;
                  return GestureDetector(
                    onTap: () => widget.onSelected(_selectedBook, ch),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSel ? AppColors.gold : AppColors.cardElevated(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '$ch',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSel ? AppColors.black : AppColors.sublabel(context),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

// kChapterCounts duplicated from reader — move to bible_constants in a future cleanup
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

class _MethodCard extends StatelessWidget {
  final _MethodMeta meta;
  final bool isSelected;
  final VoidCallback onTap;
  const _MethodCard({required this.meta, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = meta.accentColor;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isSelected ? accent.withOpacity(0.07) : AppColors.cardBg(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? accent.withOpacity(0.55) : AppColors.divider(context),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Accent bar
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 4,
              height: 72,
              decoration: BoxDecoration(
                color: isSelected ? accent : Colors.transparent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Icon
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected ? accent.withOpacity(0.15) : AppColors.cardElevated(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(meta.icon,
                color: isSelected ? accent : AppColors.sublabel(context),
                size: 19),
            ),
            const SizedBox(width: 12),
            // Labels
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          meta.label,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? accent : AppColors.label(context),
                          ),
                        ),
                        if (meta.recommended) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'GREAT START',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: accent,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      meta.subtitle,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.sublabel(context),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text(
                          meta.methodTag,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            color: AppColors.textDim,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppColors.textDim,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          meta.timeEstimate,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            color: AppColors.textDim,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Check
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Icon(Icons.check_circle, color: accent, size: 18),
              )
            else
              const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }
}

// ── Study sub-widgets ─────────────────────────────────────────────────────────

class _StudySection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _StudySection({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.gold),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final int number;
  final String text;
  const _BulletPoint({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 8, right: 10),
            decoration: BoxDecoration(
              color: AppColors.gold,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.label(context),
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? AppColors.gold : AppColors.cardBg(context),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser ? null : Border.all(color: AppColors.divider(context)),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            fontFamily: isUser ? 'Inter' : 'Lora',
            fontSize: 14,
            color: isUser ? AppColors.black : AppColors.label(context),
            height: 1.55,
            fontWeight: isUser ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _QuestionInput extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSend;
  const _QuestionInput({required this.controller, required this.loading, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16, 12, 16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        border: Border(top: BorderSide(color: AppColors.divider(context))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.label(context),
              ),
              decoration: InputDecoration(
                hintText: 'Ask a question about this passage…',
                hintStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppColors.textDim,
                ),
                filled: true,
                fillColor: AppColors.cardElevated(context),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: loading ? null : onSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: loading ? AppColors.textDim : AppColors.gold,
                shape: BoxShape.circle,
              ),
              child: loading
                  ? Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.label(context),
                      ),
                    )
                  : Icon(Icons.send, color: AppColors.black, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Loading animation ─────────────────────────────────────────────────────────

class _PulsingFlame extends StatefulWidget {
  const _PulsingFlame();

  @override
  State<_PulsingFlame> createState() => _PulsingFlameState();
}

class _PulsingFlameState extends State<_PulsingFlame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.gold.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.auto_awesome, color: AppColors.gold, size: 36),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider(context)),
      ),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final opacity = ((_ctrl.value * 3 - i).clamp(0, 1) +
                           (1 - (_ctrl.value * 3 - i - 1).clamp(0, 1))) / 2;
            return Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(opacity.clamp(0.2, 1.0)),
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
      ),
    );
  }
}
