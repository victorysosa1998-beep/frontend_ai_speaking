import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_brand.dart';
import 'ovie_ui.dart';

class HistoryPage extends StatefulWidget {
  final Map<String, List<Map<String, dynamic>>> conversations;
  final void Function(List<Map<String, dynamic>>) onSelectConversation;

  const HistoryPage({
    super.key,
    required this.conversations,
    required this.onSelectConversation,
  });

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  // Local copy so deleting an item refreshes the list immediately.
  late final Map<String, List<Map<String, dynamic>>> _conversations =
      Map.of(widget.conversations);

  List<String> get _sortedKeys {
    final keys = _conversations.keys.where((k) => int.tryParse(k) != null).toList();
    keys.sort((a, b) => int.parse(b).compareTo(int.parse(a)));
    return keys;
  }

  String _dateLabel(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final diff = today.difference(day).inDays;
    final time =
        "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
    if (diff == 0) return "Today  $time";
    if (diff == 1) return "Yesterday  $time";
    return "${t.day}/${t.month}/${t.year}  $time";
  }

  Future<void> _delete(String key) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: OvieBrand.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        title: const Text("Delete Conversation?", style: TextStyle(color: Colors.white)),
        content: Text(
          "Are you sure you want to delete this conversation permanently?",
          style: TextStyle(color: Colors.white.withOpacity(0.55)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text("Cancel", style: TextStyle(color: Colors.white.withOpacity(0.55))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    final allKeys = prefs.getStringList("conversation_keys") ?? [];
    allKeys.remove(key);
    await prefs.setStringList("conversation_keys", allKeys);
    if (!mounted) return;
    setState(() => _conversations.remove(key));
  }

  @override
  Widget build(BuildContext context) {
    final keys = _sortedKeys;

    return Scaffold(
      backgroundColor: OvieBrand.background,
      body: OvieBackground(
        child: SafeArea(
          child: Column(
            children: [
              const OvieHeader(title: "Conversation History"),
              Expanded(
                child: keys.isEmpty
                    ? _emptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: keys.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final key = keys[index];
                          final conv = _conversations[key]!;
                          final lastMessage = conv.isNotEmpty
                              ? (conv.last['content'] ?? '').toString()
                              : "Empty conversation";
                          final timestamp =
                              DateTime.fromMillisecondsSinceEpoch(int.parse(key));

                          return OvieGlassCard(
                            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                            onTap: () {
                              widget.onSelectConversation(conv);
                              Navigator.pop(context);
                            },
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(11),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [
                                      OvieBrand.primary.withOpacity(0.25),
                                      OvieBrand.secondary.withOpacity(0.25),
                                    ]),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.chat_bubble_outline_rounded,
                                      color: Colors.white, size: 18),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        lastMessage.isEmpty ? "Empty conversation" : lastMessage,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        "${_dateLabel(timestamp)}  •  ${conv.length} messages",
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.35),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: "Delete",
                                  icon: Icon(Icons.delete_outline_rounded,
                                      color: Colors.redAccent.withOpacity(0.75), size: 21),
                                  onPressed: () => _delete(key),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.04),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Icon(Icons.chat_bubble_outline_rounded,
                color: Colors.white.withOpacity(0.25), size: 40),
          ),
          const SizedBox(height: 18),
          const Text("No history yet",
              style: TextStyle(
                  color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text("Your chats with Ovie will show up here.",
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
        ],
      ),
    );
  }
}
