import 'package:flutter/material.dart';

/// A glowing ember circle that gently flickers (scale + halo opacity), looping
/// every ~3.4s. Reused by the Library streak card and the Stats screen at
/// different [size]s.
class EmberFlame extends StatefulWidget {
  const EmberFlame({super.key, this.size = 62});

  final double size;

  @override
  State<EmberFlame> createState() => _EmberFlameState();
}

class _EmberFlameState extends State<EmberFlame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Ease in/out flicker between ~0.97 and ~1.06; halo brightens with it.
        final t = Curves.easeInOut.transform(_controller.value);
        final scale = 0.97 + t * 0.09;
        final glow = 0.7 + t * 0.3;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(0, 0.2),
                radius: 0.75,
                colors: [
                  Color(0xFFFFD28A),
                  Color(0xFFF59331),
                  Color(0xFFD8551D),
                  Color(0xFF9C3B14),
                ],
                stops: [0, 0.38, 0.7, 1],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF8A3D).withValues(alpha: glow * 0.55),
                  blurRadius: widget.size * 0.42,
                  spreadRadius: widget.size * 0.08,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
