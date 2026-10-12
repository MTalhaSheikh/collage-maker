import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'fancy.dart';

/// Shape transitions (key, label). The next photo opens through the shape.
const transKinds = [('fade', 'Fade'), ('heart', 'Heart'), ('circle', 'Circle'), ('pinwheel', 'Pinwheel'), ('diagonal', 'Diagonal'), ('radial', 'Radial'), ('slant', 'Slant'), ('cross', 'Cross'), ('dots', 'Dots'), ('wipe', 'Wipe')];
const _layoutFor = {'pinwheel': 'Pinwheel', 'diagonal': 'Diagonal 5', 'radial': 'Radial 8', 'slant': 'Slant 3', 'cross': 'Slant cross'};

/// The area of the NEXT picture that is visible at progress [q] (0..1), in a w x h box.
/// Used by both the live preview (ClipPath) and the exported video (mask frames).
Path revealPath(String kind, double q, double w, double h) {
  final e = Curves.easeInOut.transform(q.clamp(0.0, 1.0)).toDouble(), mx = math.max(w, h), diag = math.sqrt(w * w + h * h);
  switch (kind) {
    case 'heart':
      final s = e * 3.6 * mx;
      return heartPath(Rect.fromCenter(center: Offset(w / 2, h / 2 - s * .08), width: s, height: s));
    case 'circle':
      return Path()..addOval(Rect.fromCircle(center: Offset(w / 2, h / 2), radius: e * diag / 2 + 1));
    case 'wipe':
      return Path()..addRect(Rect.fromLTWH(0, 0, w * e + 1, h));
    case 'dots':
      final cols = 6, cell = w / cols, rows = (h / cell).ceil() + 1, r = e * cell * .76, p = Path();
      for (var j = 0; j < rows; j++) {
        for (var i = 0; i < cols; i++) {
          p.addOval(Rect.fromCircle(center: Offset((i + .5) * cell, (j + .5) * cell), radius: r));
        }
      }
      return p;
    default:
      final f = fancyLayouts.firstWhere((l) => l.name == _layoutFor[kind], orElse: () => fancyLayouts.first), n = f.n, p = Path();
      for (var j = 0; j < n; j++) {
        final d = n > 1 ? .45 * j / (n - 1) : 0.0, s = Curves.easeOut.transform(((q - d) / .55).clamp(0.0, 1.0)).toDouble() * 1.03;
        if (s <= 0) continue;
        final c = f.cells[j], a = kind == 'radial' ? Offset(w / 2, h / 2) : fcBounds(c, w, h).center;
        final m = Matrix4.identity()
          ..translate(a.dx, a.dy, 0.0)
          ..scale(s, s, 1.0)
          ..translate(-a.dx, -a.dy, 0.0);
        p.addPath(fcPath(c, w, h, 0).transform(m.storage), Offset.zero);
      }
      return p;
  }
}
