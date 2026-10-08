import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'gen_templates.dart';

const kBg = Color(0xFF14141C), kPanel = Color(0xFF1F1F2B), kPink = Color(0xFFFF4D8D), kViolet = Color(0xFF7C4DFF);
const fonts = ['Poppins', 'Pacifico', 'Bebas Neue', 'Permanent Marker', 'Lobster', 'Dancing Script', 'Anton', 'Satisfy', 'Righteous', 'Caveat', 'Monoton', 'Oswald'];
const colors = [Colors.white, Colors.black, kPink, kViolet, Colors.amber, Colors.teal, Colors.orange, Colors.red, Colors.blue, Colors.green, Color(0xFFFFE4EC)];
const grads = <List<Color>>[[kViolet, kPink], [Color(0xFFFF9966), Color(0xFFFF5E62)], [Color(0xFF36D1DC), Color(0xFF5B86E5)], [Color(0xFF11998E), Color(0xFF38EF7D)], [Color(0xFF232526), Color(0xFF414345)]];

final stickers = <String>[
  for (final r in const [[0x1F600, 0x1F64F], [0x1F400, 0x1F43E], [0x1F337, 0x1F37C], [0x1F380, 0x1F393], [0x1F980, 0x1F9AE], [0x1F300, 0x1F320], [0x1F440, 0x1F4FC], [0x1F680, 0x1F6A4]])
    for (var c = r[0]; c <= r[1]; c++) String.fromCharCode(c),
];

const _id = <double>[1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0];
const filters = <String, List<double>>{
  'Original': _id,
  'Mono': [.33, .59, .11, 0, 0, .33, .59, .11, 0, 0, .33, .59, .11, 0, 0, 0, 0, 0, 1, 0],
  'Gold': [1.2, .1, 0, 0, 15, .1, 1.1, 0, 0, 10, 0, 0, .7, 0, 0, 0, 0, 0, 1, 0],
  'Lomo': [1.3, 0, 0, 0, -20, 0, 1.2, 0, 0, -10, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0],
  'Pink': [1.1, 0, .1, 0, 15, 0, .9, .1, 0, 0, .1, 0, 1.1, 0, 25, 0, 0, 0, 1, 0],
  'Ginkgo': [1, .1, 0, 0, 10, 0, 1.05, .1, 0, 10, 0, 0, .8, 0, -10, 0, 0, 0, 1, 0],
  'Sepia': [.39, .77, .19, 0, 0, .35, .69, .17, 0, 0, .27, .53, .13, 0, 0, 0, 0, 0, 1, 0],
  'Warm': [1.15, 0, 0, 0, 10, 0, 1.05, 0, 0, 0, 0, 0, .85, 0, 0, 0, 0, 0, 1, 0],
  'Cool': [.9, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1.15, 0, 10, 0, 0, 0, 1, 0],
  'Vivid': [1.4, -.2, -.2, 0, 0, -.2, 1.4, -.2, 0, 0, -.2, -.2, 1.4, 0, 0, 0, 0, 0, 1, 0],
  'Night': [.7, 0, 0, 0, 0, 0, .8, 0, 0, 0, 0, 0, 1.2, 0, 10, 0, 0, 0, 1, 0],
  'Fade': [.8, 0, 0, 0, 40, 0, .8, 0, 0, 40, 0, 0, .8, 0, 40, 0, 0, 0, 1, 0],
};

class Dc {
  final String e;
  final double x, y, s, r;
  const Dc(this.e, this.x, this.y, [this.s = 38, this.r = 0]);
}

class Tpl {
  final String name, cat, cap, font;
  final Color bg, ink, patC, fc;
  final Color? bg2;
  final List<Dc> deco;
  final List<Rect> rects;
  final List<double> rots;
  final bool polaroid;
  final double gap, radius, size, fw, capY, ls;
  final bool cardCap;
  final Color? tape;
  final String? img, ov;
  final int pat, shape;
  const Tpl(this.name, this.cat, this.cap, this.font, this.bg, this.bg2, this.ink, this.deco, this.rects,
      {this.rots = const [], this.polaroid = false, this.gap = 0, this.radius = 8, this.size = 34, this.pat = 0, this.patC = const Color(0x22FFFFFF), this.fc = Colors.white, this.fw = 0, this.shape = 0, this.capY = .88, this.img, this.ov, this.ls = 0, this.cardCap = false, this.tape});
  List<Rect> get cells => ov != null ? rects : cardCap ? [for (final r in rects) Rect.fromCenter(center: r.center, width: r.width * .75, height: r.height * .75)] : [for (final r in rects) Rect.fromLTWH(.5 + (r.left - .5) * .9, r.top * .9 + .02, r.width * .9, r.height * .9)];
  int get n => rects.length;
  double rot(int i) => i < rots.length ? rots[i] : 0;
}

class Pat extends CustomPainter {
  final int k;
  final Color c;
  Pat(this.k, this.c);
  @override
  void paint(Canvas cv, Size s) {
    final u = s.width / 340, p = Paint()..color = c, r = Random(7);
    switch (k) {
      case 1:
        for (var y = 0; y < 15; y++) {
          for (var x = 0; x < 15; x++) {
            cv.drawCircle(Offset((x * 24 + (y.isEven ? 12 : 0)) * u, (y * 24 + 12) * u), 2.4 * u, p);
          }
        }
      case 2:
        p.strokeWidth = 12 * u;
        for (var d = -340; d < 340; d += 30) {
          cv.drawLine(Offset(d * u, 0), Offset((d + 340) * u, s.height), p);
        }
      case 3:
        const cs = [Color(0xFFFF4D8D), Color(0xFFFFD54F), Color(0xFF4DD0E1), Colors.white, Color(0xFF7C4DFF)];
        for (var i = 0; i < 70; i++) {
          cv.save();
          cv.translate(r.nextDouble() * s.width, r.nextDouble() * s.height);
          cv.rotate(r.nextDouble() * 6);
          cv.drawRect(Rect.fromLTWH(0, 0, 9 * u, 4 * u), Paint()..color = cs[i % 5].withOpacity(.75));
          cv.restore();
        }
      case 4:
        for (var i = 0; i < 20; i++) {
          p.color = c.withOpacity(.12 + r.nextDouble() * .3);
          cv.drawCircle(Offset(r.nextDouble() * s.width, r.nextDouble() * s.height), (8 + r.nextDouble() * 26) * u, p);
        }
      case 5:
        final cx = s.width / 2, cy = s.height / 2, l = s.width * 1.5;
        for (var i = 0; i < 24; i += 2) {
          final a = i * pi / 12, b = (i + 1) * pi / 12;
          cv.drawPath(Path()..moveTo(cx, cy)..lineTo(cx + l * cos(a), cy + l * sin(a))..lineTo(cx + l * cos(b), cy + l * sin(b))..close(), p);
        }
      case 6:
        p.strokeWidth = 1;
        for (var i = 0; i < 18; i++) {
          cv.drawLine(Offset(i * 20 * u, 0), Offset(i * 20 * u, s.height), p);
          cv.drawLine(Offset(0, i * 20 * u), Offset(s.width, i * 20 * u), p);
        }
      case 7:
        for (var i = 0; i < 28; i++) {
          final x = r.nextDouble() * s.width, y = r.nextDouble() * s.height, q = (3 + r.nextDouble() * 7) * u;
          cv.drawPath(Path()..moveTo(x, y - q)..quadraticBezierTo(x, y, x + q, y)..quadraticBezierTo(x, y, x, y + q)..quadraticBezierTo(x, y, x - q, y)..quadraticBezierTo(x, y, x, y - q), p);
        }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class HeartClip extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    final w = s.width, h = s.height;
    return Path()
      ..moveTo(w / 2, h)
      ..cubicTo(-w * .2, h * .55, w * .1, -h * .05, w / 2, h * .3)
      ..cubicTo(w * .9, -h * .05, w * 1.2, h * .55, w / 2, h)
      ..close();
  }

  @override
  bool shouldReclip(_) => false;
}

Widget shaped(int shape, double radius, double w, Widget c) => switch (shape) {
      1 => ClipPath(clipper: HeartClip(), child: c),
      2 => ClipRRect(borderRadius: BorderRadius.vertical(top: Radius.circular(w / 2), bottom: Radius.circular(radius)), child: c),
      _ => ClipRRect(borderRadius: BorderRadius.circular(radius), child: c),
    };

Widget tplFrame(Tpl t, double w, double h, double radius, double k, Widget Function(double, double) c, {Widget? cap, double bw = 1, double sh = 10, int style = 0}) {
  final cc = t.polaroid && t.cardCap, glass = cc && style == 2, classic = cc && style == 1;
  final side = w * (classic ? .06 : .05) * bw;
  final fr = t.polaroid ? (cc ? (classic ? EdgeInsets.all(side) : EdgeInsets.fromLTRB(side, side, side, h * .2)) : EdgeInsets.fromLTRB(6 * k, 6 * k, 6 * k, 22 * k)) : EdgeInsets.all(t.fw * k);
  final iw = w - fr.horizontal, ih = h - fr.vertical;
  final photo = shaped(t.shape, cc ? radius * .6 : (t.polaroid ? 2 * k : radius), iw, c(iw, ih));
  if (fr == EdgeInsets.zero) return photo;
  final br = t.shape == 2 ? BorderRadius.vertical(top: Radius.circular(w / 2), bottom: Radius.circular(radius + t.fw * k)) : BorderRadius.circular(cc ? radius : (t.polaroid ? 2 * k : radius + t.fw * k));
  Widget card = Container(
    width: w,
    height: h,
    padding: fr,
    decoration: BoxDecoration(
      color: glass ? Colors.white.withOpacity(.18) : (classic ? Colors.white : t.fc),
      border: cc ? Border.all(color: glass ? Colors.white.withOpacity(.5) : Colors.black12, width: glass ? 1.2 : .6) : null,
      borderRadius: br,
      boxShadow: sh > 0 && !glass ? [BoxShadow(blurRadius: sh, color: Colors.black26, offset: Offset(0, sh * .4))] : null,
    ),
    child: photo,
  );
  if (glass) card = ClipRRect(borderRadius: br, child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14), child: card));
  return Stack(clipBehavior: Clip.none, children: [
    card,
    if (cap != null && classic)
      Positioned(
        left: side,
        right: side,
        bottom: side,
        height: h * .22,
        child: DecoratedBox(decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black54]), borderRadius: BorderRadius.vertical(bottom: Radius.circular(radius * .6))), child: Center(child: cap)),
      ),
    if (cap != null && !classic) Positioned(left: w * .06, right: w * .06, bottom: 0, height: h * .2, child: Center(child: cap)),
    if (t.polaroid && t.tape != null) Positioned(top: -7 * k, left: w / 2 - 22 * k, child: Transform.rotate(angle: .12, child: Container(width: 44 * k, height: 16 * k, color: t.tape))),
  ]);
}

final templates = genTemplates;

Future<List<Uint8List>> pickPhotos(int n) async {
  if (n == 1) {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    return x == null ? [] : [await x.readAsBytes()];
  }
  final f = await ImagePicker().pickMultiImage(limit: max(2, n));
  return Future.wait(f.take(n).map((x) => x.readAsBytes()));
}

Future<Uint8List> snap(GlobalKey k, [double ratio = 4]) async {
  await WidgetsBinding.instance.endOfFrame;
  final b = k.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final d = await (await b.toImage(pixelRatio: ratio)).toByteData(format: ui.ImageByteFormat.png);
  return d!.buffer.asUint8List();
}

Future<void> shareImg(GlobalKey k, [double ratio = 4]) async => Share.shareXFiles([XFile.fromData(await snap(k, ratio), mimeType: 'image/png', name: 'collage.png')]);

Future<void> saveImg(BuildContext c, GlobalKey k, [double ratio = 4]) async {
  await Gal.putImageBytes(await snap(k, ratio));
  if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('Saved to gallery')));
}

Widget assetImg(String p) => Image.asset(
      p,
      fit: BoxFit.cover,
      errorBuilder: (c, e, s) => Container(
        color: Colors.red.withOpacity(.3),
        alignment: Alignment.center,
        child: Text('Missing asset:\n$p\nAdd it to assets/templates/ + pubspec, then fully restart the app', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11)),
      ),
    );

const samples = ['assets/samples/s1.jpg', 'assets/samples/s2.jpg', 'assets/samples/s3.jpg', 'assets/samples/s4.jpg', 'assets/samples/s5.jpg'];

Widget glow(Color c, double s) => Container(width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [c.withOpacity(.4), c.withOpacity(0)])));
