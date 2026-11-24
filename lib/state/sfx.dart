import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'settings.dart';

enum Sound { place, slide, flip, shuffle, error, collect, hint, win }

/// Звуковые эффекты и тактильный отклик.
class Sfx {
  final Settings settings;
  final Map<Sound, AudioPool> _pools = {};
  final Map<Sound, int> _last = {};

  Sfx(this.settings);

  /// Звуки игры не должны глушить чужую музыку (Spotify и т. п.):
  /// на Android — без запроса аудиофокуса, на iOS — категория ambient
  /// (смешивается с другими и уважает беззвучный режим).
  /// Контекст задаётся каждому плееру: плееры пула иначе берут стандартный,
  /// который запрашивает фокус и ставит музыку на паузу.
  static final AudioContext _context = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  );

  Future<void> init() async {
    try {
      await AudioPlayer.global.setAudioContext(_context);
    } catch (_) {}
    for (final s in Sound.values) {
      try {
        _pools[s] = await AudioPool.create(
          source: await _source(s),
          audioContext: _context,
          maxPlayers: switch (s) {
            Sound.place || Sound.slide || Sound.flip => 4,
            _ => 2,
          },
        );
      } catch (e) {
        debugPrint('Sfx: не удалось загрузить ${s.name}: $e');
      }
    }
  }

  static Future<Source> _source(Sound s) async {
    final path = 'sounds/${s.name}.wav';
    if (!kIsWeb) return AssetSource(path);
    // Веб-сервер может отдавать .wav как application/octet-stream (в mime.types
    // nginx нет wav), а Firefox и Safari такой звук не играют. Передаём байты
    // с явным типом.
    final data = await rootBundle.load('assets/$path');
    return BytesSource(data.buffer.asUint8List(), mimeType: 'audio/wav');
  }

  void play(Sound s, {double volume = 1}) {
    if (!settings.sound) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    // Не допускаем «пулемёта» одинаковых звуков.
    if (now - (_last[s] ?? 0) < 45) return;
    _last[s] = now;
    final pool = _pools[s];
    if (pool == null) return;
    pool.start(volume: volume).catchError((_) => () async {});
  }

  void tick() {
    if (settings.haptics) HapticFeedback.selectionClick();
  }

  void light() {
    if (settings.haptics) HapticFeedback.lightImpact();
  }

  void medium() {
    if (settings.haptics) HapticFeedback.mediumImpact();
  }

  void heavy() {
    if (settings.haptics) HapticFeedback.heavyImpact();
  }
}
