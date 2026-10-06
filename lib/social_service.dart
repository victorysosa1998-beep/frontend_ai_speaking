import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'secrets.dart';

class SocialService {
  SocialService._();
  static final instance = SocialService._();
  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;
  final storage = FirebaseStorage.instance;
  final picker = ImagePicker();

  String get uid => auth.currentUser!.uid;

  String conversationId(String a, String b) {
    final ids = [a, b]..sort();
    return ids.join('_');
  }

  Future<String?> uploadProfileImage() async {
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 82, maxWidth: 1200);
    if (file == null) return null;
    final ref = storage.ref('profiles/$uid/avatar.jpg');
    await ref.putData(await file.readAsBytes(), SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();
    await db.collection('users').doc(uid).set({'photo_url': url}, SetOptions(merge: true));
    await auth.currentUser?.updatePhotoURL(url);
    return url;
  }

  static final RegExp usernamePattern = RegExp(r'^[a-z][a-z0-9_]{2,19}$');
  static const Set<String> reservedUsernames = {
    'admin', 'administrator', 'support', 'ovie', 'sympy', 'official', 'moderator',
    'mod', 'help', 'staff', 'system', 'null', 'undefined', 'user', 'users',
    'settings', 'security', 'contact', 'about', 'privacy', 'terms', 'api',
  };

  String normalizeUsername(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
  }

  bool isValidUsername(String value) {
    final u = value.trim().toLowerCase();
    return usernamePattern.hasMatch(u) && !reservedUsernames.contains(u);
  }

  Future<bool> isUsernameAvailable(String value) async {
    final u = normalizeUsername(value);
    if (!isValidUsername(u)) return false;
    final snap = await db.collection('usernames').doc(u).get();
    return !snap.exists || snap.data()?['uid'] == uid;
  }

  String _usernameBase(String name) {
    final cleaned = normalizeUsername(name);
    if (cleaned.length >= 3) return cleaned.substring(0, cleaned.length > 16 ? 16 : cleaned.length);
    return 'ovie';
  }

  Future<String> _claimAvailableUsername(String preferred) async {
    final base = _usernameBase(preferred);
    final candidates = <String>[base];
    for (var i = 0; i < 30; i++) {
      candidates.add('$base${100 + i}');
    }
    candidates.add('ovie${uid.substring(0, 6).toLowerCase()}');

    for (final candidate in candidates) {
      if (!isValidUsername(candidate)) continue;
      final usernameRef = db.collection('usernames').doc(candidate);
      final claimed = await db.runTransaction<bool>((tx) async {
        final existing = await tx.get(usernameRef);
        if (existing.exists && existing.data()?['uid'] != uid) return false;
        tx.set(usernameRef, {
          'uid': uid,
          'username': candidate,
          'created_at': existing.data()?['created_at'] ?? FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return true;
      });
      if (claimed) return candidate;
    }
    throw StateError('Could not generate a unique username. Please choose one.');
  }

  Future<void> ensureSocialProfile() async {
    final user = auth.currentUser;
    if (user == null) return;
    final ref = db.collection('users').doc(user.uid);
    final snap = await ref.get();
    final name = user.displayName?.trim().isNotEmpty == true ? user.displayName!.trim() : 'Ovie User';
    final existing = snap.data() ?? <String, dynamic>{};
    var username = (existing['username'] ?? '').toString().trim().toLowerCase();

    if (username.isEmpty || !isValidUsername(username)) {
      username = await _claimAvailableUsername(name);
    } else {
      final available = await isUsernameAvailable(username);
      if (!available) username = await _claimAvailableUsername(name);
      else {
        final usernameRef = db.collection('usernames').doc(username);
        await usernameRef.set({'uid': uid, 'username': username}, SetOptions(merge: true));
      }
    }

    await ref.set({
      'display_name': existing['display_name'] ?? name,
      'username': username,
      'email': user.email,
      'bio': existing['bio'] ?? 'Finding my vibe on Ovie ✨',
      'photo_url': existing['photo_url'] ?? user.photoURL,
      'created_at': existing['created_at'] ?? FieldValue.serverTimestamp(),
      'friends_count': existing['friends_count'] ?? 0,
      'followers_count': existing['followers_count'] ?? 0,
      'following_count': existing['following_count'] ?? 0,
      'posts_count': existing['posts_count'] ?? 0,
      'status_count': existing['status_count'] ?? 0,
    }, SetOptions(merge: true));
  }

  Future<void> changeUsername(String requested) async {
    final next = normalizeUsername(requested);
    if (!isValidUsername(next)) {
      throw FormatException('Username must be 3–20 characters, start with a letter, and use only letters, numbers or _.');
    }
    final profileRef = db.collection('users').doc(uid);
    final profile = await profileRef.get();
    final old = (profile.data()?['username'] ?? '').toString().toLowerCase();
    if (next == old) return;

    final nextRef = db.collection('usernames').doc(next);
    final oldRef = old.isEmpty ? null : db.collection('usernames').doc(old);
    await db.runTransaction((tx) async {
      final taken = await tx.get(nextRef);
      final oldSnap = oldRef == null ? null : await tx.get(oldRef);
      if (taken.exists && taken.data()?['uid'] != uid) {
        throw StateError('That username is already taken.');
      }
      tx.set(nextRef, {'uid': uid, 'username': next, 'created_at': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      tx.update(profileRef, {'username': next});
      if (oldRef != null && oldSnap != null && oldSnap.exists && oldSnap.data()?['uid'] == uid) tx.delete(oldRef);
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> myProfile() => db.collection('users').doc(uid).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> feed() => db.collection('posts').orderBy('created_at', descending: true).limit(60).snapshots();

  Future<void> createPost(String text, {String? imageUrl}) async {
    final profile = await db.collection('users').doc(uid).get();
    final data = profile.data() ?? {};
    await db.collection('posts').add({
      'author_id': uid,
      'author_name': data['display_name'] ?? auth.currentUser?.displayName ?? 'Ovie User',
      'author_username': data['username'] ?? '',
      'author_photo': data['photo_url'] ?? auth.currentUser?.photoURL,
      'text': text.trim(),
      'image_url': imageUrl,
      'created_at': FieldValue.serverTimestamp(),
      'likes': <String>[],
      'comments_count': 0,
    });
  }

  Future<void> createStatus(String text) async {
    final profile = await db.collection('users').doc(uid).get();
    final data = profile.data() ?? {};
    await db.collection('statuses').add({
      'author_id': uid,
      'author_name': data['display_name'] ?? 'Ovie User',
      'author_photo': data['photo_url'] ?? auth.currentUser?.photoURL,
      'text': text.trim(),
      'created_at': FieldValue.serverTimestamp(),
      'expires_at': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
      'likes': <String>[],
      'comments_count': 0,
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> statuses() => db.collection('statuses').where('expires_at', isGreaterThan: Timestamp.now()).orderBy('expires_at').limit(50).snapshots();

  Future<void> toggleLike(String postId, List<dynamic> likes) async {
    final ref = db.collection('posts').doc(postId);
    await ref.update({'likes': likes.contains(uid) ? FieldValue.arrayRemove([uid]) : FieldValue.arrayUnion([uid])});
  }

  Future<void> addComment(String postId, String text) async {
    if (text.trim().isEmpty) return;
    final profile = await db.collection('users').doc(uid).get();
    final data = profile.data() ?? {};
    final post = db.collection('posts').doc(postId);
    await db.runTransaction((tx) async {
      tx.set(post.collection('comments').doc(), {
        'author_id': uid,
        'author_name': data['display_name'] ?? 'Ovie User',
        'author_photo': data['photo_url'],
        'text': text.trim(),
        'created_at': FieldValue.serverTimestamp(),
      });
      tx.update(post, {'comments_count': FieldValue.increment(1)});
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> comments(String postId) => db.collection('posts').doc(postId).collection('comments').orderBy('created_at').limit(100).snapshots();

  Future<void> toggleStatusLike(String statusId, List<dynamic> likes) async {
    final ref = db.collection('statuses').doc(statusId);
    await ref.update({'likes': likes.contains(uid) ? FieldValue.arrayRemove([uid]) : FieldValue.arrayUnion([uid])});
  }

  Future<void> addStatusComment(String statusId, String text) async {
    if (text.trim().isEmpty) return;
    final profile = await db.collection('users').doc(uid).get();
    final data = profile.data() ?? {};
    final status = db.collection('statuses').doc(statusId);
    await db.runTransaction((tx) async {
      tx.set(status.collection('comments').doc(), {'author_id': uid, 'author_name': data['display_name'] ?? 'Ovie User', 'text': text.trim(), 'created_at': FieldValue.serverTimestamp()});
      tx.update(status, {'comments_count': FieldValue.increment(1)});
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> statusComments(String statusId) => db.collection('statuses').doc(statusId).collection('comments').orderBy('created_at').limit(100).snapshots();

  Future<void> sendFriendRequest(String targetUid) async {
    if (targetUid == uid) return;
    final target = await db.collection('users').doc(targetUid).get();
    if (!target.exists) throw StateError('User not found.');
    final existingFriend = await db.collection('users').doc(uid).collection('friends').doc(targetUid).get();
    if (existingFriend.exists) return;
    final id = '${uid}_$targetUid';
    await db.collection('friend_requests').doc(id).set({
      'from': uid, 'to': targetUid, 'status': 'pending', 'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> respondFriendRequest(String requestId, String fromUid, bool accept) async {
    final request = db.collection('friend_requests').doc(requestId);
    await db.runTransaction((tx) async {
      final requestSnap = await tx.get(request);
      if (!requestSnap.exists || requestSnap.data()?['to'] != uid || requestSnap.data()?['status'] != 'pending') {
        throw StateError('This friend request is no longer available.');
      }
      if (!accept) {
        tx.update(request, {'status': 'declined', 'responded_at': FieldValue.serverTimestamp()});
        return;
      }
      final meRef = db.collection('users').doc(uid);
      final fromRef = db.collection('users').doc(fromUid);
      final meFriend = meRef.collection('friends').doc(fromUid);
      final fromFriend = fromRef.collection('friends').doc(uid);
      tx.update(request, {'status': 'accepted', 'responded_at': FieldValue.serverTimestamp()});
      tx.set(meFriend, {'since': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      tx.set(fromFriend, {'since': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      tx.update(meRef, {'friends_count': FieldValue.increment(1)});
      tx.update(fromRef, {'friends_count': FieldValue.increment(1)});
    });
  }

  Future<bool> areFriends(String otherUid) async {
    return (await db.collection('users').doc(uid).collection('friends').doc(otherUid).get()).exists;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> incomingRequests() => db.collection('friend_requests').where('to', isEqualTo: uid).where('status', isEqualTo: 'pending').orderBy('created_at', descending: true).snapshots();

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> searchUsers(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final snap = await db.collection('users').orderBy('username').startAt([q]).endAt(['$q\uf8ff']).limit(20).get();
    return snap.docs.where((d) => d.id != uid).toList();
  }

  Future<void> sendMessage(String otherUid, String text) async {
    final clean = text.trim();
    if (clean.isEmpty || otherUid == uid) return;
    final blockedByMe = await db.collection('users').doc(uid).collection('blocked').doc(otherUid).get();
    final blockedMe = await db.collection('users').doc(otherUid).collection('blocked').doc(uid).get();
    if (blockedByMe.exists || blockedMe.exists) { throw StateError('Messaging is unavailable for this user.'); }
    final id = conversationId(uid, otherUid);
    final profile = await db.collection('users').doc(uid).get();
    final name = profile.data()?['display_name'] ?? 'Ovie User';
    final convo = db.collection('conversations').doc(id);
    await convo.set({
      'members': [uid, otherUid],
      'last_message': clean,
      'last_sender': uid,
      'last_message_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await convo.collection('messages').add({
      'sender_id': uid, 'sender_name': name, 'text': clean, 'created_at': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> conversations() => db.collection('conversations').where('members', arrayContains: uid).orderBy('updated_at', descending: true).snapshots();
  Stream<QuerySnapshot<Map<String, dynamic>>> messages(String otherUid) => db.collection('conversations').doc(conversationId(uid, otherUid)).collection('messages').orderBy('created_at').limitToLast(100).snapshots();

  Future<void> blockUser(String targetUid) async => db.collection('users').doc(uid).collection('blocked').doc(targetUid).set({'created_at': FieldValue.serverTimestamp()});
  Future<void> reportUser(String targetUid, String reason) async => db.collection('reports').add({'reporter_id': uid, 'target_id': targetUid, 'reason': reason, 'created_at': FieldValue.serverTimestamp(), 'type': 'user'});
  Future<void> reportPost(String postId, String reason) async => db.collection('reports').add({'reporter_id': uid, 'target_id': postId, 'reason': reason, 'created_at': FieldValue.serverTimestamp(), 'type': 'post'});

  // ---------------- AI GROUP CHAT ----------------
  String groupConversationId(String a, String b) => '${a}_$b';

  Future<List<DocumentSnapshot<Map<String, dynamic>>>> findUsersByUsernames(List<String> usernames) async {
    final out = <DocumentSnapshot<Map<String, dynamic>>>[];
    for (final raw in usernames) {
      final u = normalizeUsername(raw.replaceFirst('@', ''));
      if (u.isEmpty) continue;
      final snap = await db.collection('usernames').doc(u).get();
      final target = snap.data()?['uid']?.toString();
      if (target == null || target == uid) continue;
      final profile = await db.collection('users').doc(target).get();
      if (profile.exists) out.add(profile);
    }
    return out;
  }

  Future<String> createGroup({required String name, required List<String> memberIds, bool aiEnabled = true}) async {
    final unique = <String>{uid, ...memberIds}.toList();
    final ref = db.collection('group_chats').doc();
    final profile = await db.collection('users').doc(uid).get();
    final data = profile.data() ?? {};
    await ref.set({
      'name': name.trim().isEmpty ? 'New Ovie Squad' : name.trim(),
      'members': unique,
      'admins': [uid],
      'ai_enabled': aiEnabled,
      'ai_mode': 'mention_only',
      'created_by': uid,
      'created_at': FieldValue.serverTimestamp(),
      'last_message': '',
      'last_message_at': FieldValue.serverTimestamp(),
      'last_sender': data['username'] ?? '',
    });
    return ref.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> myGroups() => db.collection('group_chats').where('members', arrayContains: uid).orderBy('last_message_at', descending: true).limit(50).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> groupMessages(String groupId) => db.collection('group_chats').doc(groupId).collection('messages').orderBy('created_at').limitToLast(100).snapshots();

  Future<void> sendGroupMessage(String groupId, String text, {bool ai = false, String? senderName}) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    final profile = await db.collection('users').doc(uid).get();
    final d = profile.data() ?? {};
    final name = senderName ?? d['display_name'] ?? 'Ovie User';
    final username = d['username'] ?? '';
    final ref = db.collection('group_chats').doc(groupId);
    await ref.collection('messages').add({
      'sender_id': ai ? 'sympy_ai' : uid,
      'sender_name': ai ? 'Ovie' : name,
      'sender_username': ai ? 'ovie' : username,
      'text': clean,
      'is_ai': ai,
      'created_at': FieldValue.serverTimestamp(),
    });
    await ref.set({'last_message': clean, 'last_message_at': FieldValue.serverTimestamp(), 'last_sender': ai ? 'Ovie' : username}, SetOptions(merge: true));
  }

  Future<String?> askGroupAI(String groupId, {required List<Map<String, String>> context, required String request}) async {
    final user = auth.currentUser;
    if (user == null) return null;
    final idToken = await user.getIdToken();
    final response = await http.post(
      Uri.parse('${GroupCallServiceLike.baseUrl}/group_chat_ai'),
      headers: {'Content-Type': 'application/json', 'X-API-KEY': AppSecrets.appApiKey, 'Authorization': 'Bearer $idToken'},
      body: jsonEncode({'group_id': groupId, 'request': request, 'context': context}),
    ).timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) throw Exception('Ovie could not answer right now.');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['reply']?.toString();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> activeGroupCall(String groupId) => db.collection('group_chats').doc(groupId).snapshots();

  Future<void> publishGroupCall(String groupId, Map<String, dynamic> call) async {
    await db.collection('group_chats').doc(groupId).set({'active_call': call}, SetOptions(merge: true));
  }

  Future<void> endGroupCall(String groupId) async {
    await db.collection('group_chats').doc(groupId).set({'active_call': FieldValue.delete()}, SetOptions(merge: true));
  }

}

class GroupCallServiceLike { static const String baseUrl = 'https://web-production-6c359.up.railway.app'; }
