import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'data.dart';

class BlenderPage extends StatefulWidget {
  final List<Uint8List> imgs;
  const BlenderPage({super.key, required this.imgs});
  @override
  State<BlenderPage> createState() => _BS();
}

class _BS extends State<BlenderPage> {
  final key = GlobalKey();
  late final im = List.of(widget.imgs);
  double op = 1;
  bool flip = false;
  int dir = 0;
  static const names = ['Fade down', 'Fade up', 'Fade right', 'Fade left'];
  static const al = [[Alignment.topCenter, Alignment.bottomCenter], [Alignment.bottomCenter, Alignment.topCenter], [Alignment.centerLeft, Alignment.centerRight], [Alignment.centerRight, Alignment.centerLeft]];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(backgroundColor: kBg, title: const Text('Photo Blender'), actions: [
          IconButton(icon: const Icon(Icons.ios_share), onPressed: () => shareImg(key)),
          Padding(padding: const EdgeInsets.only(right: 12), child: FilledButton(onPressed: () => saveImg(context, key), child: const Text('Save'))),
        ]),
        body: Column(children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: RepaintBoundary(
                    key: key,
                    child: Stack(fit: StackFit.expand, children: [
                      Image.memory(im[1], fit: BoxFit.cover),
                      Opacity(
                        opacity: op,
                        child: ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (r) => LinearGradient(begin: al[dir][0], end: al[dir][1], colors: const [Colors.white, Colors.transparent]).createShader(r),
                          child: Transform.flip(flipX: flip, child: Image.memory(im[0], fit: BoxFit.cover)),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(color: kPanel, borderRadius: BorderRadius.vertical(top: Radius.circular(26)), boxShadow: [BoxShadow(blurRadius: 20, color: Colors.black54)]),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SafeArea(
              child: Column(children: [
                Row(children: [const Text('Opacity'), Expanded(child: Slider(value: op, min: .2, max: 1, onChanged: (v) => setState(() => op = v)))]),
                SizedBox(
                  height: 44,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    for (var i = 0; i < 4; i++) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(names[i]), selected: dir == i, onSelected: (_) => setState(() => dir = i))),
                    ActionChip(avatar: const Icon(Icons.flip, size: 18), label: const Text('Flip'), onPressed: () => setState(() => flip = !flip)),
                    const SizedBox(width: 8),
                    ActionChip(avatar: const Icon(Icons.swap_vert, size: 18), label: const Text('Swap'), onPressed: () => setState(() => im.insert(0, im.removeAt(1)))),
                  ]),
                ),
                const SizedBox(height: 8),
              ]),
            ),
          ),
        ]),
      );
}
