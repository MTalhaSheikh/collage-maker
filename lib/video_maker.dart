import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'data.dart';
import 'fx.dart';
import 'transitions.dart';
import 'video_export.dart';

const VW = 360.0;
const _aspects = [('9:16', 9 / 16), ('1:1', 1.0), ('4:5', .8)];
const _b = 'assets/templates/bg/';
const _m = 'assets/music/';

/// A photo or a video chosen by the user. [thumb] is the photo itself, or a video's first frame.
class Media {
  final String path;
  final bool video;
  final Uint8List thumb;
  Media(this.path, this.video, this.thumb);
}

final _videoExt = RegExp(r'\.(mp4|mov|m4v|3gp|mkv|webm|avi)$', caseSensitive: false);

Future<Uint8List?> _videoThumb(String p) async {
  final dir = await getTemporaryDirectory(), out = '${dir.path}/vt_${p.hashCode}.jpg';
  final s = await FFmpegKit.execute('-y -ss 0.3 -i "$p" -frames:v 1 -vf scale=800:-2 "$out"');
  if (!ReturnCode.isSuccess(await s.getReturnCode())) return null;
  return File(out).readAsBytes();
}

/// Lets the user pick photos AND videos (up to [room] items in total).
Future<List<Media>> pickMedia(BuildContext ctx, int room) async {
  if (room <= 0) return [];
  final fs = await ImagePicker().pickMultipleMedia(maxWidth: 1600, maxHeight: 1600, imageQuality: 88, limit: math.max(2, room));
  if (fs.isEmpty || !ctx.mounted) return [];
  showDialog(context: ctx, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
  final out = <Media>[];
  try {
    for (final f in fs.take(room)) {
      if (_videoExt.hasMatch(f.path)) {
        final t = await _videoThumb(f.path);
        if (t != null) out.add(Media(f.path, true, t));
      } else {
        out.add(Media(f.path, false, await f.readAsBytes()));
      }
    }
  } finally {
    if (ctx.mounted) Navigator.pop(ctx);
  }
  return out;
}

/// A video template: slide design (0 polaroid, 1 classic frame, 2 glass over blurred photo,
/// 3 full-screen), backgrounds, shape transitions, motion, seconds per item and music.
class VTpl {
  final String name, cap, font, music, fx;
  final int style;
  final List<String> bgs, trans, motion;
  final double per, capSize, ls;
  const VTpl(this.name, this.style, this.bgs, this.trans, this.motion, this.per, this.cap, this.font, this.capSize, this.ls, this.music, this.fx);
}

const vtpls = [
  VTpl('Memories', 0, ['${_b}instant_2.png', '${_b}instant_3.png'], ['pinwheel', 'fade', 'diagonal'], ['in', 'out'], 3, 'Memories', 'Josefin Sans', 16, 3, '${_m}lofi_chill.mp3', 'bokeh'),
  VTpl('Glass Blur', 2, [], ['circle', 'radial', 'fade'], ['out', 'in'], 3, 'Moments', 'Great Vibes', 30, 0, '${_m}dreamy_clouds.mp3', 'stars'),
  VTpl('Cinematic', 3, [], ['fade', 'wipe', 'radial'], ['in', 'left', 'right'], 3.5, '', 'Playfair Display', 30, 1, '${_m}piano_calm.mp3', 'leak'),
  VTpl('Summer Vibes', 1, ['${_b}summer_5.png', '${_b}summer_7.png', '${_b}summer_10.png'], ['diagonal', 'slant', 'dots'], ['left', 'right', 'in'], 2.5, 'Summer Vibes', 'Lobster', 26, 0, '${_m}happy_day.mp3', 'glitter'),
  VTpl('Birthday', 0, ['${_b}birthday_2.png', '${_b}birthday_4.png', '${_b}birthday_6.png'], ['heart', 'dots', 'radial'], ['in', 'out'], 2.5, 'Happy Birthday', 'Lobster', 24, 0, '${_m}upbeat_pop.mp3', 'glitter'),
  VTpl('Love Story', 0, ['${_b}love_1.png', '${_b}love_2.png'], ['heart', 'fade', 'circle'], ['in'], 3.5, 'Love Story', 'Dancing Script', 30, 0, '${_m}piano_calm.mp3', 'stars'),
  VTpl('Autumn', 1, ['${_b}autumn_1.png', '${_b}autumn_7.png', '${_b}autumn_9.png'], ['slant', 'cross', 'fade'], ['left', 'in'], 3, 'Autumn Vibes', 'Josefin Sans', 16, 3, '${_m}lofi_chill.mp3', 'leak'),
  VTpl('Festive', 0, ['${_b}classic_4.png', '${_b}classic_6.png', '${_b}classic_10.png'], ['radial', 'pinwheel', 'circle'], ['out', 'in'], 3, 'Happy Holidays', 'Pacifico', 22, 0, '${_m}epic_rise.mp3', 'stars'),
];

ImageProvider photoProv(Uint8List b) => ResizeImage(MemoryImage(b), width: 1000);
Tpl _ref() => templates.firstWhere((t) => t.cardCap && t.tape == null);

/// Card + window geometry of a slide in logical pixels (shared by preview and export).
class Geo {
  final double cw, ch, k, tilt, wx, wy, ww, wh;
  Geo(this.cw, this.ch, this.k, this.tilt, this.wx, this.wy, this.ww, this.wh);
}

Geo geo(VTpl t, int index, double aspect) {
  final h = VW / aspect;
  const ar = .84;
  final cw = math.min(VW * .8, h * .78 * ar), ch = cw / ar, tilt = t.style == 2 ? 0.0 : (index.isEven ? -.035 : .035);
  final side = cw * (t.style == 1 ? .06 : .05), bottom = t.style == 1 ? side : ch * .2, iw = cw - 2 * side, ih = ch - side - bottom;
  final oy = side + ih / 2 - ch / 2;
  return Geo(cw, ch, cw / 224, tilt, VW / 2 - oy * math.sin(tilt), h / 2 + oy * math.cos(tilt), iw, ih);
}

class _Clear extends CustomPainter {
  @override
  void paint(Canvas c, Size s) => c.drawRect(Offset.zero & s, Paint()..blendMode = BlendMode.clear);
  @override
  bool shouldRepaint(_) => false;
}

/// One slide. mode 0 = normal, mode 2 = frame only (card with a see-through window, used for export).
class SlideView extends StatelessWidget {
  final VTpl t;
  final ImageProvider photo;
  final int index, mode;
  final double aspect;
  final String caption;
  const SlideView(this.t, this.photo, this.index, this.aspect, this.caption, {this.mode = 0, super.key});

  @override
  Widget build(BuildContext context) {
    final h = VW / aspect, only = mode == 2;
    if (t.style == 3) {
      return SizedBox(
        width: VW,
        height: h,
        child: Stack(fit: StackFit.expand, children: [
          if (!only) Image(image: photo, fit: BoxFit.cover),
          const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.center, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87]))),
          if (caption.isNotEmpty)
            Positioned(left: 20, right: 20, bottom: h * .07, child: Text(caption, textAlign: TextAlign.center, style: GoogleFonts.getFont(t.font, fontSize: t.capSize, color: Colors.white, letterSpacing: t.ls, shadows: const [Shadow(blurRadius: 8, color: Colors.black54)]))),
        ]),
      );
    }
    final glass = t.style == 2, g = geo(t, index, aspect);
    final Widget bg = only
        ? const SizedBox.shrink()
        : glass
            ? ClipRect(child: Stack(fit: StackFit.expand, children: [ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20, tileMode: TileMode.clamp), child: Image(image: photo, fit: BoxFit.cover)), const ColoredBox(color: Colors.black26)]))
            : Image.asset(t.bgs[index % t.bgs.length], fit: BoxFit.cover);
    final ink = t.style == 0 ? const Color(0xFF3A3A3A) : Colors.white;
    final card = Transform.rotate(
      angle: g.tilt,
      child: SizedBox(
        width: g.cw,
        height: g.ch,
        child: tplFrame(
          _ref(), g.cw, g.ch, 3 * g.k, g.k,
          (iw, ih) => only ? CustomPaint(size: Size(iw, ih), painter: _Clear()) : Image(image: photo, width: iw, height: ih, fit: BoxFit.cover),
          style: t.style,
          cap: caption.isEmpty ? null : FittedBox(fit: BoxFit.scaleDown, child: Text(caption, style: GoogleFonts.getFont(t.font, fontSize: t.capSize * g.k, color: ink, letterSpacing: t.ls * g.k, shadows: t.style == 0 ? null : const [Shadow(blurRadius: 4, color: Colors.black54)]))),
        ),
      ),
    );
    return SizedBox(width: VW, height: h, child: Stack(fit: StackFit.expand, children: [bg, Center(child: card)]));
  }
}

class _RP extends CustomClipper<Path> {
  final String kind;
  final double q, w, h;
  _RP(this.kind, this.q, this.w, this.h);
  @override
  Path getClip(Size s) => revealPath(kind, q, w, h);
  @override
  bool shouldReclip(_RP o) => true;
}

class _FxT extends CustomPainter {
  final String kind;
  final AnimationController ac;
  final double Function() total;
  _FxT(this.kind, this.ac, this.total) : super(repaint: ac);
  @override
  void paint(Canvas c, Size s) => paintFx(c, s, kind, (ac.value * total()) % fxLoop);
  @override
  bool shouldRepaint(_FxT o) => o.kind != kind;
}

class _TP extends CustomPainter {
  final String kind;
  _TP(this.kind);
  @override
  void paint(Canvas c, Size s) => c.drawPath(revealPath(kind, .55, s.width, s.height), Paint()..color = kPink.withOpacity(.85));
  @override
  bool shouldRepaint(_) => false;
}

// ================= template gallery =================
class VideoMakerPage extends StatelessWidget {
  const VideoMakerPage({super.key});

  Future<void> _start(BuildContext c, int i) async {
    final m = await pickMedia(c, 20);
    if (m.isEmpty || !c.mounted) return;
    Navigator.push(c, MaterialPageRoute(builder: (_) => VideoPreviewPage(items: m, tpl: i)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(children: [
          Positioned(top: -90, right: -80, child: glow(kViolet, 320)),
          Positioned(bottom: 100, left: -130, child: glow(kPink, 300)),
          const Positioned.fill(child: FxOverlay('stars')),
          SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 16, 8),
                child: Row(children: [
                  IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => Navigator.pop(context)),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Video templates', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700)),
                      const Text('Choose a style, then add photos or videos', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white60, fontSize: 12)),
                    ]),
                  ),
                ]),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 16, crossAxisSpacing: 14, childAspectRatio: .5),
                  itemCount: vtpls.length,
                  itemBuilder: (_, i) {
                    final t = vtpls[i];
                    return FadeSlide(index: i, child: Pressable(child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _start(context, i),
                      child: Column(children: [
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(blurRadius: 16, color: Colors.black54, offset: Offset(0, 8))]),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Stack(fit: StackFit.expand, children: [
                                FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: SizedBox(width: VW, height: VW * 16 / 9, child: SlideView(t, AssetImage(samples[i % samples.length]), 0, 9 / 16, t.cap))),
                                Positioned.fill(child: FxOverlay(t.fx)),
                                const Center(child: CircleAvatar(radius: 22, backgroundColor: Colors.black45, child: Icon(Icons.play_arrow_rounded, size: 30))),
                                Positioned(left: 8, bottom: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.music_note, size: 12), const SizedBox(width: 3), Text('${t.per}s/item', style: const TextStyle(fontSize: 10))]))),
                              ]),
                            ),
                          ),
                        ),
                        Padding(padding: const EdgeInsets.only(top: 8), child: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                      ]),
                    )));
                  },
                ),
              ),
            ]),
          ),
        ]),
      );
}

// ================= preview + export =================
class VideoPreviewPage extends StatefulWidget {
  final List<Media> items;
  final int tpl;
  const VideoPreviewPage({super.key, required this.items, required this.tpl});
  @override
  State<VideoPreviewPage> createState() => _VP();
}

class _VP extends State<VideoPreviewPage> with SingleTickerProviderStateMixin {
  late List<Media> items = List.of(widget.items);
  late int ti = widget.tpl;
  late double per = vtpls[ti].per;
  late String title = vtpls[ti].cap;
  late final AnimationController ac;
  double tt = .9, vol = .8;
  int asp = 0, q = 0, renderIdx = -1;
  bool playing = true, chosen = false, isAsset = true;
  String? music, musicName, tover;
  late String fx = vtpls[ti].fx;
  bool fxChosen = false;
  VideoPlayerController? audio;
  List<String> tracks = [];
  final renderKey = GlobalKey();
  final _assets = <String, String>{};

  VTpl get t => vtpls[ti];
  double get total => items.length * per + tt;
  double get aspect => _aspects[asp].$2;
  Duration get _dur => Duration(milliseconds: (total * 1000).round());
  String _kind(int j) => tover ?? t.trans[j % t.trans.length];

  @override
  void initState() {
    super.initState();
    ac = AnimationController(vsync: this, duration: _dur)..repeat();
    _loadTracks();
  }

  @override
  void dispose() {
    ac.dispose();
    audio?.dispose();
    super.dispose();
  }

  void _snack(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  void _u(StateSetter s, VoidCallback f) {
    setState(f);
    s(() {});
  }

  String _nice(String p) => p.split('/').last.replaceAll(RegExp(r'\.\w+$'), '').split('_').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');

  // ---------- music ----------
  Future<void> _loadTracks() async {
    final m = await AssetManifest.loadFromAssetBundle(rootBundle);
    tracks = m.listAssets().where((a) => a.startsWith(_m) && !a.endsWith('/')).toList()..sort();
    if (!mounted) return;
    setState(() {});
    _defaultMusic();
  }

  void _defaultMusic() {
    if (chosen) return;
    final d = tracks.contains(t.music) ? t.music : null;
    _setMusic(d, true, d == null ? null : _nice(d));
  }

  Future<void> _setMusic(String? src, bool asset, String? name) async {
    final old = audio;
    audio = null;
    old?.dispose();
    setState(() { music = src; isAsset = asset; musicName = name; });
    if (src == null) return;
    try {
      final c = asset ? VideoPlayerController.asset(src) : VideoPlayerController.file(File(src));
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(vol);
      if (!mounted || music != src) {
        c.dispose();
        return;
      }
      audio = c;
      if (playing) c.play();
    } catch (e) {
      _snack('Could not play this music');
    }
  }

  void _resync() {
    ac.duration = _dur;
    if (playing) ac.repeat();
  }

  void _pickTpl(int i) {
    setState(() { ti = i; per = vtpls[i].per; title = vtpls[i].cap; if (!fxChosen) fx = vtpls[i].fx; });
    _resync();
    _defaultMusic();
  }

  void _toggle() {
    setState(() => playing = !playing);
    if (playing) {
      ac.repeat();
      audio?.play();
    } else {
      ac.stop();
      audio?.pause();
    }
  }

  // ---------- animated preview ----------
  SlideView _sv(int i, {int mode = 0}) => SlideView(t, photoProv(items[i].thumb), i, aspect, title, mode: mode);

  Widget _mot(int i, double local) {
    final m = t.motion[i % t.motion.length], p = (local / (per + tt)).clamp(0.0, 1.0).toDouble(), s = _sv(i);
    switch (m) {
      case 'out':
        return Transform.scale(scale: 1.12 - .12 * p, child: s);
      case 'left':
        return Transform.translate(offset: Offset((.5 - p) * .12 * VW, 0), child: Transform.scale(scale: 1.12, child: s));
      case 'right':
        return Transform.translate(offset: Offset((p - .5) * .12 * VW, 0), child: Transform.scale(scale: 1.12, child: s));
      default:
        return Transform.scale(scale: 1 + .12 * p, child: s);
    }
  }

  Widget _trans(String kind, Widget a, Widget b, double q) {
    if (kind == 'fade') return Stack(children: [a, Opacity(opacity: q, child: b)]);
    return Stack(children: [a, ClipPath(clipper: _RP(kind, q, VW, VW / aspect), child: b)]);
  }

  Widget _frame(double T) {
    final i = math.max(0, math.min((T / per).floor(), items.length - 1)), local = T - i * per, cur = _mot(i, local);
    if (i > 0 && local < tt) return _trans(_kind(i - 1), _mot(i - 1, per + local), cur, local / tt);
    return cur;
  }

  Widget _player() => LayoutBuilder(builder: (_, bc) {
        final h = VW / aspect, k = math.min((bc.maxWidth - 24) / VW, (bc.maxHeight - 16) / h);
        return Center(
          child: GestureDetector(
            onTap: _toggle,
            child: SizedBox(
              width: VW * k,
              height: h * k,
              child: FittedBox(child: SizedBox(width: VW, height: h, child: Stack(children: [ClipRect(child: AnimatedBuilder(animation: ac, builder: (_, __) => _frame(ac.value * total))), if (fx != 'none') IgnorePointer(child: CustomPaint(size: Size(VW, h), painter: _FxT(fx, ac, () => total)))]))),
            ),
          ),
        );
      });

  // ---------- sheets ----------
  void _sheet(Widget Function(StateSetter) b) => showModalBottomSheet(
        context: context,
        backgroundColor: kPanel,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
        builder: (_) => StatefulBuilder(builder: (c, s) => SafeArea(child: Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(c).viewInsets.bottom), child: b(s)))),
      );

  Future<void> _pickOwn(StateSetter s) async {
    try {
      final f = await openFile(acceptedTypeGroups: const [XTypeGroup(label: 'Audio', extensions: ['mp3', 'm4a', 'aac', 'wav', 'ogg'], mimeTypes: ['audio/*'], uniformTypeIdentifiers: ['public.audio'])]);
      if (f == null) return;
      final dir = await getTemporaryDirectory(), ext = f.name.contains('.') ? f.name.split('.').last : 'mp3';
      final out = File('${dir.path}/music_${DateTime.now().millisecondsSinceEpoch}.$ext')..writeAsBytesSync(await f.readAsBytes());
      chosen = true;
      await _setMusic(out.path, false, f.name);
      s(() {});
    } catch (e) {
      _snack('Could not pick audio: $e');
    }
  }

  void _musicSheet() => _sheet((s) => SizedBox(
        height: 420,
        child: Column(children: [
          Row(children: [
            const Text('Music', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const Spacer(),
            FilledButton.icon(onPressed: () => _pickOwn(s), icon: const Icon(Icons.library_music, size: 18), label: const Text('My music')),
          ]),
          Expanded(
            child: ListView(children: [
              ListTile(leading: const Icon(Icons.music_off), title: const Text('No music'), trailing: music == null ? const Icon(Icons.check_circle, color: kPink) : null, onTap: () { chosen = true; _setMusic(null, true, null); s(() {}); }),
              if (music != null && !isAsset) ListTile(leading: const Icon(Icons.audiotrack), title: Text(musicName ?? 'My music'), subtitle: const Text('Your own music'), trailing: const Icon(Icons.check_circle, color: kPink)),
              for (final a in tracks)
                ListTile(leading: const Icon(Icons.music_note), title: Text(_nice(a)), trailing: music == a ? const Icon(Icons.check_circle, color: kPink) : null, onTap: () { chosen = true; _setMusic(a, true, _nice(a)); s(() {}); }),
            ]),
          ),
          Row(children: [const Icon(Icons.volume_up), Expanded(child: Slider(value: vol, onChanged: (v) { vol = v; audio?.setVolume(v); s(() {}); }))]),
        ]),
      ));

  Future<void> _addMedia(StateSetter s) async {
    final m = await pickMedia(context, 20 - items.length);
    if (m.isNotEmpty) _u(s, () { items.addAll(m); _resync(); });
  }

  void _mediaSheet() => _sheet((s) => Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Text('Photos & videos (${items.length}/20)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const Spacer(),
          FilledButton.icon(onPressed: () => _addMedia(s), icon: const Icon(Icons.add_photo_alternate_outlined, size: 18), label: const Text('Add')),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 250,
          child: GridView.count(crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8, children: [
            for (var i = 0; i < items.length; i++)
              Stack(fit: StackFit.expand, children: [
                ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(items[i].thumb, fit: BoxFit.cover, cacheWidth: 200)),
                if (items[i].video) const Positioned(left: 4, bottom: 4, child: Icon(Icons.videocam, size: 16, shadows: [Shadow(blurRadius: 4)])),
                Positioned(top: 3, right: 3, child: GestureDetector(onTap: items.length > 1 ? () => _u(s, () { items.removeAt(i); _resync(); }) : null, child: const CircleAvatar(radius: 11, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14)))),
              ]),
          ]),
        ),
      ]));

  void _textSheet() => _sheet((s) => Column(mainAxisSize: MainAxisSize.min, children: [
        const Align(alignment: Alignment.centerLeft, child: Text('Title text', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
        const SizedBox(height: 12),
        TextField(controller: TextEditingController(text: title)..selection = TextSelection.collapsed(offset: title.length), onChanged: (v) => setState(() => title = v), decoration: const InputDecoration(hintText: 'Leave empty for no text')),
      ]));

  void _timeSheet() => _sheet((s) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Seconds per photo / video', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [for (final x in [2.0, 3.0, 4.0, 5.0]) ChoiceChip(label: Text('${x.toInt()}s'), selected: per == x, onSelected: (_) => _u(s, () { per = x; _resync(); }))]),
        const SizedBox(height: 8),
        Text('Total length: ${total.toStringAsFixed(1)}s', style: const TextStyle(color: Colors.white60)),
      ]));

  Widget _tt(String? kind, String label, StateSetter s) => GestureDetector(
        onTap: () => _u(s, () => tover = kind),
        child: Column(children: [
          Container(
            width: 56,
            height: 80,
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10), border: Border.all(color: tover == kind ? kPink : Colors.transparent, width: 2)),
            child: kind == null ? const Icon(Icons.auto_awesome) : ClipRRect(borderRadius: BorderRadius.circular(8), child: CustomPaint(size: const Size(52, 76), painter: _TP(kind))),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: tover == kind ? kPink : Colors.white70)),
        ]),
      );

  void _transSheet() => _sheet((s) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Transition', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const Text('How the next photo or video opens', style: TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: [_tt(null, 'Template', s), for (final k in transKinds) _tt(k.$1, k.$2, s)]),
      ]));

  Widget _fxTile(String kind, String label, StateSetter s) => GestureDetector(
        onTap: () => _u(s, () { fx = kind; fxChosen = true; }),
        child: Column(children: [
          Container(
            width: 64,
            height: 84,
            decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2B2250), Color(0xFF0F0F17)]), borderRadius: BorderRadius.circular(10), border: Border.all(color: fx == kind ? kPink : Colors.transparent, width: 2)),
            child: kind == 'none' ? const Icon(Icons.block, color: Colors.white54) : ClipRRect(borderRadius: BorderRadius.circular(8), child: FxOverlay(kind)),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: fx == kind ? kPink : Colors.white70)),
        ]),
      );

  void _fxSheet() => _sheet((s) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Light effects', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const Text('Animated sparkle over the whole video', style: TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: [for (final k in fxKinds) _fxTile(k.$1, k.$2, s)]),
      ]));

  void _sizeSheet() => _sheet((s) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Video size', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [for (var i = 0; i < _aspects.length; i++) ChoiceChip(label: Text(_aspects[i].$1), selected: asp == i, onSelected: (_) => _u(s, () => asp = i))]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [ChoiceChip(label: const Text('720p'), selected: q == 0, onSelected: (_) => _u(s, () => q = 0)), ChoiceChip(label: const Text('1080p'), selected: q == 1, onSelected: (_) => _u(s, () => q = 1))]),
      ]));

  // ---------- export ----------
  Future<String> _assetFile(String a) async {
    final c = _assets[a];
    if (c != null) return c;
    final dir = await getTemporaryDirectory(), bd = await rootBundle.load(a);
    return _assets[a] = (File('${dir.path}/${a.split('/').last}')..writeAsBytesSync(bd.buffer.asUint8List())).path;
  }

  Future<String> _musicFile() async => isAsset ? _assetFile(music!) : music!;

  Future<void> _export() async {
    if (playing) _toggle();
    final prog = ValueNotifier<double>(0);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Creating your video'),
          content: ValueListenableBuilder<double>(valueListenable: prog, builder: (_, v, __) => Column(mainAxisSize: MainAxisSize.min, children: [LinearProgressIndicator(value: v == 0 ? null : v), const SizedBox(height: 12), Text('${(v * 100).round()}%')])),
          actions: [TextButton(onPressed: () => FFmpegKit.cancel(), child: const Text('Cancel'))],
        ),
      ),
    );
    final dir = await getTemporaryDirectory(), stamp = DateTime.now().millisecondsSinceEpoch, short = q == 0 ? 720 : 1080, sc = exportSize(aspect, short).$1 / VW, jobs = <SlideJob>[];
    String? res;
    try {
      await GoogleFonts.pendingFonts();
      for (var i = 0; i < items.length; i++) {
        setState(() => renderIdx = i);
        await WidgetsBinding.instance.endOfFrame;
        await WidgetsBinding.instance.endOfFrame;
        final rb = renderKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final d = await (await rb.toImage(pixelRatio: sc)).toByteData(format: ui.ImageByteFormat.png);
        final fp = (File('${dir.path}/fr_${stamp}_$i.png')..writeAsBytesSync(d!.buffer.asUint8List())).path, g = geo(t, i, aspect);
        jobs.add(SlideJob(media: items[i].path, video: items[i].video, bg: t.style <= 1 ? await _assetFile(t.bgs[i % t.bgs.length]) : null, frame: fp, style: t.style, motion: t.motion[i % t.motion.length], cx: g.wx * sc, cy: g.wy * sc, ww: g.ww * sc, wh: g.wh * sc, ang: g.tilt));
        prog.value = .05 * (i + 1) / items.length;
      }
      setState(() => renderIdx = -1);
      final mf = music == null ? null : await _musicFile();
      res = await exportSlideshow(jobs: jobs, kinds: [for (var j = 0; j < items.length - 1; j++) _kind(j)], per: per, tt: tt, aspect: aspect, short: short, music: mf, musicVol: vol, fx: fx, onProgress: (p) => prog.value = .05 + .95 * p);
    } catch (e) {
      lastError = '$e';
    }
    if (!mounted) return;
    setState(() => renderIdx = -1);
    Navigator.pop(context);
    if (res == null) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Export failed'),
          content: SingleChildScrollView(child: Text(lastError.length > 700 ? lastError.substring(lastError.length - 700) : lastError, style: const TextStyle(fontSize: 11))),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
        ),
      );
      return;
    }
    final path = res;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Video ready'),
        content: const Text('Your video has been created.'),
        actions: [
          TextButton(onPressed: () => Share.shareXFiles([XFile(path)]), child: const Text('Share')),
          FilledButton(
            onPressed: () async {
              await Gal.putVideo(path);
              if (mounted) {
                Navigator.pop(context);
                _snack('Saved to gallery');
              }
            },
            child: const Text('Save to gallery'),
          ),
        ],
      ),
    );
  }

  // ---------- page ----------
  Widget _tool(IconData i, String l, VoidCallback f) => Expanded(child: InkWell(onTap: f, child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(children: [Icon(i), const SizedBox(height: 2), Text(l, style: const TextStyle(fontSize: 10.5))]))));

  @override
  Widget build(BuildContext context) {
    final h = VW / aspect;
    return Stack(clipBehavior: Clip.none, children: [
      Scaffold(
        appBar: AppBar(
          title: const Text('Create video'),
          actions: [Padding(padding: const EdgeInsets.only(right: 12), child: FilledButton.icon(onPressed: _export, icon: const Icon(Icons.movie_creation_outlined, size: 18), label: const Text('Export')))],
        ),
        body: Column(children: [
          Expanded(child: _player()),
          SizedBox(
            height: 40,
            child: Row(children: [
              IconButton(icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 30), onPressed: _toggle),
              Expanded(child: AnimatedBuilder(animation: ac, builder: (_, __) => LinearProgressIndicator(value: ac.value, minHeight: 3, backgroundColor: Colors.white12, color: kPink))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('${total.toStringAsFixed(1)}s', style: const TextStyle(color: Colors.white60, fontSize: 12))),
            ]),
          ),
          SizedBox(
            height: 112,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
              itemCount: vtpls.length,
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _pickTpl(i),
                child: Container(
                  width: 56,
                  margin: const EdgeInsets.only(right: 10),
                  child: Column(children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: i == ti ? kPink : Colors.transparent, width: 2)),
                        child: ClipRRect(borderRadius: BorderRadius.circular(8), child: FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: SizedBox(width: VW, height: VW * 16 / 9, child: SlideView(vtpls[i], photoProv(items[0].thumb), 0, 9 / 16, vtpls[i].cap)))),
                      ),
                    ),
                    Text(vtpls[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: i == ti ? kPink : Colors.white70)),
                  ]),
                ),
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(color: kPanel, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
            child: SafeArea(top: false, child: Row(children: [_tool(Icons.music_note, 'Music', _musicSheet), _tool(Icons.photo_library_outlined, 'Media', _mediaSheet), _tool(Icons.text_fields_rounded, 'Text', _textSheet), _tool(Icons.auto_awesome_motion, 'Transition', _transSheet), _tool(Icons.auto_fix_high, 'Effects', _fxSheet), _tool(Icons.timer_outlined, 'Time', _timeSheet), _tool(Icons.aspect_ratio, 'Size', _sizeSheet)])),
          ),
        ]),
      ),
      if (renderIdx >= 0) Positioned(left: -5000, top: 0, child: RepaintBoundary(key: renderKey, child: SizedBox(width: VW, height: h, child: _sv(renderIdx, mode: 2)))),
    ]);
  }
}
