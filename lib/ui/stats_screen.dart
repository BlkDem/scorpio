import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/stats.dart';
import 'theme.dart';

/// Цвета графика (проверены на различимость, в т.ч. для дальтоников, на тёмном фоне).
const _winColor = Color(0xFFB38B2E);
const _lossColor = Color(0xFFC25E6B);

class StatsScreen extends StatefulWidget {
  final Stats stats;
  const StatsScreen({super.key, required this.stats});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..forward();

  Stats get s => widget.stats;

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Сбросить статистику?', style: display(21, color: AppColors.goldLight)),
        content: const Text(
          'Все результаты и рекорды будут удалены без возможности восстановления.',
          style: TextStyle(color: AppColors.textDim, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _lossColor, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );
    if (ok == true) {
      s.reset();
      setState(() {});
      _intro.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0E1411),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.9),
            radius: 1.3,
            colors: [Color(0xFF1C2A22), Color(0xFF0E1411)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 12, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
                    ),
                    const SizedBox(width: 4),
                    Text('Статистика', style: display(26, color: AppColors.goldLight)),
                    const Spacer(),
                    if (s.played > 0)
                      IconButton(
                        tooltip: 'Сбросить',
                        onPressed: _reset,
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textFaint),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: s.played == 0 ? _empty() : _content(mq),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.insights_rounded, size: 56, color: AppColors.textFaint),
          const SizedBox(height: 16),
          Text('Пока пусто', style: display(24)),
          const SizedBox(height: 8),
          const Text(
            'Сыграйте первую партию — здесь появятся победы, рекорды и серии.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textDim, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _stagger(int i, Widget child) {
    return AnimatedBuilder(
      animation: _intro,
      builder: (context, c) {
        final t = Curves.easeOutCubic.transform(((_intro.value - i * 0.06) / 0.5).clamp(0, 1));
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: c),
        );
      },
      child: child,
    );
  }

  Widget _content(MediaQueryData mq) {
    final lost = s.played - s.won;
    final tiles = <(String, String, IconData)>[
      ('Текущая серия', '${s.streak}', Icons.local_fire_department_rounded),
      ('Лучшая серия', '${s.bestStreak}', Icons.emoji_events_rounded),
      ('Лучшее время', s.bestSeconds == 0 ? '—' : formatDuration(s.bestSeconds), Icons.timer_rounded),
      ('Среднее время', s.won == 0 ? '—' : formatDuration(s.avgWinSeconds), Icons.av_timer_rounded),
      ('Меньше всего ходов', s.fewestMoves == 0 ? '—' : '${s.fewestMoves}', Icons.trending_down_rounded),
      ('Среднее число ходов', s.won == 0 ? '—' : '${s.avgWinMoves}', Icons.swap_vert_rounded),
      ('Побед без подсказок', '${s.noHintWins}', Icons.psychology_rounded),
      ('Всего в игре', _longDuration(s.totalSeconds), Icons.hourglass_bottom_rounded),
    ];
    final recent = s.history.take(30).toList().reversed.toList();
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + mq.padding.bottom),
      children: [
        _stagger(
          0,
          _Panel(
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _intro,
                  builder: (context, _) => CustomPaint(
                    size: const Size(124, 124),
                    painter: _RingPainter(s.winRate * Curves.easeOutCubic.transform(_intro.value)),
                    child: SizedBox(
                      width: 124,
                      height: 124,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(s.winRate * 100 * Curves.easeOutCubic.transform(_intro.value)).round()}%',
                              style: display(30, color: AppColors.goldLight),
                            ),
                            const Text(
                              'побед',
                              style: TextStyle(fontSize: 11.5, color: AppColors.textFaint, letterSpacing: 0.6),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BigLine(label: 'Сыграно', value: '${s.played}'),
                      const SizedBox(height: 10),
                      _BigLine(label: 'Побед', value: '${s.won}', dot: _winColor),
                      const SizedBox(height: 10),
                      _BigLine(label: 'Поражений', value: '$lost', dot: _lossColor),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _stagger(
          1,
          LayoutBuilder(
            builder: (context, cons) {
              final cols = cons.maxWidth > 520 ? 4 : 2;
              const spacing = 10.0;
              final w = (cons.maxWidth - spacing * (cols - 1)) / cols;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final t in tiles)
                    SizedBox(
                      width: w,
                      child: _Tile(label: t.$1, value: t.$2, icon: t.$3),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        if (recent.isNotEmpty)
          _stagger(
            2,
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Последние партии', style: display(18))),
                      const _LegendDot(color: _winColor, label: 'Победа'),
                      const SizedBox(width: 12),
                      const _LegendDot(color: _lossColor, label: 'Поражение'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Высота столбца — длительность партии. Нажмите на столбец, чтобы увидеть детали.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textFaint),
                  ),
                  const SizedBox(height: 12),
                  _HistoryChart(records: recent, intro: _intro),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (s.history.isNotEmpty)
          _stagger(
            3,
            _Panel(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Журнал', style: display(18)),
                  const SizedBox(height: 6),
                  for (final r in s.history.take(15)) _HistoryRow(r),
                ],
              ),
            ),
          ),
      ],
    );
  }

  static String _longDuration(int seconds) {
    if (seconds < 3600) return '${seconds ~/ 60} мин';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return '$h ч $m мин';
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _Panel({required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF151D19),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: child,
    );
  }
}

class _BigLine extends StatelessWidget {
  final String label;
  final String value;
  final Color? dot;
  const _BigLine({required this.label, required this.value, this.dot});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (dot != null) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(label, style: const TextStyle(color: AppColors.textDim, fontSize: 14)),
        ),
        Text(value, style: display(20)),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _Tile({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151D19),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.gold),
          const SizedBox(height: 8),
          Text(value, style: display(22)),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textFaint, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textDim)),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  _RingPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 8;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = const Color(0x1AFFFFFF),
    );
    if (value <= 0) return;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: math.pi * 1.5,
          colors: const [Color(0xFFB4862C), Color(0xFFFFE6A3), Color(0xFFE9C46A)],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.value != value;
}

/// Столбцы последних партий: высота — время, цвет — исход. Нажатие — детали.
class _HistoryChart extends StatefulWidget {
  final List<GameRecord> records;
  final Animation<double> intro;
  const _HistoryChart({required this.records, required this.intro});

  @override
  State<_HistoryChart> createState() => _HistoryChartState();
}

class _HistoryChartState extends State<_HistoryChart> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final recs = widget.records;
    final sel = _selected != null && _selected! < recs.length ? recs[_selected!] : null;
    return LayoutBuilder(
      builder: (context, cons) {
        const h = 150.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _select(d.localPosition, cons.maxWidth),
              onHorizontalDragUpdate: (d) => _select(d.localPosition, cons.maxWidth),
              child: AnimatedBuilder(
                animation: widget.intro,
                builder: (context, _) => CustomPaint(
                  size: Size(cons.maxWidth, h),
                  painter: _BarsPainter(
                    recs,
                    Curves.easeOutCubic.transform(((widget.intro.value - 0.2) / 0.8).clamp(0, 1)),
                    _selected,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: sel == null
                  ? const SizedBox(height: 20, key: ValueKey(-1))
                  : Row(
                      key: ValueKey(_selected),
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: sel.won ? _winColor : _lossColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${sel.won ? 'Победа' : 'Поражение'} · № ${sel.deal} · ${formatDuration(sel.seconds)} · '
                            '${sel.moves} ${plural(sel.moves, 'ход', 'хода', 'ходов')}',
                            style: const TextStyle(fontSize: 13, color: AppColors.text),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  void _select(Offset p, double width) {
    final n = widget.records.length;
    final slot = _BarsPainter.slotWidth(width, n);
    final i = ((p.dx - _BarsPainter.axisW) / slot).floor();
    if (i >= 0 && i < n && i != _selected) setState(() => _selected = i);
  }
}

class _BarsPainter extends CustomPainter {
  final List<GameRecord> recs;
  final double t;
  final int? selected;

  _BarsPainter(this.recs, this.t, this.selected);

  static const axisW = 34.0;

  static double slotWidth(double width, int n) => (width - axisW) / math.max(n, 12);

  @override
  void paint(Canvas canvas, Size size) {
    final maxSec = recs.fold<int>(60, (m, r) => math.max(m, r.seconds));
    // Шкала по минутам с «круглым» верхом.
    final maxMin = (maxSec / 60).ceil();
    final step = maxMin <= 4 ? 1 : (maxMin <= 10 ? 2 : (maxMin <= 25 ? 5 : 10));
    final top = ((maxMin + step - 1) ~/ step) * step;
    final chartH = size.height - 18;
    final grid = Paint()
      ..color = const Color(0x14FFFFFF)
      ..strokeWidth = 1;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var m = 0; m <= top; m += step) {
      final y = chartH - chartH * m / top;
      canvas.drawLine(Offset(axisW, y), Offset(size.width, y), grid);
      tp.text = TextSpan(
        text: '$m м',
        style: const TextStyle(fontSize: 10, color: AppColors.textFaint),
      );
      tp.layout();
      tp.paint(canvas, Offset(axisW - tp.width - 6, y - tp.height / 2));
    }
    final slot = slotWidth(size.width, recs.length);
    final barW = math.max(3.0, slot - 2);
    for (var i = 0; i < recs.length; i++) {
      final r = recs[i];
      final hgt = math.max(3.0, chartH * (r.seconds / 60) / top * t);
      final x = axisW + i * slot + 1;
      final rect = Rect.fromLTWH(x, chartH - hgt, barW, hgt);
      final color = r.won ? _winColor : _lossColor;
      final dim = selected != null && selected != i;
      canvas.drawRRect(
        RRect.fromRectAndCorners(rect, topLeft: const Radius.circular(4), topRight: const Radius.circular(4)),
        Paint()..color = dim ? color.withValues(alpha: 0.45) : color,
      );
    }
    // Базовая линия.
    canvas.drawLine(
      Offset(axisW, chartH),
      Offset(size.width, chartH),
      Paint()
        ..color = const Color(0x40FFFFFF)
        ..strokeWidth = 1,
    );
    tp.text = const TextSpan(
      text: 'раньше',
      style: TextStyle(fontSize: 10, color: AppColors.textFaint),
    );
    tp.layout();
    tp.paint(canvas, Offset(axisW, chartH + 4));
    tp.text = const TextSpan(
      text: 'недавно',
      style: TextStyle(fontSize: 10, color: AppColors.textFaint),
    );
    tp.layout();
    tp.paint(canvas, Offset(size.width - tp.width, chartH + 4));
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) => old.t != t || old.selected != selected || old.recs != recs;
}

class _HistoryRow extends StatelessWidget {
  final GameRecord r;
  const _HistoryRow(this.r);

  @override
  Widget build(BuildContext context) {
    final d = r.at;
    String two(int v) => v.toString().padLeft(2, '0');
    final date = '${two(d.day)}.${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: (r.won ? _winColor : _lossColor).withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              r.won ? Icons.check_rounded : Icons.close_rounded,
              size: 16,
              color: r.won ? AppColors.goldLight : const Color(0xFFF0A0AA),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.won ? 'Победа' : 'Поражение', style: const TextStyle(fontSize: 14, color: AppColors.text)),
                Text('№ ${r.deal} · $date', style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatDuration(r.seconds),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.text,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '${r.moves} ${plural(r.moves, 'ход', 'хода', 'ходов')}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
