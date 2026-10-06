import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'OvieChatPage.dart';
import 'app_brand.dart';
import 'ovie_ui.dart';

class FunZonePage extends StatefulWidget {
  final String voice;
  final String vibe;

  const FunZonePage({
    super.key,
    this.voice = 'female',
    this.vibe = 'Gist',
  });

  @override
  State<FunZonePage> createState() => _FunZonePageState();
}

class _FunZonePageState extends State<FunZonePage> {
  static const _pointsKey = 'sympy_fun_points';
  static const _challengeKey = 'sympy_daily_challenge';
  static const _streakKey = 'sympy_fun_streak';
  static const _lastDayKey = 'sympy_fun_last_day';

  int _points = 0;
  int _challengeIndex = 0;
  bool _challengeDone = false;
  int _streak = 0;
  String _prompt = '';
  final Random _random = Random();

  static const List<Map<String, String>> _challenges = [
    {
      'title': 'Naija Hot Take',
      'prompt': 'Is jollof better at a party, or better the next morning?',
    },
    {
      'title': 'Soft Life Check',
      'prompt': 'You get ₦50,000 today. Spend, save, or spoil yourself?',
    },
    {
      'title': 'No Wahala',
      'prompt': 'What is one small thing that instantly improves your mood?',
    },
    {
      'title': 'Main Character',
      'prompt': 'If today had a soundtrack, what song would be playing?',
    },
    {
      'title': 'Abeg Explain',
      'prompt': 'Explain your current vibe using only three words.',
    },
    {
      'title': 'Soft Life Simulator',
      'prompt': 'You just got ₦500,000. What is the smartest way to enjoy it without finishing it?',
    },
    {
      'title': 'Naija Life Simulator',
      'prompt': 'Your salary lands and three people need help. Who gets helped first and why?',
    },
    {
      'title': 'Guess Me',
      'prompt': 'What choice would your future self probably make: japa, build here, or remote life?',
    },
  ];

  static const List<Map<String, String>> _slang = [
    {'word': 'Abeg', 'meaning': 'Please / come on / seriously? Depends on the vibe.'},
    {'word': 'No wahala', 'meaning': 'No problem. We move.'},
    {'word': 'Omo', 'meaning': 'An all-purpose reaction — surprise, excitement, disbelief, anything.'},
    {'word': 'Japa', 'meaning': 'To leave or escape, especially when looking for a better situation.'},
    {'word': 'Ginger', 'meaning': 'Energy, motivation, or something that gets you excited.'},
    {'word': 'Steeze', 'meaning': 'Effortless confidence and style.'},
    {'word': 'Sapa', 'meaning': 'That painfully familiar state of being broke.'},
    {'word': 'Wahala', 'meaning': 'Trouble, stress, drama, or a complicated situation.'},
  ];

  static const List<String> _eitherOr = [
    '₦1m now or ₦100k every month for 12 months?',
    'Beach day or game night?',
    'Unlimited data or unlimited food?',
    'Lagos weekend or Abuja weekend?',
    'Late-night gist or early-morning gist?',
    'Jollof + chicken or fried rice + turkey?',
  ];

  static const List<String> _conversationStarters = [
    'What is something you could talk about for 30 minutes without preparing?',
    'What is one opinion you will defend with your whole chest?',
    'What would your younger self be proud of today?',
    'What is your funniest harmless embarrassment?',
    'If you could instantly master one skill, what would it be?',
    'What does your perfect Saturday look like?',
  ];

  static const List<String> _finishMySentence = [
    'If I woke up with ₦10 million tomorrow, the first thing I would…',
    'My most Nigerian habit is…',
    'The one thing I would never give up for money is…',
    'If Ovie had to describe my personality in one word…',
  ];

  static const List<String> _naijaSim = [
    'You have a 7am lecture, NEPA takes light and your data is almost gone. What is the plan?',
    'Your friend says “I need small favour” at 11:58pm. What are you expecting?',
    'You get a remote job paid in dollars. Soft life, investment or family first?',
    'You are stuck in traffic and your battery is 3%. Who gets the last call?',
  ];

  static const List<String> _guessMe = [
    'Would you rather be famous online or quietly wealthy?',
    'Would you rather relocate tomorrow or build your dream life here?',
    'Are you more likely to spend, save, invest or gift unexpected money?',
  ];

  static const List<String> _emojiDecode = [
    '🍚🔥👑', '💸📱😩', '🚗💨😤', '❤️📱👀', '☕💻🌙', '🏖️😎💰',
  ];

  static const List<String> _twoTruthsOneLie = [
    'I have travelled to three states. / I can cook jollof. / I have never lost a phone.',
    'I prefer night calls. / I hate parties. / I can sleep through anything.',
    'I have made money from a side hustle. / I have pulled an all-nighter. / I never use slang.',
  ];

  static const List<String> _callChallenges = [
    'Explain your day using only sound effects for 15 seconds.',
    'Give Ovie a hot take you will defend with your whole chest.',
    'Tell a 20-second story that starts with: “Omo, you will not believe this…”',
    'Describe your dream weekend without using the words “money”, “food”, or “sleep”.',
    'Let Ovie choose between two random options for your next decision.',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final dayKey = '${today.year}-${today.month}-${today.day}';
    final storedDay = prefs.getString(_challengeKey);
    final index = today.day % _challenges.length;
    if (storedDay != dayKey) {
      await prefs.setString(_challengeKey, dayKey);
      await prefs.setBool('sympy_challenge_done_$dayKey', false);
    }
    if (!mounted) return;
    setState(() {
      _points = prefs.getInt(_pointsKey) ?? 0;
      _streak = prefs.getInt(_streakKey) ?? 0;
      _challengeIndex = index;
      _challengeDone = prefs.getBool('sympy_challenge_done_$dayKey') ?? false;
    });
  }

  Future<void> _completeChallenge() async {
    if (_challengeDone) return;
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final dayKey = '${today.year}-${today.month}-${today.day}';
    final next = _points + 25;
    final previousDay = prefs.getString(_lastDayKey);
    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayKey = '${yesterday.year}-${yesterday.month}-${yesterday.day}';
    final streak = previousDay == yesterdayKey ? _streak + 1 : 1;
    await prefs.setInt(_pointsKey, next);
    await prefs.setInt(_streakKey, streak);
    await prefs.setString(_lastDayKey, dayKey);
    await prefs.setBool('sympy_challenge_done_$dayKey', true);
    if (!mounted) return;
    setState(() {
      _points = next;
      _streak = streak;
      _challengeDone = true;
    });
    _showSnack('🔥 +25 Ovie Sparks. $_streak-day streak!');
  }

  void _newPrompt() {
    HapticFeedback.selectionClick();
    final pool = [..._conversationStarters, ..._eitherOr];
    setState(() => _prompt = pool[_random.nextInt(pool.length)]);
  }

  void _showSlang() {
    final item = _slang[_random.nextInt(_slang.length)];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF10122A),
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🇳🇬 Naija Slang Drop', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Text(item['word']!, style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(item['meaning']!, style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.45)),
            ],
          ),
        ),
      ),
    );
  }

  void _showPromptDialog(String title, String text, {bool chatAction = true}) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF10122A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Text(text, style: const TextStyle(color: Colors.white70, height: 1.45, fontSize: 16)),
        actions: [
          if (chatAction)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _openInChat(text);
              },
              icon: const Icon(Icons.call_rounded, size: 18),
              label: const Text('Take it to Ovie'),
            ),
          TextButton(
            onPressed: () async {
              await SharePlus.instance.share(ShareParams(text: 'Try this with Ovie: $text'));
            },
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }

  void _openInChat(String prompt) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OvieChatPage(
          voice: widget.voice,
          vibe: widget.vibe,
          imagePath: widget.voice == 'male'
              ? 'assets/images/buddy.png'
              : 'assets/images/missy.png',
          initialMessage: prompt,
        ),
      ),
    );
  }

  void _earnSparks(int amount, {String reason = 'Nice move!'}) async {
    final prefs = await SharedPreferences.getInstance();
    final next = (prefs.getInt(_pointsKey) ?? _points) + amount;
    await prefs.setInt(_pointsKey, next);
    if (!mounted) return;
    setState(() => _points = next);
    _showSnack('✨ +$amount Sparks — $reason');
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final challenge = _challenges[_challengeIndex];
    return Scaffold(
      backgroundColor: OvieBrand.background,
      appBar: AppBar(
        backgroundColor: OvieBrand.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Ovie Fun Zone',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: OvieBrand.royalGold.withOpacity(.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: OvieBrand.royalGold.withOpacity(.35)),
            ),
            child: Text('✨ $_points   🔥 $_streak',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 13)),
          ),
        ],
      ),
      body: OvieBackground(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
            children: [
              _heroCard(),
              const SizedBox(height: 12),
              _levelCard(),
              const SizedBox(height: 18),
              _sectionTitle('Today\'s challenge', '25 Sparks'),
              _challengeCard(challenge['title']!, challenge['prompt']!),
              const SizedBox(height: 22),
              _sectionTitle('Instant fun', 'No account data needed'),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.12,
                children: [
                  _funCard(Icons.shuffle_rounded, 'Random gist', 'Get a conversation starter', _newPrompt),
                  _funCard(Icons.local_fire_department_rounded, 'Hot take', 'Pick a side and defend it', () => _showPromptDialog('🔥 Hot Take', _eitherOr[_random.nextInt(_eitherOr.length)])),
                  _funCard(Icons.translate_rounded, 'Naija slang', 'Learn a word for the day', _showSlang),
                  _funCard(Icons.psychology_alt_rounded, 'Deep gist', 'Ask yourself something real', () => _showPromptDialog('🧠 Deep Gist', 'What is one thing you want your future self to thank you for?')),
                  _funCard(Icons.sports_mma_rounded, 'Finish it', 'Complete the sentence', () => _showPromptDialog('😂 Finish My Sentence', _finishMySentence[_random.nextInt(_finishMySentence.length)])),
                  _funCard(Icons.route_rounded, 'Naija life', 'Choose your move', () => _showPromptDialog('🇳🇬 Naija Life Simulator', _naijaSim[_random.nextInt(_naijaSim.length)])),
                  _funCard(Icons.psychology_rounded, 'Guess me', 'What would you choose?', () => _showPromptDialog('🧩 Guess Me', _guessMe[_random.nextInt(_guessMe.length)])),
                  _funCard(Icons.auto_graph_rounded, 'Soft life', 'Spend or build?', () => _showPromptDialog('💰 Soft Life Simulator', 'You get ₦500,000. Split it between enjoyment, savings and investment. What is your ratio?')),
                  _funCard(Icons.music_note_rounded, 'Vibe DJ', 'Choose your mood', () => _showPromptDialog('🎵 Vibe DJ', 'Pick your mood: heartbreak, soft life, gym, late-night gist, faith, focus or main character. Then tell Ovie what song fits.')),
                  _funCard(Icons.emoji_events_rounded, 'Achievements', 'See your Sparks level', () => _showPromptDialog('🏆 Achievements', 'Keep completing challenges, games and conversations to level up your Ovie Sparks.')),
                  _funCard(Icons.casino_rounded, 'Emoji Decode', 'Guess the Nigerian vibe', () => _showPromptDialog('🧩 Decode this', '${_emojiDecode[_random.nextInt(_emojiDecode.length)]}\n\nWhat does this mean to you?')),
                  _funCard(Icons.psychology_alt_rounded, '2 Truths + 1 Lie', 'Spot the lie', () => _showPromptDialog('🕵🏽 Spot the lie', _twoTruthsOneLie[_random.nextInt(_twoTruthsOneLie.length)])),
                  _funCard(Icons.mic_external_on_rounded, 'Call Challenge', 'Try this on your next call', () => _showPromptDialog('🎙️ Call Challenge', _callChallenges[_random.nextInt(_callChallenges.length)])),
                  _funCard(Icons.shuffle_rounded, 'Wild Card', 'Let Ovie choose your vibe', () {
                    final options = ['Chaotic', 'Hype', 'Gist', 'Story'];
                    _showPromptDialog('🎲 Wild Card', 'Your random vibe: ${options[_random.nextInt(options.length)]}\n\nTake it into a call and see what happens.');
                  }),
                ],
              ),
              if (_prompt.isNotEmpty) ...[
                const SizedBox(height: 18),
                _promptCard(),
              ],
              const SizedBox(height: 22),
              _sectionTitle('Call ideas', 'Take one into your next call'),
              ..._conversationStarters.take(4).map((text) => _ideaTile(text)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _levelCard() {
    final level = (_points ~/ 100) + 1;
    final progress = (_points % 100) / 100;
    final badge = level >= 10
        ? '👑 Gist Legend'
        : level >= 5
            ? '🔥 Gist Plug'
            : '✨ Gist Starter';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(.08)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Level $level',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
          const Spacer(),
          Text(badge,
              style: const TextStyle(
                  color: OvieBrand.royalGold, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.white.withOpacity(.08),
            valueColor: const AlwaysStoppedAnimation(OvieBrand.primary),
          ),
        ),
        const SizedBox(height: 8),
        Text('${100 - (_points % 100)} Sparks to the next level',
            style: TextStyle(color: Colors.white.withOpacity(.45), fontSize: 11)),
      ]),
    );
  }

  Widget _heroCard() => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: [
              OvieBrand.primary.withOpacity(.65),
              OvieBrand.secondary.withOpacity(.5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withOpacity(.12)),
          boxShadow: [
            BoxShadow(
                color: OvieBrand.primary.withOpacity(.28),
                blurRadius: 28,
                offset: const Offset(0, 10)),
          ],
        ),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Not every visit has to be serious 😎',
              style: TextStyle(
                  color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          Text('Talk. Laugh. Debate. Learn.',
              style: TextStyle(
                  color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, height: 1.15)),
          SizedBox(height: 8),
          Text('Collect Sparks while you discover your next conversation.',
              style: TextStyle(color: Colors.white70, height: 1.35)),
        ]),
      );

  Widget _sectionTitle(String title, String trailing) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
          Text(trailing,
              style: TextStyle(
                  color: Colors.white.withOpacity(.4),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _challengeCard(String title, String prompt) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.055),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: OvieBrand.secondary.withOpacity(.25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: OvieBrand.secondary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(prompt,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.35)),
          const SizedBox(height: 16),
          OvieGradientButton(
            label: _challengeDone ? 'COMPLETED TODAY' : 'I DID IT  +25',
            icon: _challengeDone
                ? Icons.check_circle_rounded
                : Icons.bolt_rounded,
            active: !_challengeDone,
            onPressed: _challengeDone ? null : _completeChallenge,
          ),
        ]),
      );

  static const List<Color> _cardAccents = [
    Color(0xFF8B5CF6),
    Color(0xFF4F8CFF),
    Color(0xFFF5C451),
    Color(0xFFFF6B6B),
    Color(0xFF34D399),
    Color(0xFFEC6FB0),
  ];

  Widget _funCard(IconData icon, String title, String subtitle, VoidCallback onTap) {
    final accent = _cardAccents[title.hashCode.abs() % _cardAccents.length];
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.045),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accent.withOpacity(.22)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: accent.withOpacity(.16),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const Spacer(),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.white.withOpacity(.45), fontSize: 11.5, height: 1.25)),
        ]),
      ),
    );
  }

  Widget _promptCard() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: OvieBrand.royalGold.withOpacity(.08),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: OvieBrand.royalGold.withOpacity(.25)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('💬', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(_prompt,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _ideaTile(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          tileColor: Colors.white.withOpacity(.04),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          leading: const Icon(Icons.chat_bubble_outline_rounded, color: OvieBrand.secondary),
          title: Text(text,
              style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.35)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        ),
      );
}
