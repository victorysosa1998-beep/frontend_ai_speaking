import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'social_service.dart';
import 'group_call_page.dart';
import 'app_brand.dart';
import 'ovie_ui.dart';

const _gBg = Color(0xFF070817);
const _gCard = Color(0xFF11132A);
const _gAccent = Color(0xFF7C5CFF);

class GroupChatPage extends StatefulWidget {
  final String groupId;
  const GroupChatPage({super.key, required this.groupId});
  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final c = TextEditingController();
  bool sendingAI = false;

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = c.text.trim();
    if (text.isEmpty) return;
    c.clear();
    await SocialService.instance.sendGroupMessage(widget.groupId, text);
    if (_shouldAskAI(text)) await _askAI(text);
  }

  bool _shouldAskAI(String text) {
    final t = text.toLowerCase();
    return t.contains('@ovie') ||
        t == 'ovie' ||
        t.startsWith('ovie ') ||
        t.contains('ovie,') ||
        t.contains('@sympy') ||
        t == 'sympy' ||
        t.startsWith('sympy ') ||
        t.contains('sympy,');
  }

  Future<void> _askAI(String request) async {
    if (sendingAI) return;
    setState(() => sendingAI = true);
    try {
      final docs = await FirebaseFirestore.instance
          .collection('group_chats')
          .doc(widget.groupId)
          .collection('messages')
          .orderBy('created_at', descending: true)
          .limit(30)
          .get();
      final history = docs.docs.reversed.map((d) {
        final x = d.data();
        return {
          'name': (x['sender_name'] ?? 'Someone').toString(),
          'text': (x['text'] ?? '').toString(),
          'is_ai': '${x['is_ai'] == true}',
        };
      }).toList();
      await SocialService.instance
          .askGroupAI(widget.groupId, context: history, request: request);
      // The backend persists the AI reply as the trusted Ovie member.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => sendingAI = false);
    }
  }

  Future<void> _startCall(Map<String, dynamic> group) async {
    final memberIds = List<String>.from(group['members'] ?? const []);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupCallPage(
          voice: 'female',
          vibe: 'Gist',
          groupId: widget.groupId,
          groupMemberIds: memberIds,
          autoStart: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('group_chats')
            .doc(widget.groupId)
            .snapshots(),
        builder: (context, groupSnap) {
          final group = groupSnap.data?.data() ?? {};
          final name = (group['name'] ?? 'Ovie Squad').toString();
          final members = List<String>.from(group['members'] ?? const []);
          return Scaffold(
            backgroundColor: _gBg,
            appBar: AppBar(
              backgroundColor: _gBg,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              titleSpacing: 0,
              title: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: OvieBrand.royalGradient,
                    ),
                    child: const Icon(Icons.groups_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                        Text('${members.length} people • Ovie AI',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.white38)),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Start AI group call',
                  onPressed: () => _startCall(group),
                  icon: const Icon(Icons.call_rounded),
                ),
              ],
            ),
            body: OvieBackground(
              child: Column(
                children: [
                  if (group['active_call'] is Map<String, dynamic>)
                    _CallBanner(
                      groupId: widget.groupId,
                      call: Map<String, dynamic>.from(group['active_call']),
                      group: group,
                    ),
                  Expanded(child: _messageList()),
                  if (sendingAI) _thinkingStrip(),
                  _composer(),
                ],
              ),
            ),
          );
        },
      );

  Widget _messageList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: SocialService.instance.groupMessages(widget.groupId),
      builder: (context, s) {
        if (!s.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = s.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Text('Start the gist. Ovie is listening quietly 👀',
                style: TextStyle(color: Colors.white54)),
          );
        }
        final myUid = FirebaseAuth.instance.currentUser?.uid;
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final x = docs[docs.length - 1 - i].data();
            return _MessageBubble(
              text: (x['text'] ?? '').toString(),
              sender: (x['sender_name'] ?? 'Someone').toString(),
              mine: x['sender_id'] == myUid,
              ai: x['is_ai'] == true,
            );
          },
        );
      },
    );
  }

  Widget _thinkingStrip() {
    return Padding(
      padding: const EdgeInsets.only(left: 18, bottom: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.amberAccent),
            ),
            const SizedBox(width: 8),
            Text('Ovie is thinking…',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5), fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              tooltip: 'Ask Ovie',
              onPressed: () {
                c.text = '@Ovie ';
                c.selection = TextSelection.collapsed(offset: c.text.length);
              },
              icon: const Icon(Icons.auto_awesome, color: Colors.amberAccent),
            ),
            Expanded(
              child: TextField(
                controller: c,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Message the squad…',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.07),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _send,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: OvieBrand.royalGradient,
                  boxShadow: [
                    BoxShadow(
                      color: _gAccent.withOpacity(0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  sendingAI ? Icons.hourglass_top_rounded : Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final String sender;
  final bool mine;
  final bool ai;
  const _MessageBubble({
    required this.text,
    required this.sender,
    required this.mine,
    required this.ai,
  });

  @override
  Widget build(BuildContext context) {
    const big = Radius.circular(20);
    const small = Radius.circular(5);
    final radius = BorderRadius.only(
      topLeft: big,
      topRight: big,
      bottomLeft: mine ? big : small,
      bottomRight: mine ? small : big,
    );

    BoxDecoration decoration;
    if (ai) {
      decoration = BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.35),
        borderRadius: radius,
        border: Border.all(color: Colors.amberAccent.withOpacity(0.35)),
      );
    } else if (mine) {
      decoration = BoxDecoration(
        gradient: OvieBrand.royalGradient,
        borderRadius: radius,
      );
    } else {
      decoration = BoxDecoration(
        color: _gCard,
        borderRadius: radius,
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      );
    }

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: decoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine) ...[
              Text(
                ai ? '🤖 Ovie' : sender,
                style: TextStyle(
                  color: ai ? Colors.amberAccent : OvieBrand.secondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              text,
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}

class _CallBanner extends StatelessWidget {
  final String groupId;
  final Map<String, dynamic> call;
  final Map<String, dynamic> group;
  const _CallBanner(
      {required this.groupId, required this.call, required this.group});

  @override
  Widget build(BuildContext context) {
    final host = (call['host_name'] ?? 'Someone').toString();
    final invite = (call['invite_code'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.greenAccent.withOpacity(.28)),
      ),
      child: Row(
        children: [
          const Icon(Icons.graphic_eq, color: Colors.greenAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$host started an AI group call',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.greenAccent.shade700,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: invite.isEmpty
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupCallPage(
                          voice: (call['voice'] ?? 'female').toString(),
                          vibe: (call['vibe'] ?? 'Gist').toString(),
                          groupId: groupId,
                          groupMemberIds:
                              List<String>.from(group['members'] ?? const []),
                          inviteCode: invite,
                        ),
                      ),
                    );
                  },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
}

class GroupListPage extends StatelessWidget {
  /// When true the page renders only its list (no Scaffold/AppBar) so it can
  /// sit inside another screen's tab, e.g. the Chats tab on the social home.
  final bool embedded;
  const GroupListPage({super.key, this.embedded = false});

  Future<void> _newGroup(BuildContext context) async {
    final name = TextEditingController();
    final people = TextEditingController();
    bool ai = true;
    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: _gCard,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22)),
          title: const Text('Create a group',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Group name',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: people,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Add @usernames',
                  hintText: '@ada, @emeka, @john',
                  labelStyle: TextStyle(color: Colors.white54),
                  hintStyle: TextStyle(color: Colors.white30),
                ),
              ),
              SwitchListTile(
                value: ai,
                activeColor: _gAccent,
                onChanged: (v) => setDialogState(() => ai = v),
                title: const Text('Add Ovie AI',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('Mention @Ovie when you want it to speak',
                    style: TextStyle(color: Colors.white38)),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _gAccent),
              onPressed: () async {
                try {
                  final parts = people.text
                      .split(',')
                      .map((x) => x.trim())
                      .where((x) => x.isNotEmpty)
                      .toList();
                  final users =
                      await SocialService.instance.findUsersByUsernames(parts);
                  final id = await SocialService.instance.createGroup(
                    name: name.text,
                    memberIds: users.map((x) => x.id).toList(),
                    aiEnabled: ai,
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => GroupChatPage(groupId: id)),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          e.toString().replaceFirst('Exception: ', '')),
                    ));
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    people.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: SocialService.instance.myGroups(),
            builder: (context, s) {
              if (!s.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = s.data!.docs;
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.groups_rounded,
                          size: 56, color: Colors.white.withOpacity(0.2)),
                      const SizedBox(height: 14),
                      const Text('No groups yet',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        style:
                            FilledButton.styleFrom(backgroundColor: _gAccent),
                        onPressed: () => _newGroup(context),
                        icon: const Icon(Icons.group_add),
                        label: const Text('Create your first AI group'),
                      ),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final d = docs[i];
                  final x = d.data();
                  final count = (x['members'] as List?)?.length ?? 0;
                  final aiOn = x['ai_enabled'] == true;
                  return OvieGlassCard(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => GroupChatPage(groupId: d.id)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: OvieBrand.royalGradient,
                          ),
                          child: const Icon(Icons.groups_rounded,
                              color: Colors.white),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (x['name'] ?? 'Squad').toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '$count members • ${aiOn ? 'Ovie on' : 'AI off'}',
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: Colors.white.withOpacity(0.25)),
                      ],
                    ),
                  );
                },
              );
            },
          );
    if (embedded) return Material(type: MaterialType.transparency, child: list);
    final content = OvieBackground(child: list);
    return Scaffold(
        backgroundColor: _gBg,
        appBar: AppBar(
          backgroundColor: _gBg,
          surfaceTintColor: Colors.transparent,
          title: const Text('AI Groups'),
          actions: [
            IconButton(
              tooltip: 'New group',
              onPressed: () => _newGroup(context),
              icon: const Icon(Icons.group_add_rounded),
            ),
          ],
        ),
        body: content,
      );
  }
}
