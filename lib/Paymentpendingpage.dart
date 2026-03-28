import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:loveable/Upgradepage.dart';


/// Shown after user taps "I've Made the Payment".
/// Listens for real-time Firestore updates on the order doc.
/// When admin approves → shows success and pops back.
class PaymentPendingPage extends StatefulWidget {
  final String reference;
  final CreditPack pack;
  final String orderId;

  const PaymentPendingPage({
    super.key,
    required this.reference,
    required this.pack,
    required this.orderId,
  });

  @override
  State<PaymentPendingPage> createState() => _PaymentPendingPageState();
}

class _PaymentPendingPageState extends State<PaymentPendingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  StreamSubscription<DocumentSnapshot>? _orderSub;
  String _status = 'pending'; // pending | approved | rejected

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _listenForApproval();
  }

  void _listenForApproval() {
    _orderSub = FirebaseFirestore.instance
        .collection('pending_orders')
        .doc(widget.orderId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) return;
      final data = snap.data()!;
      final status = data['status'] as String? ?? 'pending';
      if (mounted) {
        setState(() => _status = status);
        if (status == 'approved') {
          _pulseController.stop();
          _showApprovedDialog();
        } else if (status == 'rejected') {
          _pulseController.stop();
        }
      }
    });
  }

  void _showApprovedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0d0d2b),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: const Color(0xFF22c55e).withOpacity(0.3)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF22c55e).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline,
                  color: Color(0xFF22c55e), size: 44),
            ),
            const SizedBox(height: 18),
            const Text(
              "Credits Added!",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "${widget.pack.credits} credits have been added to your account.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                Navigator.of(ctx).pop();
                // Pop all the way back to first route (home/chat)
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF22c55e), Color(0xFF16a34a)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text(
                    "Start Chatting!",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _orderSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _status != 'pending',
      child: Scaffold(
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

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _status == 'rejected'
                    ? _buildRejected()
                    : _buildPending(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPending() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Animated pulse
        AnimatedBuilder(
          animation: _pulseController,
          builder: (_, __) => Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.purpleAccent
                  .withOpacity(0.1 + _pulseController.value * 0.1),
              border: Border.all(
                color: Colors.purpleAccent
                    .withOpacity(0.3 + _pulseController.value * 0.2),
                width: 2,
              ),
            ),
            child: const Icon(Icons.hourglass_top_rounded,
                color: Colors.purpleAccent, size: 44),
          ),
        ),
        const SizedBox(height: 28),

        const Text(
          "Verifying Payment",
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "Our team is reviewing your payment. Credits will be added to your account within 1 hour.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontSize: 14,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 32),

        // Reference box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purpleAccent.withOpacity(0.07),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: Colors.purpleAccent.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Text(
                "Your Reference",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.reference,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Order summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${widget.pack.name} Pack",
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              Text(
                "${widget.pack.credits} credits",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),

        Text(
          "You can safely close this screen.\nWe'll notify you when credits are added.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.2),
            fontSize: 12,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 16),

        // Allow going home
        GestureDetector(
          onTap: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
          child: Text(
            "Go back to home",
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 13,
              decoration: TextDecoration.underline,
              decorationColor: Colors.white.withOpacity(0.3),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRejected() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.cancel_outlined,
              color: Colors.redAccent, size: 44),
        ),
        const SizedBox(height: 24),
        const Text(
          "Payment Not Confirmed",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "We couldn't verify your payment. Please check your transfer and contact support at support@sympyapp.com with your reference.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 13,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Text(
            "Reference: ${widget.reference}",
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontFamily: 'monospace',
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 32),
        GestureDetector(
          onTap: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
          child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: const Center(
              child: Text(
                "Go back to home",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}