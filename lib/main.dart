import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'blender.dart';
import 'data.dart';
import 'editor.dart';
import 'templates.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Collage Maker',
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: kBg,
          colorScheme: const ColorScheme.dark(primary: kPink, secondary: kViolet),
          textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
          appBarTheme: AppBarTheme(backgroundColor: kBg, elevation: 0, scrolledUnderElevation: 0, titleTextStyle: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
          sliderTheme: const SliderThemeData(activeTrackColor: kPink, inactiveTrackColor: Colors.white12, thumbColor: Colors.white, trackHeight: 3),
          chipTheme: ChipThemeData(backgroundColor: Colors.white10, selectedColor: kViolet, side: BorderSide.none, shape: const StadiumBorder(), labelStyle: GoogleFonts.poppins(fontSize: 13)),
        ),
        home: const Home(),
      );
}

class Home extends StatelessWidget {
  const Home({super.key});

  Future<void> _go(BuildContext c, int n, Widget Function(List<Uint8List>) b) async {
    final p = await pickPhotos(n);
    if (p.length < (n == 2 ? 2 : 1) || !c.mounted) return;
    Navigator.push(c, MaterialPageRoute(builder: (_) => b(p)));
  }

  Tpl _pick(String cat, int i) => templates.where((t) => t.cat == cat).elementAt(i);

  Widget _glow(Color c, double s) => Container(width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [c.withOpacity(.4), c.withOpacity(0)])));

  Widget _fan(Tpl t, double a, double dx, double dy, double w) => Align(
        alignment: Alignment(dx, dy),
        child: Transform.rotate(
          angle: a,
          child: Container(
            width: w,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(blurRadius: 24, color: Colors.black54, offset: Offset(0, 10))]),
            child: TplPreview(t),
          ),
        ),
      );

  Widget _tile(IconData i, String title, String sub, VoidCallback f, Color c) => Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: f,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(colors: [c.withOpacity(.3), c.withOpacity(.08)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: c.withOpacity(.35), borderRadius: BorderRadius.circular(14)), child: Icon(i, size: 22)),
              const SizedBox(height: 14),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              Text(sub, style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(children: [
          Positioned(top: -90, left: -70, child: _glow(kViolet, 340)),
          Positioned(top: 140, right: -110, child: _glow(kPink, 320)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Collage Maker', style: GoogleFonts.pacifico(fontSize: 24)),
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)), child: const Text('v7', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                ]),
                Expanded(
                  child: LayoutBuilder(builder: (_, bc) {
                    final w = bc.maxHeight * .62 > 175 ? 175.0 : bc.maxHeight * .62;
                    return Stack(children: [
                      _fan(_pick('Autumn', 0), -.16, -.8, -.55, w),
                      _fan(_pick('Birthday', 2), .14, .85, -.25, w),
                      _fan(_pick('Summer', 6), -.03, -.05, .55, w * 1.08),
                    ]);
                  }),
                ),
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (r) => const LinearGradient(colors: [Colors.white, Color(0xFFFFC0DA)]).createShader(r),
                  child: Text('Turn your photos into\nbeautiful collages', style: GoogleFonts.poppins(fontSize: 27, fontWeight: FontWeight.w700, height: 1.15)),
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: () => _go(context, 20, (p) => Editor(imgs: p)),
                  child: Container(
                    height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: const LinearGradient(colors: [kViolet, kPink]),
                      boxShadow: [BoxShadow(blurRadius: 26, color: kPink.withOpacity(.45), offset: const Offset(0, 10))],
                    ),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_photo_alternate_rounded),
                      SizedBox(width: 10),
                      Text('Create collage', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  _tile(Icons.dashboard_customize_rounded, 'Templates', '${templates.length} designs', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TemplatesPage())), kViolet),
                  const SizedBox(width: 14),
                  _tile(Icons.blur_on_rounded, 'Photo blender', 'Fade & mix photos', () => _go(context, 2, (p) => BlenderPage(imgs: p)), kPink),
                ]),
              ]),
            ),
          ),
        ]),
      );
}
