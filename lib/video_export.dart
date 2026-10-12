import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'fx.dart';
import 'transitions.dart';

/// last FFmpeg error output, shown to the user if an export fails
String lastError = '';

(int, int) exportSize(double aspect, int short) {
  var w = aspect >= 1 ? (short * aspect).round() : short, h = aspect >= 1 ? short : (short / aspect).round();
  w += w % 2;
  h += h % 2;
  return (w, h);
}

Future<bool> _run(String cmd, double sec, void Function(double) p) async {
  final done = Completer<bool>();
  await FFmpegKit.executeAsync(cmd, (s) async {
    final ok = ReturnCode.isSuccess(await s.getReturnCode());
    if (!ok) lastError = (await s.getOutput()) ?? 'unknown error';
    done.complete(ok);
  }, null, (st) {
    if (sec > 0) p((st.getTime().toDouble() / 1000 / sec).clamp(0.0, 1.0).toDouble());
  });
  return done.future;
}

String _enc(bool hw, int short) {
  final br = short >= 1080 ? '12M' : '8M';
  return hw ? (Platform.isIOS ? '-c:v h264_videotoolbox -b:v $br' : '-c:v h264_mediacodec -b:v $br') : '-c:v mpeg4 -q:v 2';
}

String _motion(String m, int f) {
  const c = 'x=iw/2-(iw/zoom/2):y=ih/2-(ih/zoom/2)';
  switch (m) {
    case 'out':
      return 'z=1.12-0.12*on/$f:$c';
    case 'left':
      return 'z=1.12:x=(iw-iw/zoom)*(1-on/$f):y=ih/2-(ih/zoom/2)';
    case 'right':
      return 'z=1.12:x=(iw-iw/zoom)*on/$f:y=ih/2-(ih/zoom/2)';
    default:
      return 'z=1+0.12*on/$f:$c';
  }
}

int _ev(num v) => math.max(2, (v.round() ~/ 2) * 2);

/// One slide: its media (photo or video), the template background, the card frame image
/// (with a see-through window) and where the media goes (output pixels).
class SlideJob {
  final String media;
  final bool video;
  final String? bg;
  final String frame;
  final int style;
  final String motion;
  final double cx, cy, ww, wh, ang;
  SlideJob({required this.media, required this.video, required this.bg, required this.frame, required this.style, required this.motion, required this.cx, required this.cy, required this.ww, required this.wh, required this.ang});
}

String _slideCmd(SlideJob j, String out, int w, int h, double len, bool hw, int short) {
  final f = (len * 30).round(), ls = len.toStringAsFixed(3), ins = StringBuffer('-y');
  var idx = 0, ib = -1;
  if (j.bg != null) {
    ins.write(' -loop 1 -framerate 30 -t $ls -i "${j.bg}"');
    ib = idx++;
  }
  ins.write(j.video ? ' -i "${j.media}"' : ' -loop 1 -framerate 30 -t $ls -i "${j.media}"');
  final im = idx++;
  ins.write(' -loop 1 -framerate 30 -t $ls -i "${j.frame}"');
  final iff = idx++, glass = j.style == 2, full = j.style == 3, tw = full ? w : _ev(j.ww), th = full ? h : _ev(j.wh);
  final fc = <String>[];
  final norm = j.video ? 'trim=duration=$ls,setpts=PTS-STARTPTS,fps=30,tpad=stop_mode=clone:stop_duration=$ls,trim=duration=$ls,setpts=PTS-STARTPTS' : 'fps=30';
  fc.add('[$im:v]$norm${glass ? ',split=2[mA][mB]' : '[mA]'}');
  final fit = j.video ? 'scale=$tw:$th:force_original_aspect_ratio=increase,crop=$tw:$th' : 'scale=${tw * 2}:${th * 2}:force_original_aspect_ratio=increase,crop=${tw * 2}:${th * 2},zoompan=${_motion(j.motion, f)}:d=1:s=${tw}x$th:fps=30';
  var rw = tw, rh = th, rot = '';
  if (!full && j.ang.abs() > .001) {
    final c = math.cos(j.ang).abs(), s = math.sin(j.ang).abs();
    rw = _ev((tw * c + th * s).ceil());
    rh = _ev((tw * s + th * c).ceil());
    rot = ',rotate=${j.ang}:ow=$rw:oh=$rh:c=0x00000000';
  }
  fc.add('[mA]$fit,format=rgba$rot[med]');
  var base = '[med]';
  if (!full) {
    fc.add(glass ? '[mB]scale=$w:$h:force_original_aspect_ratio=increase,crop=$w:$h,boxblur=20:3,eq=brightness=-0.1,format=yuv420p[bg]' : '[$ib:v]scale=$w:$h:force_original_aspect_ratio=increase,crop=$w:$h,setsar=1,format=yuv420p[bg]');
    fc.add('[bg][med]overlay=x=${(j.cx - rw / 2).round()}:y=${(j.cy - rh / 2).round()}:format=auto[o1]');
    base = '[o1]';
  }
  fc.add('[$iff:v]scale=$w:$h,format=rgba[fr];$base[fr]overlay=0:0:format=auto,setsar=1,fps=30,format=yuv420p[vout]');
  return '$ins -filter_complex "${fc.join(';')}" -map "[vout]" -t $ls -r 30 -an ${_enc(hw, short)} "$out"';
}

/// Black/white mask frames: white = the next picture is visible.
Future<void> _masks(String dir, int j, String kind, int w, int h, int frames) async {
  for (var f = 0; f < frames; f++) {
    final q = (f + 1) / frames, rec = ui.PictureRecorder(), cv = Canvas(rec), box = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
    cv.drawRect(box, Paint()..color = Colors.black);
    if (kind == 'fade') {
      cv.drawRect(box, Paint()..color = Color.fromRGBO(255, 255, 255, q));
    } else if (q >= .999) {
      cv.drawRect(box, Paint()..color = Colors.white);
    } else {
      cv.drawPath(revealPath(kind, q, w.toDouble(), h.toDouble()), Paint()..color = Colors.white..isAntiAlias = true);
    }
    final bd = await (await rec.endRecording().toImage(w, h)).toByteData(format: ui.ImageByteFormat.png);
    File('$dir/m${j}_${f.toString().padLeft(3, '0')}.png').writeAsBytesSync(bd!.buffer.asUint8List());
  }
}

Future<void> _fxFrames(String dir, String kind, int w, int h) async {
  final n = (fxLoop * 30).round();
  for (var f = 0; f < n; f++) {
    final rec = ui.PictureRecorder();
    paintFx(Canvas(rec), Size(w.toDouble(), h.toDouble()), kind, f / 30);
    final bd = await (await rec.endRecording().toImage(w, h)).toByteData(format: ui.ImageByteFormat.png);
    File('$dir/fx_${f.toString().padLeft(3, '0')}.png').writeAsBytesSync(bd!.buffer.asUint8List());
  }
}

/// Builds the video: every slide becomes a short clip, then the clips are joined with the
/// shape transitions and the background music is mixed in.
Future<String?> exportSlideshow({
  required List<SlideJob> jobs,
  required List<String> kinds,
  required double per,
  required double tt,
  required double aspect,
  required int short,
  String? music,
  double musicVol = .8,
  String fx = 'none',
  required void Function(double) onProgress,
}) async {
  final dir = await getTemporaryDirectory(), stamp = DateTime.now().millisecondsSinceEpoch;
  final work = Directory('${dir.path}/vs_$stamp')..createSync(recursive: true);
  final (w, h) = exportSize(aspect, short);
  final n = jobs.length, len = per + tt, total = n * per + tt, ft = (tt * 30).round();
  var hw = true;
  final clips = <String>[];
  for (var j = 1; j < n; j++) {
    await _masks(work.path, j, kinds[j - 1], w, h, ft);
  }
  if (fx != 'none') await _fxFrames(work.path, fx, w, h);
  for (var i = 0; i < n; i++) {
    final out = '${work.path}/c$i.mp4';
    void prog(double p) => onProgress(.6 * (i + p) / n);
    var ok = await _run(_slideCmd(jobs[i], out, w, h, len, hw, short), len, prog);
    if (!ok && hw) {
      hw = false; // hardware encoder unavailable: use the software one
      ok = await _run(_slideCmd(jobs[i], out, w, h, len, false, short), len, prog);
    }
    if (!ok) return null;
    clips.add(out);
  }
  final res = '${dir.path}/CollageMaker_$stamp.mp4';
  String f3(double v) => v.toStringAsFixed(3);
  String join(bool hw) {
    final ins = StringBuffer('-y'), fc = <String>[], hasFx = fx != 'none';
    for (final c in clips) {
      ins.write(' -i "$c"');
    }
    for (var j = 1; j < n; j++) {
      ins.write(' -framerate 30 -i "${work.path}/m${j}_%03d.png"');
    }
    if (n > 1) {
      for (var k = 0; k < n; k++) {
        final tail = k < n - 1, head = k > 0, ls = ['[bi$k]', if (tail) '[ti$k]', if (head) '[hi$k]'];
        fc.add('[$k:v]split=${ls.length}${ls.join()}');
        fc.add('[bi$k]trim=start=${f3(head ? tt : 0)}:end=${f3(tail ? per : per + tt)},setpts=PTS-STARTPTS[b$k]');
        if (tail) fc.add('[ti$k]trim=start=${f3(per)}:end=${f3(per + tt)},setpts=PTS-STARTPTS,format=gbrp[t$k]');
        if (head) fc.add('[hi$k]trim=start=0:end=${f3(tt)},setpts=PTS-STARTPTS,format=gbrp[h$k]');
      }
      final seq = ['[b0]'];
      for (var j = 1; j < n; j++) {
        fc.add('[${n + j - 1}:v]format=gbrp[mk$j];[t${j - 1}][h$j][mk$j]maskedmerge,format=yuv420p,setsar=1,fps=30[tr$j]');
        seq..add('[tr$j]')..add('[b$j]');
      }
      fc.add('${seq.join()}concat=n=${seq.length}:v=1:a=0[${hasFx ? 'vcat' : 'vout'}]');
    }
    var nxt = 2 * n - 1;
    if (hasFx) {
      ins.write(' -loop 1 -framerate 30 -i "${work.path}/fx_%03d.png"');
      fc.add('[${n > 1 ? 'vcat' : '0:v'}][$nxt:v]overlay=0:0:format=auto,format=yuv420p[vout]');
      nxt++;
    }
    if (music != null) {
      ins.write(' -stream_loop -1 -i "$music"');
      fc.add('[$nxt:a]volume=${musicVol.toStringAsFixed(2)},afade=t=in:d=1,afade=t=out:st=${(total - 1.5).toStringAsFixed(2)}:d=1.5[a]');
    }
    final filt = fc.isEmpty ? '' : '-filter_complex "${fc.join(';')}" ';
    final vmap = n > 1 || hasFx ? '-map "[vout]" ${_enc(hw, short)}' : '-map 0:v -c:v copy';
    return '$ins $filt$vmap ${music != null ? '-map "[a]" -c:a aac -b:a 160k' : '-an'} -t ${total.toStringAsFixed(2)} -movflags +faststart "$res"';
  }

  var ok = await _run(join(true), total, (p) => onProgress(.6 + .4 * p));
  if (!ok && (n > 1 || fx != 'none')) ok = await _run(join(false), total, (p) => onProgress(.6 + .4 * p));
  try {
    work.deleteSync(recursive: true);
  } catch (_) {}
  return ok ? res : null;
}
