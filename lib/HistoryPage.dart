import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryPage extends StatelessWidget {
  final Map<String, List<Map<String, dynamic>>> conversations;
  final void Function(List<Map<String, dynamic>>) onSelectConversation;

  const HistoryPage({
    super.key,
    required this.conversations,
    required this.onSelectConversation,
  });

  @override
  Widget build(BuildContext context) {
    final sortedKeys = conversations.keys.toList()
      ..sort((a, b) => int.parse(b).compareTo(int.parse(a)));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Conversation History"),
        backgroundColor: Colors.black87,
      ),
      body: sortedKeys.isEmpty
          ? const Center(
              child: Text(
                "No history yet!",
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
            )
          : ListView.builder(
              itemCount: sortedKeys.length,
              itemBuilder: (context, index) {
                final key = sortedKeys[index];
                final conv = conversations[key]!;
                final lastMessage =
                    conv.isNotEmpty ? conv.last['content'] : "Empty conversation";
                final timestamp = DateTime.fromMillisecondsSinceEpoch(int.parse(key));

                return ListTile(
                  title: Text(
                    lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    "${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}",
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  tileColor: Colors.grey.withOpacity(0.1),
                  onTap: () {
                    onSelectConversation(conv);
                    Navigator.pop(context);
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text("Delete Conversation?"),
                          content: const Text(
                              "Are you sure you want to delete this conversation permanently?"),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text("Cancel"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text("Delete"),
                            ),
                          ],
                        ),
                      );

                      if (confirmed ?? false) {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove(key);
                        final allKeys = prefs.getStringList("conversation_keys") ?? [];
                        allKeys.remove(key);
                        await prefs.setStringList("conversation_keys", allKeys);

                        // Force rebuild
                        (context as Element).reassemble();
                      }
                    },
                  ),
                );
              },
            ),
      backgroundColor: Colors.black,
    );
  }
}