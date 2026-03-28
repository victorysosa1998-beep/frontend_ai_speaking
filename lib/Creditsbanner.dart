import 'package:flutter/material.dart';
import 'package:loveable/Upgradepage.dart';


/// Drop this widget inside any screen (e.g. SympyChatPage) when credits == 0.
/// Pass [remainingCredits] and it auto-shows/hides.
class CreditsBanner extends StatelessWidget {
  final int remainingCredits;
  final VoidCallback? onDismiss;

  const CreditsBanner({
    super.key,
    required this.remainingCredits,
    this.onDismiss,
  });

  bool get _show => remainingCredits <= 0;

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UpgradePage()),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1a0533), Color(0xFF0a1a3a)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.purpleAccent.withOpacity(0.35),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.purpleAccent.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.purpleAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.bolt_rounded,
                color: Colors.purpleAccent,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "You're out of credits",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Top up to keep chatting with Sympy",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7b2ff7), Color(0xFF4776E6)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                "Top Up",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Low-credit warning banner shown when credits are running low (≤10)
class LowCreditsBanner extends StatelessWidget {
  final int remainingCredits;

  const LowCreditsBanner({super.key, required this.remainingCredits});

  @override
  Widget build(BuildContext context) {
    if (remainingCredits > 10 || remainingCredits <= 0) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UpgradePage()),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.amber.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.amber, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "$remainingCredits credits left — top up soon",
                style: TextStyle(
                  color: Colors.amber.withOpacity(0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              "Top up →",
              style: TextStyle(
                color: Colors.amber.withOpacity(0.85),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}