import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:loveable/secrets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the full credit picture for a user:
///   purchasedCredits     — paid Firestore credits
///   callMinutesRemaining — free daily Redis call quota in minutes
class CreditBalance {
  final int purchasedCredits;
  final int callMinutesRemaining;
  final int callSecondsRemaining;
  final bool hasPurchasedCredits;
  final bool hasFreeMinutes;

  const CreditBalance({
    this.purchasedCredits = 0,
    this.callMinutesRemaining = 0,
    this.callSecondsRemaining = 0,
    this.hasPurchasedCredits = false,
    this.hasFreeMinutes = false,
  });

  /// True if the user has ANY usable balance (paid or free)
  bool get hasAnyBalance => hasPurchasedCredits || hasFreeMinutes;

  /// Main label shown in the drawer
  String get displayLabel {
    if (hasPurchasedCredits) {
      return "$purchasedCredits call credit${purchasedCredits == 1 ? '' : 's'} left";
    }
    if (hasFreeMinutes) {
      return "$callMinutesRemaining free min${callMinutesRemaining == 1 ? '' : 's'} left today";
    }
    return "No call credits left";
  }

  /// Subtitle shown below the label
  String get displaySublabel {
    if (hasPurchasedCredits) return "5 credits = 1 min voice call · Chat is free";
    if (hasFreeMinutes) return "Free daily call minutes · Chat is free";
    return "Top up for more voice calls";
  }

  factory CreditBalance.fromJson(Map<String, dynamic> j) {
    return CreditBalance(
      purchasedCredits: (j['purchased_credits'] as num?)?.toInt() ?? 0,
      callMinutesRemaining: (j['call_minutes_remaining'] as num?)?.toInt() ?? 0,
      callSecondsRemaining: (j['call_seconds_remaining'] as num?)?.toInt() ?? 0,
      hasPurchasedCredits: j['has_purchased_credits'] as bool? ?? false,
      hasFreeMinutes: j['has_free_minutes'] as bool? ?? false,
    );
  }
}

/// Centralized credit management service.
class CreditService {
  static final CreditService _instance = CreditService._internal();
  factory CreditService() => _instance;
  CreditService._internal();

  final _db = FirebaseFirestore.instance;
  static const _baseUrl = "https://web-production-6c359.up.railway.app";

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference? get _userDoc {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid);
  }

  /// Get the device/user ID (same logic as SympyChatPage uses for X-User-Id)
  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('sympy_user_id') ?? _uid ?? '';
  }

  /// Fetch the full balance from the backend — combines:
  ///   1. Purchased Firestore credits
  ///   2. Free daily Redis call quota (minutes remaining today)
  /// Falls back to Firestore-only if the backend is unreachable.
  Future<CreditBalance> getFullBalance() async {
    final uid = _uid;
    if (uid == null) return const CreditBalance();

    try {
      final deviceId = await _getDeviceId();
      final response = await http.get(
        Uri.parse("$_baseUrl/credits/balance"),
        headers: {
          "X-API-KEY": AppSecrets.appApiKey,
          "X-User-Id": uid,
          "X-Device-Id": deviceId,
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return CreditBalance.fromJson(data);
      }
    } catch (e) {
      print('[CreditService] getFullBalance error: $e');
    }

    // Fallback: Firestore only
    final purchased = await getCredits();
    return CreditBalance(
      purchasedCredits: purchased,
      hasPurchasedCredits: purchased > 0,
    );
  }

  /// Real-time stream of purchased Firestore credits.
  /// Used after admin approves a top-up so the drawer updates instantly.
  Stream<int> creditsStream() {
    final ref = _userDoc;
    if (ref == null) return Stream.value(0);
    return ref.snapshots().map((snap) {
      if (!snap.exists) return 0;
      return (snap.data() as Map<String, dynamic>)['credits'] as int? ?? 0;
    });
  }

  /// Get purchased credit balance once (non-streaming).
  Future<int> getCredits() async {
    try {
      final doc = await _userDoc?.get();
      if (doc == null || !doc.exists) return 0;
      return (doc.data() as Map<String, dynamic>)['credits'] as int? ?? 0;
    } catch (e) {
      print('[CreditService] getCredits error: $e');
      return 0;
    }
  }

  /// Atomically deduct [amount] purchased credits via Firestore transaction.
  Future<bool> deductCredits(int amount) async {
    final ref = _userDoc;
    if (ref == null) return false;
    try {
      bool success = false;
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) {
          success = false;
          return;
        }
        final current =
            (snap.data() as Map<String, dynamic>)['credits'] as int? ?? 0;
        if (current < amount) {
          success = false;
          return;
        }
        tx.update(ref, {'credits': FieldValue.increment(-amount)});
        success = true;
      });
      return success;
    } catch (e) {
      print('[CreditService] deductCredits error: $e');
      return false;
    }
  }

  /// Check if user has enough purchased credits without deducting.
  Future<bool> hasCredits({int required = 1}) async {
    final credits = await getCredits();
    return credits >= required;
  }

  /// Store FCM token so Cloud Functions can send push notifications.
  Future<void> saveFcmToken(String token) async {
    try {
      await _userDoc?.set({'fcm_token': token}, SetOptions(merge: true));
    } catch (e) {
      print('[CreditService] saveFcmToken error: $e');
    }
  }
}

/// Credit cost constants.
/// Text chat is FREE — credits are only spent on voice calls.
class CreditCost {
  CreditCost._();

  /// Voice calls cost 5 credits per minute.
  /// The free daily quota (Redis) is used first.
  /// When free minutes run out, purchased credits are deducted.
  static const int voiceCallPerMinute = 5;

  // Text chat is FREE — do not deduct any credits for messages.
}