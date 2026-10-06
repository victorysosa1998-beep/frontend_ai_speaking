import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'social_service.dart';
import 'voice_selection_screen.dart';
import 'group_call_page.dart';
import 'login_page.dart';
import 'account_deletion_page.dart';
import 'app_brand.dart';
import 'ovie_ui.dart';
import 'group_chat_page.dart';
import 'direct_chat_page.dart';
import 'call_screen_video.dart';

const _accent = OvieBrand.primary;
const _card = OvieBrand.card;

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

String _initial(dynamic name) {
  final s = (name ?? '').toString().trim();
  return s.isEmpty ? '?' : String.fromCharCode(s.runes.first).toUpperCase();
}

String _ago(Timestamp? t) {
  if (t == null) return 'now';
  final date = t.toDate();
  final diff = DateTime.now().difference(date);
  if (diff.inSeconds < 60) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${date.day}/${date.month}/${date.year % 100}';
}

InputDecoration _field(
  String hint, {
  String? label,
  String? helper,
  String? prefixText,
  Widget? prefix,
  Widget? suffix,
}) {
  OutlineInputBorder border([Color? c, double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: c == null ? BorderSide.none : BorderSide(color: c, width: w),
  );
  return InputDecoration(
    hintText: hint,
    labelText: label,
    helperText: helper,
    prefixText: prefixText,
    prefixIcon: prefix,
    suffixIcon: suffix,
    hintStyle: const TextStyle(color: Colors.white38),
    labelStyle: const TextStyle(color: Colors.white54),
    helperStyle: const TextStyle(color: Colors.white38),
    prefixStyle: const TextStyle(color: Colors.white70),
    counterStyle: const TextStyle(color: Colors.white38),
    filled: true,
    fillColor: Colors.white.withValues(alpha: .07),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: border(),
    enabledBorder: border(),
    focusedBorder: border(_accent, 1.4),
  );
}

Future<T?> _showSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _card,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: builder,
  );
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String _cleanError(Object e) => e
    .toString()
    .replaceFirst('Bad state: ', '')
    .replaceFirst('FormatException: ', '')
    .replaceFirst('Exception: ', '');

class _Avatar extends StatelessWidget {
  final String? photo;
  final dynamic name;
  final double radius;
  final bool ring;
  const _Avatar({
    required this.photo,
    required this.name,
    this.radius = 22,
    this.ring = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photo != null && photo!.isNotEmpty;
    final core = CircleAvatar(
      radius: radius,
      backgroundColor: _accent.withValues(alpha: .35),
      backgroundImage: hasPhoto ? NetworkImage(photo!) : null,
      child: hasPhoto
          ? null
          : Text(
              _initial(name),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: radius * .75,
              ),
            ),
    );
    if (!ring) return core;
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: OvieBrand.royalGradient,
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: OvieBrand.background,
        ),
        child: core,
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  const _PageHeader({required this.title, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.6,
                ),
              ),
            ),
            for (final a in actions) ...[const SizedBox(width: 8), a],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _accent.withValues(alpha: .14),
                border: Border.all(color: _accent.withValues(alpha: .25)),
              ),
              child: Icon(icon, color: _accent, size: 34),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, height: 1.4),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final dynamic value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '$value',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 20,
        ),
      ),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
    ],
  );
}

class _StatsRow extends StatelessWidget {
  final List<Widget> stats;
  const _StatsRow(this.stats);

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < stats.length; i++) {
      if (i > 0) {
        children.add(
          Container(width: 1, height: 28, color: Colors.white.withValues(alpha: .08)),
        );
      }
      children.add(Expanded(child: Center(child: stats[i])));
    }
    return OvieGlassCard(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(children: children),
    );
  }
}

/// Gradient banner + overlapping avatar used by both profile pages.
class _ProfileHero extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onAvatarTap;
  const _ProfileHero({required this.data, this.onAvatarTap});

  @override
  Widget build(BuildContext context) {
    final name = data['display_name'] ?? 'Ovie User';
    final username = (data['username'] ?? '').toString();
    final bio = (data['bio'] ?? '').toString();
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                height: 100,
                margin: const EdgeInsets.only(bottom: 50),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: LinearGradient(
                    colors: [
                      _accent.withValues(alpha: .55),
                      OvieBrand.secondary.withValues(alpha: .35),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                child: GestureDetector(
                  onTap: onAvatarTap,
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: OvieBrand.background,
                        ),
                        child: _Avatar(
                          photo: data['photo_url']?.toString(),
                          name: name,
                          radius: 48,
                        ),
                      ),
                      if (onAvatarTap != null)
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: OvieBrand.royalGradient,
                              border: Border.all(
                                color: OvieBrand.background,
                                width: 3,
                              ),
                            ),
                            child: const Icon(
                              Icons.photo_camera_rounded,
                              size: 15,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '$name',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -.4,
          ),
        ),
        if (username.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '@$username',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ),
        if (bio.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              bio,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App shell
// ─────────────────────────────────────────────────────────────────────────────

class SocialHome extends StatefulWidget {
  const SocialHome({super.key});
  @override
  State<SocialHome> createState() => _SocialHomeState();
}

class _SocialHomeState extends State<SocialHome> {
  int tab = 0;
  final service = SocialService.instance;

  @override
  void initState() {
    super.initState();
    service.ensureSocialProfile();
  }

  @override
  Widget build(BuildContext context) {
    const selectedColor = Colors.white;
    final idleColor = Colors.white.withValues(alpha: .5);
    return Scaffold(
      backgroundColor: OvieBrand.background,
      body: OvieBackground(
        // Transparent Material so ink splashes paint above the gradient.
        child: Material(
          type: MaterialType.transparency,
          child: IndexedStack(
            index: tab,
            children: const [
              SocialFeedPage(),
              DiscoverPage(),
              MessagesPage(),
              OvieHubPage(),
              SocialProfilePage(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF0B0D20),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: .07)),
          ),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            labelTextStyle: WidgetStateProperty.resolveWith(
              (s) => TextStyle(
                fontSize: 11,
                fontWeight: s.contains(WidgetState.selected)
                    ? FontWeight.w800
                    : FontWeight.w500,
                color: s.contains(WidgetState.selected)
                    ? selectedColor
                    : idleColor,
              ),
            ),
            iconTheme: WidgetStateProperty.resolveWith(
              (s) => IconThemeData(
                color: s.contains(WidgetState.selected)
                    ? selectedColor
                    : idleColor,
              ),
            ),
          ),
          child: NavigationBar(
            height: 68,
            backgroundColor: Colors.transparent,
            indicatorColor: _accent.withValues(alpha: .28),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore_rounded),
                label: 'Discover',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline_rounded),
                selectedIcon: Icon(Icons.chat_bubble_rounded),
                label: 'Chats',
              ),
              NavigationDestination(
                icon: Icon(Icons.auto_awesome_outlined),
                selectedIcon: Icon(Icons.auto_awesome),
                label: 'Ovie',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Me',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> requireUgcTerms(BuildContext context) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return false;
  final snap = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .get();
  if (snap.data()?['ugc_terms_accepted'] == true) return true;
  if (!context.mounted) return false;
  var accepted = false;
  await showDialog(
    context: context,
    builder: (d) => AlertDialog(
      backgroundColor: _card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text(
        'Before you post',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      ),
      content: const Text(
        'Ovie is a social space. By posting, you agree not to upload threats, harassment, illegal content, sexual content involving minors, or content that targets people for abuse. You can report and block users at any time.',
        style: TextStyle(color: Colors.white70, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () {
            accepted = true;
            Navigator.pop(d);
          },
          child: const Text('I agree'),
        ),
      ],
    ),
  );
  if (accepted) {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'ugc_terms_accepted': true,
      'ugc_terms_accepted_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
  return accepted;
}

// ─────────────────────────────────────────────────────────────────────────────
// Feed
// ─────────────────────────────────────────────────────────────────────────────

/// Reusable "write something" sheet for posts and statuses.
class _ComposeSheet extends StatefulWidget {
  final String title;
  final String hint;
  final String note;
  final String button;
  final int maxLength;
  final Future<void> Function(String text) onSubmit;
  const _ComposeSheet({
    required this.title,
    required this.hint,
    required this.button,
    required this.maxLength,
    required this.onSubmit,
    this.note = '',
  });

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  final c = TextEditingController();
  bool posting = false;
  String? error;

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = c.text.trim();
    if (text.isEmpty || posting) return;
    setState(() {
      posting = true;
      error = null;
    });
    try {
      await widget.onSubmit(text);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          posting = false;
          error = 'Could not post. Check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: SocialService.instance.myProfile(),
                builder: (context, s) {
                  final d = s.data?.data() ?? {};
                  return _Avatar(
                    photo: d['photo_url']?.toString(),
                    name: d['display_name'],
                    radius: 20,
                  );
                },
              ),
              const SizedBox(width: 12),
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: c,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            maxLength: widget.maxLength,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(color: Colors.white, height: 1.4),
            cursorColor: _accent,
            decoration: _field(widget.hint),
          ),
          if (widget.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 6),
              child: Text(
                widget.note,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),
          const SizedBox(height: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: c,
            builder: (context, v, _) => OvieGradientButton(
              label: posting ? 'Posting…' : widget.button,
              active: v.text.trim().isNotEmpty && !posting,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }
}

class SocialFeedPage extends StatefulWidget {
  const SocialFeedPage({super.key});
  @override
  State<SocialFeedPage> createState() => _SocialFeedPageState();
}

class _SocialFeedPageState extends State<SocialFeedPage> {
  final s = SocialService.instance;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _feed = s.feed();

  Future<void> compose() async {
    if (!await requireUgcTerms(context)) return;
    if (!mounted) return;
    await _showSheet(
      context,
      (_) => _ComposeSheet(
        title: 'What’s your vibe?',
        hint: 'Post a thought, gist, win or random idea…',
        button: 'Post',
        maxLength: 500,
        onSubmit: (t) => s.createPost(t),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverAppBar(
        floating: true,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 64,
        titleSpacing: 20,
        title: const OvieLogo(size: 34),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: OvieIconButton(
              icon: Icons.search_rounded,
              onTap: () =>
                  showSearch(context: context, delegate: UserSearchDelegate()),
            ),
          ),
        ],
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
          child: OvieGlassCard(
            onTap: compose,
            radius: 22,
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Row(
              children: [
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: s.myProfile(),
                  builder: (context, snap) {
                    final d = snap.data?.data() ?? {};
                    return _Avatar(
                      photo: d['photo_url']?.toString(),
                      name: d['display_name'],
                      radius: 20,
                    );
                  },
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'What’s your vibe?',
                    style: TextStyle(color: Colors.white54, fontSize: 15),
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: OvieBrand.royalGradient,
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
      const SliverToBoxAdapter(child: StatusStrip()),
      const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 4),
          child: Text(
            'For you',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
              letterSpacing: -.3,
            ),
          ),
        ),
      ),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _feed,
        builder: (c, snap) {
          if (snap.hasError) {
            return const SliverToBoxAdapter(
              child: _EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load your feed',
                body: 'Check your connection and try again.',
              ),
            );
          }
          if (!snap.hasData) {
            return SliverList.builder(
              itemCount: 3,
              itemBuilder: (_, __) => const _PostSkeleton(),
            );
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return SliverToBoxAdapter(
              child: _EmptyState(
                icon: Icons.bubble_chart_rounded,
                title: 'Nothing here yet',
                body: 'Be the first to share something with the community.',
                actionLabel: 'Write a post',
                onAction: compose,
              ),
            );
          }
          return SliverList.builder(
            itemCount: docs.length,
            itemBuilder: (c, i) =>
                PostCard(key: ValueKey(docs[i].id), doc: docs[i]),
          );
        },
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ],
  );
}

class _PostSkeleton extends StatelessWidget {
  const _PostSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, [double h = 12]) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(6),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: OvieGlassCard(
        radius: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white.withValues(alpha: .08),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [bar(120, 13), const SizedBox(height: 6), bar(70)],
                ),
              ],
            ),
            const SizedBox(height: 16),
            bar(double.infinity),
            const SizedBox(height: 8),
            bar(220),
          ],
        ),
      ),
    );
  }
}

// ── Statuses ────────────────────────────────────────────────────────────────

class StatusStrip extends StatelessWidget {
  const StatusStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SocialService.instance;
    return SizedBox(
      height: 106,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: s.statuses(),
        builder: (c, snap) {
          final docs = snap.data?.docs ?? [];
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: docs.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (c, i) {
              if (i == 0) return const _AddStatus();
              final doc = docs[i - 1];
              final d = doc.data();
              return GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => StatusViewer(doc: doc),
                  ),
                ),
                child: Column(
                  children: [
                    _Avatar(
                      photo: d['author_photo']?.toString(),
                      name: d['author_name'],
                      radius: 27,
                      ring: true,
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 66,
                      child: Text(
                        (d['author_name'] ?? 'User').toString(),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AddStatus extends StatelessWidget {
  const _AddStatus();

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () async {
      if (!await requireUgcTerms(context)) return;
      if (!context.mounted) return;
      await _showSheet(
        context,
        (_) => _ComposeSheet(
          title: 'Post a status',
          hint: 'What’s happening?',
          note: 'Statuses disappear after 24 hours.',
          button: 'Share status',
          maxLength: 140,
          onSubmit: (t) => SocialService.instance.createStatus(t),
        ),
      );
    },
    child: Column(
      children: [
        SizedBox(
          width: 63,
          height: 63,
          child: Stack(
            alignment: Alignment.center,
            children: [
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: SocialService.instance.myProfile(),
                builder: (context, snap) {
                  final d = snap.data?.data() ?? {};
                  return _Avatar(
                    photo: d['photo_url']?.toString(),
                    name: d['display_name'],
                    radius: 29,
                  );
                },
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: OvieBrand.royalGradient,
                    border: Border.all(color: OvieBrand.background, width: 2),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your status',
          style: TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    ),
  );
}

/// Full-screen, story-style status viewer. Hold to pause; it also pauses
/// while you type or read comments.
class StatusViewer extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const StatusViewer({super.key, required this.doc});
  @override
  State<StatusViewer> createState() => _StatusViewerState();
}

class _StatusViewerState extends State<StatusViewer>
    with SingleTickerProviderStateMixin {
  static const _palettes = [
    [Color(0xFF4C2BD6), Color(0xFF1B2A6B)],
    [Color(0xFF7C3AED), Color(0xFF2563EB)],
    [Color(0xFF0F766E), Color(0xFF1E3A8A)],
    [Color(0xFFBE185D), Color(0xFF5B21B6)],
  ];

  final c = TextEditingController();
  final focus = FocusNode();
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _stream =
      FirebaseFirestore.instance
          .collection('statuses')
          .doc(widget.doc.id)
          .snapshots();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _comments =
      SocialService.instance.statusComments(widget.doc.id);
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    _progress.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        Navigator.of(context).maybePop();
      }
    });
    focus.addListener(_syncPlayback);
    _progress.forward();
  }

  @override
  void dispose() {
    _progress.dispose();
    focus.dispose();
    c.dispose();
    super.dispose();
  }

  void _syncPlayback() {
    if (focus.hasFocus || _sheetOpen) {
      _progress.stop();
    } else if (mounted) {
      _progress.forward();
    }
  }

  Future<void> _sendComment() async {
    final text = c.text.trim();
    if (text.isEmpty) return;
    c.clear();
    focus.unfocus();
    try {
      await SocialService.instance.addStatusComment(widget.doc.id, text);
    } catch (_) {
      if (mounted) _toast(context, 'Could not send your comment.');
    }
  }

  Future<void> _openComments() async {
    _sheetOpen = true;
    _syncPlayback();
    await _showSheet(
      context,
      (_) => _CommentsView(
        stream: _comments,
        onSend: (t) =>
            SocialService.instance.addStatusComment(widget.doc.id, t),
      ),
    );
    _sheetOpen = false;
    _syncPlayback();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palettes[widget.doc.id.hashCode.abs() % _palettes.length];
    return Scaffold(
      backgroundColor: OvieBrand.background,
      body: GestureDetector(
        onLongPressStart: (_) => _progress.stop(),
        onLongPressEnd: (_) => _syncPlayback(),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: palette,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snap) {
                final d = snap.data?.data() ?? widget.doc.data();
                final likes = List<String>.from(d['likes'] ?? []);
                final mine = likes.contains(
                  FirebaseAuth.instance.currentUser?.uid,
                );
                final text = (d['text'] ?? '').toString();
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                      child: AnimatedBuilder(
                        animation: _progress,
                        builder: (_, __) => ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: _progress.value,
                            minHeight: 3,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation(
                              Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 6, 0),
                      child: Row(
                        children: [
                          _Avatar(
                            photo: d['author_photo']?.toString(),
                            name: d['author_name'],
                            radius: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (d['author_name'] ?? 'Status').toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  _ago(d['created_at'] as Timestamp?),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 30),
                          child: Text(
                            text,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: text.length > 120 ? 22 : 30,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _ActionPill(
                                icon: mine
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                label: '${likes.length}',
                                color: mine ? Colors.pinkAccent : Colors.white,
                                onTap: () => SocialService.instance
                                    .toggleStatusLike(widget.doc.id, likes),
                              ),
                              const SizedBox(width: 8),
                              _ActionPill(
                                icon: Icons.chat_bubble_outline_rounded,
                                label: '${d['comments_count'] ?? 0}',
                                color: Colors.white,
                                onTap: _openComments,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: c,
                                  focusNode: focus,
                                  onSubmitted: (_) => _sendComment(),
                                  textInputAction: TextInputAction.send,
                                  style: const TextStyle(color: Colors.white),
                                  cursorColor: Colors.white,
                                  decoration: InputDecoration(
                                    hintText: 'Reply to this status…',
                                    hintStyle: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                    filled: true,
                                    fillColor: Colors.black.withValues(
                                      alpha: .22,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(26),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: palette.first,
                                ),
                                onPressed: _sendComment,
                                icon: const Icon(Icons.arrow_upward_rounded),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ── Posts ───────────────────────────────────────────────────────────────────

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(icon, key: ValueKey(icon), color: color, size: 19),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PostCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const PostCard({super.key, required this.doc});

  void _openAuthor(BuildContext context, String? authorId) {
    if (authorId == null || authorId.isEmpty) return;
    if (authorId == FirebaseAuth.instance.currentUser?.uid) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PublicProfilePage(userId: authorId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final likes = List<String>.from(d['likes'] ?? []);
    final mine = likes.contains(FirebaseAuth.instance.currentUser?.uid);
    final text = (d['text'] ?? '').toString();
    final image = d['image_url']?.toString();
    final authorId = d['author_id']?.toString();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: OvieGlassCard(
        radius: 24,
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => _openAuthor(context, authorId),
                  child: _Avatar(
                    photo: d['author_photo']?.toString(),
                    name: d['author_name'],
                    radius: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openAuthor(context, authorId),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (d['author_name'] ?? 'User').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '@${d['author_username'] ?? ''} • ${_ago(d['created_at'] as Timestamp?)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  color: _card,
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: Colors.white54,
                  ),
                  onSelected: (v) async {
                    if (v == 'report') {
                      await SocialService.instance.reportPost(
                        doc.id,
                        'User reported post',
                      );
                      if (context.mounted) {
                        _toast(context, 'Reported. Thanks for keeping Ovie safe.');
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'report',
                      child: Text(
                        'Report post',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 8, 0),
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
              ),
            if (image != null && image.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 8, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 340),
                    child: Image.network(
                      image,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (c, child, p) => p == null
                          ? child
                          : Container(
                              height: 200,
                              color: Colors.white10,
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                      errorBuilder: (_, __, ___) => Container(
                        height: 120,
                        color: Colors.white10,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                _ActionPill(
                  icon: mine
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: '${likes.length}',
                  color: mine ? Colors.pinkAccent : Colors.white70,
                  onTap: () => SocialService.instance.toggleLike(doc.id, likes),
                ),
                const SizedBox(width: 8),
                _ActionPill(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: '${d['comments_count'] ?? 0}',
                  color: Colors.white70,
                  onTap: () => _showSheet(
                    context,
                    (_) => CommentsSheet(postId: doc.id),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Copy text',
                  onPressed: text.isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(ClipboardData(text: text));
                          if (context.mounted) _toast(context, 'Post copied');
                        },
                  icon: const Icon(
                    Icons.ios_share_rounded,
                    color: Colors.white54,
                    size: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Comments ────────────────────────────────────────────────────────────────

class CommentsSheet extends StatefulWidget {
  final String postId;
  const CommentsSheet({super.key, required this.postId});
  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      SocialService.instance.comments(widget.postId);

  @override
  Widget build(BuildContext context) => _CommentsView(
    stream: _stream,
    onSend: (t) => SocialService.instance.addComment(widget.postId, t),
  );
}

class _CommentsView extends StatefulWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final Future<void> Function(String text) onSend;
  const _CommentsView({required this.stream, required this.onSend});
  @override
  State<_CommentsView> createState() => _CommentsViewState();
}

class _CommentsViewState extends State<_CommentsView> {
  final c = TextEditingController();
  bool sending = false;

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = c.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    c.clear();
    try {
      await widget.onSend(text);
    } catch (_) {
      if (mounted) {
        c.text = text;
        _toast(context, 'Could not send your comment.');
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: media.size.height * .72,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Comments',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: widget.stream,
                builder: (context, s) {
                  if (s.hasError) {
                    return const _EmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load comments',
                      body: 'Try again in a moment.',
                    );
                  }
                  if (!s.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = s.data!.docs;
                  if (docs.isEmpty) {
                    return const _EmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'No comments yet',
                      body: 'Start the conversation.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, i) {
                      final x = docs[i].data();
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Avatar(
                            photo: x['author_photo']?.toString(),
                            name: x['author_name'],
                            radius: 17,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        (x['author_name'] ?? '').toString(),
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _ago(x['created_at'] as Timestamp?),
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  (x['text'] ?? '').toString(),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: c,
                      onSubmitted: (_) => _send(),
                      textInputAction: TextInputAction.send,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(color: Colors.white),
                      cursorColor: _accent,
                      decoration: _field('Add a comment…'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: _accent),
                    onPressed: sending ? null : _send,
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Discover
// ─────────────────────────────────────────────────────────────────────────────

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});
  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final c = TextEditingController();
  Timer? _debounce;
  int _ticket = 0;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> results = [];
  bool loading = false;
  bool searched = false;
  bool failed = false;

  @override
  void dispose() {
    _debounce?.cancel();
    c.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    if (v.trim().isEmpty) {
      _ticket++;
      setState(() {
        results = [];
        searched = false;
        loading = false;
        failed = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), search);
  }

  Future<void> search() async {
    final q = c.text.trim().replaceFirst('@', '');
    if (q.isEmpty) return;
    final ticket = ++_ticket;
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      final r = await SocialService.instance.searchUsers(q);
      if (!mounted || ticket != _ticket) return;
      setState(() {
        results = r;
        searched = true;
        loading = false;
      });
    } catch (_) {
      if (!mounted || ticket != _ticket) return;
      setState(() {
        loading = false;
        failed = true;
      });
    }
  }

  Widget _body() {
    if (failed) {
      return const _EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Search failed',
        body: 'Check your connection and try again.',
      );
    }
    if (!searched && !loading) {
      return const _EmptyState(
        icon: Icons.alternate_email_rounded,
        title: 'Find your people',
        body: 'Search by username to add friends and start a chat.',
      );
    }
    if (searched && results.isEmpty && !loading) {
      return _EmptyState(
        icon: Icons.person_search_rounded,
        title: 'No one found',
        body: 'Nobody matches “${c.text.trim()}”. Check the spelling and try again.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) =>
          UserTile(data: results[i].data(), uid: results[i].id),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _PageHeader(
        title: 'Discover',
        actions: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: SocialService.instance.incomingRequests(),
            builder: (context, snap) {
              final n = snap.data?.docs.length ?? 0;
              return Badge(
                isLabelVisible: n > 0,
                label: Text('$n'),
                backgroundColor: Colors.pinkAccent,
                child: OvieIconButton(
                  icon: Icons.person_add_alt_1_rounded,
                  onTap: () => _showSheet(
                    context,
                    (_) => const FriendRequestsSheet(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: TextField(
          controller: c,
          onChanged: _onChanged,
          onSubmitted: (_) => search(),
          textInputAction: TextInputAction.search,
          autocorrect: false,
          style: const TextStyle(color: Colors.white),
          cursorColor: _accent,
          decoration: _field(
            'Search @username',
            prefix: const Icon(Icons.search_rounded, color: Colors.white54),
            suffix: c.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      c.clear();
                      _onChanged('');
                    },
                    icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  ),
          ),
        ),
      ),
      if (loading)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: LinearProgressIndicator(minHeight: 2),
        ),
      Expanded(child: _body()),
    ],
  );
}

class UserTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final String uid;
  const UserTile({super.key, required this.data, required this.uid});

  @override
  Widget build(BuildContext context) {
    return OvieGlassCard(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PublicProfilePage(userId: uid)),
      ),
      child: Row(
        children: [
          _Avatar(
            photo: data['photo_url']?.toString(),
            name: data['display_name'] ?? 'S',
            radius: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (data['display_name'] ?? 'Ovie User').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${data['username'] ?? ''}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: Colors.white.withValues(alpha: .3),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Public profile
// ─────────────────────────────────────────────────────────────────────────────

class PublicProfilePage extends StatefulWidget {
  final String userId;
  const PublicProfilePage({super.key, required this.userId});
  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  bool busy = false;
  bool requested = false;
  late final Future<bool> _friend = SocialService.instance.areFriends(
    widget.userId,
  );
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _profile =
      FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .snapshots();

  Future<void> _sendRequest() async {
    setState(() => busy = true);
    try {
      await SocialService.instance.sendFriendRequest(widget.userId);
      if (mounted) {
        setState(() => requested = true);
        _toast(context, 'Friend request sent ✨');
      }
    } catch (e) {
      if (mounted) _toast(context, _cleanError(e));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _confirmBlock(String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Block $name?',
          style: const TextStyle(color: Colors.white),
        ),
        content: const Text(
          'They will not be able to message you, and you will not be able to message them.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await SocialService.instance.blockUser(widget.userId);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.userId == FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: OvieBrand.background,
      body: OvieBackground(
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _profile,
              builder: (context, snap) {
                final d = snap.data?.data() ?? {};
                final name = (d['display_name'] ?? 'Ovie User').toString();
                return Column(
                  children: [
                    OvieHeader(
                      title: 'Profile',
                      trailing: isMe
                          ? null
                          : PopupMenuButton<String>(
                              color: _card,
                              icon: const Icon(
                                Icons.more_horiz_rounded,
                                color: Colors.white,
                              ),
                              onSelected: (v) async {
                                if (v == 'report') {
                                  await SocialService.instance.reportUser(
                                    widget.userId,
                                    'Reported from profile',
                                  );
                                  if (context.mounted) {
                                    _toast(context, 'Reported. Thanks.');
                                  }
                                } else if (v == 'block') {
                                  _confirmBlock(name);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'report',
                                  child: Text(
                                    'Report user',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'block',
                                  child: Text(
                                    'Block user',
                                    style: TextStyle(color: Colors.redAccent),
                                  ),
                                ),
                              ],
                            ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                        children: [
                          _ProfileHero(data: d),
                          const SizedBox(height: 22),
                          _StatsRow([
                            _Stat('Friends', d['friends_count'] ?? 0),
                            _Stat('Followers', d['followers_count'] ?? 0),
                            _Stat('Posts', d['posts_count'] ?? 0),
                          ]),
                          if (!isMe) ...[
                            const SizedBox(height: 22),
                            FutureBuilder<bool>(
                              future: _friend,
                              builder: (context, f) {
                                final side = BorderSide(
                                  color: Colors.white.withValues(alpha: .2),
                                );
                                final outlined = OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: side,
                                  minimumSize: const Size.fromHeight(52),
                                  shape: const StadiumBorder(),
                                );
                                final Widget primary;
                                if (f.data == true) {
                                  primary = OutlinedButton.icon(
                                    style: outlined,
                                    onPressed: null,
                                    icon: const Icon(Icons.check_rounded),
                                    label: const Text('Friends'),
                                  );
                                } else if (requested) {
                                  primary = OutlinedButton.icon(
                                    style: outlined,
                                    onPressed: null,
                                    icon: const Icon(Icons.hourglass_top_rounded),
                                    label: const Text('Request sent'),
                                  );
                                } else {
                                  primary = FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _accent,
                                      minimumSize: const Size.fromHeight(52),
                                      shape: const StadiumBorder(),
                                    ),
                                    onPressed: busy ? null : _sendRequest,
                                    icon: const Icon(
                                      Icons.person_add_alt_1_rounded,
                                    ),
                                    label: const Text('Add friend'),
                                  );
                                }
                                return Row(
                                  children: [
                                    Expanded(child: primary),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: outlined,
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => DirectChatScreen(
                                              otherUid: widget.userId,
                                              otherName: name,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.chat_bubble_outline_rounded,
                                        ),
                                        label: const Text('Message'),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class UserSearchDelegate extends SearchDelegate<String> {
  UserSearchDelegate()
    : super(
        searchFieldLabel: 'Search @username',
        searchFieldStyle: const TextStyle(color: Colors.white, fontSize: 16),
      );

  @override
  ThemeData appBarTheme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      scaffoldBackgroundColor: OvieBrand.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: OvieBrand.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.white38),
      ),
      textSelectionTheme: const TextSelectionThemeData(cursorColor: _accent),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext c) => [
    if (query.isNotEmpty)
      IconButton(
        onPressed: () => query = '',
        icon: const Icon(Icons.close_rounded),
      ),
  ];

  @override
  Widget? buildLeading(BuildContext c) => IconButton(
    onPressed: () => close(c, ''),
    icon: const Icon(Icons.arrow_back_rounded),
  );

  @override
  Widget buildResults(BuildContext context) {
    final q = query.trim().replaceFirst('@', '');
    return FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      future: SocialService.instance.searchUsers(q),
      builder: (c, s) {
        if (s.hasError) {
          return const _EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Search failed',
            body: 'Check your connection and try again.',
          );
        }
        if (!s.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.data!.isEmpty) {
          return _EmptyState(
            icon: Icons.person_search_rounded,
            title: 'No one found',
            body: 'Nobody matches “$q”.',
          );
        }
        return Material(
          type: MaterialType.transparency,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: s.data!.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) =>
                UserTile(data: s.data![i].data(), uid: s.data![i].id),
          ),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) => const _EmptyState(
    icon: Icons.alternate_email_rounded,
    title: 'Search Ovie users',
    body: 'Type a username, then press search.',
  );
}

// ── Friend requests ─────────────────────────────────────────────────────────

class FriendRequestsSheet extends StatelessWidget {
  const FriendRequestsSheet({super.key});

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
              'Friend requests',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: SocialService.instance.incomingRequests(),
            builder: (c, s) {
              if (s.hasError) {
                return const _EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load requests',
                  body: 'Try again in a moment.',
                );
              }
              if (!s.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (s.data!.docs.isEmpty) {
                return const _EmptyState(
                  icon: Icons.mark_email_read_outlined,
                  title: 'All caught up',
                  body: 'New friend requests will show up here.',
                );
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: s.data!.docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _RequestTile(doc: s.data!.docs[i]),
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}

class _RequestTile extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _RequestTile({required this.doc});
  @override
  State<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends State<_RequestTile> {
  bool busy = false;
  late final Future<DocumentSnapshot<Map<String, dynamic>>> _user =
      FirebaseFirestore.instance
          .collection('users')
          .doc(widget.doc.data()['from'])
          .get();

  Future<void> _respond(bool accept) async {
    setState(() => busy = true);
    try {
      await SocialService.instance.respondFriendRequest(
        widget.doc.id,
        widget.doc.data()['from'],
        accept,
      );
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        _toast(context, _cleanError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _user,
      builder: (c, s) {
        final p = s.data?.data() ?? {};
        return OvieGlassCard(
          radius: 18,
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              _Avatar(
                photo: p['photo_url']?.toString(),
                name: p['display_name'] ?? 'S',
                radius: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (p['display_name'] ?? 'Someone').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '@${p['username'] ?? ''}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Decline',
                onPressed: busy ? null : () => _respond(false),
                icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
              ),
              IconButton.filled(
                tooltip: 'Accept',
                style: IconButton.styleFrom(backgroundColor: _accent),
                onPressed: busy ? null : () => _respond(true),
                icon: const Icon(Icons.check_rounded),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chats
// ─────────────────────────────────────────────────────────────────────────────

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Column(
      children: [
        _PageHeader(
          title: 'Chats',
          actions: [
            OvieIconButton(
              icon: Icons.group_add_rounded,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GroupListPage()),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Container(
            height: 48,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: .08)),
            ),
            child: TabBar(
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              splashBorderRadius: BorderRadius.circular(18),
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              indicator: BoxDecoration(
                gradient: OvieBrand.royalGradient,
                borderRadius: BorderRadius.circular(18),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800),
              tabs: const [
                Tab(height: 38, text: 'People'),
                Tab(height: 38, text: 'AI Groups'),
              ],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            children: [
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: SocialService.instance.conversations(),
                builder: (c, s) {
                  if (s.hasError) {
                    return const _EmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load chats',
                      body: 'Check your connection and try again.',
                    );
                  }
                  if (!s.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (s.data!.docs.isEmpty) {
                    return const _EmptyState(
                      icon: Icons.forum_outlined,
                      title: 'No chats yet',
                      body: 'Find someone on Discover and say hi.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: s.data!.docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => ConversationTile(
                      key: ValueKey(s.data!.docs[i].id),
                      data: s.data!.docs[i].data(),
                    ),
                  );
                },
              ),
              const GroupListPage(embedded: true),
            ],
          ),
        ),
      ],
    ),
  );
}

class ConversationTile extends StatefulWidget {
  final Map<String, dynamic> data;
  const ConversationTile({super.key, required this.data});
  @override
  State<ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<ConversationTile> {
  late final String? _other = _findOther();
  late final Future<DocumentSnapshot<Map<String, dynamic>>>? _user =
      _other == null
      ? null
      : FirebaseFirestore.instance.collection('users').doc(_other).get();

  String? _findOther() {
    final members = List<String>.from(widget.data['members'] ?? []);
    if (members.isEmpty) return null;
    final me = FirebaseAuth.instance.currentUser?.uid;
    return members.firstWhere((x) => x != me, orElse: () => members.first);
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return const SizedBox.shrink();
    final me = FirebaseAuth.instance.currentUser?.uid;
    final last = (widget.data['last_message'] ?? '').toString();
    final fromMe = widget.data['last_sender'] == me;
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _user,
      builder: (c, s) {
        final p = s.data?.data() ?? {};
        final name = (p['display_name'] ?? 'Chat').toString();
        return OvieGlassCard(
          radius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  DirectChatScreen(otherUid: _other!, otherName: name),
            ),
          ),
          child: Row(
            children: [
              _Avatar(photo: p['photo_url']?.toString(), name: name, radius: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      last.isEmpty ? 'Say hi 👋' : '${fromMe ? 'You: ' : ''}$last',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _ago(widget.data['updated_at'] as Timestamp?),
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ovie hub
// ─────────────────────────────────────────────────────────────────────────────

class OvieHubPage extends StatelessWidget {
  const OvieHubPage({super.key});

  Future<void> _startVideo(BuildContext context) async {
    final choice = await _showSheet<Map<String, String>>(
      context,
      (_) => const _VideoCallSheet(),
    );
    if (choice == null || !context.mounted) return;
    final male = choice['voice'] == 'male';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          voice: choice['voice']!,
          vibe: choice['vibe']!,
          imagePath: male ? 'assets/images/buddy.png' : 'assets/images/missy.png',
        ),
      ),
    );
  }

  void _soon(
    BuildContext context,
    IconData icon,
    String title,
    String body,
  ) {
    _showSheet(
      context,
      (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: OvieBrand.royalGradient,
                ),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: OvieBrand.royalGold.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Coming soon',
                  style: TextStyle(
                    color: OvieBrand.royalGold,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.45),
              ),
              const SizedBox(height: 22),
              OvieGradientButton(
                label: 'Got it',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const _PageHeader(title: 'Ovie World'),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            _HubHero(
              onVoice: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VoiceSelectionScreen()),
              ),
              onVideo: () => _startVideo(context),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Text(
                'Explore',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _HubTile(
              icon: Icons.groups_rounded,
              title: 'AI Friend Groups',
              subtitle: 'Bring Ovie into your social world.',
              colors: const [Color(0xFF8B5CF6), Color(0xFF4F8CFF)],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const GroupCallPage(voice: 'male', vibe: 'Chill'),
                ),
              ),
            ),
            _HubTile(
              icon: Icons.psychology_alt_rounded,
              title: 'AI Social Games',
              subtitle: 'Mysteries, missions, debates and gist battles.',
              colors: const [Color(0xFFEC4899), Color(0xFF8B5CF6)],
              soon: true,
              onTap: () => _soon(
                context,
                Icons.psychology_alt_rounded,
                'AI Social Games',
                'Secret Missions, Who Said That?, Gist Battle and Social Mystery are being rolled out here.',
              ),
            ),
            _HubTile(
              icon: Icons.translate_rounded,
              title: 'Naija Language Lab',
              subtitle: 'Practice Pidgin, Yoruba, Igbo, Hausa and Edo/Bini.',
              colors: const [Color(0xFF10B981), Color(0xFF3B82F6)],
              soon: true,
              onTap: () => _soon(
                context,
                Icons.translate_rounded,
                'Naija Language Lab',
                'Ovie will learn to understand and speak more Nigerian languages, with a graceful fallback when speech is unclear.',
              ),
            ),
            _HubTile(
              icon: Icons.auto_stories_rounded,
              title: 'Living Memories',
              subtitle: 'Turn your friendship history into stories.',
              colors: const [Color(0xFFF59E0B), Color(0xFFEC4899)],
              soon: true,
              onTap: () => _soon(
                context,
                Icons.auto_stories_rounded,
                'Living Memories',
                'Capture a moment today. Ovie can later turn it into a story, timeline or throwback game.',
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _HubHero extends StatelessWidget {
  final VoidCallback onVoice;
  final VoidCallback onVideo;
  const _HubHero({required this.onVoice, required this.onVideo});

  Widget _face(String asset, double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: OvieBrand.surface,
      border: Border.all(color: OvieBrand.background, width: 3),
    ),
    child: ClipOval(
      child: Image.asset(
        asset,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.person, color: Colors.white38),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            _accent.withValues(alpha: .6),
            OvieBrand.secondary.withValues(alpha: .38),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 98,
                height: 64,
                child: Stack(
                  children: [
                    Positioned(left: 0, child: _face('assets/images/buddy.png', 64)),
                    Positioned(left: 34, child: _face('assets/images/missy.png', 64)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Talk to your AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Pick Buddy or Missy and start a call. Switch on video and they can see you too.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: OvieBrand.background,
                    minimumSize: const Size.fromHeight(48),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: onVoice,
                  icon: const Icon(Icons.call_rounded, size: 20),
                  label: const Text(
                    'Voice call',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: .5)),
                    minimumSize: const Size.fromHeight(48),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: onVideo,
                  icon: const Icon(Icons.videocam_rounded, size: 20),
                  label: const Text(
                    'Video call',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;
  final bool soon;
  const _HubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
    this.soon = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: OvieGlassCard(
      onTap: onTap,
      radius: 22,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (soon) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: OvieBrand.royalGold.withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Soon',
                          style: TextStyle(
                            color: OvieBrand.royalGold,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: Colors.white.withValues(alpha: .3),
          ),
        ],
      ),
    ),
  );
}

/// Bottom sheet to choose who to video call and the vibe.
class _VideoCallSheet extends StatefulWidget {
  const _VideoCallSheet();
  @override
  State<_VideoCallSheet> createState() => _VideoCallSheetState();
}

class _VideoCallSheetState extends State<_VideoCallSheet> {
  String voice = 'male';
  String vibe = 'Chaotic';

  static const _vibes = [
    ['🤪 Chaotic', 'Chaotic'],
    ['🔥 Savage', 'Savage'],
    ['🧘 Calm', 'Therapist'],
    ['⚡ Hype', 'Hype'],
    ['🗣️ Gist', 'Gist'],
    ['📖 Story', 'Story'],
  ];

  Widget _person(String id, String name, String asset) {
    final selected = voice == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => voice = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: selected
                ? _accent.withValues(alpha: .18)
                : Colors.white.withValues(alpha: .05),
            border: Border.all(
              color: selected ? _accent : Colors.white.withValues(alpha: .09),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: Image.asset(
                    asset,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.person, color: Colors.white38),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Start a video call',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your camera preview stays on your device unless the call is live.',
              style: TextStyle(color: Colors.white54, height: 1.35),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _person('male', 'Buddy', 'assets/images/buddy.png'),
                const SizedBox(width: 12),
                _person('female', 'Missy', 'assets/images/missy.png'),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final v in _vibes)
                  ChoiceChip(
                    label: Text(v[0]),
                    selected: vibe == v[1],
                    onSelected: (_) => setState(() => vibe = v[1]),
                    showCheckmark: false,
                    backgroundColor: Colors.white.withValues(alpha: .06),
                    selectedColor: _accent.withValues(alpha: .35),
                    side: BorderSide(
                      color: vibe == v[1]
                          ? _accent
                          : Colors.white.withValues(alpha: .1),
                    ),
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            OvieGradientButton(
              label: 'Start video call',
              icon: Icons.videocam_rounded,
              onPressed: () =>
                  Navigator.pop(context, {'voice': voice, 'vibe': vibe}),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// My profile
// ─────────────────────────────────────────────────────────────────────────────

class SocialProfilePage extends StatelessWidget {
  const SocialProfilePage({super.key});

  Future<void> _changePhoto(BuildContext context) async {
    try {
      await SocialService.instance.uploadProfileImage();
    } catch (_) {
      if (context.mounted) _toast(context, 'Could not update your photo.');
    }
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Log out?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'You can log back in any time.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (r) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: SocialService.instance.myProfile(),
        builder: (c, s) {
          final d = s.data?.data() ?? {};
          return Column(
            children: [
              _PageHeader(
                title: 'Me',
                actions: [
                  OvieIconButton(
                    icon: Icons.edit_rounded,
                    onTap: () => _showSheet(
                      context,
                      (_) => EditProfileSheet(data: d),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  children: [
                    _ProfileHero(
                      data: d,
                      onAvatarTap: () => _changePhoto(context),
                    ),
                    const SizedBox(height: 22),
                    _StatsRow([
                      _Stat('Friends', d['friends_count'] ?? 0),
                      _Stat('Followers', d['followers_count'] ?? 0),
                      _Stat('Following', d['following_count'] ?? 0),
                    ]),
                    const SizedBox(height: 26),
                    const Text(
                      'Your vibe',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        '✨ AI Friend',
                        '🇳🇬 Naija',
                        '🎮 Games',
                        '🎙️ Voice',
                        '🌍 Languages',
                      ]
                          .map(
                            (x) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _accent.withValues(alpha: .14),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _accent.withValues(alpha: .3),
                                ),
                              ),
                              child: Text(
                                x,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 28),
                    OvieGlassCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _SettingRow(
                            icon: Icons.logout_rounded,
                            label: 'Log out',
                            color: Colors.white,
                            onTap: () => _logout(context),
                          ),
                          Divider(
                            height: 1,
                            color: Colors.white.withValues(alpha: .07),
                          ),
                          _SettingRow(
                            icon: Icons.delete_forever_rounded,
                            label: 'Delete account',
                            color: Colors.redAccent,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AccountDeletionPage(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: Colors.white.withValues(alpha: .25),
          ),
        ],
      ),
    ),
  );
}

class EditProfileSheet extends StatefulWidget {
  final Map<String, dynamic> data;
  const EditProfileSheet({super.key, required this.data});
  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late TextEditingController name, username, bio;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.data['display_name'] ?? '');
    username = TextEditingController(text: widget.data['username'] ?? '');
    bio = TextEditingController(text: widget.data['bio'] ?? '');
  }

  @override
  void dispose() {
    name.dispose();
    username.dispose();
    bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await SocialService.instance.changeUsername(username.text);
      final display = name.text.trim().isEmpty
          ? 'Ovie User'
          : name.text.trim();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .set({
            'display_name': display,
            'bio': bio.text.trim(),
          }, SetOptions(merge: true));
      await FirebaseAuth.instance.currentUser?.updateDisplayName(display);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _toast(context, _cleanError(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      0,
      20,
      MediaQuery.of(context).viewInsets.bottom + 20,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Edit profile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: name,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: Colors.white),
            cursorColor: _accent,
            decoration: _field('Your name', label: 'Display name'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: username,
            maxLength: 20,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: Colors.white),
            cursorColor: _accent,
            decoration: _field(
              'username',
              label: 'Username',
              prefixText: '@',
              helper: '3–20 chars: a-z, 0-9 and _',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: bio,
            maxLength: 160,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(color: Colors.white),
            cursorColor: _accent,
            decoration: _field('Tell people about you', label: 'Bio'),
          ),
          const SizedBox(height: 12),
          OvieGradientButton(
            label: saving ? 'Saving…' : 'Save changes',
            active: !saving,
            onPressed: saving ? null : _save,
          ),
        ],
      ),
    ),
  );
}
