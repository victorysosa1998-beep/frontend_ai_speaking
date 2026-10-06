import 'package:flutter/material.dart';
import 'package:ovie/UpgradePage.dart';
import 'app_brand.dart';

void _openUpgrade(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const UpgradePage()),
  );
}

/// Drop this widget inside any screen (e.g. OvieChatPage) when credits == 0.
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            OvieBrand.primary.withOpacity(0.22),
            OvieBrand.secondary.withOpacity(0.16),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OvieBrand.primary.withOpacity(0.40)),
        boxShadow: [
          BoxShadow(
            color: OvieBrand.primary.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openUpgrade(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: OvieBrand.royalGold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.bolt_rounded,
                      color: OvieBrand.royalGold, size: 22),
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
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Top up to keep chatting with Ovie",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: OvieBrand.royalGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "Top Up",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: OvieBrand.royalGold.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OvieBrand.royalGold.withOpacity(0.28)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openUpgrade(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: OvieBrand.royalGold, size: 17),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "$remainingCredits credits left — top up soon",
                    style: TextStyle(
                      color: OvieBrand.royalGold.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  "Top up →",
                  style: TextStyle(
                    color: OvieBrand.royalGold.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
