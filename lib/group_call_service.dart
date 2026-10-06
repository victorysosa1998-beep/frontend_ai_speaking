import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'secrets.dart';

class GroupCallHost {
  final String token;
  final String url;
  final String room;
  final String identity;
  final String inviteCode;
  final int secondsRemaining;
  final int purchasedCredits;

  const GroupCallHost({
    required this.token,
    required this.url,
    required this.room,
    required this.identity,
    required this.inviteCode,
    required this.secondsRemaining,
    required this.purchasedCredits,
  });

  factory GroupCallHost.fromJson(Map<String, dynamic> json) => GroupCallHost(
        token: json['token'] as String,
        url: json['url'] as String,
        room: json['room'] as String,
        identity: (json['identity'] as String?) ?? '',
        inviteCode: json['invite_code'] as String,
        secondsRemaining: (json['seconds_remaining'] as num?)?.toInt() ?? 0,
        purchasedCredits: (json['purchased_credits'] as num?)?.toInt() ?? 0,
      );
}

class GroupCallJoin {
  final String token;
  final String url;
  final String room;
  final String identity;

  const GroupCallJoin({
    required this.token,
    required this.url,
    required this.room,
    required this.identity,
  });

  factory GroupCallJoin.fromJson(Map<String, dynamic> json) => GroupCallJoin(
        token: json['token'] as String,
        url: json['url'] as String,
        room: json['room'] as String,
        identity: json['identity'] as String,
      );
}

class GroupCallService {
  static const String baseUrl = 'https://web-production-6c359.up.railway.app';

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString('sympy_user_id');
    if (deviceId == null || deviceId.isEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch.toString();
      deviceId = 'user_${now.substring(now.length > 10 ? now.length - 10 : 0)}';
      await prefs.setString('sympy_user_id', deviceId);
    }
    return {
      'Content-Type': 'application/json',
      'X-API-KEY': AppSecrets.appApiKey,
      'X-Device-Id': deviceId,
    };
  }

  static Future<GroupCallHost> createHost({
    required String gender,
    required String vibe,
  }) async {
    final uri = Uri.parse('$baseUrl/get_token').replace(queryParameters: {
      'gender': gender,
      'vibe': vibe,
      'mode': 'group',
    });
    final response = await http.get(uri, headers: await _headers()).timeout(
          const Duration(seconds: 15),
        );
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response, 'Could not create the group call.'));
    }
    return GroupCallHost.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  static Future<GroupCallJoin> joinWithInvite(String inviteCode) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/join_group_room'),
          headers: await _headers(),
          body: jsonEncode({'invite_code': inviteCode.trim()}),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response, 'Could not join this Ovie room.'));
    }
    return GroupCallJoin.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  static Future<void> reportUsage(int durationSeconds) async {
    if (durationSeconds <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('sympy_user_id');
    if (deviceId == null || deviceId.isEmpty) return;
    try {
      await http.post(
        Uri.parse('$baseUrl/call_ended?duration_seconds=$durationSeconds'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 8));
    } catch (_) {
      // The existing 1:1 call path already handles retry-on-next-launch.
      // Group calls fail silently here so a network blip cannot trap the user.
    }
  }


  static Future<void> notifyGroupMembers({required String groupId, required String inviteCode, required String room, required String hostName, required String voice, required String vibe}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final token = await user.getIdToken();
    try {
      await http.post(
        Uri.parse('$baseUrl/group_call_notify'),
        headers: {'Content-Type': 'application/json', 'X-API-KEY': AppSecrets.appApiKey, 'Authorization': 'Bearer $token'},
        body: jsonEncode({'group_id': groupId, 'invite_code': inviteCode, 'room': room, 'host_name': hostName, 'voice': voice, 'vibe': vibe}),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  static String _errorMessage(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['detail'] is String) {
        return body['detail'] as String;
      }
      if (body is Map && body['detail'] is Map && body['detail']['message'] is String) {
        return body['detail']['message'] as String;
      }
    } catch (_) {}
    return '$fallback (${response.statusCode})';
  }
}
