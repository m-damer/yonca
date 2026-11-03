import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../shared/permission_primer.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import 'activity_labels.dart';
import '../../theme/tokens.dart';
import '../../theme/lucide.dart';

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
        icon: _playing ? Lu.pause : Lu.play,
        filled: true,
        size: 40,
        tooltip: _playing ? l.voicePause : l.voicePlay,
        onTap: _toggle,
      ),
      const SizedBox(width: AppSpace.md),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xs),
          child: LinearProgressIndicator(value: frac, minHeight: 6, backgroundColor: pal.track, color: pal.primary),
        ),
      ),
      const SizedBox(width: AppSpace.md),
      Text(formatDuration(_playing || _pos > 0 ? _pos : _total),
          textDirection: TextDirection.ltr, style: TextStyle(color: pal.text2, fontSize: AppFont.meta)),
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

  /// The last bars of the live wave, 0 (quiet) to 1 (loud), newest last.
  static const _bars = 28;
  final List<double> _levels = List<double>.filled(_bars, 0);
  Timer? _ampTimer;

  // The microphone's loudness in dB differs from phone to phone, so the wave adapts: the quiet level
  // (floor) and the loud level (peak) follow what the phone really reports.
  double _floor = -60;
  double _peak = -20;

  void _listenLevel() {
    _ampTimer?.cancel();
    _ampTimer = Timer.periodic(const Duration(milliseconds: 90), (_) async {
      final r = _rec;
      if (r == null) return;
      try {
        final a = await r.getAmplitude();
        if (!mounted || _state != _Rec.recording) return;
        final db = a.current.isFinite ? a.current.clamp(-120.0, 0.0) : -120.0;
        _floor = db < _floor ? db : _floor + (db - _floor) * 0.01;
        _peak = db > _peak ? db : _peak - 0.15;
        if (_peak < _floor + 10) _peak = _floor + 10;
        final level = ((db - _floor) / (_peak - _floor)).clamp(0.0, 1.0);
        setState(() {
          _levels
            ..removeAt(0)
            ..add(level);
        });
      } catch (_) {}
    });
  }

  void _stopLevel() {
    _ampTimer?.cancel();
    _ampTimer = null;
  }

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
    final l = AppLocalizations.of(context);
    if (!await PermissionPrimer.once(context, 'microphone', icon: Lu.mic, title: l.permMicTitle, body: l.permMicBody)) return;
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
    _levels.fillRange(0, _bars, 0);
    _floor = -60;
    _peak = -20;
    _startTimer();
    _listenLevel();
    _set(_Rec.recording);
  }

  Future<void> _pause() async {
    await _rec?.pause();
    _timer?.cancel();
    _stopLevel();
    _set(_Rec.paused);
  }

  Future<void> _resume() async {
    await _rec?.resume();
    _startTimer();
    _listenLevel();
    _set(_Rec.recording);
  }

  Future<void> _stop() async {
    final out = await _rec?.stop();
    _timer?.cancel();
    _stopLevel();
    _set(_Rec.idle);
    final path = out ?? _path;
    if (path != null) widget.onChanged(VoiceResult(path, _ms));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ampTimer?.cancel();
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
    Widget card(Widget child) => GlassCard(padding: const EdgeInsets.all(AppSpace.lg), child: child);
    Widget body;
    if (_state != _Rec.idle) {
      final live = _state == _Rec.recording;
      body = card(Column(children: [
        Row(children: [
          Icon(Lu.circleDot, color: live ? pal.error : pal.text2, size: AppIcon.sm),
          const SizedBox(width: AppSpace.sm),
          Text(live ? l.voiceRecording : l.voicePause, style: TextStyle(color: live ? pal.error : pal.text2, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(formatDuration(_ms), textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: AppFont.pageTitle)),
        ]),
        const SizedBox(height: AppSpace.lg),
        // Left to right always: the newest bar is on the right, in Arabic too.
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            height: AppControl.md,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
              for (var i = 0; i < _bars; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: 3,
                  height: 4.0 + _levels[i] * (AppControl.md - 4),
                  margin: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
                  decoration: BoxDecoration(color: live ? pal.text : pal.text2, borderRadius: BorderRadius.circular(AppRadius.xxs)),
                ),
            ]),
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          GlassIconButton(
            icon: live ? Lu.pause : Lu.mic,
            size: 56,
            radius: 28,
            tooltip: live ? l.voicePause : l.voiceResume,
            onTap: live ? _pause : _resume,
          ),
          const SizedBox(width: AppSpace.lg),
          Material(
            color: pal.error,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _stop,
              child: SizedBox(width: AppControl.xl, height: AppControl.xl, child: Icon(Lu.square, color: Theme.of(context).colorScheme.onError, size: AppIcon.xl)),
            ),
          ),
        ]),
        const SizedBox(height: AppSpace.sm),
        Text(l.voicePauseStop, style: TextStyle(color: pal.text2, fontSize: AppFont.meta)),
      ]));
    } else if (v != null) {
      body = card(Row(children: [
        Expanded(child: VoicePlayer(key: ValueKey(v.path), path: v.path, durationMs: v.durationMs)),
        const SizedBox(width: AppSpace.sm),
        GlassIconButton(icon: Lu.trash2, danger: true, size: 40, tooltip: l.voiceDelete, onTap: () => widget.onChanged(null)),
      ]));
    } else {
      body = GlassCard(
        padding: EdgeInsets.zero,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: _start,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Row(children: [
                Container(
                  width: 56,
                  height: AppControl.xl,
                  decoration: BoxDecoration(color: pal.primary, shape: BoxShape.circle),
                  child: Icon(Lu.mic, color: pal.onPrimary, size: AppIcon.xl),
                ),
                const SizedBox(width: AppSpace.lg),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.voiceNote, style: const TextStyle(fontSize: AppFont.body, fontWeight: FontWeight.w600)),
                    Text(l.voiceTapHint, style: TextStyle(fontSize: AppFont.meta, color: pal.text2)),
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
        Padding(padding: const EdgeInsets.only(top: AppSpace.sm), child: Text(l.micDenied, style: TextStyle(color: pal.error, fontSize: AppFont.meta))),
    ]);
  }
}
