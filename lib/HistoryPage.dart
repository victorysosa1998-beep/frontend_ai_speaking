

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryPage extends StatelessWidget {
  final Map<String, List<Map<String, dynamic>>> conversations;
  final void Function(List<Map<String, dynamic>>) onSelectConversation;

  const HistoryPage({super.key, required this.conversations, required this.onSelectConversation});

  @override
  Widget build(BuildContext context) {
    final sortedKeys = conversations.keys.toList()..sort((a, b) => int.parse(b).compareTo(int.parse(a)));

    return Scaffold(
      backgroundColor: const Color(0xFF060714),
      body: Stack(children: [
        Container(decoration: const BoxDecoration(gradient: LinearGradient(
          colors: [Color(0xFF060714), Color(0xFF0d0d2b), Color(0xFF060714)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ))),
        Positioned(top: -60, right: -60, child: Container(width: 240, height: 240,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blueAccent.withOpacity(0.07)))),
        Positioned(bottom: 100, left: -50, child: Container(width: 200, height: 200,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.purpleAccent.withOpacity(0.06)))),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.chevron_left, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context)),
                const Expanded(child: Center(child: Text("Conversation History", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)))),
                const SizedBox(width: 48),
              ]),
            ),
            Expanded(
              child: sortedKeys.isEmpty
                ? Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.04),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Icon(Icons.chat_bubble_outline, color: Colors.white.withOpacity(0.2), size: 40),
                      ),
                      const SizedBox(height: 16),
                      Text("No history yet!", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16)),
                    ]),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sortedKeys.length,
                    itemBuilder: (context, index) {
                      final key = sortedKeys[index];
                      final conv = conversations[key]!;
                      final lastMessage = conv.isNotEmpty ? conv.last['content'] : "Empty conversation";
                      final timestamp = DateTime.fromMillisecondsSinceEpoch(int.parse(key));

                      return GestureDetector(
                        onTap: () { onSelectConversation(conv); Navigator.pop(context); },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.07)),
                          ),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.chat_bubble_outline, color: Colors.blueAccent, size: 18),
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 4),
                              Text(
                                "${timestamp.day}/${timestamp.month}/${timestamp.year}  ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}",
                                style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
                              ),
                            ])),
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: Colors.redAccent.withOpacity(0.7), size: 20),
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    backgroundColor: const Color(0xFF0d0d2b),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withOpacity(0.08))),
                                    title: const Text("Delete Conversation?", style: TextStyle(color: Colors.white)),
                                    content: Text("Are you sure you want to delete this conversation permanently?",
                                      style: TextStyle(color: Colors.white.withOpacity(0.5))),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Cancel", style: TextStyle(color: Colors.white.withOpacity(0.5)))),
                                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.redAccent))),
                                    ],
                                  ),
                                );
                                if (confirmed ?? false) {
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.remove(key);
                                  final allKeys = prefs.getStringList("conversation_keys") ?? [];
                                  allKeys.remove(key);
                                  await prefs.setStringList("conversation_keys", allKeys);
                                  (context as Element).reassemble();
                                }
                              },
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
            ),
          ]),
        ),
      ]),
    );
  }
}