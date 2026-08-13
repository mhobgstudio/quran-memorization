import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// Minimal audio interface so UI and tests don't depend on just_audio.
abstract class QuranAudio {
  /// Plays [urls] in order, repeating the whole unit [repeat] times.
  /// A [repeat] of 0 or less loops the unit until [pause] or [stop].
  Future<void> play({required List<String> urls, required int repeat});

  Future<void> pause();

  Future<void> stop();

  /// Sets the playback speed (0.5x..2x); persists across plays.
  Future<void> setSpeed(double speed);

  Future<void> dispose();

  /// Fires when the current unit finishes playing (all repeats done).
  Stream<void> get onCompleted;
}

/// just_audio-backed playback of per-ayah recitation.
///
/// The [AudioPlayer] is created lazily on the first [play] and never at
/// construction, so the app starts instantly and audio is only initialised
/// when the user actually plays something (and if the platform has no audio
/// output — e.g. headless browsers — the player simply reports the playback
/// error instead of crashing the app at startup).
class JustQuranAudio implements QuranAudio {
  // ignore: prefer_initializing_formals, unnecessary_this
  JustQuranAudio({AudioPlayer? player}) : this._player = player;

  AudioPlayer? _player;

  final StreamController<void> _completed = StreamController<void>.broadcast();
  StreamSubscription<void>? _completedSub;

  /// Lazily creates the player; returns null when audio is unavailable.
  AudioPlayer? _lazy() {
    var player = _player;
    if (player != null) return player;
    try {
      player = AudioPlayer();
      _player = player;
      _completedSub = player.processingStateStream
          .where((state) => state == ProcessingState.completed)
          .map((_) {})
          .listen((_) => _completed.add(null));
    } catch (_) {
      return null;
    }
    return player;
  }

  @override
  Future<void> play({required List<String> urls, required int repeat}) async {
    final player = _lazy();
    if (player == null) throw StateError('Audio is unavailable on this device');
    await player.stop();
    // repeat <= 0: loop the unit until stopped; otherwise duplicate the
    // concatenated ayah sources so just_audio plays it [repeat] times.
    final infinite = repeat <= 0;
    await player.setLoopMode(infinite ? LoopMode.all : LoopMode.off);
    final sources = [
      for (var r = 0; r < (infinite ? 1 : repeat); r++)
        for (final url in urls) AudioSource.uri(Uri.parse(url)),
    ];
    await player.setAudioSources(sources);
    await player.play();
  }

  @override
  Future<void> pause() async => _player?.pause();

  @override
  Future<void> stop() async => _player?.stop();

  @override
  Future<void> setSpeed(double speed) async => _player?.setSpeed(speed);

  @override
  Future<void> dispose() async {
    await _completedSub?.cancel();
    await _completed.close();
    await _player?.dispose();
  }

  @override
  Stream<void> get onCompleted => _completed.stream;
}
