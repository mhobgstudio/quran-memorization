import 'package:just_audio/just_audio.dart';

/// Minimal audio interface so UI and tests don't depend on just_audio.
abstract class QuranAudio {
  /// Plays [urls] in order, repeating the whole unit [repeat] times.
  /// A [repeat] of 0 or less loops the unit until [pause] or [stop].
  Future<void> play({required List<String> urls, required int repeat});

  Future<void> pause();

  Future<void> stop();

  Future<void> dispose();

  /// Fires when the current unit finishes playing (all repeats done).
  Stream<void> get onCompleted;
}

/// just_audio-backed playback of per-ayah recitation.
class JustQuranAudio implements QuranAudio {
  JustQuranAudio({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> play({required List<String> urls, required int repeat}) async {
    await _player.stop();
    // repeat <= 0: loop the unit until stopped; otherwise duplicate the
    // concatenated ayah sources so just_audio plays it [repeat] times.
    final infinite = repeat <= 0;
    await _player.setLoopMode(infinite ? LoopMode.all : LoopMode.off);
    final sources = [
      for (var r = 0; r < (infinite ? 1 : repeat); r++)
        for (final url in urls) AudioSource.uri(Uri.parse(url)),
    ];
    await _player.setAudioSources(sources);
    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();

  @override
  Stream<void> get onCompleted => _player.processingStateStream
      .where((state) => state == ProcessingState.completed)
      .map((_) {});
}
