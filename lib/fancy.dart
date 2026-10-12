import 'dart:math' as math;
import 'package:flutter/material.dart';

/// One cell of a stylish layout. kind 0 = convex polygon (points in 0..1),
/// 1 = heart, 2 = circle (both fitted inside rect r).
class Fc {
  final int kind;
  final List<Offset> pts;
  final Rect? r;
  const Fc(this.kind, this.pts, [this.r]);
}

class FL {
  final String name;
  final List<Fc> cells;
  const FL(this.name, this.cells);
  int get n => cells.length;
}

List<Offset> _sq() => const [Offset(0, 0), Offset(1, 0), Offset(1, 1), Offset(0, 1)];

List<Offset> _dedupe(List<Offset> p) {
  final o = <Offset>[];
  for (final q in p) {
    if (o.isEmpty || (q - o.last).distance > 1e-6) o.add(q);
  }
  if (o.length > 1 && (o.first - o.last).distance < 1e-6) o.removeLast();
  return o;
}

/// keep the part of [p] where a*x + b*y <= d
List<Offset> _clip(List<Offset> p, double a, double b, double d) {
  final o = <Offset>[];
  for (var i = 0; i < p.length; i++) {
    final c = p[i], n = p[(i + 1) % p.length];
    final fc = a * c.dx + b * c.dy - d, fn = a * n.dx + b * n.dy - d;
    if (fc <= 0) o.add(c);
    if ((fc < 0 && fn > 0) || (fc > 0 && fn < 0)) {
      final t = fc / (fc - fn);
      o.add(Offset(c.dx + (n.dx - c.dx) * t, c.dy + (n.dy - c.dy) * t));
    }
  }
  return o;
}

/// keep the left (or right) side of the line a->b
List<Offset> _side(List<Offset> p, Offset a, Offset b, bool left) {
  final dx = b.dx - a.dx, dy = b.dy - a.dy, s = left ? 1.0 : -1.0, k = dx * a.dy - dy * a.dx;
  return _clip(p, s * dy, -s * dx, -s * k);
}

List<FL> _buildFancy() {
  Fc poly(List<Offset> p) => Fc(0, _dedupe(p));
  Fc rc(double x, double y, double w, double h) => poly([Offset(x, y), Offset(x + w, y), Offset(x + w, y + h), Offset(x, y + h)]);
  const c = Offset(.5, .5);
  final sq = _sq(), out = <FL>[];
  Fc wedge(double a0, double a1) => poly(_side(_side(sq, c, c + Offset(math.cos(a0), math.sin(a0)), true), c, c + Offset(math.cos(a1), math.sin(a1)), false));
  out.add(FL('Heart', [rc(0, 0, .5, .5), rc(.5, 0, .5, .5), rc(0, .5, .5, .5), rc(.5, .5, .5, .5), const Fc(1, [], Rect.fromLTWH(.17, .17, .66, .66))]));
  out.add(FL('Pinwheel', [rc(0, 0, .65, .35), rc(.65, 0, .35, .65), rc(.35, .65, .65, .35), rc(0, .35, .35, .65), rc(.35, .35, .3, .3)]));
  for (final n in [3, 5]) {
    out.add(FL('Diagonal $n', [for (var i = 0; i < n; i++) poly(_clip(_clip(sq, -1, -1, -2 * i / n), 1, 1, 2 * (i + 1) / n))]));
  }
  const k = .3;
  out.add(FL('Slant 3', [for (var i = 0; i < 3; i++) poly(_clip(_clip(sq, -1, -k, -i * (1 + k) / 3), 1, k, (i + 1) * (1 + k) / 3))]));
  for (final n in [6, 8]) {
    out.add(FL('Radial $n', [for (var i = 0; i < n; i++) wedge(i * 2 * math.pi / n, (i + 1) * 2 * math.pi / n)]));
  }
  out.add(FL('Circles', [rc(0, 0, .66, 1), const Fc(2, [], Rect.fromLTWH(.68, .02, .3, .3)), const Fc(2, [], Rect.fromLTWH(.68, .35, .3, .3)), const Fc(2, [], Rect.fromLTWH(.68, .68, .3, .3))]));
  const l1a = Offset(0, .4), l1b = Offset(1, .3), l2a = Offset(.45, 0), l2b = Offset(.6, 1);
  Fc quad(bool below, bool leftOf) => poly(_side(_side(sq, l1a, l1b, below), l2a, l2b, leftOf));
  out.add(FL('Slant cross', [quad(false, true), quad(false, false), quad(true, true), quad(true, false)]));
  return out;
}

final fancyLayouts = _buildFancy();

/// inset (d > 0) or grow (d < 0) a convex polygon
List<Offset> _inset(List<Offset> p, double d) {
  final n = p.length;
  if (n < 3 || d == 0) return p;
  var area = 0.0;
  for (var i = 0; i < n; i++) {
    area += p[i].dx * p[(i + 1) % n].dy - p[(i + 1) % n].dx * p[i].dy;
  }
  final s = area > 0 ? 1.0 : -1.0, pts = <Offset>[], dirs = <Offset>[];
  for (var i = 0; i < n; i++) {
    final e = p[(i + 1) % n] - p[i], u = e / e.distance;
    pts.add(p[i] + Offset(-u.dy, u.dx) * s * d);
    dirs.add(u);
  }
  final out = <Offset>[];
  for (var i = 0; i < n; i++) {
    final j = (i + n - 1) % n, cr = dirs[j].dx * dirs[i].dy - dirs[j].dy * dirs[i].dx;
    if (cr.abs() < 1e-6) {
      out.add(pts[i]);
      continue;
    }
    final w = pts[i] - pts[j], t = (w.dx * dirs[i].dy - w.dy * dirs[i].dx) / cr;
    out.add(pts[j] + dirs[j] * t);
  }
  return out;
}

Rect _fit(Fc c, double W, double H, double d) {
  final r = c.r!, side = math.min(r.width * W, r.height * H);
  return Rect.fromCenter(center: Offset((r.left + r.width / 2) * W, (r.top + r.height / 2) * H), width: side - 2 * d, height: side - 2 * d);
}

Path fcPath(Fc c, double W, double H, double d) {
  if (c.kind == 0) return Path()..addPolygon(_inset([for (final o in c.pts) Offset(o.dx * W, o.dy * H)], d), true);
  final rr = _fit(c, W, H, d);
  if (c.kind == 2) return Path()..addOval(rr);
  final w = rr.width, h = rr.height;
  return (Path()
        ..moveTo(w / 2, h)
        ..cubicTo(-w * .2, h * .55, w * .1, -h * .05, w / 2, h * .3)
        ..cubicTo(w * .9, -h * .05, w * 1.2, h * .55, w / 2, h)
        ..close())
      .shift(rr.topLeft);
}

Rect fcBounds(Fc c, double W, double H) {
  if (c.kind != 0) return _fit(c, W, H, 0);
  var l = 1e9, t = 1e9, r = -1e9, b = -1e9;
  for (final o in c.pts) {
    l = math.min(l, o.dx * W);
    r = math.max(r, o.dx * W);
    t = math.min(t, o.dy * H);
    b = math.max(b, o.dy * H);
  }
  return Rect.fromLTRB(l, t, r, b);
}

class FcClip extends CustomClipper<Path> {
  final Fc c;
  final double gap, grow;
  FcClip(this.c, this.gap, [this.grow = 0]);
  @override
  Path getClip(Size s) => fcPath(c, s.width, s.height, gap / 2 - grow);
  @override
  bool shouldReclip(FcClip o) => o.c != c || o.gap != gap || o.grow != grow;
}

class FlThumb extends CustomPainter {
  final FL f;
  FlThumb(this.f);
  @override
  void paint(Canvas cv, Size s) {
    final fill = Paint()..color = Colors.white24, line = Paint()..color = Colors.white70..style = PaintingStyle.stroke..strokeWidth = 1.4;
    for (final c in f.cells) {
      final p = fcPath(c, s.width, s.height, .8);
      cv.drawPath(p, fill);
      cv.drawPath(p, line);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

Path heartPath(Rect rr) {
  final w = rr.width, h = rr.height;
  return (Path()
        ..moveTo(w / 2, h)
        ..cubicTo(-w * .2, h * .55, w * .1, -h * .05, w / 2, h * .3)
        ..cubicTo(w * .9, -h * .05, w * 1.2, h * .55, w / 2, h)
        ..close())
      .shift(rr.topLeft);
}
