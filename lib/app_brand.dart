import 'package:flutter/material.dart';

/// Ovie is the public app brand. Technical package/Firebase identifiers are
/// intentionally kept unchanged so existing production data and builds remain compatible.
class OvieBrand {
  static const String name = 'Ovie';
  static const String tagline = 'Your AI companion, your world.';
  static const Color background = Color(0xFF070817);
  static const Color surface = Color(0xFF101329);
  static const Color card = Color(0xFF12162F);
  static const Color primary = Color(0xFF8B5CF6);
  static const Color secondary = Color(0xFF4F8CFF);
  static const Color royalGold = Color(0xFFF5C451);

  static const LinearGradient royalGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFF4F8CFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class OvieLogo extends StatelessWidget {
  final double size;
  final bool showWordmark;

  const OvieLogo({super.key, this.size = 52, this.showWordmark = true});

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: OvieBrand.royalGradient,
        boxShadow: [
          BoxShadow(
            color: OvieBrand.primary.withOpacity(.30),
            blurRadius: size * .45,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(
        Icons.workspace_premium_rounded,
        color: OvieBrand.royalGold,
        size: size * .52,
      ),
    );

    if (!showWordmark) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 12),
        const Text(
          'Ovie',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -.5,
          ),
        ),
      ],
    );
  }
}
