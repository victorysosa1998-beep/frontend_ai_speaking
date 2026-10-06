import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'app_brand.dart';
import 'ovie_ui.dart';
import 'social_service.dart';

/// One-to-one chat between the signed-in user and [otherUid].
///
/// Used by social_home.dart (profile "Message" button and the Chats list).
class DirectChatScreen extends StatefulWidget {
  final String otherUid;
  final String otherName;
  const DirectChatScreen({
    super.key,
    required this.otherUid,
    required this.otherName,
  });

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _service = SocialService.instance;
  bool _sending = false;
  bool _hasText = false;
  int _lastCount = 0;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _messages =
      _service.messages(widget.otherUid);
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _profile =
      FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUid)
          .snapshots();

  @override
  void initState() {
    super.initState();
    _input.addListener(() {
      final has = _input.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _input.clear();
    try {
      await _service.sendMessage(widget.otherUid, text);
    } catch (e) {
      // Put the text back so nothing the person typed is lost.
      _input.text = text;
      _input.selection = TextSelection.collapsed(offset: text.length);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Bad state: ', ''),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _jumpToEnd({bool animate = true}) {
    if (!_scroll.hasClients) return;
    final target = _scroll.position.maxScrollExtent;
    if (animate) {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    } else {
      _scroll.jumpTo(target);
    }
  }

  Future<void> _confirmBlock() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: OvieBrand.card,
        title: Text(
          'Block ${widget.otherName}?',
          style: const TextStyle(color: Colors.white),
        ),
        content: const Text(
          'You will no longer be able to message each other.',
          style: TextStyle(color: Colors.white70, height: 1.35),
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
    await _service.blockUser(widget.otherUid);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _report() async {
    await _service.reportUser(widget.otherUid, 'Reported from chat');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thanks, we will review this report.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: OvieBrand.background,
      body: OvieBackground(
        child: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _messages,
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return const _CenterNote(
                        icon: Icons.cloud_off_rounded,
                        title: 'Could not load messages',
                        body: 'Check your connection and try again.',
                      );
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data!.docs;
                    if (docs.isEmpty) {
                      return _CenterNote(
                        icon: Icons.waving_hand_rounded,
                        title: 'Say hi to ${widget.otherName}',
                        body: 'Your messages will show up here.',
                      );
                    }
                    if (docs.length != _lastCount) {
                      final first = _lastCount == 0;
                      _lastCount = docs.length;
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _jumpToEnd(animate: !first),
                      );
                    }
                    return ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final d = docs[i].data();
                        final mine = d['sender_id'] == me;
                        final at = (d['created_at'] as Timestamp?)?.toDate();
                        final prev = i > 0 ? docs[i - 1].data() : null;
                        final prevAt =
                            (prev?['created_at'] as Timestamp?)?.toDate();
                        final newDay = at != null &&
                            (prevAt == null || !_sameDay(at, prevAt));
                        final grouped = prev != null &&
                            prev['sender_id'] == d['sender_id'] &&
                            !newDay;
                        return Column(
                          children: [
                            if (newDay) _DayChip(date: at),
                            _Bubble(
                              text: (d['text'] ?? '').toString(),
                              mine: mine,
                              time: at,
                              topGap: grouped ? 3 : 10,
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              _composer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _profile,
      builder: (context, snap) {
        final p = snap.data?.data() ?? {};
        final name = (p['display_name'] ?? widget.otherName).toString();
        final photo = p['photo_url'] as String?;
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              OvieIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.maybePop(context),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 20,
                backgroundColor: OvieBrand.primary,
                backgroundImage: photo != null ? NetworkImage(photo) : null,
                child: photo == null
                    ? Text(
                        name.isEmpty ? '?' : name[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
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
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if ((p['username'] ?? '').toString().isNotEmpty)
                      Text(
                        '@${p['username']}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: OvieBrand.card,
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
                onSelected: (v) {
                  if (v == 'report') _report();
                  if (v == 'block') _confirmBlock();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'report',
                    child: Text('Report', style: TextStyle(color: Colors.white)),
                  ),
                  PopupMenuItem(
                    value: 'block',
                    child: Text(
                      'Block',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _composer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: .09)),
              ),
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 5,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: Colors.white),
                cursorColor: OvieBrand.primary,
                decoration: const InputDecoration(
                  hintText: 'Message',
                  hintStyle: TextStyle(color: Colors.white38),
                  counterText: '',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _hasText ? OvieBrand.royalGradient : null,
              color: _hasText ? null : Colors.white.withValues(alpha: .07),
              boxShadow: _hasText
                  ? [
                      BoxShadow(
                        color: OvieBrand.primary.withValues(alpha: .4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : const [],
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _hasText ? _send : null,
                child: Icon(
                  Icons.arrow_upward_rounded,
                  color: _hasText ? Colors.white : Colors.white24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _clock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour >= 12 ? 'PM' : 'AM'}';
}

String _dayLabel(DateTime t) {
  final now = DateTime.now();
  if (_sameDay(t, now)) return 'Today';
  if (_sameDay(t, now.subtract(const Duration(days: 1)))) return 'Yesterday';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[t.month - 1]} ${t.day}${t.year == now.year ? '' : ', ${t.year}'}';
}

class _DayChip extends StatelessWidget {
  final DateTime? date;
  const _DayChip({required this.date});

  @override
  Widget build(BuildContext context) {
    if (date == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _dayLabel(date!),
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  final bool mine;
  final DateTime? time;
  final double topGap;
  const _Bubble({
    required this.text,
    required this.mine,
    required this.time,
    required this.topGap,
  });

  @override
  Widget build(BuildContext context) {
    const r = Radius.circular(20);
    const tail = Radius.circular(6);
    final maxW = MediaQuery.of(context).size.width * .76;
    return Padding(
      padding: EdgeInsets.only(top: topGap),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 9, 14, 7),
            decoration: BoxDecoration(
              gradient: mine ? OvieBrand.royalGradient : null,
              color: mine ? null : Colors.white.withValues(alpha: .08),
              border: mine
                  ? null
                  : Border.all(color: Colors.white.withValues(alpha: .07)),
              borderRadius: BorderRadius.only(
                topLeft: r,
                topRight: r,
                bottomLeft: mine ? r : tail,
                bottomRight: mine ? tail : r,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  time == null ? 'Sending…' : _clock(time!),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .55),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CenterNote extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _CenterNote({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: OvieBrand.primary.withValues(alpha: .14),
              ),
              child: Icon(icon, color: OvieBrand.primary, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
