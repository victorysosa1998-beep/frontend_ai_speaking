import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:loveable/secrets.dart';
import 'package:loveable/Upgradepage.dart';
import 'package:loveable/PaymentPendingPage.dart';

// ─── YOUR PAYMENT DETAILS — edit these ───────────────────────────────────────
const _kBankName       = "Opay";
const _kAccountName    = "Sosa Technologies";
const _kAccountNumber  = "9059607887";        // <-- replace with real account
const _kUsdtAddress    = "TGEU6XSCuKZdeAf8Xwn2jkgsJVeY7hNd51"; // <-- TRC-20
const _kUsdtNetwork    = "TRC-20 (Tron)";
// ─────────────────────────────────────────────────────────────────────────────

String _generateReference() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rand = Random.secure();
  final suffix =
      List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  return 'SYMP-$suffix';
}

class PaymentDetailsPage extends StatefulWidget {
  final CreditPack pack;
  final String method; // 'ngn' or 'usdt'

  const PaymentDetailsPage({
    super.key,
    required this.pack,
    required this.method,
  });

  @override
  State<PaymentDetailsPage> createState() => _PaymentDetailsPageState();
}

class _PaymentDetailsPageState extends State<PaymentDetailsPage> {
  late final String _reference;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _reference = _generateReference();
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("$label copied!"),
        backgroundColor: const Color(0xFF22c55e),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static const _baseUrl = "https://web-production-6c359.up.railway.app";

  Future<void> _iHavePaid() async {
    setState(() => _submitting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Not logged in");

      // 1. Write pending order to Firestore
      final orderRef = await FirebaseFirestore.instance
          .collection('pending_orders')
          .add({
        'user_id': user.uid,
        'user_email': user.email ?? '',
        'user_name': user.displayName ?? '',
        'pack_id': widget.pack.id,
        'pack_name': widget.pack.name,
        'credits': widget.pack.credits,
        'amount_ngn': widget.pack.priceNgn,
        'amount_usdt': widget.pack.priceUsdt,
        'payment_method': widget.method,
        'reference': _reference,
        'status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
        'approved_at': null,
        'approved_by': null,
      });

      // 2. Notify admin via Telegram (fire and forget — don't block the user)
      _notifyAdmin(orderRef.id, user);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentPendingPage(
            reference: _reference,
            pack: widget.pack,
            orderId: orderRef.id,
          ),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Fire-and-forget — notifies admin via Telegram without blocking the user.
  Future<void> _notifyAdmin(String orderId, User user) async {
    try {
      await http.post(
        Uri.parse("$_baseUrl/notify_admin"),
        headers: {
          "Content-Type": "application/json",
          "X-API-KEY": AppSecrets.appApiKey,
        },
        body: jsonEncode({
          "order_id": orderId,
          "user_name": user.displayName ?? '',
          "user_email": user.email ?? '',
          "pack_name": widget.pack.name,
          "credits": widget.pack.credits,
          "amount_ngn": widget.pack.priceNgn,
          "amount_usdt": widget.pack.priceUsdt,
          "payment_method": widget.method,
          "reference": _reference,
        }),
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      // Silently ignore — Firestore order is already written.
      // Admin can still see it in AdminPanelPage.
      debugPrint('[PaymentDetails] _notifyAdmin error: $e');
    }
  }

  bool get _isNgn => widget.method == 'ngn';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060714),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF060714), Color(0xFF0d0d2b), Color(0xFF060714)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            top: -80, right: -80,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent.withOpacity(0.07),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left,
                            color: Colors.white, size: 30),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            "Payment Details",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    children: [
                      const SizedBox(height: 8),
                      // Amount card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              (_isNgn
                                  ? const Color(0xFF22c55e)
                                  : const Color(0xFF26a17b)).withOpacity(0.12),
                              Colors.transparent,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: (_isNgn
                                ? const Color(0xFF22c55e)
                                : const Color(0xFF26a17b)).withOpacity(0.25),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              "AMOUNT TO PAY",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 11,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isNgn
                                  ? "₦${widget.pack.priceNgn}"
                                  : "\$${widget.pack.priceUsdt.toStringAsFixed(2)} USDT",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${widget.pack.credits} credits · ${widget.pack.name} Pack",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      _SectionLabel(_isNgn ? "BANK DETAILS" : "USDT WALLET"),
                      const SizedBox(height: 10),

                      if (_isNgn) ...[
                        _DetailRow(label: "Bank", value: _kBankName,
                            onCopy: () => _copy(_kBankName, "Bank name")),
                        _DetailRow(label: "Account Name", value: _kAccountName,
                            onCopy: () => _copy(_kAccountName, "Account name")),
                        _DetailRow(label: "Account Number", value: _kAccountNumber,
                            isHighlighted: true,
                            onCopy: () => _copy(_kAccountNumber, "Account number")),
                      ] else ...[
                        _DetailRow(label: "Network", value: _kUsdtNetwork, onCopy: null),
                        _DetailRow(label: "Wallet Address", value: _kUsdtAddress,
                            isHighlighted: true, isAddress: true,
                            onCopy: () => _copy(_kUsdtAddress, "Wallet address")),
                      ],
                      const SizedBox(height: 20),

                      _SectionLabel("YOUR UNIQUE REFERENCE"),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => _copy(_reference, "Reference"),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.purpleAccent.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.purpleAccent.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _reference,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Include this as payment description/memo",
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.35),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.purpleAccent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.copy_outlined,
                                    color: Colors.purpleAccent, size: 18),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Warning
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.amber.withOpacity(0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline,
                                color: Colors.amber, size: 16),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _isNgn
                                    ? "Transfer the exact amount and include your reference as the payment description. Payments without a reference may be delayed."
                                    : "Send the exact USDT amount on TRC-20 network ONLY. Do NOT use ERC-20 or BEP-20 — funds sent on the wrong network will be lost.",
                                style: TextStyle(
                                  color: Colors.amber.withOpacity(0.7),
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom CTA
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF060714).withOpacity(0.97),
                border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.07))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _submitting ? null : _iHavePaid,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: !_submitting
                            ? const LinearGradient(
                                colors: [Color(0xFF7b2ff7), Color(0xFF4776E6)],
                              )
                            : null,
                        color: _submitting
                            ? Colors.white.withOpacity(0.06)
                            : null,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: _submitting
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                "I've Made the Payment  ✓",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Only tap this after you have sent the payment",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.2),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.3),
          fontSize: 11,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w600,
        ),
      );
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlighted;
  final bool isAddress;
  final VoidCallback? onCopy;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isHighlighted = false,
    this.isAddress = false,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isHighlighted
            ? Colors.blueAccent.withOpacity(0.06)
            : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighlighted
              ? Colors.blueAccent.withOpacity(0.2)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.35), fontSize: 11)),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isAddress ? 13 : 15,
                    fontWeight:
                        isHighlighted ? FontWeight.bold : FontWeight.w500,
                    fontFamily: isAddress ? 'monospace' : null,
                  ),
                  maxLines: isAddress ? 2 : 1,
                  overflow: isAddress
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onCopy != null) ...[
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onCopy,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.copy_outlined,
                    color: Colors.white.withOpacity(0.4), size: 15),
              ),
            ),
          ],
        ],
      ),
    );
  }
}