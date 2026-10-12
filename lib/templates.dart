import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'data.dart';
import 'editor.dart';
import 'fx.dart';

class TplPreview extends StatelessWidget {
  final Tpl t;
  const TplPreview(this.t, {super.key});

  Widget _card(int i, double s, double k) {
    final r = t.cells[i], w = r.width * s, h = r.height * s, o = t.name.codeUnits.fold(0, (a, b) => a + b);
    return Positioned(
      left: r.left * s,
      top: r.top * s,
      width: w,
      height: h,
      child: Transform.rotate(
        angle: t.rot(i),
        child: tplFrame(
          t, w, h, t.radius * (w / 224), w / 224,
          (iw, ih) => Image.asset(samples[(i + o) % samples.length], width: iw, height: ih, fit: BoxFit.cover, alignment: const Alignment(0, -.55), cacheWidth: 360),
          cap: i == 0 && t.cardCap ? FittedBox(fit: BoxFit.scaleDown, child: Text(t.cap, style: GoogleFonts.getFont(t.font, fontSize: t.size * w / 224, color: t.ink, letterSpacing: t.ls * w / 224))) : null,
          sh: 10 * k,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: LayoutBuilder(builder: (_, bc) {
            final s = bc.maxWidth, k = s / 340;
            return Container(
              decoration: BoxDecoration(color: t.bg, image: t.img == null ? null : DecorationImage(image: AssetImage(t.img!), fit: BoxFit.cover)),
              child: Stack(children: [for (var i = 1; i < t.n; i++) _card(i, s, k), if (t.n > 0) _card(0, s, k)]),
            );
          }),
        ),
      );
}

class TemplatesPage extends StatefulWidget {
  const TemplatesPage({super.key});
  @override
  State<TemplatesPage> createState() => _TS();
}

class _TS extends State<TemplatesPage> {
  String cat = 'All';

  Widget _pill(String c) {
    final on = cat == c;
    return GestureDetector(
      onTap: () => setState(() => cat = c),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: on ? const LinearGradient(colors: [kViolet, kPink]) : null, color: on ? null : Colors.white10),
        child: Text(c, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: on ? Colors.white : Colors.white70)),
      ),
    );
  }

  Widget _tile(Tpl t) => InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          final p = await pickPhotos(t.n);
          if (p.isEmpty || !mounted) return;
          final o = p.length;
          while (p.length < t.n) {
            p.add(p[p.length % o]);
          }
          Navigator.push(context, MaterialPageRoute(builder: (_) => Editor(imgs: p, tpl: t)));
        },
        child: _glass(Column(children: [
          Stack(children: [
            DecoratedBox(decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(blurRadius: 16, color: Colors.black54, offset: Offset(0, 8))]), child: TplPreview(t)),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.photo_library_outlined, size: 12), const SizedBox(width: 4), Text('${t.n}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))]),
              ),
            ),
          ]),
          Expanded(child: Align(alignment: Alignment.topCenter, child: Padding(padding: const EdgeInsets.only(top: 8), child: Text(t.name, maxLines: 1, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)))),
        ])),
      );

  Widget _glass(Widget c) => ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(.08), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white.withOpacity(.16))), child: c),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cats = ['All', ...{for (final t in templates) t.cat}];
    final list = templates.where((t) => cat == 'All' || t.cat == cat).toList();
    return Scaffold(
      body: Stack(children: [
        Positioned(top: -90, right: -80, child: glow(kViolet, 320)),
        Positioned(bottom: 120, left: -130, child: glow(kPink, 300)),
        const Positioned.fill(child: FxOverlay('stars')),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 20, 4),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => Navigator.pop(context)),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Templates', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700)),
                  Text('${list.length} designs', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ]),
              ]),
            ),
            SizedBox(height: 50, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(16, 6, 6, 6), children: [for (final c in cats) _pill(c)])),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: .8),
                itemCount: list.length,
                itemBuilder: (_, i) => FadeSlide(index: i, child: Pressable(child: _tile(list[i]))),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
