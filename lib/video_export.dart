import 'dart:async';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:path_provider/path_provider.dart';

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
  final br = short >= 1080 ? '10M' : '6M';
  return hw ? (Platform.isIOS ? '-c:v h264_videotoolbox -b:v $br' : '-c:v h264_mediacodec -b:v $br') : '-c:v mpeg4 -q:v 3';
}

// Ken-Burns style motion for one slide (no commas / quotes so it needs no escaping)
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

/// Turns the rendered slide images into a video: motion + transitions + background music.
/// Returns the mp4 path, or null on failure (see [lastError]).
Future<String?> exportSlideshow({
  required List<String> slides,
  required double per,
  required double tt,
  required List<String> trans,
  required List<String> motion,
  required double aspect,
  required int short,
  String? music,
  double musicVol = .8,
  required void Function(double) onProgress,
}) async {
  final dir = await getTemporaryDirectory();
  final out = '${dir.path}/CollageMaker_${DateTime.now().millisecondsSinceEpoch}.mp4';
  final (w, h) = exportSize(aspect, short);
  final n = slides.length, total = n * per + tt, frames = ((per + tt) * 30).round();

  String cmd(bool hw) {
    final ins = StringBuffer('-y');
    for (final s in slides) {
      ins.write(' -i "$s"');
    }
    final fc = <String>[];
    for (var i = 0; i < n; i++) {
      fc.add('[$i:v]zoompan=${_motion(motion[i % motion.length], frames)}:d=$frames:s=${w}x$h:fps=30,setsar=1,format=yuv420p[v$i]');
    }
    var last = '[v0]';
    for (var i = 1; i < n; i++) {
      final o = i == n - 1 ? '[vout]' : '[x$i]';
      fc.add('$last[v$i]xfade=transition=${trans[(i - 1) % trans.length]}:duration=$tt:offset=${(i * per).toStringAsFixed(3)}$o');
      last = o;
    }
    if (music != null) {
      ins.write(' -stream_loop -1 -i "$music"');
      fc.add('[$n:a]volume=${musicVol.toStringAsFixed(2)},afade=t=in:d=1,afade=t=out:st=${(total - 1.5).toStringAsFixed(2)}:d=1.5[a]');
    }
    return '$ins -filter_complex "${fc.join(';')}" -map "${n == 1 ? '[v0]' : '[vout]'}" ${music != null ? '-map "[a]" ' : ''}-t ${total.toStringAsFixed(2)} -r 30 ${_enc(hw, short)} ${music != null ? '-c:a aac -b:a 160k ' : ''}-movflags +faststart "$out"';
  }

  var ok = await _run(cmd(true), total, onProgress);
  if (!ok) ok = await _run(cmd(false), total, onProgress); // fall back to software encoder
  return ok ? out : null;
}
