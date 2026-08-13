import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/quran_audio.dart';
import '../memorization_calc.dart' show MemorizationDirection;
import 'audio_player.dart';

/// App-level audio state so today's unit keeps playing after the mushaf
/// viewer is closed — the planner screen shows a persistent mini player that
/// can pause/resume the unit, close it, or reopen the viewer at its page.
///
/// Owns a single [QuranAudio] instance for the whole app lifetime; the mushaf
/// viewer binds to it instead of creating its own player.
class AudioUnitController extends ChangeNotifier {
  AudioUnitController({QuranAudio? audio})
    : _audio = audio ?? JustQuranAudio() {
    _sub = _audio.onCompleted.listen((_) {
      _playing = false;
      notifyListeners();
    });
  }

  final QuranAudio _audio;
  StreamSubscription<void>? _sub;

  bool _playing = false;
  bool get playing => _playing;

  String? _error;
  String? get error => _error;

  String _label = '';

  /// Short title of the playing unit, e.g. "سورة البقرة · page 22".
  String get label => _label;

  String _settings = '';

  /// Snapshot of the playback settings shown under [label], e.g.
  /// "Husary (murattal) · 1.5× · repeat ×3".
  String get settings => _settings;

  int _page = 1;
  int get page => _page;

  double _linesPerDay = 0;
  double get linesPerDay => _linesPerDay;

  MemorizationDirection _direction = MemorizationDirection.forward;
  MemorizationDirection get direction => _direction;

  int _repeat = 1;
  int get repeat => _repeat;

  Reciter _reciter = Reciter.alafasy;
  Reciter get reciter => _reciter;

  double _speed = 1.0;
  double get speed => _speed;

  /// Whether a unit has been started (playing, paused, or just finished) and
  /// the mini player should be visible.
  bool get hasUnit => _label.isNotEmpty;

  List<String> _urls = const [];

  /// Starts playing [urls] as today's unit and remembers everything the mini
  /// player needs to pause/resume or reopen the viewer.
  Future<void> play({
    required List<String> urls,
    required String label,
    required String settings,
    required int page,
    required double linesPerDay,
    required MemorizationDirection direction,
    required int repeat,
    required Reciter reciter,
    required double speed,
  }) async {
    _urls = urls;
    _label = label;
    _settings = settings;
    _page = page;
    _linesPerDay = linesPerDay;
    _direction = direction;
    _repeat = repeat;
    _reciter = reciter;
    _speed = speed;
    _error = null;
    await _audio.setSpeed(speed);
    try {
      await _audio.play(urls: urls, repeat: repeat);
      _playing = true;
    } catch (_) {
      _playing = false;
      _error = "Couldn't play audio — check your connection.";
    }
    notifyListeners();
  }

  /// Pauses a playing unit (keeps the mini player).
  Future<void> pause() async {
    if (!_playing) return;
    await _audio.pause();
    _playing = false;
    notifyListeners();
  }

  /// Pauses a playing unit or (re)starts a paused one.
  Future<void> toggle() async {
    if (_playing) {
      await _audio.pause();
      _playing = false;
    } else {
      await _restart();
    }
    notifyListeners();
  }

  Future<void> _restart() async {
    if (_urls.isEmpty) return;
    _error = null;
    try {
      await _audio.play(urls: _urls, repeat: _repeat);
      _playing = true;
    } catch (_) {
      _playing = false;
      _error = "Couldn't play audio — check your connection.";
    }
  }

  /// Applies a new playback speed immediately (even mid-unit); the next
  /// [play] also carries it.
  Future<void> setSpeed(double speed) async {
    if (speed == _speed) return;
    _speed = speed;
    await _audio.setSpeed(speed);
    notifyListeners();
  }

  /// Stops playback and dismisses the unit (hides the mini player).
  void stop() {
    _audio.stop();
    _playing = false;
    _label = '';
    _settings = '';
    _urls = const [];
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _audio.dispose();
    super.dispose();
  }
}
