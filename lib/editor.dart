import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'data.dart';
import 'fancy.dart';
import 'layouts.dart';

const S = 340.0;
// canvas sizes: name, ratio, width/height ratio, export pixels (1080 px wide)
const sizes = [('Square', '1:1', 1.0, '1080×1080'), ('Post', '4:5', .8, '1080×1350'), ('Story', '9:16', 9 / 16, '1080×1920')]; // fixed logical canvas size; scaled to fit the screen

class Item {
  String text, font;
  Color color;
  double size, scale = 1, rot = 0, ls = 0;
  Offset pos;
  Item(this.text, this.font, this.color, this.size, this.pos);
  Item copy() => Item(text, font, color, size, pos)
    ..scale = scale
    ..rot = rot
    ..ls = ls;
}

/// A movable / resizable / rotatable photo card (template mode).
class Pc {
  double cx, cy, w, ar, rot;
  int img;
  String cap;
  Pc(this.cx, this.cy, this.w, this.ar, this.rot, this.img, this.cap);
  Pc copy() => Pc(cx, cy, w, ar, rot, img, cap);
}

class Snap {
  final List<Pc> cards;
  final List<Item> items;
  final List<Uint8List> imgs;
  final int li;
  final double gap, radius, pad;
  final Color bg;
  final List<Color>? grad;
  final bool patOn;
  final String filter;
  final double cr, bw, sh, blur, dim;
  final int cs;
  final Uint8List? bgPic;
  final int sz;
  Snap(this.cards, this.items, this.imgs, this.li, this.gap, this.radius, this.pad, this.bg, this.grad, this.patOn, this.filter, this.cr, this.bw, this.sh, this.cs, this.blur, this.dim, this.bgPic, this.sz);
}

class Editor extends StatefulWidget {
  final List<Uint8List> imgs;
  final Tpl? tpl;
  const Editor({super.key, required this.imgs, this.tpl});
  @override
  State<Editor> createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  final key = GlobalKey();
  late List<Uint8List> imgs = List.of(widget.imgs);
  late List<List<Rect>> layouts = layoutsFor(imgs.length);
  final cards = <Pc>[], items = <Item>[], undo = <Snap>[], redo = <Snap>[];
  int li = 0, tab = 0, sel = -1, selC = -1;
  double gap = 6, radius = 8, pad = 0, b0 = 1, r0 = 0, _k = 1, cr = 3, bw = 1, sh = 10;
  Color bg = Colors.white;
  List<Color>? grad;
  bool patOn = true, ip = false;
  int sz = 0; // canvas size index
  int cs = 0; // card style: 0 polaroid, 1 classic, 2 glass
  double blur = 0, dim = 0;
  Uint8List? bgPic;
  String filter = 'Original';
  Tpl? get t => widget.tpl;
  double get _H => S / sizes[sz].$3;

  @override
  void initState() {
    super.initState();
    final tp = t;
    if (tp == null) return;
    li = -1;
    bg = tp.bg;
    if (tp.bg2 != null) grad = [tp.bg, tp.bg2!];
    for (var i = 0; i < tp.n; i++) {
      final r = tp.rects[i];
      cards.add(Pc(r.center.dx, r.center.dy, r.width * .75, r.height / r.width, tp.rot(i), i, i == 0 ? tp.cap : ''));
    }
  }

  // ---------- undo / redo ----------
  Snap _snap() => Snap(cards.map((c) => c.copy()).toList(), items.map((i) => i.copy()).toList(), List.of(imgs), li, gap, radius, pad, bg, grad, patOn, filter, cr, bw, sh, cs, blur, dim, bgPic, sz);
  void _commit() {
    undo.add(_snap());
    if (undo.length > 60) undo.removeAt(0);
    redo.clear();
  }

  void _restore(Snap s) => setState(() {
        cards..clear()..addAll(s.cards);
        items..clear()..addAll(s.items);
        imgs = s.imgs;
        layouts = layoutsFor(imgs.length);
        li = s.li; gap = s.gap; radius = s.radius; pad = s.pad; bg = s.bg; grad = s.grad; patOn = s.patOn; filter = s.filter; cr = s.cr; bw = s.bw; sh = s.sh; cs = s.cs; blur = s.blur; dim = s.dim; bgPic = s.bgPic; sz = s.sz;
        sel = -1; selC = -1;
      });
  void _undo() {
    if (undo.isEmpty) return;
    redo.add(_snap());
    _restore(undo.removeLast());
  }

  void _redo() {
    if (redo.isEmpty) return;
    undo.add(_snap());
    _restore(redo.removeLast());
  }

  void _do(VoidCallback f) {
    _commit();
    setState(f);
  }

  void _ed(void Function(Item) fn, {bool c = true}) {
    if (sel < 0 || sel >= items.length) return;
    if (c) _commit();
    setState(() => fn(items[sel]));
  }

  Future<void> _out(Future<void> Function(GlobalKey) f) async {
    setState(() { sel = -1; selC = -1; });
    await f(key);
  }

  // ---------- actions ----------
  Future<void> _add() async {
    final p = await pickPhotos(20 - imgs.length);
    if (p.isEmpty) return;
    _do(() {
      for (final x in p) {
        imgs.add(x);
        if (li < 0) cards.add(Pc(.5 + .04 * (cards.length % 5 - 2), .5, .38, cards.isEmpty ? 1.15 : cards[0].ar, 0, imgs.length - 1, ''));
      }
      layouts = layoutsFor(imgs.length);
      if (li >= 0) li = 0;
    });
  }

  Future<String?> _ask(String title, String init) {
    final c = TextEditingController(text: init);
    return showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'Type something')),
        actions: [TextButton(onPressed: () => Navigator.pop(d, c.text), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _addText() async {
    final s = await _ask('Add text', '');
    if (s == null || s.isEmpty) return;
    _do(() {
      items.add(Item(s, 'Pacifico', Colors.white, 34, const Offset(40, 80)));
      sel = items.length - 1;
      selC = -1;
      ip = false;
    });
  }

  void _setLayout(int i) => _do(() {
        if (t != null) {
          if (i >= 0 && li < 0) { pad = 34; gap = 8; radius = 10; }
          if (i < 0) pad = 0;
        }
        li = i; sel = -1; selC = -1;
      });

  void _menu(int i) => showModalBottomSheet(
        context: context,
        builder: (_) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Replace photo'),
              onTap: () async {
                Navigator.pop(context);
                final p = await pickPhotos(1);
                if (p.isNotEmpty) _do(() => imgs[i] = p.first);
              },
            ),
            if (imgs.length > 1)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove photo'),
                onTap: () {
                  Navigator.pop(context);
                  _do(() {
                    imgs.removeAt(i);
                    layouts = layoutsFor(imgs.length);
                    li = 0;
                  });
                },
              ),
          ]),
        ),
      );

  // ---------- canvas pieces ----------
  Widget _cell(int i, double W, double H) {
    final r = layouts[li][i];
    final w = r.width * W - gap, h = r.height * H - gap;
    return Positioned(
      left: r.left * W + gap / 2,
      top: r.top * H + gap / 2,
      width: w,
      height: h,
      child: GestureDetector(
        onLongPress: () => _menu(i),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: ColorFiltered(
            colorFilter: ColorFilter.matrix(filters[filter]!),
            child: InteractiveViewer(minScale: 1, maxScale: 4, child: SizedBox(width: w, height: h, child: Image.memory(imgs[i], fit: BoxFit.cover))),
          ),
        ),
      ),
    );
  }

  Widget _card(int i) {
    final c = cards[i], tp = t!, w = c.w * S, h = w * c.ar, k = (w / 224).clamp(.5, 2.0);
    return Positioned(
      key: ValueKey(i),
      left: c.cx * S - w / 2,
      top: c.cy * _H - h / 2,
      width: w,
      height: h,
      child: Transform.rotate(
        angle: c.rot,
        child: GestureDetector(
          onTap: () => setState(() { selC = i; sel = -1; }),
          onScaleStart: (_) {
            _commit();
            setState(() { selC = i; sel = -1; });
            b0 = c.w;
            r0 = c.rot;
          },
          onScaleUpdate: (d) => setState(() {
            c.cx += d.focalPointDelta.dx / _k / S;
            c.cy += d.focalPointDelta.dy / _k / _H;
            c.w = (b0 * d.scale).clamp(.15, 1.0);
            c.rot = r0 + d.rotation;
          }),
          child: Stack(clipBehavior: Clip.none, children: [
            tplFrame(
              tp, w, h, cr * k, k,
              (iw, ih) => ColorFiltered(colorFilter: ColorFilter.matrix(filters[filter]!), child: Image.memory(imgs[c.img.clamp(0, imgs.length - 1)], width: iw, height: ih, fit: BoxFit.cover)),
              cap: c.cap.isEmpty ? null : FittedBox(fit: BoxFit.scaleDown, child: Text(c.cap, style: GoogleFonts.getFont(tp.font, fontSize: tp.size * w / 224, color: cs == 0 ? tp.ink : Colors.white, shadows: cs == 0 ? null : const [Shadow(blurRadius: 4, color: Colors.black54)], letterSpacing: tp.ls * w / 224))),
              style: cs,
              bw: bw,
              sh: sh,
            ),
            if (selC == i) Positioned.fill(child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(border: Border.all(color: kPink, width: 2))))),
          ]),
        ),
      ),
    );
  }

  Widget _item(int i) {
    final it = items[i];
    return Positioned(
      left: it.pos.dx,
      top: it.pos.dy,
      child: GestureDetector(
        onTap: () => setState(() { sel = i; selC = -1; ip = true; }),
        onScaleStart: (_) {
          _commit();
          setState(() { sel = i; selC = -1; ip = true; });
          b0 = it.scale;
          r0 = it.rot;
        },
        onScaleUpdate: (d) => setState(() {
          it.pos += d.focalPointDelta / _k;
          it.scale = (b0 * d.scale).clamp(.3, 6.0);
          it.rot = r0 + d.rotation;
        }),
        child: Transform.rotate(
          angle: it.rot,
          child: Transform.scale(
            scale: it.scale,
            child: Container(
              decoration: BoxDecoration(border: sel == i ? Border.all(color: Colors.white70) : null),
              child: Text(it.text, style: GoogleFonts.getFont(it.font, fontSize: it.size, letterSpacing: it.ls, color: it.color, shadows: const [Shadow(blurRadius: 4, color: Colors.black38)])),
            ),
          ),
        ),
      ),
    );
  }

  ImageProvider? _bgProv(Tpl? tp) => bgPic != null ? MemoryImage(bgPic!) : (patOn && tp?.img != null ? AssetImage(tp!.img!) : null);

  Widget _bgLayer(Tpl? tp) {
    final p = _bgProv(tp);
    if (p == null) return const SizedBox.shrink();
    Widget im = Image(image: p, fit: BoxFit.cover);
    if (blur > 0) im = ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur, tileMode: TileMode.clamp), child: im);
    return Positioned.fill(child: Stack(fit: StackFit.expand, children: [im, if (dim > 0) ColoredBox(color: Colors.black.withOpacity(dim))]));
  }

  Future<void> _pickBg() async {
    final p = await pickPhotos(1);
    if (p.isNotEmpty) _do(() => bgPic = p.first);
  }

  void _resetBg() => _do(() {
        final tp = t;
        bgPic = null; patOn = true; blur = 0; dim = 0;
        bg = tp?.bg ?? Colors.white;
        grad = tp?.bg2 != null ? [tp!.bg, tp.bg2!] : null;
      });

  Widget _fancy(FL f, double W, double H) => Stack(fit: StackFit.expand, children: [for (var i = 0; i < f.n; i++) _fcell(f, i, W, H)]);

  Widget _fcell(FL f, int i, double W, double H) {
    final c = f.cells[i], bb = fcBounds(c, W, H), at = i % imgs.length;
    final photo = ColorFiltered(
      colorFilter: ColorFilter.matrix(filters[filter]!),
      child: InteractiveViewer(minScale: 1, maxScale: 4, child: SizedBox(width: bb.width, height: bb.height, child: Image.memory(imgs[at], fit: BoxFit.cover))),
    );
    final layer = Positioned.fill(
      child: ClipPath(
        clipper: FcClip(c, gap),
        child: Stack(children: [Positioned.fromRect(rect: bb, child: GestureDetector(onLongPress: () => _menu(at), child: photo))]),
      ),
    );
    if (c.kind != 1) return layer;
    return Stack(fit: StackFit.expand, children: [Positioned.fill(child: ClipPath(clipper: FcClip(c, gap, gap * .9 + 3), child: const ColoredBox(color: Colors.white))), layer]);
  }

  Widget _fthumb(int f) => Container(
        width: 56,
        height: 56,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(color: Colors.white12, border: Border.all(color: li == 1000 + f ? kPink : Colors.white24, width: 2), borderRadius: BorderRadius.circular(6)),
        child: CustomPaint(size: const Size(52, 52), painter: FlThumb(fancyLayouts[f])),
      );

  void _setSize(int i) {
    if (i == sz) return;
    _do(() {
      final k = (S / sizes[i].$3) / _H;
      for (final it in items) {
        it.pos = Offset(it.pos.dx, it.pos.dy * k);
      }
      sz = i;
      sel = -1;
      selC = -1;
    });
  }

  Widget _sizeRow() => _row([
        for (var i = 0; i < sizes.length; i++)
          _gap(ChoiceChip(
            avatar: Icon(const [Icons.crop_square, Icons.crop_portrait, Icons.smartphone][i], size: 18),
            label: Text('${sizes[i].$1} ${sizes[i].$2} · ${sizes[i].$4}'),
            selected: sz == i,
            onSelected: (_) => _setSize(i),
          )),
      ]);

  Widget _styleRow() => _row([
        for (var i = 0; i < 3; i++)
          _gap(ChoiceChip(
            avatar: Icon(const [Icons.crop_portrait, Icons.crop_square, Icons.blur_on][i], size: 18),
            label: Text(const ['Polaroid', 'Classic', 'Glass'][i]),
            selected: cs == i,
            onSelected: (_) => _do(() => cs = i),
          )),
      ]);

  Widget _canvas() => LayoutBuilder(builder: (_, bc) {
        final tp = t;
        _k = math.min((bc.maxWidth - 24) / S, (bc.maxHeight - 24) / _H);
        return Center(
          child: SizedBox(
            width: S * _k,
            height: _H * _k,
            child: FittedBox(
              child: SizedBox(
                width: S,
                height: _H,
                child: RepaintBoundary(
                  key: key,
                  child: GestureDetector(
                    onTap: () => setState(() { sel = -1; selC = -1; }),
                    child: Container(
                      decoration: BoxDecoration(
                        color: grad == null ? bg : null,
                        gradient: grad == null ? null : LinearGradient(colors: grad!, begin: Alignment.topLeft, end: Alignment.bottomRight),
                      ),
                      child: Stack(clipBehavior: Clip.hardEdge, children: [
                        _bgLayer(tp),
                        if (patOn && tp != null && tp.pat > 0) Positioned.fill(child: CustomPaint(painter: Pat(tp.pat, tp.patC))),
                        if (li >= 0)
                          Padding(
                            padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + (tp != null ? 30 : 0)),
                            child: LayoutBuilder(builder: (_, c) => li >= 1000 ? _fancy(fancyLayouts[li - 1000], c.maxWidth, c.maxHeight) : Stack(children: [for (var i = 0; i < layouts[li].length; i++) _cell(i, c.maxWidth, c.maxHeight)])),
                          ),
                        if (li >= 0 && tp != null && tp.cap.isNotEmpty)
                          Positioned(left: 0, right: 0, bottom: 6, child: Center(child: Text(tp.cap, style: GoogleFonts.getFont(tp.font, fontSize: tp.size * .8, color: tp.ink, letterSpacing: tp.ls)))),
                        if (li < 0) for (final i in [for (var j = 1; j < cards.length; j++) if (j != selC) j, if (cards.isNotEmpty && selC != 0) 0, if (selC >= 0 && selC < cards.length) selC]) _card(i),
                        for (var i = 0; i < items.length; i++) _item(i),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      });

  // ---------- panels ----------
  Widget _row(List<Widget> c) => SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal, children: c));
  Widget _gap(Widget w) => Padding(padding: const EdgeInsets.only(right: 8), child: w);

  Widget _dots(List<Color> cs, void Function(Color) f) => _row([
        for (final c in cs)
          GestureDetector(
            onTap: () => f(c),
            child: Container(width: 32, height: 32, margin: const EdgeInsets.all(6), decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.white54))),
          ),
      ]);

  Widget _slider(String l, double v, double lo, double hi, ValueChanged<double> f) => Row(children: [
        SizedBox(width: 70, child: Text(l, style: const TextStyle(fontSize: 13))),
        Expanded(child: Slider(value: v.clamp(lo, hi), min: lo, max: hi, onChangeStart: (_) => _commit(), onChanged: f)),
      ]);

  Widget _mini(bool on, List<Rect> rs) => Container(
        width: 56,
        height: 56,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(color: Colors.white12, border: Border.all(color: on ? kPink : Colors.white24, width: 2), borderRadius: BorderRadius.circular(6)),
        child: Stack(children: [for (final r in rs) Positioned(left: r.left * 52 + 1, top: r.top * 52 + 1, width: r.width * 52 - 2, height: r.height * 52 - 2, child: Container(color: Colors.white70))]),
      );

  Widget _filterThumb(String n) => GestureDetector(
        onTap: () => _do(() => filter = n),
        child: Container(
          width: 64,
          margin: const EdgeInsets.only(right: 8),
          child: Column(children: [
            Container(
              decoration: BoxDecoration(border: Border.all(color: n == filter ? kPink : Colors.transparent, width: 2), borderRadius: BorderRadius.circular(8)),
              child: ClipRRect(borderRadius: BorderRadius.circular(6), child: ColorFiltered(colorFilter: ColorFilter.matrix(filters[n]!), child: Image.memory(imgs[0], width: 56, height: 56, fit: BoxFit.cover))),
            ),
            Text(n, style: TextStyle(fontSize: 11, color: n == filter ? kPink : Colors.white70)),
          ]),
        ),
      );

  Widget _cardPanel() {
    final c = cards[selC];
    return Column(children: [
      _slider('Size', c.w, .15, 1, (v) => setState(() => c.w = v)),
      _slider('Rotate', c.rot, -.8, .8, (v) => setState(() => c.rot = v)),
      _row([
        _gap(ActionChip(
          avatar: const Icon(Icons.swap_horiz, size: 18),
          label: const Text('Change photo'),
          onPressed: () async {
            final p = await pickPhotos(1);
            if (p.isNotEmpty) _do(() => imgs[c.img.clamp(0, imgs.length - 1)] = p.first);
          },
        )),
        _gap(ActionChip(
          avatar: const Icon(Icons.edit, size: 18),
          label: const Text('Edit text'),
          onPressed: () async {
            final s = await _ask('Card text', c.cap);
            if (s != null) _do(() => c.cap = s);
          },
        )),
        _gap(ActionChip(avatar: const Icon(Icons.style, size: 18), label: Text(const ['Polaroid', 'Classic', 'Glass'][cs]), onPressed: () => _do(() => cs = (cs + 1) % 3))),
        _gap(ActionChip(avatar: const Icon(Icons.delete_outline, size: 18), label: const Text('Remove'), onPressed: () => _do(() { cards.remove(c); selC = -1; }))),
      ]),
    ]);
  }

  Widget _itemPanel() {
    final it = items[sel];
    return Column(children: [
      _slider('Size', it.scale, .3, 6, (v) => setState(() => it.scale = v)),
      _slider('Rotate', it.rot, -math.pi, math.pi, (v) => setState(() => it.rot = v)),
      _row([
        _gap(ActionChip(
          avatar: const Icon(Icons.edit, size: 18),
          label: const Text('Edit'),
          onPressed: () async {
            final s = await _ask('Edit', it.text);
            if (s != null && s.isNotEmpty) _do(() => it.text = s);
          },
        )),
        _gap(ActionChip(avatar: const Icon(Icons.copy, size: 18), label: const Text('Duplicate'), onPressed: () => _do(() { items.add(it.copy()..pos = it.pos + const Offset(16, 16)); sel = items.length - 1; }))),
        _gap(ActionChip(avatar: const Icon(Icons.delete_outline, size: 18), label: const Text('Delete'), onPressed: () => _do(() { items.removeAt(sel); sel = -1; }))),
      ]),
    ]);
  }

  Widget _panel() {
    final sl = sel >= 0 && sel < items.length ? items[sel] : null;
    return switch (tab) {
      0 => Column(children: [
        _sizeRow(),
        SizedBox(
          height: 60,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            if (t != null) GestureDetector(onTap: () => _setLayout(-1), child: _mini(li < 0, t!.cells)),
            for (var f = 0; f < fancyLayouts.length; f++) GestureDetector(onTap: () => _setLayout(1000 + f), child: _fthumb(f)),
            for (var i = 0; i < layouts.length; i++) GestureDetector(onTap: () => _setLayout(i), child: _mini(i == li, layouts[i])),
          ]),
        ),
      ]),
      1 => li < 0
          ? SingleChildScrollView(child: Column(children: [
              _styleRow(),
              _slider('Corners', cr, 0, 24, (v) => setState(() => cr = v)),
              _slider('Border', bw, 0, 2, (v) => setState(() => bw = v)),
              _slider('Shadow', sh, 0, 24, (v) => setState(() => sh = v)),
            ]))
          : Column(children: [
          _slider('Spacing', gap, 0, 24, (v) => setState(() => gap = v)),
          _slider('Corners', radius, 0, 40, (v) => setState(() => radius = v)),
          _slider('Frame', pad, 0, 60, (v) => setState(() => pad = v)),
        ]),
      2 => SizedBox(height: 84, child: ListView(scrollDirection: Axis.horizontal, children: [for (final n in filters.keys) _filterThumb(n)])),
      3 => Column(children: [
          _row([
            _gap(ActionChip(avatar: const Icon(Icons.add, size: 18), label: const Text('Add text'), onPressed: _addText)),
            for (final f in fonts) _gap(ChoiceChip(label: Text(f, style: GoogleFonts.getFont(f)), selected: sl?.font == f, onSelected: (_) => _ed((it) => it.font = f))),
          ]),
          _dots(colors, (c) => _ed((it) => it.color = c)),
          Row(children: [
            const Icon(Icons.format_size, size: 18),
            Expanded(child: Slider(value: (sl?.size ?? 34.0).clamp(12.0, 96.0).toDouble(), min: 12, max: 96, onChangeStart: (_) => _commit(), onChanged: (v) => _ed((it) => it.size = v, c: false))),
            const Icon(Icons.rotate_right, size: 18),
            Expanded(child: Slider(value: (sl?.rot ?? 0.0).clamp(-math.pi, math.pi).toDouble(), min: -math.pi, max: math.pi, onChangeStart: (_) => _commit(), onChanged: (v) => _ed((it) => it.rot = v, c: false))),
          ]),
        ]),
      4 => SizedBox(
          height: 96,
          child: GridView.builder(
            scrollDirection: Axis.horizontal,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
            itemCount: stickers.length,
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => _do(() {
                items.add(Item(stickers[i], 'Poppins', Colors.white, 48, const Offset(120, 120)));
                sel = items.length - 1;
                selC = -1;
                ip = false;
              }),
              child: Center(child: Text(stickers[i], style: const TextStyle(fontSize: 30))),
            ),
          ),
        ),
      _ => SingleChildScrollView(
          child: Column(children: [
            _row([
              _gap(ActionChip(avatar: const Icon(Icons.photo_library_outlined, size: 18), label: const Text('My photo'), onPressed: _pickBg)),
              if (t != null) _gap(ActionChip(avatar: const Icon(Icons.restore, size: 18), label: const Text('Template'), onPressed: _resetBg)),
              if (bgPic != null) _gap(ActionChip(avatar: const Icon(Icons.close, size: 18), label: const Text('Remove photo'), onPressed: () => _do(() => bgPic = null))),
            ]),
            _dots(colors, (c) => _do(() { bg = c; grad = null; patOn = false; bgPic = null; })),
            _row([
              for (final g in grads)
                GestureDetector(
                  onTap: () => _do(() { grad = g; patOn = false; bgPic = null; }),
                  child: Container(width: 40, height: 32, margin: const EdgeInsets.all(6), decoration: BoxDecoration(gradient: LinearGradient(colors: g), borderRadius: BorderRadius.circular(8))),
                ),
            ]),
            _slider('Blur', blur, 0, 20, (v) => setState(() => blur = v)),
            _slider('Dim', dim, 0, .7, (v) => setState(() => dim = v)),
          ]),
        ),
    };
  }

  Widget _ib(IconData i, VoidCallback? f) => IconButton(icon: Icon(i), onPressed: f, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 38, minHeight: 44), visualDensity: VisualDensity.compact);

  @override
  Widget build(BuildContext context) {
    if (selC >= cards.length) selC = -1;
    const tabs = [(Icons.grid_view_rounded, 'Layout'), (Icons.border_outer_rounded, 'Border'), (Icons.filter_vintage_rounded, 'Filter'), (Icons.text_fields_rounded, 'Text'), (Icons.emoji_emotions_rounded, 'Sticker'), (Icons.palette_rounded, 'Background')];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBg,
        leadingWidth: 124,
        leading: Row(children: [_ib(Icons.close, () => Navigator.pop(context)), _ib(Icons.undo, undo.isEmpty ? null : _undo), _ib(Icons.redo, redo.isEmpty ? null : _redo)]),
        actions: [
          if (imgs.length < 20) _ib(Icons.add_photo_alternate_outlined, _add),
          if (sel >= 0 && sel < items.length) _ib(Icons.delete_outline, () => _do(() { items.removeAt(sel); sel = -1; })),
          _ib(Icons.ios_share, () => _out((k) => shareImg(k, 1080 / S))),
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 10),
            child: FilledButton.icon(onPressed: () => _out((k) => saveImg(context, k, 1080 / S)), icon: const Icon(Icons.download, size: 18), label: const Text('Save')),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF14141C), Color(0xFF1C1631)])),
        child: Column(children: [
        Expanded(child: _canvas()),
        Container(
          decoration: const BoxDecoration(color: kPanel, borderRadius: BorderRadius.vertical(top: Radius.circular(26)), boxShadow: [BoxShadow(blurRadius: 20, color: Colors.black54)]),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: SafeArea(
            child: Column(children: [
              SizedBox(height: selC >= 0 || (ip && sel >= 0) || tab == 0 || tab == 1 || tab == 3 || tab == 5 ? 150 : 100, child: AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: KeyedSubtree(key: ValueKey('$tab-${selC >= 0}-${ip && sel >= 0}'), child: Align(alignment: Alignment.centerLeft, child: selC >= 0 ? _cardPanel() : (ip && sel >= 0 && sel < items.length && tab != 3) ? _itemPanel() : _panel())))),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                for (var i = 0; i < tabs.length; i++)
                  InkWell(
                    onTap: () => setState(() { tab = i; selC = -1; ip = false; if (i != 3) sel = -1; }),
                    child: Container(
                      decoration: tab == i && selC < 0 ? BoxDecoration(color: kPink.withOpacity(.14), borderRadius: BorderRadius.circular(14)) : null,
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                      child: Column(children: [
                        Icon(tabs[i].$1, color: tab == i && selC < 0 ? kPink : Colors.white70),
                        Text(tabs[i].$2, style: TextStyle(fontSize: 11, color: tab == i && selC < 0 ? kPink : Colors.white70)),
                      ]),
                    ),
                  ),
              ]),
            ]),
          ),
        ),
      ])),
    );
  }
}
