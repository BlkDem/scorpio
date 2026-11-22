import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/stats.dart';
import 'theme.dart';

/// Окно победы.
class WinOverlay extends StatefulWidget {
  final GameRecord record;
  final RecordNews? news;
  final Stats stats;
  final VoidCallback onNewGame;
  final VoidCallback onStats;
  final VoidCallback onClose;

  const WinOverlay({
    super.key,
    required this.record,
    required this.news,
    required this.stats,
    required this.onNewGame,
    required this.onStats,
    required this.onClose,
  });

  @override
  State<WinOverlay> createState() => _WinOverlayState();
}

class _WinOverlayState extends State<WinOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final n = widget.news;
    final badges = <String>[
      if (n?.bestTime ?? false) 'Рекорд времени!',
      if (n?.fewestMoves ?? false) 'Меньше всего ходов!',
      if (n?.bestStreak ?? false) 'Лучшая серия: ${widget.stats.bestStreak}',
      if (r.hints == 0) 'Без подсказок',
    ];
    return AnimatedBuilder(
      animation: _a,
      builder: (context, _) {
        final t = _a.value;
        final pop = Curves.easeOutBack.transform(((t - 0.1) / 0.9).clamp(0, 1));
        return GestureDetector(
          onTap: widget.onClose,
          child: Container(
            color: Color.fromRGBO(0, 0, 0, 0.45 * Curves.easeOut.transform(t)),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(24),
            child: GestureDetector(
              onTap: () {},
              child: Opacity(
                opacity: pop.clamp(0, 1),
                child: Transform.scale(
                  scale: 0.85 + 0.15 * pop,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF1F2A24), Color(0xFF111714)],
                        ),
                        border: Border.all(color: const Color(0x66E9C46A), width: 1.2),
                        boxShadow: const [BoxShadow(color: Color(0xB0000000), blurRadius: 40, offset: Offset(0, 16))],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Laurel(t: t),
                          const SizedBox(height: 6),
                          ShaderMask(
                            shaderCallback: (b) => const LinearGradient(
                              colors: [Color(0xFFFFF1C4), Color(0xFFE9C46A), Color(0xFFB4862C)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ).createShader(b),
                            child: Text(
                              'Победа!',
                              style: display(44, color: Colors.white, weight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Раскладка № ${r.deal}',
                            style: const TextStyle(color: AppColors.textFaint, fontSize: 13, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              _Metric(label: 'Время', value: formatDuration(r.seconds)),
                              _Metric(label: 'Ходы', value: '${r.moves}'),
                              _Metric(label: 'Подсказки', value: '${r.hints}'),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _Metric(label: 'Побед', value: '${widget.stats.won}', small: true),
                              _Metric(label: 'Процент', value: '${(widget.stats.winRate * 100).round()}%', small: true),
                              _Metric(label: 'Серия', value: '${widget.stats.streak}', small: true),
                            ],
                          ),
                          if (badges.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              alignment: WrapAlignment.center,
                              children: [
                                for (final b in badges)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0x26E9C46A),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: const Color(0x55E9C46A)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star_rounded, size: 14, color: AppColors.gold),
                                        const SizedBox(width: 4),
                                        Text(
                                          b,
                                          style: const TextStyle(
                                            color: AppColors.goldLight,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: GoldButton(label: 'Статистика', onPressed: widget.onStats, filled: false),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: GoldButton(label: 'Новая партия', onPressed: widget.onNewGame),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final bool small;
  const _Metric({required this.label, required this.value, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: display(small ? 19 : 26, color: small ? AppColors.text : AppColors.goldLight)),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: const TextStyle(fontSize: 10, color: AppColors.textFaint, letterSpacing: 1.2),
          ),
        ],
      ),
    );
  }
}

/// Лавровый венок со звездой.
class _Laurel extends StatelessWidget {
  final double t;
  const _Laurel({required this.t});

  @override
  Widget build(BuildContext context) => CustomPaint(size: const Size(120, 56), painter: _LaurelPainter(t));
}

class _LaurelPainter extends CustomPainter {
  final double t;
  _LaurelPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(colors: [Color(0xFFFFE9A8), Color(0xFFC9972F)]).createShader(Offset.zero & size);
    final cx = size.width / 2;
    final center = Offset(cx, size.height * 0.48);
    const radius = 25.0;
    final grow = Curves.easeOut.transform(t.clamp(0, 1));
    final stem = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..shader = paint.shader;
    for (final side in [-1.0, 1.0]) {
      // Ветвь венка: от низа вверх по дуге, листья по касательной.
      const from = 0.45;
      const to = 2.75;
      final end = from + (to - from) * grow;
      final branch = Path();
      for (var k = 0; k <= 20; k++) {
        final phi = from + (end - from) * k / 20;
        final p = center + Offset(side * math.sin(phi), math.cos(phi)) * radius;
        if (k == 0) {
          branch.moveTo(p.dx, p.dy);
        } else {
          branch.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(branch, stem);
      const leaves = 8;
      for (var i = 0; i < leaves; i++) {
        final phi = from + (to - from) * (i + 0.5) / leaves;
        if (phi > end) break;
        final base = center + Offset(side * math.sin(phi), math.cos(phi)) * radius;
        final tangent = math.atan2(-math.sin(phi), side * math.cos(phi));
        for (final out in [-1.0, 1.0]) {
          canvas.save();
          canvas.translate(base.dx, base.dy);
          canvas.rotate(tangent + out * side * 0.75);
          final size = 1 - i / leaves * 0.35;
          canvas.drawOval(Rect.fromCenter(center: Offset(5.5 * size, 0), width: 11 * size, height: 4.6 * size), paint);
          canvas.restore();
        }
      }
    }
    // Звезда.
    final s = Curves.elasticOut.transform(((t - 0.3) / 0.7).clamp(0, 1));
    if (s > 0) {
      final path = Path();
      final c = center;
      for (var i = 0; i < 10; i++) {
        final r = (i.isEven ? 15.0 : 6.5) * s;
        final a = -math.pi / 2 + i * math.pi / 5;
        final p = c + Offset(math.cos(a), math.sin(a)) * r;
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0x66FFD36E)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LaurelPainter old) => old.t != t;
}
