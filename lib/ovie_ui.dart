import 'package:flutter/material.dart';
import 'app_brand.dart';

/// Shared building blocks so every Ovie screen looks like one app.
/// NEW FILE: put it next to app_brand.dart in lib/.

/// Dark gradient page background with two soft brand-coloured glows.
class OvieBackground extends StatelessWidget {
  final Widget child;
  const OvieBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF060714), Color(0xFF0B0D26), Color(0xFF060714)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Positioned(
          top: -110,
          left: -90,
          child: _Glow(size: 340, color: OvieBrand.primary.withOpacity(.20)),
        ),
        Positioned(
          bottom: 40,
          right: -100,
          child: _Glow(size: 300, color: OvieBrand.secondary.withOpacity(.14)),
        ),
        child,
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  final double size;
  final Color color;
  const _Glow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      ),
    );
  }
}

/// Frosted card surface. Pass [onTap] to make it tappable with a ripple.
class OvieGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final Color? borderColor;
  final Color? fill;

  const OvieGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.radius = 20,
    this.borderColor,
    this.fill,
  });

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return Material(
      color: fill ?? Colors.white.withOpacity(.05),
      shape: RoundedRectangleBorder(
        borderRadius: shape,
        side: BorderSide(color: borderColor ?? Colors.white.withOpacity(.09)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Primary call-to-action. When [active] is false it looks disabled but still
/// fires [onPressed], so you can show a "pick something first" message.
class OvieGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool active;

  const OvieGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.active = true,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 56,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: active ? OvieBrand.royalGradient : null,
        color: active ? null : Colors.white.withOpacity(.07),
        border: active ? null : Border.all(color: Colors.white.withOpacity(.08)),
        boxShadow: active
            ? [
                BoxShadow(
                  color: OvieBrand.primary.withOpacity(.40),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ]
            : const [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onPressed,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon,
                      size: 20,
                      color: active ? Colors.white : Colors.white30),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: active ? Colors.white : Colors.white.withOpacity(.3),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
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

/// Round glass icon button (used for back buttons etc.).
class OvieIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  const OvieIconButton({super.key, required this.icon, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(.06),
      shape: CircleBorder(side: BorderSide(color: Colors.white.withOpacity(.08))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 20, color: color ?? Colors.white),
        ),
      ),
    );
  }
}

/// Simple screen header: back button, centred title, optional trailing widget.
class OvieHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  const OvieHeader({super.key, required this.title, this.onBack, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          OvieIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: onBack ?? () => Navigator.maybePop(context),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          SizedBox(width: 44, height: 44, child: trailing),
        ],
      ),
    );
  }
}
