import 'dart:math';
import 'dart:ui';

void _gen(int left, List<int> cur, List<List<int>> out) {
  if (left == 0) {
    out.add(List.of(cur));
    return;
  }
  if (cur.length >= 6) return;
  for (var p = min(5, left); p >= 1; p--) {
    cur.add(p);
    _gen(left - p, cur, out);
    cur.removeLast();
  }
}

List<Rect> _rows(List<int> c, bool flip) => [
      for (var y = 0; y < c.length; y++)
        for (var x = 0; x < c[y]; x++)
          flip
              ? Rect.fromLTWH(y / c.length, x / c[y], 1 / c.length, 1 / c[y])
              : Rect.fromLTWH(x / c[y], y / c.length, 1 / c[y], 1 / c.length),
    ];

/// All row-based layouts (and their rotated versions) for [n] photos.
List<List<Rect>> layoutsFor(int n) {
  if (n == 1) return [[const Rect.fromLTWH(0, 0, 1, 1)]];
  final all = <List<int>>[];
  _gen(n, [], all);
  double score(List<int> c) => c.fold(0.0, (s, v) => s + pow(v - n / c.length, 2));
  all.sort((a, b) => score(a).compareTo(score(b)));
  final top = all.take(150).toList();
  return [
    if (n >= 3) [const Rect.fromLTWH(0, 0, .5, 1), for (var i = 0; i < n - 1; i++) Rect.fromLTWH(.5, i / (n - 1), .5, 1 / (n - 1))],
    if (n >= 3) [const Rect.fromLTWH(0, 0, 1, .5), for (var i = 0; i < n - 1; i++) Rect.fromLTWH(i / (n - 1), .5, 1 / (n - 1), .5)],
    for (final c in top) _rows(c, false),
    for (final c in top) _rows(c, true),
  ];
}
