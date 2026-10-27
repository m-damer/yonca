import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import 'activity_labels.dart';

/// The player that is playing now. A new player stops the previous one (only one plays at a time).
final ValueNotifier<Object?> _activePlayer = ValueNotifier<Object?>(null);

/// Inline voice player: play, pause, resume, progress and duration.
class VoicePlayer extends StatefulWidget {
  const VoicePlayer({super.key, required this.path, required this.durationMs});
  final String path;
  final int durationMs;

  @override
  State<VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<VoicePlayer> {
  AudioPlayer? _player;
  final List<StreamSubscription<dynamic>> _subs = [];
  bool _playing = false;
  late int _total = widget.durationMs;
  int _pos = 0;

  AudioPlayer _ensure() {
    var pl = _player;
    if (pl != null) return pl;
    pl = _player = AudioPlayer();
    _subs.add(pl.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    }));
    _subs.add(pl.onPositionChanged.listen((d) {
      if (mounted) setState(() => _pos = d.inMilliseconds);
    }));
    _subs.add(pl.onDurationChanged.listen((d) {
      if (mounted && d.inMilliseconds > 0) setState(() => _total = d.inMilliseconds);
    }));
    _subs.add(pl.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _pos = 0);
    }));
    return pl;
  }

  @override
  void initState() {
    super.initState();
    _activePlayer.addListener(_onActive);
  }

  void _onActive() {
    if (_activePlayer.value != this && _playing) _player?.pause();
  }

  Future<void> _toggle() async {
    final pl = _ensure();
    if (_playing) {
      await pl.pause();
      return;
    }
    _activePlayer.value = this;
    if (_pos > 0 && _pos < _total) {
      await pl.resume();
    } else {
      await pl.play(DeviceFileSource(widget.path));
    }
  }

  @override
  void dispose() {
    _activePlayer.removeListener(_onActive);
    for (final s in _subs) {
      s.cancel();
    }
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    final frac = _total <= 0 ? 0.0 : (_pos / _total).clamp(0.0, 1.0);
    return Row(children: [
      GlassIconButton(
        icon: _playing ? Icons.pause : Icons.play_arrow,
        filled: true,
        size: 40,
        tooltip: _playing ? l.voicePause : l.voicePlay,
        onTap: _toggle,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: frac, minHeight: 6, backgroundColor: pal.track, color: pal.primary),
        ),
      ),
      const SizedBox(width: 12),
      Text(formatDuration(_playing || _pos > 0 ? _pos : _total),
          textDirection: TextDirection.ltr, style: TextStyle(color: pal.text2, fontSize: 13)),
    ]);
  }
}

/// What the recorder hands back to the form.
class VoiceResult {
  const VoiceResult(this.path, this.durationMs);
  final String path;
  final int durationMs;
}

/// Record, pause, resume and stop a voice note, then play it back. No time limit.
class VoiceRecorderField extends StatefulWidget {
  const VoiceRecorderField({super.key, required this.value, required this.onChanged, this.onRecordingChanged});
  final VoiceResult? value;
  final ValueChanged<VoiceResult?> onChanged;

  /// Tells the form whether a recording is in progress (leaving then asks to keep it).
  final ValueChanged<bool>? onRecordingChanged;

  @override
  State<VoiceRecorderField> createState() => _VoiceRecorderFieldState();
}

enum _Rec { idle, recording, paused }

class _VoiceRecorderFieldState extends State<VoiceRecorderField> {
  AudioRecorder? _rec;
  _Rec _state = _Rec.idle;
  bool _denied = false;
  int _ms = 0;
  Timer? _timer;
  String? _path;

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() => _ms += 250);
    });
  }

  void _set(_Rec s) {
    setState(() => _state = s);
    widget.onRecordingChanged?.call(s != _Rec.idle);
  }

  Future<void> _start() async {
    final r = _rec ??= AudioRecorder();
    bool ok;
    try {
      ok = await r.hasPermission();
    } catch (_) {
      ok = false;
    }
    if (!ok) {
      if (mounted) setState(() => _denied = true);
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(dir.path, 'voice'))..createSync(recursive: true);
    final path = p.join(folder.path, 'v${DateTime.now().millisecondsSinceEpoch}.m4a');
    await r.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    _path = path;
    _ms = 0;
    _denied = false;
    _startTimer();
    _set(_Rec.recording);
  }

  Future<void> _pause() async {
    await _rec?.pause();
    _timer?.cancel();
    _set(_Rec.paused);
  }

  Future<void> _resume() async {
    await _rec?.resume();
    _startTimer();
    _set(_Rec.recording);
  }

  Future<void> _stop() async {
    final out = await _rec?.stop();
    _timer?.cancel();
    _set(_Rec.idle);
    final path = out ?? _path;
    if (path != null) widget.onChanged(VoiceResult(path, _ms));
  }

  @override
  void dispose() {
    _timer?.cancel();
    final r = _rec;
    if (r != null) {
      if (_state != _Rec.idle) {
        r.stop().whenComplete(r.dispose);
      } else {
        r.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    final v = widget.value;
    Widget card(Widget child) => GlassCard(padding: const EdgeInsets.all(16), child: child);
    Widget body;
    if (_state != _Rec.idle) {
      final live = _state == _Rec.recording;
      body = card(Column(children: [
        Row(children: [
          Icon(Icons.fiber_manual_record, color: live ? pal.error : pal.text2, size: 14),
          const SizedBox(width: 6),
          Text(live ? l.voiceRecording : l.voicePause, style: TextStyle(color: live ? pal.error : pal.text2, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(formatDuration(_ms), textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 22)),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 40,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
            for (var i = 0; i < 28; i++)
              Container(
                width: 3,
                height: 8.0 + ((i * 7 + _ms ~/ 250 * 5) % 5) * 7,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(color: pal.text, borderRadius: BorderRadius.circular(2)),
              ),
          ]),
        ),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          GlassIconButton(
            icon: live ? Icons.pause : Icons.mic,
            size: 56,
            radius: 28,
            tooltip: live ? l.voicePause : l.voiceResume,
            onTap: live ? _pause : _resume,
          ),
          const SizedBox(width: 16),
          Material(
            color: pal.error,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _stop,
              child: SizedBox(width: 56, height: 56, child: Icon(Icons.stop, color: Theme.of(context).colorScheme.onError, size: 28)),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Text(l.voicePauseStop, style: TextStyle(color: pal.text2, fontSize: 13)),
      ]));
    } else if (v != null) {
      body = card(Row(children: [
        Expanded(child: VoicePlayer(key: ValueKey(v.path), path: v.path, durationMs: v.durationMs)),
        const SizedBox(width: 8),
        GlassIconButton(icon: Icons.delete_outline, size: 40, tooltip: l.voiceDelete, onTap: () => widget.onChanged(null)),
      ]));
    } else {
      body = GlassCard(
        padding: EdgeInsets.zero,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _start,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: pal.primary, shape: BoxShape.circle),
                  child: Icon(Icons.mic, color: pal.onPrimary, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.voiceNote, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    Text(l.voiceTapHint, style: TextStyle(fontSize: 13, color: pal.text2)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      body,
      if (_denied)
        Padding(padding: const EdgeInsets.only(top: 6), child: Text(l.micDenied, style: TextStyle(color: pal.error, fontSize: 13))),
    ]);
  }
}
