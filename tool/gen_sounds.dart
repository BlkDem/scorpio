// Синтез звуковых эффектов пасьянса. Запуск: dart run tool/gen_sounds.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const sr = 44100;
final rnd = math.Random(7);

Float64List buf(double seconds) => Float64List((seconds * sr).round());

double noise() => rnd.nextDouble() * 2 - 1;

/// Однополюсные фильтры.
class Lp {
  double a, y = 0;
  Lp(double cutoff) : a = 1 - math.exp(-2 * math.pi * cutoff / sr);
  double f(double x) => y += a * (x - y);
}

class Hp {
  final Lp lp;
  Hp(double cutoff) : lp = Lp(cutoff);
  double f(double x) => x - lp.f(x);
}

void addNoiseBurst(
  Float64List b,
  int start,
  double dur,
  double amp, {
  double lo = 300,
  double hi = 6000,
  double attack = 0.002,
  double decay = 0.03,
}) {
  final hp = Hp(lo);
  final lp = Lp(hi);
  final n = (dur * sr).round();
  for (var i = 0; i < n && start + i < b.length; i++) {
    final t = i / sr;
    final env = (t < attack ? t / attack : 1.0) * math.exp(-(t - attack).clamp(0, 99) / decay);
    b[start + i] += lp.f(hp.f(noise())) * amp * env;
  }
}

void addTone(
  Float64List b,
  int start,
  double dur,
  double freq,
  double amp, {
  double attack = 0.004,
  double decay = 0.3,
  double bend = 0,
  List<double> harmonics = const [1],
}) {
  final n = (dur * sr).round();
  var phase = 0.0;
  for (var i = 0; i < n && start + i < b.length; i++) {
    final t = i / sr;
    final f = freq * (1 + bend * t);
    phase += 2 * math.pi * f / sr;
    final env = (t < attack ? t / attack : 1.0) * math.exp(-t / decay);
    var v = 0.0;
    for (var h = 0; h < harmonics.length; h++) {
      v += math.sin(phase * (h + 1) * (h == 0 ? 1 : 1.0 + h * 0.002)) * harmonics[h];
    }
    b[start + i] += v * amp * env;
  }
}

void write(String name, Float64List b, {double gain = 1}) {
  var peak = 0.0;
  for (final v in b) {
    peak = math.max(peak, v.abs());
  }
  final norm = peak == 0 ? 1.0 : 0.89 / peak * gain;
  final data = ByteData(44 + b.length * 2);
  void str(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  data.setUint32(4, 36 + b.length * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sr, Endian.little);
  data.setUint32(28, sr * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, b.length * 2, Endian.little);
  for (var i = 0; i < b.length; i++) {
    // Мягкое затухание в конце, чтобы не щёлкало.
    final tail = math.min(1.0, (b.length - i) / (sr * 0.005));
    data.setInt16(44 + i * 2, (b[i] * norm * tail * 32767).round().clamp(-32768, 32767), Endian.little);
  }
  File('assets/sounds/$name.wav').writeAsBytesSync(data.buffer.asUint8List());
  stdout.writeln('$name.wav  ${(b.length / sr * 1000).round()} ms');
}

void main() {
  Directory('assets/sounds').createSync(recursive: true);

  // Карта ложится на сукно: мягкий «тук» + шорох бумаги.
  {
    final b = buf(0.16);
    addNoiseBurst(b, 0, 0.12, 0.8, lo: 500, hi: 5200, attack: 0.001, decay: 0.018);
    addTone(b, 0, 0.08, 150, 0.35, attack: 0.001, decay: 0.02, bend: -1.5);
    write('place', b, gain: 0.75);
  }

  // Скольжение карты.
  {
    final b = buf(0.22);
    addNoiseBurst(b, 0, 0.2, 0.6, lo: 1400, hi: 7000, attack: 0.03, decay: 0.05);
    addNoiseBurst(b, (0.12 * sr).round(), 0.08, 0.5, lo: 600, hi: 4000, attack: 0.001, decay: 0.015);
    write('slide', b, gain: 0.6);
  }

  // Переворот карты: щелчок.
  {
    final b = buf(0.1);
    addNoiseBurst(b, 0, 0.06, 1.0, lo: 1800, hi: 9000, attack: 0.0005, decay: 0.008);
    addNoiseBurst(b, (0.018 * sr).round(), 0.05, 0.5, lo: 900, hi: 5000, attack: 0.0005, decay: 0.01);
    write('flip', b, gain: 0.55);
  }

  // Перетасовка (рифл).
  {
    final b = buf(0.9);
    for (var i = 0; i < 46; i++) {
      final t = 0.05 + 0.7 * (i / 46) + rnd.nextDouble() * 0.01;
      addNoiseBurst(
        b,
        (t * sr).round(),
        0.03,
        0.4 + rnd.nextDouble() * 0.4,
        lo: 1500,
        hi: 8000,
        attack: 0.0005,
        decay: 0.004,
      );
    }
    addNoiseBurst(b, (0.78 * sr).round(), 0.1, 0.9, lo: 400, hi: 4000, attack: 0.001, decay: 0.02);
    write('shuffle', b, gain: 0.6);
  }

  // Ошибка: глухой удар.
  {
    final b = buf(0.14);
    addTone(b, 0, 0.14, 190, 0.8, attack: 0.002, decay: 0.035, bend: -1.2, harmonics: [1, 0.3]);
    addNoiseBurst(b, 0, 0.04, 0.2, lo: 200, hi: 1500, decay: 0.01);
    write('error', b, gain: 0.5);
  }

  // Собрана масть: колокольчик.
  {
    final b = buf(1.1);
    const bell = [1.0, 0.0, 0.45, 0.0, 0.2, 0.0, 0.08];
    addTone(b, 0, 1.1, 1046.5, 0.5, decay: 0.35, harmonics: bell);
    addTone(b, (0.09 * sr).round(), 1.0, 1318.5, 0.45, decay: 0.35, harmonics: bell);
    addTone(b, (0.18 * sr).round(), 0.9, 1568.0, 0.4, decay: 0.4, harmonics: bell);
    write('collect', b, gain: 0.5);
  }

  // Подсказка: мягкий «динь».
  {
    final b = buf(0.7);
    addTone(b, 0, 0.7, 1760, 0.5, decay: 0.18, harmonics: [1, 0, 0.3]);
    addTone(b, (0.07 * sr).round(), 0.6, 2349.3, 0.3, decay: 0.15, harmonics: [1, 0, 0.2]);
    write('hint', b, gain: 0.35);
  }

  // Победа: арпеджио с переливом.
  {
    final b = buf(2.6);
    const notes = [523.25, 659.25, 783.99, 1046.5, 1318.5, 1568.0, 2093.0];
    const bell = [1.0, 0.35, 0.25, 0.1, 0.05];
    for (var i = 0; i < notes.length; i++) {
      addTone(b, (i * 0.11 * sr).round(), 2.0, notes[i], 0.5, decay: 0.6, harmonics: bell);
    }
    for (var i = 0; i < 3; i++) {
      addTone(b, ((0.9 + i * 0.02) * sr).round(), 1.6, [1046.5, 1318.5, 1568.0][i], 0.45, decay: 0.8, harmonics: bell);
    }
    write('win', b, gain: 0.55);
  }
}
