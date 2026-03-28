import 'package:flutter/material.dart';
import 'package:loveable/Paymentdetailspage.dart';
import 'package:loveable/Upgradepage.dart';


class PaymentMethodPage extends StatefulWidget {
  final CreditPack pack;
  const PaymentMethodPage({super.key, required this.pack});

  @override
  State<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

class _PaymentMethodPageState extends State<PaymentMethodPage> {
  String? _method; // 'ngn' or 'usdt'

  void _proceed() {
    if (_method == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentDetailsPage(
          pack: widget.pack,
          method: _method!,
        ),
      ),
    );
  }

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
            top: -60, right: -60,
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purpleAccent.withOpacity(0.07),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // App bar
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
                            "Payment Method",
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
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),

                        // Order summary
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.07)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.purpleAccent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  widget.pack.icon,
                                  color: Colors.purpleAccent,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${widget.pack.name} Pack",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      "${widget.pack.credits} credits",
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.4),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "₦${widget.pack.priceNgn}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    "\$${widget.pack.priceUsdt.toStringAsFixed(2)} USDT",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.3),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        Text(
                          "HOW DO YOU WANT TO PAY?",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 11,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // NGN transfer
                        _MethodCard(
                          icon: Icons.account_balance_outlined,
                          iconColor: const Color(0xFF22c55e),
                          title: "Nigerian Bank Transfer",
                          subtitle: "Pay via bank transfer · Instant verification",
                          badge: "NGN",
                          badgeColor: const Color(0xFF22c55e),
                          isSelected: _method == 'ngn',
                          onTap: () => setState(() => _method = 'ngn'),
                        ),
                        const SizedBox(height: 12),

                        // USDT transfer
                        _MethodCard(
                          icon: Icons.currency_bitcoin,
                          iconColor: const Color(0xFF26a17b),
                          title: "USDT (TRC-20)",
                          subtitle:
                              "Pay with Tether · Tron network only",
                          badge: "USDT",
                          badgeColor: const Color(0xFF26a17b),
                          isSelected: _method == 'usdt',
                          onTap: () => setState(() => _method = 'usdt'),
                        ),
                        const SizedBox(height: 28),

                        // Security note
                        Row(
                          children: [
                            Icon(Icons.verified_user_outlined,
                                color: Colors.white.withOpacity(0.2), size: 14),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Credits are manually verified and loaded within 1 hour of payment confirmation.",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.25),
                                  fontSize: 11,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // CTA
                Padding(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: MediaQuery.of(context).padding.bottom + 20,
                    top: 12,
                  ),
                  child: GestureDetector(
                    onTap: _method != null ? _proceed : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: _method != null
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFF7b2ff7),
                                  Color(0xFF4776E6)
                                ],
                              )
                            : null,
                        color: _method == null
                            ? Colors.white.withOpacity(0.06)
                            : null,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: Text(
                          _method != null
                              ? "Continue to Payment Details  →"
                              : "Select a payment method",
                          style: TextStyle(
                            color: _method != null
                                ? Colors.white
                                : Colors.white.withOpacity(0.3),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _MethodCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? iconColor.withOpacity(0.06)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? iconColor.withOpacity(0.4)
                : Colors.white.withOpacity(0.07),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? iconColor : Colors.transparent,
                border: Border.all(
                  color: isSelected ? iconColor : Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 12)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}