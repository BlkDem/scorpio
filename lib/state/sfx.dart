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

  Future<void> init() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
      );
    } catch (_) {}
    for (final s in Sound.values) {
      try {
        _pools[s] = await AudioPool.create(
          source: AssetSource('sounds/${s.name}.wav'),
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
