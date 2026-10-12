import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Length (seconds) of one seamless light-effect loop. Preview and export use the same painter.
const fxLoop = 3.0;
const fxKinds = [('none', 'None'), ('stars', 'Star light'), ('glitter', 'Glitter'), ('bokeh', 'Bokeh'), ('leak', 'Light leak')];
const _seed = {'stars': 11, 'glitter': 23, 'bokeh': 37, 'leak': 5};

void _spark(Canvas c, Offset o, double r, double a, Color col, {bool glow = true}) {
  if (a <= .01) return;
  if (glow) c.drawCircle(o, r * .9, Paint()..color = col.withOpacity(a * .35)..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .6));
  final p = Path()
    ..moveTo(o.dx, o.dy - r)
    ..quadraticBezierTo(o.dx, o.dy, o.dx + r, o.dy)
    ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + r)
    ..quadraticBezierTo(o.dx, o.dy, o.dx - r, o.dy)
    ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy - r);
  c.drawPath(p, Paint()..color = col.withOpacity(a.clamp(0.0, 1.0)));
}

/// Draws one frame of a light effect (transparent background) at time [t] seconds.
void paintFx(Canvas c, Size s, String kind, double t) {
  if (kind == 'none') return;
  final u = s.width / 360, ph = (t % fxLoop) / fxLoop, r = math.Random(_seed[kind] ?? 1);
  double tw(int k, double p0) => .5 + .5 * math.sin(2 * math.pi * (k * ph + p0));
  switch (kind) {
    case 'stars':
      for (var i = 0; i < 30; i++) {
        final x = r.nextDouble() * s.width, y = r.nextDouble() * s.height, sz = (4 + r.nextDouble() * 11) * u, k = 1 + r.nextInt(3), w = tw(k, r.nextDouble());
        _spark(c, Offset(x, y), sz * (.55 + .45 * w), w * w, Color.lerp(Colors.white, const Color(0xFFFFE6A8), r.nextDouble())!);
      }
    case 'glitter':
      for (var i = 0; i < 100; i++) {
        final x = r.nextDouble() * s.width, y = r.nextDouble() * s.height, sz = (1.6 + r.nextDouble() * 3.4) * u, k = 2 + r.nextInt(4), w = tw(k, r.nextDouble());
        _spark(c, Offset(x, y), sz, w * w * w, Color.lerp(const Color(0xFFFFD76A), Colors.white, r.nextDouble())!, glow: false);
      }
    case 'bokeh':
      for (var i = 0; i < 14; i++) {
        final x = r.nextDouble() * s.width, y = r.nextDouble() * s.height, rad = (14 + r.nextDouble() * 28) * u, p0 = r.nextDouble(), p1 = r.nextDouble();
        final a = .08 + .12 * tw(2, p0), col = Color.lerp(Colors.white, const Color(0xFFFFC2DD), r.nextDouble())!;
        c.drawCircle(Offset(x + math.cos(2 * math.pi * (ph + p1)) * 10 * u, y + math.sin(2 * math.pi * (ph + p0)) * 18 * u), rad, Paint()..color = col.withOpacity(a)..maskFilter = MaskFilter.blur(BlurStyle.normal, rad * .35));
      }
    case 'leak':
      final k = .22 + .16 * math.sin(2 * math.pi * 2 * ph), box = Offset.zero & s;
      for (final top in [true, false]) {
        final cx = s.width * (.5 + (top ? .45 : -.45) * math.sin(2 * math.pi * ph)), o = Offset(cx, top ? s.height * .12 : s.height * .9);
        c.drawRect(box, Paint()..shader = ui.Gradient.radial(o, s.width * .95, [const Color(0xFFFFB86B).withOpacity(k), const Color(0xFFFF6B9D).withOpacity(k * .4), Colors.transparent], const [0, .5, 1]));
      }
  }
}

class _FxP extends CustomPainter {
  final String kind;
  final Animation<double> a;
  _FxP(this.kind, this.a) : super(repaint: a);
  @override
  void paint(Canvas c, Size s) => paintFx(c, s, kind, a.value * fxLoop);
  @override
  bool shouldRepaint(_FxP o) => o.kind != kind;
}

/// A self-animating light effect layer (stars, glitter, bokeh, light leak).
class FxOverlay extends StatefulWidget {
  final String kind;
  const FxOverlay(this.kind, {super.key});
  @override
  State<FxOverlay> createState() => _FxO();
}

class _FxO extends State<FxOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(child: CustomPaint(size: Size.infinite, painter: _FxP(widget.kind, c)));
}

/// Fade + slide-up entrance; later [index]es arrive a little later (staggered).
class FadeSlide extends StatelessWidget {
  final Widget child;
  final int index;
  const FadeSlide({super.key, required this.child, this.index = 0});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 380 + 70 * (index % 8)),
        curve: Curves.easeOutCubic,
        builder: (_, v, c) => Opacity(opacity: v.clamp(0.0, 1.0), child: Transform.translate(offset: Offset(0, 26 * (1 - v)), child: c)),
        child: child,
      );
}

/// Shrinks slightly while pressed.
class Pressable extends StatefulWidget {
  final Widget child;
  const Pressable({super.key, required this.child});
  @override
  State<Pressable> createState() => _PressS();
}

class _PressS extends State<Pressable> {
  bool down = false;
  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => setState(() => down = true),
        onPointerUp: (_) => setState(() => down = false),
        onPointerCancel: (_) => setState(() => down = false),
        child: AnimatedScale(scale: down ? .96 : 1, duration: const Duration(milliseconds: 110), curve: Curves.easeOut, child: widget.child),
      );
}

/// Gentle floating / tilting loop.
class Floating extends StatefulWidget {
  final Widget child;
  final double phase;
  const Floating({super.key, required this.child, this.phase = 0});
  @override
  State<Floating> createState() => _FloatS();
}

class _FloatS extends State<Floating> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600))..repeat();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        builder: (_, child) {
          final s = math.sin(2 * math.pi * (c.value + widget.phase));
          return Transform.translate(offset: Offset(0, s * 6), child: Transform.rotate(angle: s * .012, child: child));
        },
        child: widget.child,
      );
}

/// Rebuilds with a value that breathes between 0 and 1 (for glowing buttons).
class Pulse extends StatefulWidget {
  final Widget Function(double v) builder;
  const Pulse({super.key, required this.builder});
  @override
  State<Pulse> createState() => _PulseS();
}

class _PulseS extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: c, builder: (_, __) => widget.builder(Curves.easeInOut.transform(c.value)));
}
