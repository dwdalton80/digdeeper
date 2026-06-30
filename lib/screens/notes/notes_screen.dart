import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/constants/colors.dart';
import '../../core/services/badge_service.dart';

// ── Note model ────────────────────────────────────────────────────────────────

class NoteEntry {
  final String id;
  final String title;
  final String? content;
  final String type; // 'manual' | 'aiStudy' | 'sermon'
  final String? passage;
  final String? overview;
  final String? speaker;
  final DateTime? sermonDate;
  final List<String> applicationPoints;
  final List<String> reflectionQuestions;
  final String? prayerPrompt;
  final DateTime createdAt;

  NoteEntry({
    required this.id,
    required this.title,
    required this.type,
    this.content,
    this.passage,
    this.overview,
    this.speaker,
    this.sermonDate,
    required this.applicationPoints,
    required this.reflectionQuestions,
    this.prayerPrompt,
    required this.createdAt,
  });

  factory NoteEntry.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return NoteEntry(
      id: doc.id,
      title: d['title'] as String? ?? 'Untitled',
      content: d['content'] as String?,
      type: d['type'] as String? ?? 'manual',
      passage: d['passage'] as String?,
      overview: d['overview'] as String?,
      speaker: d['speaker'] as String?,
      sermonDate: (d['sermonDate'] as Timestamp?)?.toDate(),
      applicationPoints: List<String>.from(d['applicationPoints'] as List? ?? []),
      reflectionQuestions: List<String>.from(d['reflectionQuestions'] as List? ?? []),
      prayerPrompt: d['prayerPrompt'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  String get preview {
    if (type == 'aiStudy') return overview ?? content ?? '';
    return content ?? '';
  }
}

// ── Main screen ───────────────────────────────────────────────────────────────

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _filter = 'All'; // 'All' | 'Personal' | 'Sermon' | 'Study'
  final Set<String> _deletedIds = {}; // locally-deleted IDs to suppress stream re-insertion

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Stream<List<NoteEntry>> get _allNotesStream {
    if (_uid == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('notes')
        .doc(_uid)
        .collection('entries')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(NoteEntry.fromDoc).toList());
  }

  List<NoteEntry> _applyFilter(List<NoteEntry> notes) {
    return notes.where((n) {
      final matchFilter = _filter == 'All'
          || (_filter == 'Personal' && n.type != 'sermon' && n.type != 'aiStudy')
          || (_filter == 'Sermon'   && n.type == 'sermon')
          || (_filter == 'Study'    && n.type == 'aiStudy');
      final matchSearch = _search.isEmpty
          || n.title.toLowerCase().contains(_search.toLowerCase())
          || n.preview.toLowerCase().contains(_search.toLowerCase())
          || (n.passage?.toLowerCase().contains(_search.toLowerCase()) ?? false)
          || (n.speaker?.toLowerCase().contains(_search.toLowerCase()) ?? false);
      return matchFilter && matchSearch;
    }).toList();
  }

  Future<void> _deleteNote(String id) async {
    if (_uid == null) return;
    // Suppress the item immediately so the stream can't re-insert it
    // before Firestore propagates the delete.
    setState(() => _deletedIds.add(id));
    await FirebaseFirestore.instance
        .collection('notes').doc(_uid).collection('entries').doc(id).delete();
  }

  void _openNote(NoteEntry note) => showModalBottomSheet(
    context: context, isScrollControlled: true,
    backgroundColor: AppColors.cardDark,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _NoteDetailSheet(note: note, onDelete: () => _deleteNote(note.id)),
  );

  void _openNewNote() => showModalBottomSheet(
    context: context, isScrollControlled: true,
    backgroundColor: AppColors.cardDark,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _NewNoteSheet(uid: _uid),
  );

  void _openNewSermonNote() => showModalBottomSheet(
    context: context, isScrollControlled: true,
    backgroundColor: AppColors.cardDark,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _NewSermonNoteSheet(uid: _uid),
  );

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(margin: const EdgeInsets.only(top: 10, bottom: 8), width: 36, height: 4,
            decoration: BoxDecoration(color: AppColors.divider(context), borderRadius: BorderRadius.circular(2))),
          Material(color: Colors.transparent, child: ListTile(
            leading: Icon(Icons.edit_note_outlined, color: AppColors.gold),
            title: Text('Personal Note', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: AppColors.label(context))),
            subtitle: Text('Thoughts, highlights, reflections', style: TextStyle(fontFamily: 'Inter', color: AppColors.sublabel(context), fontSize: 12)),
            onTap: () { Navigator.pop(context); _openNewNote(); },
          )),
          Material(color: Colors.transparent, child: ListTile(
            leading: Icon(Icons.church_outlined, color: AppColors.gold),
            title: Text('Sermon Note', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: AppColors.label(context))),
            subtitle: Text('Date, speaker, scripture, notes', style: TextStyle(fontFamily: 'Inter', color: AppColors.sublabel(context), fontSize: 12)),
            onTap: () { Navigator.pop(context); _openNewSermonNote(); },
          )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ── AI Insights ─────────────────────────────────────────────────────────────

  Future<void> _showAiInsights(List<NoteEntry> notes) async {
    if (notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add some notes first to get insights.')));
      return;
    }

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AiInsightsSheet(notes: notes),
    );
  }

  // ── Bookmarks ────────────────────────────────────────────────────────────────

  void _showBookmarks() {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _BookmarksSheet(uid: _uid),
    );
  }

  // ── Export ───────────────────────────────────────────────────────────────────

  Future<void> _exportNotes(List<NoteEntry> notes) async {
    if (notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No notes to export.')));
      return;
    }

    final doc = pw.Document();
    final dateFormat = DateFormat('MMMM d, yyyy');

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (context) {
        final widgets = <pw.Widget>[
          pw.Text('My Notes', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
          pw.Text('Exported ${dateFormat.format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
          pw.SizedBox(height: 24),
        ];

        for (final note in notes) {
          widgets.add(pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 20),
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Expanded(
                  child: pw.Text(note.title,
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Text(dateFormat.format(note.createdAt),
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              ]),
              if (note.passage != null) ...[
                pw.SizedBox(height: 4),
                pw.Text(note.passage!,
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.blueGrey700)),
              ],
              if (note.speaker != null) ...[
                pw.SizedBox(height: 2),
                pw.Text('Speaker: ${note.speaker}',
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
              ],
              if (note.content?.isNotEmpty == true) ...[
                pw.SizedBox(height: 8),
                pw.Text(note.content!,
                  style: const pw.TextStyle(fontSize: 12)),
              ],
              if (note.overview?.isNotEmpty == true) ...[
                pw.SizedBox(height: 8),
                pw.Text('Overview: ${note.overview!}',
                  style: const pw.TextStyle(fontSize: 12)),
              ],
              if (note.applicationPoints.isNotEmpty) ...[
                pw.SizedBox(height: 8),
                pw.Text('Application:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ...note.applicationPoints.map((p) => pw.Text('• $p',
                  style: const pw.TextStyle(fontSize: 11))),
              ],
            ]),
          ));
        }
        return widgets;
      },
    ));

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'dig-deeper-notes-${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<NoteEntry>>(
          stream: _allNotesStream,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: AppColors.gold));
            }
            final all = (snap.data ?? []).where((n) => !_deletedIds.contains(n.id)).toList();
            final filtered = _applyFilter(all);
            final now = DateTime.now();
            final thisMonth = all.where((n) =>
              n.createdAt.year == now.year && n.createdAt.month == now.month).length;

            return Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    // ── Header ───────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Row(children: [
                          Text('Notes',
                            style: TextStyle(fontFamily: 'Lora', fontSize: 26,
                              fontWeight: FontWeight.bold, color: AppColors.label(context))),
                          const Spacer(),
                          GestureDetector(
                            onTap: _showAddMenu,
                            child: Container(
                              width: 38, height: 38,
                              decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(10)),
                              child: Icon(Icons.add, color: AppColors.black, size: 22),
                            ),
                          ),
                        ]),
                      ),
                    ),

                    // ── Stats row ─────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Row(children: [
                          _StatCard(value: '$thisMonth', label: 'Notes this month'),
                          const SizedBox(width: 12),
                          _StatCard(value: '${all.length}', label: 'Total notes'),
                        ]),
                      ),
                    ),

                    // ── Action buttons ────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _ActionBtn(icon: Icons.add_circle_outline,    label: 'New Note',    onTap: _showAddMenu),
                            _ActionBtn(icon: Icons.auto_awesome_outlined, label: 'AI Insights', onTap: () => _showAiInsights(all)),
                            _ActionBtn(icon: Icons.bookmark_outline,      label: 'Bookmarks',   onTap: _showBookmarks),
                            _ActionBtn(icon: Icons.ios_share_outlined,    label: 'Export',      onTap: () => _exportNotes(all)),
                          ],
                        ),
                      ),
                    ),

                    // ── Search ────────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (v) => setState(() => _search = v),
                          style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.label(context)),
                          decoration: InputDecoration(
                            hintText: 'Search notes…',
                            hintStyle: TextStyle(color: AppColors.textDim, fontFamily: 'Inter', fontSize: 14),
                            prefixIcon: Icon(Icons.search, color: AppColors.textDim, size: 18),
                            suffixIcon: _search.isNotEmpty
                                ? GestureDetector(
                                    onTap: () { setState(() => _search = ''); _searchCtrl.clear(); },
                                    child: Icon(Icons.close, color: AppColors.textDim, size: 18),
                                  )
                                : null,
                            filled: true, fillColor: AppColors.cardBg(context),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ),

                    // ── Filter chips ──────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: ['All', 'Personal', 'Sermon', 'Study'].map((f) {
                              final sel = f == _filter;
                              return GestureDetector(
                                onTap: () => setState(() => _filter = f),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: sel ? AppColors.gold : AppColors.cardBg(context),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(f,
                                    style: TextStyle(fontFamily: 'Inter', fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: sel ? AppColors.black : AppColors.sublabel(context))),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),

                    // ── Section label ─────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                        child: Text(
                          filtered.isEmpty ? '' : 'Recent Notes',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 13,
                            fontWeight: FontWeight.w700, color: AppColors.sublabel(context), letterSpacing: 0.5),
                        ),
                      ),
                    ),

                    // ── Note list ─────────────────────────────────────────
                    if (all.isEmpty)
                      SliverFillRemaining(
                        child: _EmptyState(
                          icon: Icons.edit_note_outlined,
                          message: 'Your Bible notes, sermon notes, and AI study sessions will all appear here.',
                        ),
                      )
                    else if (filtered.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Text('No notes match your search.',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.sublabel(context))),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (_, i) {
                              final note = filtered[i];
                              return note.type == 'sermon'
                                  ? _SermonCard(note: note, onTap: () => _openNote(note), onDelete: () => _deleteNote(note.id))
                                  : _NoteCard(note: note, onTap: () => _openNote(note), onDelete: () => _deleteNote(note.id));
                            },
                            childCount: filtered.length,
                          ),
                        ),
                      ),
                  ],
                ),

              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Personal note card ────────────────────────────────────────────────────────

class _NoteCard extends StatelessWidget {
  final NoteEntry note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NoteCard({required this.note, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(note.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.delete_outline, color: AppColors.error, size: 22),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBg(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: note.type == 'aiStudy'
                          ? AppColors.gold.withOpacity(0.12)
                          : AppColors.cardElevated(context),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      note.type == 'aiStudy' ? 'AI Study' : 'Note',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: note.type == 'aiStudy' ? AppColors.gold : AppColors.sublabel(context),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (note.passage != null) ...[
                    const SizedBox(width: 8),
                    Text(note.passage!,
                        style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textDim)),
                  ],
                  const Spacer(),
                  Text(DateFormat('MMM d').format(note.createdAt),
                      style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textDim)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                note.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.label(context)),
              ),
              if (note.preview.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  note.preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.sublabel(context), height: 1.4),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sermon card ───────────────────────────────────────────────────────────────

class _SermonCard extends StatelessWidget {
  final NoteEntry note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SermonCard({required this.note, required this.onTap, required this.onDelete});

  // Derive a short category tag from the passage (e.g. "John 3:16" → "John")
  String get _tag {
    if (note.passage == null || note.passage!.isEmpty) return '';
    return note.passage!.split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = note.sermonDate != null
        ? DateFormat('MMM d, yyyy').format(note.sermonDate!)
        : DateFormat('MMM d, yyyy').format(note.createdAt);

    return Dismissible(
      key: Key(note.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.delete_outline, color: AppColors.error, size: 22),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBg(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: title + category tag ───────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      note.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter', fontSize: 16,
                        fontWeight: FontWeight.w700, color: AppColors.label(context)),
                    ),
                  ),
                  if (_tag.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(_tag,
                        style: TextStyle(
                          fontFamily: 'Inter', fontSize: 11,
                          fontWeight: FontWeight.w700, color: AppColors.gold)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),

              // ── Date ────────────────────────────────────────────────────
              Text(dateStr,
                style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textDim)),

              // ── Preview ─────────────────────────────────────────────────
              if (note.preview.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  note.preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter', fontSize: 13, color: AppColors.sublabel(context), height: 1.45),
                ),
              ],

              // ── Scripture ref at bottom ──────────────────────────────────
              if (note.passage != null && note.passage!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Icon(Icons.menu_book_outlined, size: 12, color: AppColors.gold),
                  const SizedBox(width: 5),
                  Text(note.passage!,
                    style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.gold)),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared delete confirm ─────────────────────────────────────────────────────

Future<bool> _confirmDelete(BuildContext context) async {
  return await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.cardDark,
      title: Text('Delete note?',
          style: TextStyle(fontFamily: 'Lora', color: AppColors.label(context))),
      content: Text('This cannot be undone.',
          style: TextStyle(fontFamily: 'Inter', color: AppColors.sublabel(context))),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel', style: TextStyle(color: AppColors.sublabel(context))),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Delete', style: TextStyle(color: AppColors.error)),
        ),
      ],
    ),
  ) ?? false;
}

// ── Note detail sheet ─────────────────────────────────────────────────────────

class _NoteDetailSheet extends StatelessWidget {
  final NoteEntry note;
  final VoidCallback onDelete;
  const _NoteDetailSheet({required this.note, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36, height: 4,
            decoration: BoxDecoration(color: AppColors.divider(context), borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(note.title,
                    style: TextStyle(
                      fontFamily: 'Lora', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.label(context))),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                  onPressed: () { Navigator.pop(context); onDelete(); },
                ),
                IconButton(
                  icon: Icon(Icons.close, color: AppColors.sublabel(context), size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Sermon meta row
          if (note.type == 'sermon')
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  if (note.sermonDate != null) ...[
                    Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.gold),
                    const SizedBox(width: 5),
                    Text(DateFormat('MMMM d, yyyy').format(note.sermonDate!),
                        style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.gold)),
                  ],
                  if (note.speaker != null && note.speaker!.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.person_outline, size: 12, color: AppColors.textDim),
                    const SizedBox(width: 4),
                    Text(note.speaker!,
                        style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textDim)),
                  ],
                  if (note.passage != null && note.passage!.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.menu_book_outlined, size: 12, color: AppColors.textDim),
                    const SizedBox(width: 4),
                    Text(note.passage!,
                        style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textDim)),
                  ],
                ],
              ),
            )
          else if (note.passage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.menu_book_outlined, size: 13, color: AppColors.gold),
                  const SizedBox(width: 5),
                  Text(note.passage!,
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.gold)),
                  const SizedBox(width: 12),
                  Text(DateFormat('MMMM d, yyyy').format(note.createdAt),
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textDim)),
                ],
              ),
            ),
          Divider(color: AppColors.divider(context), height: 1),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: note.type == 'aiStudy'
                  ? _buildStudyBody(context)
                  : _buildTextBody(context),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTextBody(BuildContext context) => [
    Text(
      note.content ?? '',
      style: TextStyle(fontFamily: 'Inter', fontSize: 15, color: AppColors.label(context), height: 1.65),
    ),
  ];

  List<Widget> _buildStudyBody(BuildContext context) => [
    if (note.overview != null && note.overview!.isNotEmpty)
      _Section(title: 'Overview', body: note.overview!),
    if (note.applicationPoints.isNotEmpty)
      _BulletSection(title: 'Application', items: note.applicationPoints),
    if (note.reflectionQuestions.isNotEmpty)
      _BulletSection(title: 'Reflection Questions', items: note.reflectionQuestions),
    if (note.prayerPrompt != null && note.prayerPrompt!.isNotEmpty)
      _Section(title: 'Prayer', body: note.prayerPrompt!, accent: true),
  ];
}

// ── Section widgets ───────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final String body;
  final bool accent;
  const _Section({required this.title, required this.body, this.accent = false});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: accent ? AppColors.gold.withOpacity(0.06) : AppColors.cardElevated(context),
      borderRadius: BorderRadius.circular(12),
      border: accent ? Border.all(color: AppColors.gold.withOpacity(0.2)) : null,
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title.toUpperCase(),
        style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w700,
          letterSpacing: 1, color: accent ? AppColors.gold : AppColors.sublabel(context))),
      const SizedBox(height: 8),
      Text(body,
        style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.label(context), height: 1.6)),
    ]),
  );
}

class _BulletSection extends StatelessWidget {
  final String title;
  final List<String> items;
  const _BulletSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.cardElevated(context), borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title.toUpperCase(),
        style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w700,
          letterSpacing: 1, color: AppColors.sublabel(context))),
      const SizedBox(height: 10),
      ...items.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            margin: const EdgeInsets.only(top: 7),
            width: 4, height: 4,
            decoration: BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(item,
            style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.label(context), height: 1.55))),
        ]),
      )),
    ]),
  );
}

// ── New personal note sheet ───────────────────────────────────────────────────

class _NewNoteSheet extends StatefulWidget {
  final String? uid;
  final String? prefillTitle;
  final String? prefillContent;
  const _NewNoteSheet({this.uid, this.prefillTitle, this.prefillContent});

  @override
  State<_NewNoteSheet> createState() => _NewNoteSheetState();
}

class _NewNoteSheetState extends State<_NewNoteSheet> {
  late final TextEditingController _title;
  late final TextEditingController _content;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title   = TextEditingController(text: widget.prefillTitle ?? '');
    _content = TextEditingController(text: widget.prefillContent ?? '');
  }

  @override
  void dispose() { _title.dispose(); _content.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (widget.uid == null) return;
    if (_title.text.trim().isEmpty && _content.text.trim().isEmpty) {
      Navigator.pop(context); return;
    }
    setState(() => _saving = true);
    await FirebaseFirestore.instance
        .collection('notes').doc(widget.uid).collection('entries').add({
      'title': _title.text.trim().isEmpty ? 'Untitled' : _title.text.trim(),
      'content': _content.text.trim(),
      'type': 'manual',
      'createdAt': FieldValue.serverTimestamp(),
    });
    BadgeService().onNoteSaved(); // fire-and-forget
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg(context),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(margin: const EdgeInsets.only(top: 10, bottom: 4), width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.divider(context), borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
              child: Row(children: [
                Text('New Note', style: TextStyle(fontFamily: 'Lora', fontSize: 18,
                  fontWeight: FontWeight.bold, color: AppColors.label(context))),
                const Spacer(),
                TextButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold))
                      : Text('Save', style: TextStyle(fontFamily: 'Inter', fontSize: 15,
                          fontWeight: FontWeight.w700, color: AppColors.gold)),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: TextField(
                controller: _title,
                autofocus: true,
                style: TextStyle(fontFamily: 'Inter', fontSize: 16,
                  fontWeight: FontWeight.w600, color: AppColors.label(context)),
                decoration: const InputDecoration(
                  hintText: 'Title', border: InputBorder.none, isDense: true,
                  hintStyle: TextStyle(color: AppColors.textDim, fontFamily: 'Inter', fontSize: 16)),
                textInputAction: TextInputAction.next,
              ),
            ),
            Divider(color: AppColors.divider(context), height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: TextField(
                controller: _content,
                maxLines: 8,
                style: TextStyle(fontFamily: 'Inter', fontSize: 15, color: AppColors.label(context), height: 1.6),
                decoration: const InputDecoration(
                  hintText: 'Write your thoughts…', border: InputBorder.none, isDense: true,
                  hintStyle: TextStyle(color: AppColors.textDim, fontFamily: 'Inter', fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── New sermon note sheet ─────────────────────────────────────────────────────

class _NewSermonNoteSheet extends StatefulWidget {
  final String? uid;
  const _NewSermonNoteSheet({this.uid});

  @override
  State<_NewSermonNoteSheet> createState() => _NewSermonNoteSheetState();
}

class _NewSermonNoteSheetState extends State<_NewSermonNoteSheet> {
  final _titleCtrl   = TextEditingController();
  final _speakerCtrl = TextEditingController();
  final _passageCtrl = TextEditingController();
  final _notesCtrl   = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _speakerCtrl.dispose();
    _passageCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.gold,
            onPrimary: AppColors.black,
            surface: AppColors.cardBg(context),
            onSurface: AppColors.label(context),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (widget.uid == null) return;
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);
    await FirebaseFirestore.instance
        .collection('notes').doc(widget.uid).collection('entries').add({
      'title': title,
      'speaker': _speakerCtrl.text.trim(),
      'passage': _passageCtrl.text.trim(),
      'content': _notesCtrl.text.trim(),
      'type': 'sermon',
      'sermonDate': Timestamp.fromDate(_date),
      'createdAt': FieldValue.serverTimestamp(),
    });
    BadgeService().onNoteSaved(); // fire-and-forget
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      height: screenH * 0.75,
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36, height: 4,
            decoration: BoxDecoration(color: AppColors.divider(context), borderRadius: BorderRadius.circular(2)),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
            child: Row(children: [
              Icon(Icons.church_outlined, color: AppColors.gold, size: 18),
              const SizedBox(width: 10),
              Text('Sermon Notes', style: TextStyle(fontFamily: 'Lora', fontSize: 18,
                fontWeight: FontWeight.bold, color: AppColors.label(context))),
            ]),
          ),
          Divider(color: AppColors.divider(context), height: 1),

          // Scrollable fields
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date row
                  GestureDetector(
                    onTap: _pickDate,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Row(children: [
                        Icon(Icons.calendar_today_outlined, color: AppColors.gold, size: 18),
                        const SizedBox(width: 14),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('DATE', style: TextStyle(fontFamily: 'Inter', fontSize: 10,
                            fontWeight: FontWeight.w700, letterSpacing: 1, color: AppColors.sublabel(context))),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('EEEE, MMMM d, yyyy').format(_date),
                            style: TextStyle(fontFamily: 'Inter', fontSize: 15,
                              fontWeight: FontWeight.w500, color: AppColors.label(context)),
                          ),
                        ]),
                        const Spacer(),
                        Icon(Icons.chevron_right, color: AppColors.textDim, size: 18),
                      ]),
                    ),
                  ),
                  Divider(color: AppColors.divider(context), height: 1),

                  _FieldRow(
                    icon: Icons.title_outlined,
                    label: 'TITLE',
                    child: TextField(
                      controller: _titleCtrl,
                      autofocus: true,
                      style: TextStyle(fontFamily: 'Inter', fontSize: 15,
                        fontWeight: FontWeight.w500, color: AppColors.label(context)),
                      decoration: const InputDecoration(
                        hintText: 'Sermon title', border: InputBorder.none, isDense: true,
                        hintStyle: TextStyle(color: AppColors.textDim, fontFamily: 'Inter', fontSize: 15)),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  Divider(color: AppColors.divider(context), height: 1),

                  _FieldRow(
                    icon: Icons.person_outline,
                    label: 'SPEAKER',
                    child: TextField(
                      controller: _speakerCtrl,
                      style: TextStyle(fontFamily: 'Inter', fontSize: 15,
                        fontWeight: FontWeight.w500, color: AppColors.label(context)),
                      decoration: const InputDecoration(
                        hintText: 'Pastor / speaker name', border: InputBorder.none, isDense: true,
                        hintStyle: TextStyle(color: AppColors.textDim, fontFamily: 'Inter', fontSize: 15)),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  Divider(color: AppColors.divider(context), height: 1),

                  _FieldRow(
                    icon: Icons.menu_book_outlined,
                    label: 'SCRIPTURE',
                    child: TextField(
                      controller: _passageCtrl,
                      style: TextStyle(fontFamily: 'Inter', fontSize: 15,
                        fontWeight: FontWeight.w500, color: AppColors.label(context)),
                      decoration: const InputDecoration(
                        hintText: 'e.g. John 3:16–21', border: InputBorder.none, isDense: true,
                        hintStyle: TextStyle(color: AppColors.textDim, fontFamily: 'Inter', fontSize: 15)),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  Divider(color: AppColors.divider(context), height: 1),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('NOTES', style: TextStyle(fontFamily: 'Inter', fontSize: 10,
                        fontWeight: FontWeight.w700, letterSpacing: 1, color: AppColors.sublabel(context))),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notesCtrl,
                        maxLines: 6,
                        style: TextStyle(fontFamily: 'Inter', fontSize: 15,
                          color: AppColors.label(context), height: 1.6),
                        decoration: const InputDecoration(
                          hintText: 'Key points, quotes, what stood out…',
                          border: InputBorder.none, isDense: true,
                          hintStyle: TextStyle(color: AppColors.textDim, fontFamily: 'Inter', fontSize: 15)),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ),

          // ── Sticky bottom action bar ─────────────────────────────────────
          Divider(color: AppColors.divider(context), height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottom),
            child: Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.cardElevated(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text('Cancel', style: TextStyle(fontFamily: 'Inter', fontSize: 15,
                        fontWeight: FontWeight.w600, color: AppColors.sublabel(context))),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _saving ? null : _save,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: _saving
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.black))
                          : Text('Save', style: TextStyle(fontFamily: 'Inter', fontSize: 15,
                              fontWeight: FontWeight.w700, color: AppColors.black)),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;
  const _FieldRow({required this.icon, required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: AppColors.gold, size: 18),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 10,
            fontWeight: FontWeight.w700, letterSpacing: 1, color: AppColors.sublabel(context))),
          const SizedBox(height: 2),
          child,
        ]),
      ),
    ]),
  );
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider(context)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
          style: TextStyle(
            fontFamily: 'Lora', fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.label(context))),
        const SizedBox(height: 2),
        Text(label,
          style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.sublabel(context))),
      ]),
    ),
  );
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(children: [
      Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          color: AppColors.cardBg(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider(context)),
        ),
        child: Icon(icon, color: AppColors.gold, size: 22),
      ),
      const SizedBox(height: 6),
      Text(label,
        style: TextStyle(fontFamily: 'Inter', fontSize: 11,
          fontWeight: FontWeight.w500, color: AppColors.sublabel(context))),
    ]),
  );
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? buttonLabel;
  final VoidCallback? onAdd;
  const _EmptyState({required this.icon, required this.message,
    this.buttonLabel, this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: AppColors.gold, size: 30),
        ),
        const SizedBox(height: 16),
        Text('Nothing here yet',
          style: TextStyle(fontFamily: 'Lora', fontSize: 20,
            fontWeight: FontWeight.bold, color: AppColors.label(context))),
        const SizedBox(height: 8),
        Text(message,
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.sublabel(context), height: 1.5)),
        if (onAdd != null) ...[
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(12)),
              child: Text(buttonLabel ?? '',
                style: TextStyle(fontFamily: 'Inter', fontSize: 14,
                  fontWeight: FontWeight.w700, color: AppColors.black)),
            ),
          ),
        ],
      ]),
    ),
  );
}

// ── AI Insights Sheet ─────────────────────────────────────────────────────────

class _AiInsightsSheet extends StatefulWidget {
  final List<NoteEntry> notes;
  const _AiInsightsSheet({required this.notes});

  @override
  State<_AiInsightsSheet> createState() => _AiInsightsSheetState();
}

class _AiInsightsSheetState extends State<_AiInsightsSheet> {
  bool _loading = true;
  String? _error;
  List<String> _themes = [];
  String _summary = '';
  String _growthArea = '';
  String _suggestedNext = '';

  @override
  void initState() {
    super.initState();
    _fetchInsights();
  }

  Future<void> _fetchInsights() async {
    try {
      final fn = FirebaseFunctions.instance.httpsCallable('getNotesInsightsFn');
      final notesData = widget.notes.take(30).map((n) => {
        'title': n.title,
        'type': n.type,
        if (n.content != null) 'content': n.content,
        if (n.passage != null) 'passage': n.passage,
        if (n.speaker != null) 'speaker': n.speaker,
      }).toList();

      final result = await fn.call({'notes': notesData});
      final d = Map<String, dynamic>.from(result.data as Map);
      if (mounted) {
        setState(() {
          _themes = List<String>.from(d['themes'] as List? ?? []);
          _summary = d['summary'] as String? ?? '';
          _growthArea = d['growthArea'] as String? ?? '';
          _suggestedNext = d['suggestedNext'] as String? ?? '';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Could not load insights. Try again.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, ctrl) => Column(children: [
        Container(margin: const EdgeInsets.only(top: 10, bottom: 8), width: 36, height: 4,
          decoration: BoxDecoration(color: AppColors.divider(context), borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Row(children: [
            Icon(Icons.auto_awesome_outlined, color: AppColors.gold, size: 20),
            const SizedBox(width: 8),
            Text('AI Insights',
              style: TextStyle(fontFamily: 'Lora', fontSize: 20,
                fontWeight: FontWeight.bold, color: AppColors.label(context))),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Icon(Icons.close, color: AppColors.sublabel(context), size: 20)),
          ]),
        ),
        Divider(color: AppColors.divider(context), height: 1),
        Expanded(
          child: _loading
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(color: AppColors.gold),
                SizedBox(height: 16),
                Text('Analyzing your notes…',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.sublabel(context))),
              ]))
            : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: AppColors.sublabel(context), fontFamily: 'Inter')))
              : ListView(controller: ctrl, padding: const EdgeInsets.fromLTRB(20, 20, 20, 40), children: [
                  // Themes chips
                  Text('Themes in Your Study',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                      fontWeight: FontWeight.w700, color: AppColors.sublabel(context), letterSpacing: 0.8)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: _themes.map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.gold.withOpacity(0.4)),
                    ),
                    child: Text(t, style: TextStyle(
                      fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gold)),
                  )).toList()),
                  const SizedBox(height: 24),

                  // Summary
                  _InsightSection(icon: Icons.auto_stories_outlined, label: 'Your Study Journey', body: _summary),
                  const SizedBox(height: 20),

                  // Growth area
                  _InsightSection(icon: Icons.trending_up_outlined, label: 'Spiritual Focus', body: _growthArea),
                  const SizedBox(height: 20),

                  // Suggested next
                  _InsightSection(icon: Icons.explore_outlined, label: 'What to Explore Next', body: _suggestedNext),
                ]),
        ),
      ]),
    );
  }
}

class _InsightSection extends StatelessWidget {
  final IconData icon;
  final String label;
  final String body;
  const _InsightSection({required this.icon, required this.label, required this.body});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.cardBg(context),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.divider(context)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: AppColors.gold, size: 16),
        const SizedBox(width: 6),
        Text(label,
          style: TextStyle(fontFamily: 'Inter', fontSize: 12,
            fontWeight: FontWeight.w700, color: AppColors.sublabel(context), letterSpacing: 0.6)),
      ]),
      const SizedBox(height: 10),
      Text(body,
        style: TextStyle(fontFamily: 'Inter', fontSize: 14,
          color: AppColors.label(context), height: 1.55)),
    ]),
  );
}

// ── Bookmarks Sheet ───────────────────────────────────────────────────────────

class _BookmarksSheet extends StatelessWidget {
  final String? uid;
  const _BookmarksSheet({this.uid});

  Color _highlightColor(String color) {
    switch (color) {
      case 'yellow': return const Color(0xFFFFF176);
      case 'green':  return const Color(0xFFA5D6A7);
      case 'blue':   return const Color(0xFF90CAF9);
      case 'pink':   return const Color(0xFFF48FB1);
      default:       return AppColors.gold;
    }
  }

  String _bookName(String verseId) {
    // verseId format: bookId_chapter_verse e.g. jhn_3_16
    const names = {
      'gen':'Genesis','exo':'Exodus','lev':'Leviticus','num':'Numbers','deu':'Deuteronomy',
      'jos':'Joshua','jdg':'Judges','rut':'Ruth','1sa':'1 Samuel','2sa':'2 Samuel',
      '1ki':'1 Kings','2ki':'2 Kings','1ch':'1 Chronicles','2ch':'2 Chronicles',
      'ezr':'Ezra','neh':'Nehemiah','est':'Esther','job':'Job','psa':'Psalms',
      'pro':'Proverbs','ecc':'Ecclesiastes','sng':'Song of Solomon','isa':'Isaiah',
      'jer':'Jeremiah','lam':'Lamentations','ezk':'Ezekiel','dan':'Daniel',
      'hos':'Hosea','jol':'Joel','amo':'Amos','oba':'Obadiah','jon':'Jonah',
      'mic':'Micah','nam':'Nahum','hab':'Habakkuk','zep':'Zephaniah','hag':'Haggai',
      'zec':'Zechariah','mal':'Malachi','mat':'Matthew','mrk':'Mark','luk':'Luke',
      'jhn':'John','act':'Acts','rom':'Romans','1co':'1 Corinthians','2co':'2 Corinthians',
      'gal':'Galatians','eph':'Ephesians','php':'Philippians','col':'Colossians',
      '1th':'1 Thessalonians','2th':'2 Thessalonians','1ti':'1 Timothy','2ti':'2 Timothy',
      'tit':'Titus','phm':'Philemon','heb':'Hebrews','jas':'James',
      '1pe':'1 Peter','2pe':'2 Peter','1jn':'1 John','2jn':'2 John','3jn':'3 John',
      'jud':'Jude','rev':'Revelation',
    };
    final parts = verseId.split('_');
    if (parts.isEmpty) return verseId;
    final bookId = parts[0];
    final chap = parts.length > 1 ? parts[1] : '';
    final verse = parts.length > 2 ? parts[2] : '';
    final book = names[bookId] ?? bookId;
    if (chap.isEmpty) return book;
    if (verse.isEmpty) return '$book $chap';
    return '$book $chap:$verse';
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return SizedBox(height: 200,
        child: Center(child: Text('Sign in to view bookmarks',
          style: TextStyle(color: AppColors.sublabel(context), fontFamily: 'Inter'))));
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, ctrl) => Column(children: [
        Container(margin: const EdgeInsets.only(top: 10, bottom: 8), width: 36, height: 4,
          decoration: BoxDecoration(color: AppColors.divider(context), borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Row(children: [
            Icon(Icons.bookmark_outlined, color: AppColors.gold, size: 20),
            const SizedBox(width: 8),
            Text('Bookmarks',
              style: TextStyle(fontFamily: 'Lora', fontSize: 20,
                fontWeight: FontWeight.bold, color: AppColors.label(context))),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Icon(Icons.close, color: AppColors.sublabel(context), size: 20)),
          ]),
        ),
        Divider(color: AppColors.divider(context), height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('highlights')
                .doc(uid)
                .collection('verses')
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: AppColors.gold));
              }
              final docs = snap.data?.docs ?? [];
              // Filter out old bad-format keys (purely numeric)
              final valid = docs.where((d) => d.id.contains('_')).toList();
              if (valid.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Text('No bookmarks yet.\nLong-press any verse in the Bible reader to highlight it.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Inter', fontSize: 14,
                        color: AppColors.sublabel(context), height: 1.5)),
                  ),
                );
              }
              return ListView.separated(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                itemCount: valid.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final doc = valid[i];
                  final data = doc.data() as Map<String, dynamic>;
                  final color = data['color'] as String? ?? 'yellow';
                  final ref = _bookName(doc.id);
                  final parts = doc.id.split('_');

                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      if (parts.length >= 2) {
                        context.go('/reader', extra: {
                          'book': parts[0],
                          'chapter': int.tryParse(parts[1]) ?? 1,
                          'startVerse': parts.length >= 3 ? int.tryParse(parts[2]) : null,
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider(context)),
                      ),
                      child: Row(children: [
                        Container(width: 4, height: 36, decoration: BoxDecoration(
                          color: _highlightColor(color), borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(ref,
                            style: TextStyle(fontFamily: 'Inter', fontSize: 14,
                              fontWeight: FontWeight.w600, color: AppColors.label(context))),
                        ),
                        Icon(Icons.chevron_right, color: AppColors.textDim, size: 18),
                      ]),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}
