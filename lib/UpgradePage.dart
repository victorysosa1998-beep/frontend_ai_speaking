import 'package:flutter/material.dart';
import 'package:loveable/PaymentMethodPage.dart';

class CreditPack {
  final String id;
  final String name;
  final int credits;
  final int priceNgn;
  final double priceUsdt;
  final bool isPopular;
  final String description;
  final IconData icon;

  const CreditPack({
    required this.id,
    required this.name,
    required this.credits,
    required this.priceNgn,
    required this.priceUsdt,
    this.isPopular = false,
    required this.description,
    required this.icon,
  });
}

const List<CreditPack> kCreditPacks = [
  CreditPack(
    id: 'starter',
    name: 'Starter',
    credits: 50,
    priceNgn: 2500,
    priceUsdt: 1.55,
    description: '~10 mins voice call',
    icon: Icons.bolt_outlined,
  ),
  CreditPack(
    id: 'popular',
    name: 'Popular',
    credits: 200,
    priceNgn: 8500,
    priceUsdt: 5.30,
    isPopular: true,
    description: '~40 mins voice call · best value',
    icon: Icons.star_outline_rounded,
  ),
  CreditPack(
    id: 'pro',
    name: 'Pro',
    credits: 500,
    priceNgn: 19500,
    priceUsdt: 12.20,
    description: '~100 mins voice call',
    icon: Icons.workspace_premium_outlined,
  ),
  CreditPack(
    id: 'unlimited',
    name: 'Unlimited',
    credits: 1200,
    priceNgn: 42000,
    priceUsdt: 26.25,
    description: '~240 mins voice call — power user',
    icon: Icons.all_inclusive_rounded,
  ),
];

class UpgradePage extends StatefulWidget {
  const UpgradePage({super.key});

  @override
  State<UpgradePage> createState() => _UpgradePageState();
}

class _UpgradePageState extends State<UpgradePage> {
  CreditPack? _selected;

  @override
  void initState() {
    super.initState();
    _selected = kCreditPacks.firstWhere((p) => p.isPopular);
  }

  void _proceed() {
    // Guard: should never be null given initState sets it, but safety first
    final CreditPack? pack = _selected;
    if (pack == null) return;

    // Use mounted check before navigating — avoids use-after-dispose crash
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentMethodPage(pack: pack),
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
                colors: [
                  Color(0xFF060714),
                  Color(0xFF0d0d2b),
                  Color(0xFF060714)
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purpleAccent.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent.withOpacity(0.06),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                            "Top Up Credits",
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
                      // Info banner
                      Container(
                        margin:
                            const EdgeInsets.only(bottom: 24, top: 8),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.purpleAccent.withOpacity(0.12),
                              Colors.blueAccent.withOpacity(0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color:
                                  Colors.purpleAccent.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.purpleAccent
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.bolt_rounded,
                                  color: Colors.purpleAccent, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Credits are for voice calls only",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Chat is free forever. 5 credits = 1 min voice call. Pay via bank transfer or USDT.",
                                    style: TextStyle(
                                      color:
                                          Colors.white.withOpacity(0.45),
                                      fontSize: 12,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 12),
                        child: Text(
                          "CHOOSE A PACK",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 11,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      // Pack cards
                      ...kCreditPacks.map((pack) => _PackCard(
                            pack: pack,
                            isSelected: _selected?.id == pack.id,
                            onTap: () =>
                                setState(() => _selected = pack),
                          )),

                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline,
                              color: Colors.white.withOpacity(0.2),
                              size: 14),
                          const SizedBox(width: 6),
                          Text(
                            "Manual verification · Credits added within 1 hour",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.25),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Sticky bottom CTA
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF060714).withOpacity(0.95),
                border: Border(
                    top: BorderSide(
                        color: Colors.white.withOpacity(0.07))),
              ),
              child: GestureDetector(
                onTap: _selected != null ? _proceed : null,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: _selected != null
                        ? const LinearGradient(
                            colors: [
                              Color(0xFF7b2ff7),
                              Color(0xFF4776E6)
                            ],
                          )
                        : null,
                    color: _selected == null
                        ? Colors.white.withOpacity(0.06)
                        : null,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: _selected != null
                        ? [
                            BoxShadow(
                              color: const Color(0xFF7b2ff7)
                                  .withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      _selected != null
                          ? "Continue with ${_selected!.name} Pack  →"
                          : "Select a pack to continue",
                      style: TextStyle(
                        color: _selected != null
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
          ),
        ],
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  final CreditPack pack;
  final bool isSelected;
  final VoidCallback onTap;

  const _PackCard({
    required this.pack,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.purpleAccent.withOpacity(0.08)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? Colors.purpleAccent.withOpacity(0.45)
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
                color: isSelected
                    ? Colors.purpleAccent.withOpacity(0.15)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(pack.icon,
                  color: isSelected
                      ? Colors.purpleAccent
                      : Colors.white.withOpacity(0.4),
                  size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        pack.name,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withOpacity(0.8),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (pack.isPopular) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                Colors.purpleAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            "BEST VALUE",
                            style: TextStyle(
                              color: Colors.purpleAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    pack.description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
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
                  "₦${pack.priceNgn}",
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withOpacity(0.7),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "\$${pack.priceUsdt.toStringAsFixed(2)} USDT",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? Colors.purpleAccent
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? Colors.purpleAccent
                      : Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check,
                      color: Colors.white, size: 12)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
