import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/subscription_provider.dart';
import '../../core/services/badge_service.dart';
import '../paywall/compare_screen.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

String? get _uid   => FirebaseAuth.instance.currentUser?.uid;
String? get _uname => FirebaseAuth.instance.currentUser?.displayName;

String _generateCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rng = Random.secure();
  return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1)  return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24)   return '${diff.inHours}h ago';
  if (diff.inDays == 1)    return 'Yesterday';
  if (diff.inDays < 7)     return '${diff.inDays}d ago';
  return DateFormat('MMM d').format(dt);
}

List<Color> _groupGradient(String groupId) {
  const palettes = [
    [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
    [Color(0xFF2D1B4E), Color(0xFF1A0E3C), Color(0xFF3D1A6E)],
    [Color(0xFF1B2A1F), Color(0xFF0D1F12), Color(0xFF2A4030)],
    [Color(0xFF2A1A0E), Color(0xFF3D2510), Color(0xFF1A0D05)],
    [Color(0xFF1A2A3D), Color(0xFF0D1A2A), Color(0xFF203A5A)],
    [Color(0xFF2D1F1A), Color(0xFF4A2F20), Color(0xFF1A0F0A)],
  ];
  final idx = groupId.codeUnits.fold(0, (a, b) => a + b) % palettes.length;
  return palettes[idx];
}

// ── Main Screen ───────────────────────────────────────────────────────────────

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_uid == null) {
      return Scaffold(
        body: Center(child: Text('Sign in to view groups',
          style: TextStyle(color: AppColors.sublabel(context), fontFamily: 'Inter'))),
      );
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .where('memberIds', arrayContains: _uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: AppColors.gold)));
        }
        if (snap.hasError) return _EmptyGroupsView(groupCount: 0);
        // Sort client-side to avoid composite index requirement
        final groups = (snap.data?.docs ?? [])
          ..sort((a, b) {
            final ta = ((a.data() as Map)['lastActivity'] as Timestamp?)?.toDate() ?? DateTime(0);
            final tb = ((b.data() as Map)['lastActivity'] as Timestamp?)?.toDate() ?? DateTime(0);
            return tb.compareTo(ta);
          });
        final isPro = ref.watch(isProProvider);
        if (groups.isEmpty) return _EmptyGroupsView(groupCount: 0, isPro: isPro);
        return _GroupsHomeView(groups: groups, isPro: isPro);
      },
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyGroupsView extends StatelessWidget {
  final int groupCount;
  final bool isPro;
  const _EmptyGroupsView({required this.groupCount, this.isPro = false});

  void _guardedAction(BuildContext context, VoidCallback action) {
    if (!isPro && groupCount >= 1) {
      showCompareScreen(context);
    } else {
      action();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Groups', style: TextStyle(fontFamily: 'Lora', fontSize: 26,
              fontWeight: FontWeight.bold, color: AppColors.label(context))),
            const Spacer(),
            _HeaderIconBtn(icon: Icons.group_add_outlined,
              onTap: () => _guardedAction(context, () => _showJoinGroup(context))),
            const SizedBox(width: 8),
            _HeaderIconBtn(icon: Icons.add,
              onTap: () => _guardedAction(context, () => _showCreateGroup(context))),
          ]),
          const Spacer(),
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 80, height: 80,
              decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.group_outlined, color: AppColors.gold, size: 38)),
            const SizedBox(height: 20),
            Text('No groups yet', style: TextStyle(fontFamily: 'Lora', fontSize: 22,
              fontWeight: FontWeight.bold, color: AppColors.label(context))),
            const SizedBox(height: 8),
            Text('Study together with friends, share insights,\nand pray for one another.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.sublabel(context), height: 1.55)),
          ])),
          const Spacer(),
          _GoldBtn(label: 'Create a Group',
            onTap: () => _guardedAction(context, () => _showCreateGroup(context))),
          const SizedBox(height: 12),
          _OutlineBtn(label: 'Join with Code', icon: Icons.group_add_outlined,
            onTap: () => _guardedAction(context, () => _showJoinGroup(context))),
          const SizedBox(height: 8),
        ]),
      )),
    );
  }
}

// ── Main hub (scrollable) ─────────────────────────────────────────────────────

class _GroupsHomeView extends StatefulWidget {
  final List<QueryDocumentSnapshot> groups;
  final bool isPro;
  const _GroupsHomeView({required this.groups, this.isPro = false});

  @override
  State<_GroupsHomeView> createState() => _GroupsHomeViewState();
}

class _GroupsHomeViewState extends State<_GroupsHomeView> {
  // null = All groups
  String? _selectedGroupId;

  void _guardedGroupAction(BuildContext context, VoidCallback action) {
    if (!widget.isPro && widget.groups.length >= 1) {
      showCompareScreen(context);
    } else {
      action();
    }
  }

  int get _totalMembers => widget.groups.fold(0, (sum, g) {
    final d = g.data() as Map<String, dynamic>;
    return sum + ((d['memberCount'] as int?) ?? (d['memberIds'] as List?)?.length ?? 1);
  });

  String _groupName(QueryDocumentSnapshot g) =>
      (g.data() as Map<String, dynamic>)['name'] as String? ?? 'Group';

  @override
  Widget build(BuildContext context) {
    final groups = widget.groups;
    final allGroupIds = groups.map((g) => g.id).toList();
    final feedGroupIds = _selectedGroupId != null ? [_selectedGroupId!] : allGroupIds;
    final multiGroup = groups.length > 1;

    return Scaffold(
      body: SafeArea(child: CustomScrollView(slivers: [
        // Header
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(children: [
            Text('Groups', style: TextStyle(fontFamily: 'Lora', fontSize: 26,
              fontWeight: FontWeight.bold, color: AppColors.label(context))),
            const Spacer(),
            _HeaderIconBtn(icon: Icons.group_add_outlined,
              onTap: () => _guardedGroupAction(context, () => _showJoinGroup(context))),
            const SizedBox(width: 8),
            _HeaderIconBtn(icon: Icons.add,
              onTap: () => _guardedGroupAction(context, () => _showCreateGroup(context))),
          ]),
        )),

        // Stats row
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(children: [
            _StatChip(value: '${groups.length}', label: groups.length == 1 ? 'Group' : 'Groups'),
            const SizedBox(width: 12),
            _StatChip(value: '$_totalMembers', label: 'Members'),
            const SizedBox(width: 12),
            const _StatChip(value: 'Active', label: 'Status', gold: true),
          ]),
        )),

        // Your Groups section
        SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Row(children: [
              Text('Your Groups', style: TextStyle(fontFamily: 'Lora', fontSize: 18,
                fontWeight: FontWeight.bold, color: AppColors.label(context))),
              const Spacer(),
              if (groups.length > 2)
                GestureDetector(
                  onTap: () => _showAllGroups(context, groups),
                  child: Text('See All', style: TextStyle(fontFamily: 'Inter', fontSize: 13,
                    fontWeight: FontWeight.w600, color: AppColors.gold))),
            ]),
          ),
          SizedBox(height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: groups.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) => _GroupCard(
                groupDoc: groups[i],
                onTap: () => _openGroupDetail(context, groups[i])),
            )),
        ])),

        // Community Feed header
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
          child: Text('Community Feed', style: TextStyle(fontFamily: 'Lora', fontSize: 18,
            fontWeight: FontWeight.bold, color: AppColors.label(context))),
        )),

        // Group filter chips — only shown when member of 2+ groups
        if (multiGroup)
          SliverToBoxAdapter(child: SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                // "All" chip
                _FeedFilterChip(
                  label: 'All',
                  selected: _selectedGroupId == null,
                  onTap: () => setState(() => _selectedGroupId = null),
                ),
                const SizedBox(width: 8),
                // One chip per group
                ...groups.map((g) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FeedFilterChip(
                    label: _groupName(g),
                    selected: _selectedGroupId == g.id,
                    onTap: () => setState(() =>
                      _selectedGroupId = _selectedGroupId == g.id ? null : g.id),
                  ))),
              ],
            ),
          )),

        SliverToBoxAdapter(child: SizedBox(height: multiGroup ? 12 : 4)),

        _MergedFeedSliver(
          groupIds: allGroupIds,
          filterGroupId: _selectedGroupId,
        ),
        SliverToBoxAdapter(child: SizedBox(height: 32)),
      ])),
    );
  }
}

// ── Group card ────────────────────────────────────────────────────────────────

class _GroupCard extends StatelessWidget {
  final QueryDocumentSnapshot groupDoc;
  final VoidCallback onTap;
  const _GroupCard({required this.groupDoc, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final d           = groupDoc.data() as Map<String, dynamic>;
    final name        = d['name']          as String? ?? 'Group';
    final coverUrl    = d['coverImageUrl'] as String?;
    final memberCount = (d['memberCount'] as int?) ?? (d['memberIds'] as List?)?.length ?? 1;
    final isCreator   = (d['creatorUid'] ?? d['creatorId']) == _uid;
    final gradient    = _groupGradient(groupDoc.id);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 170,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider(context))),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          // Cover
          Positioned.fill(child: coverUrl != null
              ? Image.network(coverUrl, fit: BoxFit.cover)
              : Container(
                  decoration: BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: gradient)),
                  child: Center(child: Icon(Icons.group_outlined,
                    color: Colors.white.withOpacity(0.08), size: 64)))),
          // Gradient overlay
          Positioned.fill(child: Container(decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(0.82)],
              stops: const [0.3, 1.0])))),
          // Active badge
          Positioned(top: 10, right: 10, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: AppColors.success.withOpacity(0.85),
              borderRadius: BorderRadius.circular(8)),
            child: Text('Active', style: TextStyle(fontFamily: 'Inter', fontSize: 10,
              fontWeight: FontWeight.w700, color: Colors.white)))),
          // Creator badge
          if (isCreator)
            Positioned(top: 10, left: 10, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.9),
                borderRadius: BorderRadius.circular(6)),
              child: Text('Creator', style: TextStyle(fontFamily: 'Inter', fontSize: 9,
                fontWeight: FontWeight.w800, color: AppColors.black)))),
          // Info + button
          Positioned(bottom: 0, left: 0, right: 0, child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Lora', fontSize: 14,
                  fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.people_outline, size: 11, color: Colors.white70),
                const SizedBox(width: 4),
                Text('$memberCount members', style: TextStyle(fontFamily: 'Inter',
                  fontSize: 11, color: Colors.white70)),
              ]),
              const SizedBox(height: 8),
              Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(8)),
                child: Center(child: Text('View Group', style: TextStyle(fontFamily: 'Inter',
                  fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.black)))),
            ]),
          )),
        ]),
      ),
    );
  }
}

// ── Merged feed sliver ────────────────────────────────────────────────────────

class _MergedFeedSliver extends StatefulWidget {
  final List<String> groupIds;
  final String? filterGroupId; // null = show all
  const _MergedFeedSliver({required this.groupIds, this.filterGroupId});

  @override
  State<_MergedFeedSliver> createState() => _MergedFeedSliverState();
}

class _MergedFeedSliverState extends State<_MergedFeedSliver> {
  bool _loading = true;
  final Map<String, List<Map<String, dynamic>>> _cache = {};

  List<Map<String, dynamic>> get _visibleItems {
    final source = widget.filterGroupId != null
        ? (_cache[widget.filterGroupId] ?? [])
        : _cache.values.expand((e) => e).toList();
    return (source.toList()
      ..sort((a, b) {
        final ta = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
        final tb = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
        return tb.compareTo(ta);
      })).take(30).toList();
  }

  @override
  void initState() {
    super.initState();
    for (final gid in widget.groupIds) {
      FirebaseFirestore.instance
          .collection('groups').doc(gid).collection('feed')
          .orderBy('createdAt', descending: true).limit(15)
          .snapshots()
          .listen((snap) {
        _cache[gid] = snap.docs
            .map((d) => {...d.data(), 'feedDocId': d.id, 'groupId': gid})
            .toList();
        if (mounted) setState(() => _loading = false);
      });
    }
    if (widget.groupIds.isEmpty) setState(() => _loading = false);
  }

  @override
  void didUpdateWidget(_MergedFeedSliver old) {
    super.didUpdateWidget(old);
    // Rebuild when filter changes — no extra fetch needed, data already cached
    if (old.filterGroupId != widget.filterGroupId) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator(color: AppColors.gold))));
    }
    final items = _visibleItems;
    if (items.isEmpty) {
      return SliverToBoxAdapter(child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: _EmptyFeedCard()));
    }
    return SliverList(delegate: SliverChildBuilderDelegate(
      (context, i) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: _FeedCard(item: items[i])),
      childCount: items.length,
    ));
  }
}

class _EmptyFeedCard extends StatelessWidget {
  const _EmptyFeedCard();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: AppColors.cardBg(context), borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.divider(context))),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.chat_bubble_outline, color: AppColors.gold, size: 28),
      SizedBox(height: 12),
      Text('Nothing posted yet', style: TextStyle(fontFamily: 'Inter', fontSize: 14,
        fontWeight: FontWeight.w600, color: AppColors.label(context))),
      SizedBox(height: 4),
      Text('Open a group and share something with your community.',
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.sublabel(context))),
    ]),
  );
}

class _FeedCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _FeedCard({required this.item});

  static const _avatarColors = [
    AppColors.gold,
    Color(0xFF7B9EFF),
    Color(0xFF7ECDB9),
    Color(0xFFE88FAB),
    Color(0xFFA78BFA),
  ];

  IconData get _icon {
    switch (item['type'] as String?) {
      case 'verse_share': return Icons.menu_book_outlined;
      case 'study':       return Icons.psychology_outlined;
      case 'question':    return Icons.help_outline;
      default:            return Icons.chat_bubble_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authorName   = item['authorName']   as String? ?? 'Someone';
    final content      = item['content']      as String? ?? '';
    final passage      = item['passage']      as String?;
    final commentCount = item['commentCount'] as int? ?? 0;
    final dt           = (item['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final isOwn        = item['authorUid'] == _uid;
    final avatarColor  = _avatarColors[authorName.codeUnits.fold(0, (a, b) => a + b) % _avatarColors.length];
    final initial      = authorName.isNotEmpty ? authorName[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: () => _openFeedThread(context, item),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.cardBg(context), borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider(context))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 40, height: 40,
              decoration: BoxDecoration(
                color: avatarColor.withOpacity(isOwn ? 0.25 : 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: avatarColor.withOpacity(0.4))),
              child: Center(child: Text(isOwn ? 'Y' : initial,
                style: TextStyle(fontFamily: 'Inter', fontSize: 15,
                  fontWeight: FontWeight.w800, color: avatarColor)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isOwn ? 'You' : authorName,
                style: TextStyle(fontFamily: 'Inter', fontSize: 13,
                  fontWeight: FontWeight.w700, color: AppColors.label(context))),
              Text(_timeAgo(dt),
                style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textDim)),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.divider(context))),
              child: Icon(_icon, size: 13, color: AppColors.sublabel(context))),
          ]),
          if (passage != null) ...[
            const SizedBox(height: 10),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.gold.withOpacity(0.2))),
              child: Text(passage, style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                fontWeight: FontWeight.w600, color: AppColors.gold))),
          ],
          if (content.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(content, maxLines: 3, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Inter', fontSize: 14,
                color: AppColors.label(context), height: 1.5)),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.chat_bubble_outline, size: 13, color: AppColors.textDim),
            const SizedBox(width: 4),
            Text('$commentCount ${commentCount == 1 ? 'reply' : 'replies'}',
              style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textDim)),
            const Spacer(),
            Text('Reply →', style: TextStyle(fontFamily: 'Inter', fontSize: 12,
              color: AppColors.gold, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
  }
}

// ── Feed thread ───────────────────────────────────────────────────────────────

void _openFeedThread(BuildContext context, Map<String, dynamic> item) {
  final groupId   = item['groupId']   as String;
  final feedDocId = item['feedDocId'] as String;
  final feedRef   = FirebaseFirestore.instance
      .collection('groups').doc(groupId).collection('feed').doc(feedDocId);
  showModalBottomSheet(context: context, isScrollControlled: true,
    backgroundColor: AppColors.cardDark,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _ThreadSheet(feedDocRef: feedRef, initialData: item));
}

class _ThreadSheet extends StatefulWidget {
  final DocumentReference feedDocRef;
  final Map<String, dynamic> initialData;
  const _ThreadSheet({required this.feedDocRef, required this.initialData});
  @override
  State<_ThreadSheet> createState() => _ThreadSheetState();
}

class _ThreadSheetState extends State<_ThreadSheet> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  Future<void> _sendReply() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _uid == null) return;
    setState(() => _sending = true);
    final batch = FirebaseFirestore.instance.batch();
    batch.set(widget.feedDocRef.collection('replies').doc(), {
      'authorUid': _uid, 'authorName': _uname ?? 'Anonymous',
      'content': text, 'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(widget.feedDocRef, {'commentCount': FieldValue.increment(1)});
    await batch.commit();
    _ctrl.clear();
    if (mounted) setState(() => _sending = false);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final content = widget.initialData['content'] as String? ?? '';
    final author  = widget.initialData['authorName'] as String? ?? 'Someone';
    final isOwn   = widget.initialData['authorUid'] == _uid;
    return DraggableScrollableSheet(
      initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
      builder: (_, ctrl) => Column(children: [
        _SheetHandle(),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isOwn ? 'You' : author, style: TextStyle(fontFamily: 'Inter', fontSize: 13,
              fontWeight: FontWeight.w700, color: AppColors.gold)),
            const SizedBox(height: 4),
            Text(content, style: TextStyle(fontFamily: 'Inter', fontSize: 14,
              color: AppColors.label(context), height: 1.5)),
          ])),
        Divider(color: AppColors.divider(context), height: 1),
        Expanded(child: StreamBuilder<QuerySnapshot>(
          stream: widget.feedDocRef.collection('replies').orderBy('createdAt').snapshots(),
          builder: (context, snap) {
            final replies = snap.data?.docs ?? [];
            if (replies.isEmpty) {
              return Center(child: Text('No replies yet. Be the first!',
                style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.sublabel(context))));
            }
            return ListView.separated(
              controller: ctrl, padding: const EdgeInsets.all(16),
              itemCount: replies.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final r    = replies[i].data() as Map<String, dynamic>;
                final ra   = r['authorName'] as String? ?? 'Someone';
                final rt   = r['content']    as String? ?? '';
                final rdt  = (r['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                final own  = r['authorUid'] == _uid;
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (!own) ...[
                    CircleAvatar(radius: 14, backgroundColor: AppColors.gold.withOpacity(0.15),
                      child: Text(ra.isNotEmpty ? ra[0].toUpperCase() : '?',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 11,
                          fontWeight: FontWeight.w700, color: AppColors.gold))),
                    const SizedBox(width: 8),
                  ],
                  Expanded(child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: own ? AppColors.gold.withOpacity(0.1) : AppColors.cardElevated(context),
                      borderRadius: BorderRadius.circular(12)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (!own) Text(ra, style: TextStyle(fontFamily: 'Inter', fontSize: 11,
                        fontWeight: FontWeight.w700, color: AppColors.gold)),
                      Text(rt, style: TextStyle(fontFamily: 'Inter', fontSize: 13,
                        color: AppColors.label(context), height: 1.4)),
                      const SizedBox(height: 3),
                      Text(_timeAgo(rdt), style: TextStyle(fontFamily: 'Inter',
                        fontSize: 10, color: AppColors.textDim)),
                    ]))),
                  if (own) const SizedBox(width: 36),
                ]);
              },
            );
          },
        )),
        Container(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.of(context).viewInsets.bottom),
          decoration: BoxDecoration(color: AppColors.cardBg(context),
            border: Border(top: BorderSide(color: AppColors.divider(context)))),
          child: Row(children: [
            Expanded(child: TextField(controller: _ctrl,
              style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.label(context)),
              decoration: InputDecoration(hintText: 'Add a reply…',
                hintStyle: TextStyle(color: AppColors.textDim, fontFamily: 'Inter', fontSize: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                filled: true, fillColor: AppColors.cardElevated(context),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)))),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sending ? null : _sendReply,
              child: Container(width: 38, height: 38,
                decoration: BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                child: _sending
                    ? Padding(padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(color: AppColors.black, strokeWidth: 2))
                    : Icon(Icons.send_rounded, color: AppColors.black, size: 18))),
          ]),
        ),
      ]),
    );
  }
}

// ── Group detail sheet ────────────────────────────────────────────────────────

void _openGroupDetail(BuildContext context, QueryDocumentSnapshot groupDoc) {
  showModalBottomSheet(context: context, isScrollControlled: true,
    backgroundColor: AppColors.cardDark, useRootNavigator: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _GroupDetailSheet(groupDoc: groupDoc));
}

void _showAllGroups(BuildContext context, List<QueryDocumentSnapshot> groups) {
  showModalBottomSheet(context: context, isScrollControlled: true,
    backgroundColor: AppColors.cardDark,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.7, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
      builder: (_, ctrl) => Column(children: [
        _SheetHandle(),
        Padding(padding: EdgeInsets.only(bottom: 12),
          child: Text('All Your Groups', style: TextStyle(fontFamily: 'Lora', fontSize: 18,
            fontWeight: FontWeight.bold, color: AppColors.label(context)))),
        Expanded(child: ListView.separated(
          controller: ctrl, padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: groups.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) {
            final d    = groups[i].data() as Map<String, dynamic>;
            final name = d['name']        as String? ?? 'Group';
            final cnt  = (d['memberCount'] as int?) ?? (d['memberIds'] as List?)?.length ?? 1;
            return GestureDetector(
              onTap: () { Navigator.pop(ctx); _openGroupDetail(context, groups[i]); },
              child: Container(padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.cardElevated(context),
                  borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider(context))),
                child: Row(children: [
                  Container(width: 40, height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: _groupGradient(groups[i].id)),
                      borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.group_outlined, color: Colors.white38, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: TextStyle(fontFamily: 'Inter', fontSize: 14,
                      fontWeight: FontWeight.w700, color: AppColors.label(context))),
                    Text('$cnt members', style: TextStyle(fontFamily: 'Inter',
                      fontSize: 12, color: AppColors.sublabel(context))),
                  ])),
                  Icon(Icons.chevron_right, color: AppColors.textDim, size: 18),
                ])));
          },
        )),
      ]),
    ));
}

class _GroupDetailSheet extends StatefulWidget {
  final QueryDocumentSnapshot groupDoc;
  const _GroupDetailSheet({required this.groupDoc});
  @override
  State<_GroupDetailSheet> createState() => _GroupDetailSheetState();
}

class _GroupDetailSheetState extends State<_GroupDetailSheet>
    with SingleTickerProviderStateMixin {
  late TabController _inner;
  int _innerIndex = 0;
  bool _uploading = false;

  // Live snapshot so cover photo updates without closing/reopening the sheet
  Map<String, dynamic> _liveData = {};

  Map<String, dynamic> get _d => _liveData.isNotEmpty
      ? _liveData
      : (widget.groupDoc.data() as Map<String, dynamic>);
  String get _groupId    => widget.groupDoc.id;
  String get _inviteCode => _d['inviteCode'] as String? ?? '------';
  bool   get _isCreator  => (_d['creatorUid'] ?? _d['creatorId']) == _uid;
  int    get _members    => (_d['memberCount'] as int?) ?? (_d['memberIds'] as List?)?.length ?? 1;
  String get _name       => _d['name']        as String? ?? 'Group';
  String get _desc       => _d['description'] as String? ?? '';
  String get _coverUrl   => _d['coverImageUrl'] as String? ?? '';

  Future<void> _pickAndUploadCover() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final ref = FirebaseStorage.instance
          .ref('groupCovers/$_groupId/cover.jpg');
      await ref.putData(await picked.readAsBytes(),
          SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('groups').doc(_groupId)
          .update({'coverImageUrl': url});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showGroupMenu(BuildContext context) {
    showModalBottomSheet(
      context: context, backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _SheetHandle(),
        if (_isCreator) ...[
          _MenuTile(icon: Icons.edit_outlined, label: 'Edit Group Name',
            onTap: () { Navigator.pop(context); _showEditName(context); }),
          _MenuTile(icon: Icons.camera_alt_outlined, label: 'Change Cover Photo',
            onTap: () { Navigator.pop(context); _pickAndUploadCover(); }),
          Divider(color: AppColors.divider(context), height: 1),
          _MenuTile(icon: Icons.delete_outline, label: 'Delete Group',
            color: AppColors.error,
            onTap: () { Navigator.pop(context); _confirmDelete(context); }),
        ] else ...[
          _MenuTile(icon: Icons.exit_to_app, label: 'Leave Group',
            color: AppColors.error,
            onTap: () { Navigator.pop(context); _confirmLeave(context); }),
        ],
        const SizedBox(height: 8),
      ])));
  }

  void _showEditName(BuildContext context) {
    final ctrl = TextEditingController(text: _name);
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _SheetHandle(),
          Text('Edit Group Name', style: TextStyle(fontFamily: 'Lora', fontSize: 20,
            fontWeight: FontWeight.bold, color: AppColors.label(context))),
          const SizedBox(height: 16),
          TextField(controller: ctrl, autofocus: true,
            style: TextStyle(fontFamily: 'Inter', fontSize: 15, color: AppColors.label(context)),
            decoration: InputDecoration(hintText: 'Group name',
              hintStyle: TextStyle(color: AppColors.textDim, fontFamily: 'Inter'),
              filled: true, fillColor: AppColors.cardElevated(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
          const SizedBox(height: 16),
          _GoldBtn(label: 'Save', onTap: () async {
            final name = ctrl.text.trim();
            if (name.isEmpty) return;
            await FirebaseFirestore.instance
                .collection('groups').doc(_groupId).update({'name': name});
            if (context.mounted) Navigator.pop(context);
          }),
        ])));
  }

  void _confirmDelete(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.cardDark,
      title: Text('Delete Group?', style: TextStyle(fontFamily: 'Lora',
        color: AppColors.label(context), fontWeight: FontWeight.bold)),
      content: Text('This will permanently delete "$_name" and all its posts, prayers, and challenges.',
        style: TextStyle(fontFamily: 'Inter', color: AppColors.sublabel(context))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: AppColors.sublabel(context)))),
        TextButton(
          onPressed: () async {
            Navigator.pop(context); // close dialog
            Navigator.pop(context); // close group sheet
            await FirebaseFirestore.instance
                .collection('groups').doc(_groupId).delete();
          },
          child: Text('Delete', style: TextStyle(color: AppColors.error,
            fontWeight: FontWeight.w700))),
      ]));
  }

  void _confirmLeave(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.cardDark,
      title: Text('Leave Group?', style: TextStyle(fontFamily: 'Lora',
        color: AppColors.label(context), fontWeight: FontWeight.bold)),
      content: Text('You\'ll leave "$_name". You can rejoin later with the invite code.',
        style: TextStyle(fontFamily: 'Inter', color: AppColors.sublabel(context))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: AppColors.sublabel(context)))),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            Navigator.pop(context);
            final batch = FirebaseFirestore.instance.batch();
            final groupRef = FirebaseFirestore.instance.collection('groups').doc(_groupId);
            batch.update(groupRef, {
              'memberIds': FieldValue.arrayRemove([_uid]),
              'memberCount': FieldValue.increment(-1),
            });
            batch.delete(groupRef.collection('members').doc(_uid));
            await batch.commit();
          },
          child: Text('Leave', style: TextStyle(color: AppColors.error,
            fontWeight: FontWeight.w700))),
      ]));
  }

  late final _groupStream = FirebaseFirestore.instance
      .collection('groups').doc(widget.groupDoc.id).snapshots();
  late final _groupSub = _groupStream.listen((snap) {
    if (snap.exists && mounted) {
      setState(() => _liveData = snap.data() ?? {});
    }
  });

  @override
  void initState() {
    super.initState();
    _liveData = widget.groupDoc.data() as Map<String, dynamic>;
    _inner = TabController(length: 3, vsync: this)
      ..addListener(() { if (!_inner.indexIsChanging) setState(() => _innerIndex = _inner.index); });
  }
  @override
  void dispose() { _groupSub.cancel(); _inner.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final gradient = _groupGradient(_groupId);
    return DraggableScrollableSheet(
      initialChildSize: 0.92, minChildSize: 0.6, maxChildSize: 0.97, expand: false,
      builder: (_, ctrl) => Column(children: [
        // Hero image
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: SizedBox(height: 180, width: double.infinity, child: Stack(children: [
            Positioned.fill(child: _coverUrl.isNotEmpty
                ? Image.network(_coverUrl, fit: BoxFit.cover)
                : Container(decoration: BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient)))),
            Positioned.fill(child: Container(decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.85)], stops: const [0.2, 1.0])))),
            Positioned(top: 10, left: 0, right: 0,
              child: Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2))))),
            // ⋯ menu — top-left
            Positioned(top: 6, left: 8, child: GestureDetector(
              onTap: () => _showGroupMenu(context),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                child: Icon(Icons.more_horiz, color: Colors.white, size: 18)))),
            // Upload progress overlay
            if (_uploading)
              Positioned.fill(child: Container(
                color: Colors.black54,
                child: Center(child: CircularProgressIndicator(color: AppColors.gold)))),
            // Camera edit button — creator only
            if (_isCreator && !_uploading)
              Positioned(top: 12, right: 12, child: GestureDetector(
                onTap: _pickAndUploadCover,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24)),
                  child: Icon(Icons.camera_alt_outlined,
                    color: Colors.white, size: 18)))),
            Positioned(bottom: 14, left: 16, right: 80,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_name, style: TextStyle(fontFamily: 'Lora', fontSize: 22,
                  fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.people_outline, size: 13, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text('$_members members', style: TextStyle(fontFamily: 'Inter',
                    fontSize: 12, color: Colors.white70)),
                ]),
                if (_desc.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(_desc, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.white60)),
                ],
              ])),
            Positioned(bottom: 10, right: 12, child: GestureDetector(
              onTap: () => _showInviteSheet(context, _inviteCode, _name),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.gold.withOpacity(0.35))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('INVITE CODE', style: TextStyle(fontFamily: 'Inter', fontSize: 8,
                      letterSpacing: 1.2, color: Colors.white54)),
                    Text(_inviteCode, style: TextStyle(fontFamily: 'Inter', fontSize: 15,
                      fontWeight: FontWeight.w800, color: AppColors.gold, letterSpacing: 3)),
                  ]),
                  const SizedBox(width: 8),
                  Icon(Icons.ios_share_rounded, size: 16, color: AppColors.gold),
                ]),
              ))),
          ])),
        ),

        TabBar(controller: _inner, indicatorColor: AppColors.gold, indicatorWeight: 2,
          labelColor: AppColors.label(context), unselectedLabelColor: AppColors.textDim,
          labelStyle: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(fontFamily: 'Inter', fontSize: 13),
          tabs: const [Tab(text: 'Feed'), Tab(text: 'Prayers'), Tab(text: 'Challenges')]),
        Divider(color: AppColors.divider(context), height: 1),

        Expanded(child: Stack(children: [
          TabBarView(controller: _inner, children: [
            _FeedTab(groupId: _groupId),
            _PrayersTab(groupId: _groupId),
            _ChallengesTab(groupId: _groupId, isCreator: _isCreator),
          ]),
          Positioned(bottom: 20, right: 20, child: FloatingActionButton(
            heroTag: '${_groupId}_detail',
            backgroundColor: AppColors.gold, foregroundColor: AppColors.black,
            onPressed: () {
              if (_innerIndex == 0) _showNewPost(context, _groupId);
              if (_innerIndex == 1) _showNewPrayer(context, _groupId);
              if (_innerIndex == 2 && _isCreator) _showNewChallenge(context, _groupId);
            },
            child: Icon(_innerIndex == 1 ? Icons.volunteer_activism_outlined
              : _innerIndex == 2 ? Icons.flag_outlined : Icons.add))),
        ])),
      ]),
    );
  }
}

// ── Feed tab ──────────────────────────────────────────────────────────────────

class _FeedTab extends StatelessWidget {
  final String groupId;
  const _FeedTab({required this.groupId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups').doc(groupId).collection('feed')
          .orderBy('createdAt', descending: true).limit(30).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: AppColors.gold));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const _EmptyTab(icon: Icons.chat_bubble_outline,
            message: 'No posts yet.\nTap + to share a verse, thought, or study update.');
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: docs.length, separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            return _FeedCard(item: {...d, 'feedDocId': docs[i].id, 'groupId': groupId});
          });
      },
    );
  }
}

// ── Prayers tab ───────────────────────────────────────────────────────────────

class _PrayersTab extends StatelessWidget {
  final String groupId;
  const _PrayersTab({required this.groupId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups').doc(groupId).collection('prayers')
          .orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: AppColors.gold));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const _EmptyTab(icon: Icons.volunteer_activism_outlined,
            message: 'No prayer requests yet.\nTap + to share a prayer need.');
        }
        final active   = docs.where((d) => (d.data() as Map)['isAnswered'] != true).toList();
        final answered = docs.where((d) => (d.data() as Map)['isAnswered'] == true).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            if (active.isNotEmpty) ...[
              _Label('Praying for'), const SizedBox(height: 8),
              ...active.map((d) => Padding(padding: const EdgeInsets.only(bottom: 10),
                child: _PrayerCard(doc: d, groupId: groupId))),
            ],
            if (answered.isNotEmpty) ...[
              const SizedBox(height: 16),
              _Label('Answered Prayers 🙌'), const SizedBox(height: 8),
              ...answered.map((d) => Padding(padding: const EdgeInsets.only(bottom: 10),
                child: _PrayerCard(doc: d, groupId: groupId, dimmed: true))),
            ],
          ],
        );
      },
    );
  }
}

class _PrayerCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final String groupId;
  final bool dimmed;
  const _PrayerCard({required this.doc, required this.groupId, this.dimmed = false});

  Future<void> _togglePray() async {
    if (_uid == null) return;
    final d = doc.data() as Map<String, dynamic>;
    final prayedBy = List<String>.from(d['prayedBy'] as List? ?? []);
    final hasPrayed = prayedBy.contains(_uid);
    final updated = hasPrayed ? (prayedBy..remove(_uid)) : (prayedBy..add(_uid!));
    await doc.reference.update({'prayedBy': updated, 'prayedCount': updated.length});
  }

  @override
  Widget build(BuildContext context) {
    final d           = doc.data() as Map<String, dynamic>;
    final authorName  = d['authorName']  as String? ?? 'Someone';
    final request     = d['request']     as String? ?? '';
    final prayedBy    = List<String>.from(d['prayedBy'] as List? ?? []);
    final prayedCount = d['prayedCount'] as int? ?? prayedBy.length;
    final isAnswered  = d['isAnswered']  as bool? ?? false;
    final isOwn       = d['authorUid']   == _uid;
    final hasPrayed   = prayedBy.contains(_uid);
    final dt          = (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    return Opacity(opacity: dimmed ? 0.65 : 1.0,
      child: Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.cardBg(context), borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isAnswered ? AppColors.success.withOpacity(0.4) : AppColors.divider(context))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(isOwn ? 'You' : authorName,
              style: TextStyle(fontFamily: 'Inter', fontSize: 13,
                fontWeight: FontWeight.w600, color: AppColors.label(context)))),
            Text(_timeAgo(dt), style: TextStyle(fontFamily: 'Inter',
              fontSize: 11, color: AppColors.textDim)),
          ]),
          const SizedBox(height: 8),
          Text(request, style: TextStyle(fontFamily: 'Inter', fontSize: 13,
            color: AppColors.label(context), height: 1.5)),
          const SizedBox(height: 10),
          Row(children: [
            if (!isAnswered) GestureDetector(
              onTap: _togglePray,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: hasPrayed ? AppColors.gold.withOpacity(0.15) : AppColors.cardElevated(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: hasPrayed ? AppColors.gold.withOpacity(0.5) : AppColors.divider(context))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('🙏', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 5),
                  Text('$prayedCount praying', style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: hasPrayed ? AppColors.gold : AppColors.sublabel(context))),
                ]))),
            if (isAnswered) Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20)),
              child: Text('✓ Answered', style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                fontWeight: FontWeight.w600, color: AppColors.success))),
            const Spacer(),
            if (isOwn && !isAnswered)
              GestureDetector(
                onTap: () => doc.reference.update({'isAnswered': true}),
                child: Text('Mark answered', style: TextStyle(fontFamily: 'Inter',
                  fontSize: 12, color: AppColors.sublabel(context)))),
          ]),
        ])));
  }
}

// ── Challenges tab ────────────────────────────────────────────────────────────

class _ChallengesTab extends StatelessWidget {
  final String groupId;
  final bool isCreator;
  const _ChallengesTab({required this.groupId, required this.isCreator});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups').doc(groupId).collection('challenges')
          .orderBy('startDate', descending: true).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: AppColors.gold));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _EmptyTab(icon: Icons.flag_outlined,
            message: isCreator
                ? 'No challenges yet.\nTap + to create a group challenge.'
                : 'No challenges yet.\nOnly the group creator can add challenges.');
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: docs.length, separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _ChallengeCard(doc: docs[i], groupId: groupId));
      },
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final String groupId;
  const _ChallengeCard({required this.doc, required this.groupId});

  IconData get _icon {
    switch ((doc.data() as Map<String, dynamic>)['type'] as String?) {
      case 'reading': return Icons.menu_book_outlined;
      case 'memory':  return Icons.stars_outlined;
      default:        return Icons.psychology_outlined;
    }
  }

  void _showProgressPicker(BuildContext context, int current) {
    int selected = current;
    showModalBottomSheet(context: context, backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(builder: (ctx, setLocal) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('My Progress', style: TextStyle(fontFamily: 'Lora', fontSize: 18,
            fontWeight: FontWeight.bold, color: AppColors.label(context))),
          const SizedBox(height: 20),
          Text('$selected%', style: TextStyle(fontFamily: 'Inter', fontSize: 36,
            fontWeight: FontWeight.bold, color: AppColors.gold)),
          Slider(value: selected.toDouble(), min: 0, max: 100, divisions: 20,
            activeColor: AppColors.gold, inactiveColor: AppColors.divider(context),
            onChanged: (v) => setLocal(() => selected = v.toInt())),
          const SizedBox(height: 8),
          _GoldBtn(label: 'Save', onTap: () async {
            await doc.reference.update({'memberProgress.$_uid': selected});
            if (ctx.mounted) Navigator.pop(ctx);
          }),
        ]))));
  }

  @override
  Widget build(BuildContext context) {
    final d          = doc.data() as Map<String, dynamic>;
    final title      = d['title']       as String? ?? 'Challenge';
    final desc       = d['description'] as String? ?? '';
    final passage    = d['passage']     as String?;
    final start      = (d['startDate']  as Timestamp?)?.toDate();
    final end        = (d['endDate']    as Timestamp?)?.toDate();
    final progress   = Map<String, dynamic>.from(d['memberProgress'] as Map? ?? {});
    final myProgress = (progress[_uid] as num?)?.toInt() ?? 0;
    final fmt = DateFormat('MMM d');
    final dateRange  = (start != null && end != null) ? '${fmt.format(start)} – ${fmt.format(end)}' : '';
    final isActive   = end != null && end.isAfter(DateTime.now());
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.cardBg(context), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isActive ? AppColors.gold.withOpacity(0.3) : AppColors.divider(context))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(_icon, color: AppColors.gold, size: 18)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontFamily: 'Inter', fontSize: 14,
              fontWeight: FontWeight.w700, color: AppColors.label(context))),
            if (dateRange.isNotEmpty) Text(dateRange, style: TextStyle(
              fontFamily: 'Inter', fontSize: 11, color: AppColors.sublabel(context))),
          ])),
          if (isActive) Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8)),
            child: Text('Active', style: TextStyle(fontFamily: 'Inter', fontSize: 10,
              fontWeight: FontWeight.w700, color: AppColors.gold))),
        ]),
        if (passage != null) ...[
          const SizedBox(height: 10),
          Text(passage, style: TextStyle(fontFamily: 'Inter', fontSize: 12,
            fontWeight: FontWeight.w600, color: AppColors.gold)),
        ],
        if (desc.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(desc, style: TextStyle(fontFamily: 'Inter', fontSize: 13,
            color: AppColors.sublabel(context), height: 1.4)),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Text('Your progress', style: TextStyle(fontFamily: 'Inter',
            fontSize: 11, color: AppColors.sublabel(context))),
          const Spacer(),
          Text('$myProgress%', style: TextStyle(fontFamily: 'Inter',
            fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.gold)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: myProgress / 100,
            backgroundColor: AppColors.divider(context),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold), minHeight: 5)),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => _showProgressPicker(context, myProgress),
          child: Text('Update progress →', style: TextStyle(fontFamily: 'Inter',
            fontSize: 12, color: AppColors.gold, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

// ── Post / Prayer / Challenge sheets ─────────────────────────────────────────

void _showNewPost(BuildContext context, String groupId) {
  showModalBottomSheet(context: context, isScrollControlled: true,
    backgroundColor: AppColors.cardDark,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _NewPostSheet(groupId: groupId));
}

class _NewPostSheet extends StatefulWidget {
  final String groupId;
  const _NewPostSheet({required this.groupId});
  @override
  State<_NewPostSheet> createState() => _NewPostSheetState();
}

class _NewPostSheetState extends State<_NewPostSheet> {
  String _type = 'general';
  final _content = TextEditingController();
  final _passage = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    if (_content.text.trim().isEmpty || _uid == null) return;
    setState(() => _saving = true);
    await FirebaseFirestore.instance
        .collection('groups').doc(widget.groupId).collection('feed').add({
      'type': _type, 'authorUid': _uid, 'authorName': _uname ?? 'Anonymous',
      'content': _content.text.trim(),
      if (_passage.text.trim().isNotEmpty) 'passage': _passage.text.trim(),
      'commentCount': 0, 'createdAt': FieldValue.serverTimestamp(),
    });
    await FirebaseFirestore.instance.collection('groups').doc(widget.groupId)
        .update({'lastActivity': FieldValue.serverTimestamp()});
    BadgeService().onGroupPost(); // fire-and-forget
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() { _content.dispose(); _passage.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      _SheetHandle(),
      Text('New Post', style: TextStyle(fontFamily: 'Lora', fontSize: 20,
        fontWeight: FontWeight.bold, color: AppColors.label(context))),
      const SizedBox(height: 16),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        for (final t in [
          ('general', 'Thought', Icons.chat_bubble_outline),
          ('verse_share', 'Verse', Icons.menu_book_outlined),
          ('study', 'Study', Icons.psychology_outlined),
          ('question', 'Question', Icons.help_outline),
        ])
          GestureDetector(
            onTap: () => setState(() => _type = t.$1),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _type == t.$1 ? AppColors.gold.withOpacity(0.15) : AppColors.cardElevated(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _type == t.$1 ? AppColors.gold.withOpacity(0.5) : AppColors.divider(context))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(t.$3, size: 13, color: _type == t.$1 ? AppColors.gold : AppColors.sublabel(context)),
                const SizedBox(width: 5),
                Text(t.$2, style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _type == t.$1 ? AppColors.gold : AppColors.sublabel(context))),
              ])),
          ),
      ])),
      const SizedBox(height: 14),
      if (_type == 'verse_share') ...[
        _Field(ctrl: _passage, hint: 'Passage (e.g. John 3:16)', minLines: 1),
        const SizedBox(height: 10),
      ],
      _Field(ctrl: _content,
        hint: _type == 'question' ? 'What\'s your question?'
            : _type == 'verse_share' ? 'What stood out to you?'
            : 'Share something with your group…',
        minLines: 3),
      const SizedBox(height: 16),
      _GoldBtn(label: 'Post', onTap: _saving ? null : _save, loading: _saving),
    ]),
  );
}

void _showNewPrayer(BuildContext context, String groupId) {
  showModalBottomSheet(context: context, isScrollControlled: true,
    backgroundColor: AppColors.cardDark,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _NewPrayerSheet(groupId: groupId));
}

class _NewPrayerSheet extends StatefulWidget {
  final String groupId;
  const _NewPrayerSheet({required this.groupId});
  @override
  State<_NewPrayerSheet> createState() => _NewPrayerSheetState();
}

class _NewPrayerSheetState extends State<_NewPrayerSheet> {
  final _request = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    if (_request.text.trim().isEmpty || _uid == null) return;
    setState(() => _saving = true);
    await FirebaseFirestore.instance
        .collection('groups').doc(widget.groupId).collection('prayers').add({
      'authorUid': _uid, 'authorName': _uname ?? 'Anonymous',
      'request': _request.text.trim(),
      'isAnswered': false, 'prayedBy': [], 'prayedCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    BadgeService().onPrayerRequest(); // fire-and-forget
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() { _request.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      _SheetHandle(),
      Text('Prayer Request', style: TextStyle(fontFamily: 'Lora', fontSize: 20,
        fontWeight: FontWeight.bold, color: AppColors.label(context))),
      const SizedBox(height: 6),
      Text('Share what\'s on your heart.',
        style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.sublabel(context))),
      const SizedBox(height: 16),
      _Field(ctrl: _request, hint: 'What would you like prayer for?', minLines: 4),
      const SizedBox(height: 16),
      _GoldBtn(label: 'Share Request', onTap: _saving ? null : _save, loading: _saving),
    ]),
  );
}

void _showNewChallenge(BuildContext context, String groupId) {
  showModalBottomSheet(context: context, isScrollControlled: true,
    backgroundColor: AppColors.cardDark,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _NewChallengeSheet(groupId: groupId));
}

class _NewChallengeSheet extends StatefulWidget {
  final String groupId;
  const _NewChallengeSheet({required this.groupId});
  @override
  State<_NewChallengeSheet> createState() => _NewChallengeSheetState();
}

class _NewChallengeSheetState extends State<_NewChallengeSheet> {
  final _title   = TextEditingController();
  final _desc    = TextEditingController();
  final _passage = TextEditingController();
  String _type = 'reading';
  DateTime _start = DateTime.now();
  DateTime _end   = DateTime.now().add(const Duration(days: 7));
  bool _saving = false;

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _uid == null) return;
    setState(() => _saving = true);
    await FirebaseFirestore.instance
        .collection('groups').doc(widget.groupId).collection('challenges').add({
      'title': _title.text.trim(), 'description': _desc.text.trim(), 'type': _type,
      if (_passage.text.trim().isNotEmpty) 'passage': _passage.text.trim(),
      'startDate': Timestamp.fromDate(_start), 'endDate': Timestamp.fromDate(_end),
      'memberProgress': {}, 'createdAt': FieldValue.serverTimestamp(),
    });
    if (mounted) Navigator.pop(context);
  }

  String _fmt(DateTime d) => DateFormat('MMM d, yyyy').format(d);

  @override
  void dispose() { _title.dispose(); _desc.dispose(); _passage.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      _SheetHandle(),
      Text('New Challenge', style: TextStyle(fontFamily: 'Lora', fontSize: 20,
        fontWeight: FontWeight.bold, color: AppColors.label(context))),
      const SizedBox(height: 16),
      _Field(ctrl: _title, hint: 'Challenge title', minLines: 1),
      const SizedBox(height: 10),
      _Field(ctrl: _desc, hint: 'Description (optional)', minLines: 2),
      const SizedBox(height: 10),
      _Field(ctrl: _passage, hint: 'Passage or book (optional)', minLines: 1),
      const SizedBox(height: 14),
      Row(children: [
        for (final t in [
          ('reading', 'Reading', Icons.menu_book_outlined),
          ('study',   'Study',   Icons.psychology_outlined),
          ('memory',  'Memory',  Icons.stars_outlined),
        ])
          Expanded(child: GestureDetector(
            onTap: () => setState(() => _type = t.$1),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _type == t.$1 ? AppColors.gold.withOpacity(0.12) : AppColors.cardElevated(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _type == t.$1 ? AppColors.gold.withOpacity(0.5) : AppColors.divider(context))),
              child: Column(children: [
                Icon(t.$3, size: 16, color: _type == t.$1 ? AppColors.gold : AppColors.sublabel(context)),
                const SizedBox(height: 4),
                Text(t.$2, style: TextStyle(fontFamily: 'Inter', fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _type == t.$1 ? AppColors.gold : AppColors.sublabel(context))),
              ])))),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _DateTile(label: 'Start', date: _fmt(_start),
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: _start,
              firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
            if (d != null) setState(() => _start = d);
          })),
        const SizedBox(width: 10),
        Expanded(child: _DateTile(label: 'End', date: _fmt(_end),
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: _end,
              firstDate: _start, lastDate: DateTime.now().add(const Duration(days: 365)));
            if (d != null) setState(() => _end = d);
          })),
      ]),
      const SizedBox(height: 16),
      _GoldBtn(label: 'Create Challenge', onTap: _saving ? null : _save, loading: _saving),
    ]),
  );
}

// ── Invite sheet ──────────────────────────────────────────────────────────────

void _showInviteSheet(BuildContext context, String code, String groupName) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.cardDark,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _SheetHandle(),
          const SizedBox(height: 4),
          Text('Invite to $groupName',
            style: TextStyle(fontFamily: 'Lora', fontSize: 20,
              fontWeight: FontWeight.bold, color: AppColors.warmWhite)),
          const SizedBox(height: 6),
          Text('Share this code with friends to let them join.',
            style: TextStyle(fontFamily: 'Inter', fontSize: 13,
              color: AppColors.warmWhite.withOpacity(0.5))),
          const SizedBox(height: 24),

          // Big code display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gold.withOpacity(0.3))),
            child: Text(code,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Inter', fontSize: 36,
                fontWeight: FontWeight.w900, color: AppColors.gold,
                letterSpacing: 8)),
          ),

          const SizedBox(height: 20),

          // Share button
          GestureDetector(
            onTap: () {
              Share.share(
                'Join my Bible study group "$groupName" on Dig Deeper!\n\nUse invite code: $code\n\nDownload the app to get started.',
              );
            },
            child: Container(
              width: double.infinity, height: 50,
              decoration: BoxDecoration(
                color: AppColors.gold, borderRadius: BorderRadius.circular(14)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.ios_share_rounded, color: AppColors.black, size: 18),
                const SizedBox(width: 8),
                Text('Share Invite', style: TextStyle(fontFamily: 'Inter',
                  fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.black)),
              ])),
          ),

          const SizedBox(height: 10),

          // Copy button
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invite code copied!')));
            },
            child: Container(
              width: double.infinity, height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.warmWhite.withOpacity(0.12))),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.copy_outlined,
                  color: AppColors.warmWhite.withOpacity(0.6), size: 18),
                const SizedBox(width: 8),
                Text('Copy Code', style: TextStyle(fontFamily: 'Inter',
                  fontSize: 15, fontWeight: FontWeight.w600,
                  color: AppColors.warmWhite.withOpacity(0.6))),
              ])),
          ),
        ]),
      ),
    ),
  );
}

// ── Create / Join ─────────────────────────────────────────────────────────────

void _showCreateGroup(BuildContext context) {
  showModalBottomSheet(context: context, isScrollControlled: true,
    backgroundColor: AppColors.cardDark,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => const _CreateGroupSheet());
}

class _CreateGroupSheet extends StatefulWidget {
  const _CreateGroupSheet();
  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  bool _saving = false;

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty || _uid == null) return;
    setState(() => _saving = true);
    try {
      final groupRef = FirebaseFirestore.instance.collection('groups').doc();
      await groupRef.set({
        'name': name,
        'description': _desc.text.trim(),
        'creatorUid': _uid,
        'memberIds': [_uid],
        'memberCount': 1,
        'inviteCode': _generateCode(),
        'lastActivity': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      await groupRef.collection('members').doc(_uid).set({
        'role': 'creator',
        'name': _uname ?? 'Anonymous',
        'joinedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create group: $e')));
      }
    }
  }

  @override
  void dispose() { _name.dispose(); _desc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      _SheetHandle(),
      Text('Create a Group', style: TextStyle(fontFamily: 'Lora', fontSize: 20,
        fontWeight: FontWeight.bold, color: AppColors.label(context))),
      const SizedBox(height: 6),
      Text('Give your group a name. Members join with a 6-letter code.',
        style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.sublabel(context))),
      const SizedBox(height: 16),
      _Field(ctrl: _name, hint: 'Group name', minLines: 1),
      const SizedBox(height: 10),
      _Field(ctrl: _desc, hint: 'Description (optional)', minLines: 2),
      const SizedBox(height: 16),
      _GoldBtn(label: 'Create Group', onTap: _saving ? null : _create, loading: _saving),
    ]),
  );
}

void _showJoinGroup(BuildContext context) {
  showModalBottomSheet(context: context, isScrollControlled: true,
    backgroundColor: AppColors.cardDark,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => const _JoinGroupSheet());
}

class _JoinGroupSheet extends StatefulWidget {
  const _JoinGroupSheet();
  @override
  State<_JoinGroupSheet> createState() => _JoinGroupSheetState();
}

class _JoinGroupSheetState extends State<_JoinGroupSheet> {
  final _code = TextEditingController();
  bool _joining = false;
  String? _error;

  Future<void> _join() async {
    final code = _code.text.trim().toUpperCase();
    if (code.length != 6 || _uid == null) return;
    setState(() { _joining = true; _error = null; });
    final snap = await FirebaseFirestore.instance
        .collection('groups').where('inviteCode', isEqualTo: code).limit(1).get();
    if (snap.docs.isEmpty) {
      setState(() { _error = 'No group found with that code.'; _joining = false; });
      return;
    }
    final groupRef  = snap.docs.first.reference;
    final groupData = snap.docs.first.data();
    final members   = List<String>.from(groupData['memberIds'] as List? ?? []);
    if (members.contains(_uid)) {
      setState(() { _error = 'You\'re already in this group.'; _joining = false; });
      return;
    }
    final batch = FirebaseFirestore.instance.batch();
    batch.update(groupRef, {
      'memberIds': FieldValue.arrayUnion([_uid]),
      'memberCount': FieldValue.increment(1),
      'lastActivity': FieldValue.serverTimestamp(),
    });
    batch.set(groupRef.collection('members').doc(_uid), {
      'role': 'member', 'name': _uname ?? 'Anonymous',
      'joinedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() { _code.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      _SheetHandle(),
      Text('Join a Group', style: TextStyle(fontFamily: 'Lora', fontSize: 20,
        fontWeight: FontWeight.bold, color: AppColors.label(context))),
      const SizedBox(height: 6),
      Text('Enter the 6-character invite code.',
        style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.sublabel(context))),
      const SizedBox(height: 16),
      TextField(controller: _code, textCapitalization: TextCapitalization.characters,
        maxLength: 6, textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Inter', fontSize: 24,
          fontWeight: FontWeight.w800, color: AppColors.label(context), letterSpacing: 8),
        decoration: InputDecoration(
          hintText: 'ABC123',
          hintStyle: TextStyle(color: AppColors.textDim, fontSize: 24, letterSpacing: 8),
          counterText: '', filled: true, fillColor: AppColors.cardElevated(context),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          errorText: _error)),
      const SizedBox(height: 16),
      _GoldBtn(label: 'Join Group', onTap: _joining ? null : _join, loading: _joining),
    ]),
  );
}

// ── Shared UI atoms ───────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  final bool gold;
  const _StatChip({required this.value, required this.label, this.gold = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: gold ? AppColors.gold.withOpacity(0.1) : AppColors.cardBg(context),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: gold ? AppColors.gold.withOpacity(0.3) : AppColors.divider(context))),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: TextStyle(fontFamily: 'Inter', fontSize: 16,
        fontWeight: FontWeight.w800, color: gold ? AppColors.gold : AppColors.label(context))),
      Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 10,
        color: AppColors.sublabel(context), fontWeight: FontWeight.w600)),
    ]));
}

class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyTab({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(40),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 60, height: 60,
        decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: AppColors.gold, size: 28)),
      const SizedBox(height: 16),
      Text(message, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Inter',
        fontSize: 14, color: AppColors.sublabel(context), height: 1.55)),
    ])));
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(fontFamily: 'Inter',
    fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.sublabel(context), letterSpacing: 0.8));
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final int minLines;
  const _Field({required this.ctrl, required this.hint, this.minLines = 1});

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl, minLines: minLines, maxLines: minLines == 1 ? 1 : 8,
    style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.label(context)),
    decoration: InputDecoration(hintText: hint,
      hintStyle: TextStyle(color: AppColors.textDim, fontFamily: 'Inter', fontSize: 14),
      filled: true, fillColor: AppColors.cardElevated(context),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)));
}

class _DateTile extends StatelessWidget {
  final String label;
  final String date;
  final VoidCallback onTap;
  const _DateTile({required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.cardElevated(context), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider(context))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 10,
          fontWeight: FontWeight.w700, color: AppColors.sublabel(context), letterSpacing: 0.6)),
        const SizedBox(height: 4),
        Text(date, style: TextStyle(fontFamily: 'Inter', fontSize: 13,
          fontWeight: FontWeight.w600, color: AppColors.label(context))),
      ])));
}

class _GoldBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  const _GoldBtn({required this.label, this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(width: double.infinity, height: 50,
      decoration: BoxDecoration(
        color: onTap == null ? AppColors.gold.withOpacity(0.5) : AppColors.gold,
        borderRadius: BorderRadius.circular(14)),
      child: Center(child: loading
          ? const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(color: AppColors.black, strokeWidth: 2))
          : Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 15,
              fontWeight: FontWeight.w700, color: AppColors.black)))));
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(width: double.infinity, height: 50,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider(context))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: AppColors.label(context), size: 18),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 15,
          fontWeight: FontWeight.w600, color: AppColors.label(context))),
      ])));
}

class _HeaderIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(width: 36, height: 36,
      decoration: BoxDecoration(color: AppColors.cardBg(context), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider(context))),
      child: Icon(icon, color: AppColors.label(context), size: 18)));
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16), width: 36, height: 4,
    decoration: BoxDecoration(color: AppColors.divider(context), borderRadius: BorderRadius.circular(2)));
}

class _FeedFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FeedFilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? AppColors.gold : AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? AppColors.gold : AppColors.divider(context))),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: TextStyle(fontFamily: 'Inter', fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? AppColors.black : AppColors.sublabel(context))),
    ),
  );
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _MenuTile({required this.icon, required this.label, required this.onTap,
    this.color = AppColors.warmWhite});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 15,
        fontWeight: FontWeight.w500, color: color)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    ),
  );
}
