import 'package:shared_preferences/shared_preferences.dart';

import '../data/quran_audio.dart' show Reciter;

/// Persisted audio-bar preferences so the user's chosen reciter, playback
/// speed, and repeat count survive app restarts.
///
/// Values are stored in [SharedPreferences] under `audio.*` keys and applied
/// as the defaults when the mushaf viewer opens (and when a fresh unit is
/// created). The active unit's settings still override them mid-session.
class AudioSettings {
  const AudioSettings({
    this.reciter = Reciter.alafasy,
    this.speed = 1.0,
    this.repeat = 3,
  });

  /// Reciter used for new units.
  final Reciter reciter;

  /// Playback speed (0.5x-2x).
  final double speed;

  /// Repeat count (0 = loop until stopped).
  final int repeat;

  static const _kReciter = 'audio.reciter';
  static const _kSpeed = 'audio.speed';
  static const _kRepeat = 'audio.repeat';

  AudioSettings copyWith({Reciter? reciter, double? speed, int? repeat}) {
    return AudioSettings(
      reciter: reciter ?? this.reciter,
      speed: speed ?? this.speed,
      repeat: repeat ?? this.repeat,
    );
  }

  /// Loads the persisted settings, falling back to the defaults when a key
  /// is missing or unreadable.
  static Future<AudioSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AudioSettings(
      reciter: Reciter.values.firstWhere(
        (r) => r.name == prefs.getString(_kReciter),
        orElse: () => Reciter.alafasy,
      ),
      speed: prefs.getDouble(_kSpeed) ?? 1.0,
      repeat: prefs.getInt(_kRepeat) ?? 3,
    );
  }

  /// Persists these settings for the next app launch.
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kReciter, reciter.name);
    await prefs.setDouble(_kSpeed, speed);
    await prefs.setInt(_kRepeat, repeat);
  }
}
