import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'group_call_service.dart';
import 'app_brand.dart';
import 'ovie_ui.dart';

class GroupCallPage extends StatefulWidget {
  final String voice;
  final String vibe;
  final String? groupId;
  final List<String> groupMemberIds;
  final bool autoStart;
  final String? inviteCode;

  const GroupCallPage({
    super.key,
    required this.voice,
    required this.vibe,
    this.groupId,
    this.groupMemberIds = const [],
    this.autoStart = false,
    this.inviteCode,
  });

  @override
  State<GroupCallPage> createState() => _GroupCallPageState();
}

class _GroupCallPageState extends State<GroupCallPage> {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  Timer? _participantTimer;
  bool _connecting = false;
  bool _connected = false;
  bool _muted = false;
  bool _speaker = true;
  bool _isHost = false;
  String _identity = '';
  String _inviteCode = '';
  String _roomName = '';
  String _activeSpeaker = '';
  String _status = 'Choose how you want to join.';
  final TextEditingController _inviteController = TextEditingController();
  final TextEditingController _chatController = TextEditingController();
  final List<_GroupChatMessage> _messages = [];
  final Map<String, int> _scores = {};
  final List<String> _games = const [
    '🔥 Hot Seat',
    '🎯 Who Goes First?',
    '😂 Finish My Sentence',
    '🧠 Deep Gist',
    '💰 Soft Life Simulator',
    '🇳🇬 Naija Life Simulator',
  ];
  int _gameIndex = 0;
  String? _activeReaction;
  DateTime? _callStartedAt;
  bool _usageReported = false;
  Timer? _speakerPoller;
  String _lastPublishedSpeaker = '';
  final Map<String, String> _participantNames = {};
  String _myDisplayName = 'Someone';

  @override
  void initState() {
    super.initState();
    _loadMyNameAndMaybeStart();
  }

  Future<void> _loadMyNameAndMaybeStart() async {
    try {
      final u = FirebaseAuth.instance.currentUser;
      if (u != null) {
        final snap = await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
        _myDisplayName = (snap.data()?['display_name'] ?? u.displayName ?? 'Someone').toString();
      }
    } catch (_) {}
    if (widget.autoStart && mounted) {
      if ((widget.inviteCode ?? '').isNotEmpty) {
        await _joinGuestCode(widget.inviteCode!);
      } else {
        await _startHost();
      }
    }
  }

  Future<void> _joinGuestCode(String code) async {
    setState(() { _connecting = true; _status = 'Joining the AI call…'; });
    try {
      final guest = await GroupCallService.joinWithInvite(code);
      _identity = guest.identity;
      _inviteCode = code;
      await _connect(guest.token, guest.url, guest.room);
    } catch (e) { if (mounted) _showError(e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => _connecting = false); }
  }

  @override
  void dispose() {
    _participantTimer?.cancel();
    _speakerPoller?.cancel();
    _listener?.dispose();
    _room?.disconnect();
    _inviteController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _startHost() async {
    setState(() {
      _connecting = true;
      _status = 'Creating your room…';
    });
    try {
      final host = await GroupCallService.createHost(
        gender: widget.voice,
        vibe: widget.vibe,
      );
      _isHost = true;
      _identity = host.identity;
      _inviteCode = host.inviteCode;
      await _connect(host.token, host.url, host.room);
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _joinGuest() async {
    final code = _inviteController.text.trim();
    if (code.isEmpty) {
      _showError('Paste the Ovie invite code first.');
      return;
    }
    setState(() {
      _connecting = true;
      _status = 'Joining the room…';
    });
    try {
      final guest = await GroupCallService.joinWithInvite(code);
      _identity = guest.identity;
      _inviteCode = code;
      await _connect(guest.token, guest.url, guest.room);
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _connect(String token, String url, String room) async {
    final liveRoom = Room();
    _room = liveRoom;
    _roomName = room;
    _listener = liveRoom.createListener();
    _listener!
      ..on<RoomDisconnectedEvent>((_) {
        if (mounted) setState(() => _connected = false);
      })
      ..on<TrackSubscribedEvent>((event) async {
        if (event.track is RemoteAudioTrack) {
          await event.track.start();
        }
      })
      ..on<ParticipantConnectedEvent>((event) {
        _broadcastSystem('${_displayName(event.participant.identity)} joined the room.');
        _refreshParticipants();
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        _broadcastSystem('${_displayName(event.participant.identity)} left the room.');
        _refreshParticipants();
      })
      ..on<DataReceivedEvent>((event) {
        _handleData(event.data);
      });

    await liveRoom.connect(
      url,
      token,
      connectOptions: const ConnectOptions(autoSubscribe: true),
    );
    await liveRoom.localParticipant?.setMicrophoneEnabled(true);
    await liveRoom.setSpeakerOn(_speaker);

    if (!mounted) return;
    setState(() {
      _connected = true;
      _callStartedAt = DateTime.now();
      _status = 'Room is live. Invite your people. 🎉';
      _activeSpeaker = _identity;
    });
    _participantTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() {});
    });
    _speakerPoller?.cancel();
    _speakerPoller = Timer.periodic(const Duration(milliseconds: 350), (_) => _detectActiveSpeaker());

    await _publish({'type': 'presence', 'identity': _identity, 'name': _myDisplayName});
    if (_isHost) {
      await _sendTurn(_identity);
      await _publish({'type': 'system', 'text': 'Host started a Ovie group call. 🎉'});
      if ((widget.groupId ?? '').isNotEmpty) {
        await SocialServiceBridge.publishCall(widget.groupId!, {
          'room': _roomName, 'invite_code': _inviteCode, 'host_id': _identity, 'host_name': _myDisplayName,
          'voice': widget.voice, 'vibe': widget.vibe, 'started_at': DateTime.now().toIso8601String(),
        });
        await GroupCallService.notifyGroupMembers(groupId: widget.groupId!, inviteCode: _inviteCode, room: _roomName, hostName: _myDisplayName, voice: widget.voice, vibe: widget.vibe);
      }
    }
  }

  void _detectActiveSpeaker() {
    final room = _room;
    if (room == null || !_connected) return;
    String? active;
    for (final p in room.remoteParticipants.values) {
      final id = p.identity;
      if (id.startsWith('agent') || id.startsWith('sympy_ai')) continue;
      if (p.isSpeaking) { active = id; break; }
    }
    if (active == null && room.localParticipant?.isSpeaking == true) active = _identity;
    if (active != null && active != _lastPublishedSpeaker) {
      _lastPublishedSpeaker = active;
      _sendTurn(active);
    }
  }

  Future<void> _sendTurn(String identity) async {
    _activeSpeaker = identity;
    await _publish({'type': 'turn', 'identity': identity});
    if (mounted) setState(() {});
  }

  Future<void> _publish(Map<String, dynamic> payload) async {
    final participant = _room?.localParticipant;
    if (participant == null) return;
    await participant.publishData(
      utf8.encode(jsonEncode(payload)),
      reliable: true,
      topic: 'sympy-group',
    );
  }

  void _handleData(List<int> bytes) {
    try {
      final raw = utf8.decode(bytes);
      final data = jsonDecode(raw) as Map<String, dynamic>;
      switch (data['type']) {
        case 'presence':
          final pid = data['identity']?.toString() ?? '';
          final pname = data['name']?.toString() ?? '';
          if (pid.isNotEmpty && pname.isNotEmpty) _participantNames[pid] = pname;
          if (mounted) setState(() {});
          break;
        case 'turn':
          final identity = data['identity']?.toString() ?? '';
          if (identity.isNotEmpty && mounted) {
            setState(() => _activeSpeaker = identity);
          }
          break;
        case 'chat':
          _addMessage(
            data['sender']?.toString() ?? 'Guest',
            data['text']?.toString() ?? '',
            mine: data['sender']?.toString() == _identity,
          );
          break;
        case 'system':
          _addMessage('Ovie', data['text']?.toString() ?? '', system: true);
          break;
        case 'game':
          _addMessage('🎮 Ovie Game', data['prompt']?.toString() ?? '', system: true);
          break;
        case 'reaction':
          final emoji = data['emoji']?.toString() ?? '';
          if (emoji.isNotEmpty && mounted) {
            setState(() => _activeReaction = emoji);
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted && _activeReaction == emoji) setState(() => _activeReaction = null);
            });
          }
          break;
        case 'score':
          final player = data['player']?.toString() ?? '';
          final points = (data['points'] as num?)?.toInt() ?? 0;
          if (player.isNotEmpty) _scores[player] = (_scores[player] ?? 0) + points;
          if (mounted) setState(() {});
          break;
      }
    } catch (_) {}
  }

  void _addMessage(String sender, String text, {bool mine = false, bool system = false}) {
    if (text.trim().isEmpty || !mounted) return;
    setState(() {
      _messages.add(_GroupChatMessage(sender: sender, text: text, mine: mine, system: system));
      if (_messages.length > 100) _messages.removeAt(0);
    });
  }

  Future<void> _sendChat() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    _chatController.clear();
    _addMessage('You', text, mine: true);
    await _publish({'type': 'chat', 'sender': _identity, 'text': text});
  }

  Future<void> _launchGame() async {
    final games = <String>['hot_take', 'who_first', 'finish', 'deep', 'soft_life', 'naija_life', 'surprise'];
    final game = games[_gameIndex % games.length];
    _gameIndex++;
    final labels = {
      'hot_take': '🔥 Hot Take',
      'who_first': '🎯 Who Goes First?',
      'finish': '😂 Finish My Sentence',
      'deep': '🧠 Deep Gist',
      'soft_life': '💰 Soft Life Simulator',
      'naija_life': '🇳🇬 Naija Life Simulator',
      'surprise': '✨ Surprise Game',
    };
    await _publish({'type': 'game_request', 'game': game});
    _addMessage('🎮 Ovie', '${labels[game]} is cooking…', system: true);
    await _sendTurn(_identity);
  }

  Future<void> _sendReaction(String emoji) async {
    setState(() => _activeReaction = emoji);
    await _publish({'type': 'reaction', 'emoji': emoji});
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _activeReaction == emoji) setState(() => _activeReaction = null);
    });
  }

  void _showScores() {
    final entries = _scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF10122A),
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🏆 Squad leaderboard', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              if (entries.isEmpty) const Text('No Sparks yet. Give the best answer 10 points!', style: TextStyle(color: Colors.white54)),
              ...entries.map((e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(child: Text(e.key == _identity ? '😎' : '🗣️')),
                    title: Text(_displayName(e.key), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    trailing: Text('✨ ${e.value}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900)),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _givePoint() async {
    await _publish({'type': 'score', 'player': _activeSpeaker, 'points': 10});
    _scores[_activeSpeaker] = (_scores[_activeSpeaker] ?? 0) + 10;
    if (mounted) setState(() {});
  }

  void _broadcastSystem(String text) {
    if (mounted) _addMessage('Ovie', text, system: true);
  }

  void _refreshParticipants() {
    if (mounted) setState(() {});
  }

  String _displayName(String identity) {
    return _participantNames[identity] ?? (identity == _identity ? _myDisplayName : 'Guest');
  }

  int minInt(int a, int b) => a < b ? a : b;

  Future<void> _shareInvite() async {
    if (_inviteCode.isEmpty) return;
    await Share.share(
      '🎙️ Join my Ovie group call!\n\nOpen Ovie → Play with Friends → Join a Room and paste this invite code:\n\n$_inviteCode\n\nLet’s gist, play games and let Ovie host 😎🇳🇬',
      subject: 'Join my Ovie call',
    );
  }

  void _copyInvite() {
    if (_inviteCode.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _inviteCode));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite code copied. 📋')));
  }

  Future<void> _leaveRoom() async {
    if (_isHost && (widget.groupId ?? '').isNotEmpty) { try { await SocialServiceBridge.endCall(widget.groupId!); } catch (_) {} }
    if (!_usageReported) {
      _usageReported = true;
      final started = _callStartedAt;
      if (started != null) {
        final seconds = DateTime.now().difference(started).inSeconds;
        await GroupCallService.reportUsage(seconds);
      }
    }
    await _room?.disconnect();
    if (mounted) Navigator.pop(context);
  }

  Future<bool> _handleBack() async {
    await _leaveRoom();
    return false;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final participants = <String>{
      if (_identity.isNotEmpty) _identity,
      ...?_room?.remoteParticipants.keys,
    }.toList();

    return WillPopScope(
      onWillPop: _handleBack,
      child: Scaffold(
        backgroundColor: OvieBrand.background,
        appBar: AppBar(
          backgroundColor: OvieBrand.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.groups_rounded, color: OvieBrand.secondary, size: 22),
              const SizedBox(width: 8),
              const Text('Ovie Squad',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              if (_connected) ...[
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ADE80).withOpacity(.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF4ADE80).withOpacity(.4)),
                  ),
                  child: Text('${participants.length} live',
                      style: const TextStyle(
                          color: Color(0xFF4ADE80),
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ],
          ),
          actions: [
            if (_connected)
              IconButton(
                  tooltip: 'Share invite',
                  icon: const Icon(Icons.share_rounded),
                  onPressed: _shareInvite),
          ],
        ),
        body: OvieBackground(
          child: _connected ? _buildConnected(participants) : _buildLobby(),
        ),
      ),
    );
  }

  Widget _buildLobby() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: [
                OvieBrand.primary.withOpacity(.55),
                OvieBrand.secondary.withOpacity(.40),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(.12)),
            boxShadow: [
              BoxShadow(
                color: OvieBrand.primary.withOpacity(.25),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🎙️ Gist together.',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900)),
              SizedBox(height: 8),
              Text(
                  'Bring your people into one AI-powered room. Talk, chat, play games and let Ovie host the chaos.',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 15, height: 1.4)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OvieGradientButton(
          label: _connecting ? 'CONNECTING…' : 'START A GROUP CALL',
          icon: Icons.add_call,
          active: !_connecting,
          onPressed: _connecting ? null : _startHost,
        ),
        const SizedBox(height: 26),
        Row(children: [
          Expanded(child: Divider(color: Colors.white.withOpacity(.08))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('OR JOIN A FRIEND',
                style: TextStyle(
                    color: Colors.white.withOpacity(.4),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
          ),
          Expanded(child: Divider(color: Colors.white.withOpacity(.08))),
        ]),
        const SizedBox(height: 18),
        TextField(
          controller: _inviteController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.vpn_key_rounded,
                color: Colors.white.withOpacity(.35), size: 20),
            hintText: 'Paste invite code',
            hintStyle: TextStyle(color: Colors.white.withOpacity(.35)),
            filled: true,
            fillColor: Colors.white.withOpacity(.06),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _connecting ? null : _joinGuest,
          icon: const Icon(Icons.login_rounded),
          label: const Text('Join room'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(16),
            side: BorderSide(color: Colors.white.withOpacity(.18)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 20),
        Text(_status,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(.45))),
      ],
    );
  }

  Widget _buildConnected(List<String> participants) {
    return Column(
      children: [
        if (_isHost && _inviteCode.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
            decoration: BoxDecoration(
              color: OvieBrand.royalGold.withOpacity(.09),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: OvieBrand.royalGold.withOpacity(.25)),
            ),
            child: Row(children: [
              const Icon(Icons.link_rounded,
                  color: OvieBrand.royalGold, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Invite: ${_inviteCode.substring(0, _inviteCode.length > 18 ? 18 : _inviteCode.length)}…',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              IconButton(
                  tooltip: 'Copy',
                  onPressed: _copyInvite,
                  icon: const Icon(Icons.copy_rounded,
                      color: Colors.white70, size: 20)),
              IconButton(
                  tooltip: 'Share',
                  onPressed: _shareInvite,
                  icon: const Icon(Icons.share_rounded,
                      color: Colors.white70, size: 20)),
            ]),
          ),
        SizedBox(
          height: 112,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            scrollDirection: Axis.horizontal,
            itemCount: participants.length,
            itemBuilder: (_, i) {
              final id = participants[i];
              final active = id == _activeSpeaker;
              return Container(
                width: 82,
                margin: const EdgeInsets.only(right: 10),
                child: Column(children: [
                  const SizedBox(height: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active
                          ? OvieBrand.secondary.withOpacity(.2)
                          : Colors.white.withOpacity(.06),
                      border: Border.all(
                          color: active
                              ? OvieBrand.secondary
                              : Colors.white.withOpacity(.1),
                          width: active ? 2.5 : 1),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                  color: OvieBrand.secondary.withOpacity(.5),
                                  blurRadius: 16,
                                  spreadRadius: 1)
                            ]
                          : const [],
                    ),
                    child: Center(
                        child: Text(id == _identity ? '😎' : '🗣️',
                            style: const TextStyle(fontSize: 25))),
                  ),
                  const SizedBox(height: 6),
                  Text(_displayName(id),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: active ? Colors.white : Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                  if (active)
                    const Text('speaking',
                        style: TextStyle(
                            color: OvieBrand.secondary, fontSize: 9)),
                ]),
              );
            },
          ),
        ),
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Text('Say something — the room is live 🎙️',
                      style: TextStyle(color: Colors.white.withOpacity(.35))),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final m = _messages[i];
                    final BoxDecoration deco = m.system
                        ? BoxDecoration(
                            color: Colors.white.withOpacity(.04),
                            borderRadius: BorderRadius.circular(14),
                          )
                        : m.mine
                            ? BoxDecoration(
                                gradient: OvieBrand.royalGradient,
                                borderRadius: BorderRadius.circular(18),
                              )
                            : BoxDecoration(
                                color: const Color(0xFF12162F),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                    color: Colors.white.withOpacity(.07)),
                              );
                    return Align(
                      alignment: m.system
                          ? Alignment.center
                          : (m.mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft),
                      child: Container(
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * .82),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: deco,
                        child: Column(
                          crossAxisAlignment: m.system
                              ? CrossAxisAlignment.center
                              : CrossAxisAlignment.start,
                          children: [
                            Text(m.sender,
                                style: TextStyle(
                                    color: m.system
                                        ? OvieBrand.royalGold
                                        : (m.mine
                                            ? Colors.white70
                                            : OvieBrand.secondary),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 3),
                            Text(m.text,
                                style: const TextStyle(
                                    color: Colors.white, height: 1.3)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (_activeReaction != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(_activeReaction!, style: const TextStyle(fontSize: 36)),
          ),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: ['😂', '🔥', '😭', '❤️', 'Omo!', 'Abeg!']
                .map((emoji) => Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: ActionChip(
                        backgroundColor: Colors.white.withOpacity(.07),
                        side: BorderSide(color: Colors.white.withOpacity(.1)),
                        label: Text(emoji,
                            style: const TextStyle(color: Colors.white)),
                        onPressed: () => _sendReaction(emoji),
                      ),
                    ))
                .toList(),
          ),
        ),
        _gameBar(),
        _controls(),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  style: const TextStyle(color: Colors.white),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendChat(),
                  decoration: InputDecoration(
                    hintText: 'Drop a gist…',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(.3)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(.07),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendChat,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: OvieBrand.royalGradient,
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _gameBar() => SizedBox(
        height: 52,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          scrollDirection: Axis.horizontal,
          itemCount: _games.length,
          separatorBuilder: (_, __) => const SizedBox(width: 7),
          itemBuilder: (_, i) => Center(
            child: ActionChip(
              backgroundColor: OvieBrand.primary.withOpacity(.16),
              side: BorderSide(color: OvieBrand.primary.withOpacity(.4)),
              label: Text(_games[i],
                  style: const TextStyle(color: Colors.white, fontSize: 12.5)),
              onPressed: _launchGame,
            ),
          ),
        ),
      );

  Widget _roundControl(IconData icon, VoidCallback onTap,
      {String? tooltip, bool danger = false, bool off = false}) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: danger
                ? Colors.redAccent
                : (off
                    ? Colors.redAccent.withOpacity(.16)
                    : Colors.white.withOpacity(.09)),
            border: Border.all(
                color: danger
                    ? Colors.transparent
                    : (off
                        ? Colors.redAccent.withOpacity(.4)
                        : Colors.white.withOpacity(.12))),
          ),
          child: Icon(icon,
              size: 21, color: off ? Colors.redAccent : Colors.white),
        ),
      ),
    );
  }

  Widget _controls() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _roundControl(
              _muted ? Icons.mic_off : Icons.mic,
              () async {
                setState(() => _muted = !_muted);
                await _room?.localParticipant?.setMicrophoneEnabled(!_muted);
              },
              tooltip: _muted ? 'Unmute' : 'Mute',
              off: _muted,
            ),
            _roundControl(
              _speaker ? Icons.volume_up : Icons.volume_off,
              () async {
                setState(() => _speaker = !_speaker);
                await _room?.setSpeakerOn(_speaker);
              },
              tooltip: 'Speaker',
              off: !_speaker,
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: GestureDetector(
                  onTap: () => _sendTurn(_identity),
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: OvieBrand.royalGradient,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.record_voice_over_rounded,
                            color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text('My turn',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _roundControl(Icons.add_reaction_rounded, _givePoint,
                tooltip: 'Give a point'),
            _roundControl(Icons.emoji_events_rounded, _showScores,
                tooltip: 'Scores'),
            const SizedBox(width: 8),
            _roundControl(Icons.call_end_rounded, _leaveRoom,
                tooltip: 'Leave', danger: true),
          ],
        ),
      );
}

class _GroupChatMessage {
  final String sender;
  final String text;
  final bool mine;
  final bool system;
  const _GroupChatMessage({required this.sender, required this.text, this.mine = false, this.system = false});
}

class SocialServiceBridge { static Future<void> publishCall(String groupId, Map<String,dynamic> call) async { await FirebaseFirestore.instance.collection('group_chats').doc(groupId).set({'active_call':call}, SetOptions(merge:true)); } static Future<void> endCall(String groupId) async { await FirebaseFirestore.instance.collection('group_chats').doc(groupId).set({'active_call':FieldValue.delete()}, SetOptions(merge:true)); } }
