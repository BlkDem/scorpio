import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/settings.dart';
import 'art/card_painter.dart';
import 'theme.dart';

/// Меню «Ещё»: настройки, правила, раскладка по номеру.
class MenuSheet extends StatefulWidget {
  final Settings settings;
  final int dealNumber;
  final VoidCallback onRestart;
  final ValueChanged<int> onDealByNumber;

  const MenuSheet({
    super.key,
    required this.settings,
    required this.dealNumber,
    required this.onRestart,
    required this.onDealByNumber,
  });

  @override
  State<MenuSheet> createState() => _MenuSheetState();
}

class _MenuSheetState extends State<MenuSheet> {
  Settings get s => widget.settings;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.88, maxWidth: 600),
      decoration: const BoxDecoration(
        color: Color(0xFF141B17),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0x40E9C46A))),
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: const Color(0x40FFFFFF), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _ActionTile(
                    icon: Icons.restart_alt_rounded,
                    title: 'Переиграть',
                    subtitle: '№ ${widget.dealNumber}',
                    onTap: widget.onRestart,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionTile(
                    icon: Icons.tag_rounded,
                    title: 'По номеру',
                    subtitle: 'Выбрать раскладку',
                    onTap: _askNumber,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionTile(
                    icon: Icons.menu_book_rounded,
                    title: 'Правила',
                    subtitle: 'Как играть',
                    onTap: () => showRules(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _Section('Рубашка карт'),
            const SizedBox(height: 10),
            SizedBox(
              height: 112,
              child: Row(
                children: [
                  for (var i = 0; i < BackDesign.all.length; i++)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => s.backIndex = i),
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: s.backIndex == i ? AppColors.gold : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: CustomPaint(size: const Size(54, 75.6), painter: _BackPreview(BackDesign.all[i])),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              BackDesign.all[i].name,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: s.backIndex == i ? AppColors.gold : AppColors.textDim,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _Section('Сукно'),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < TableDesign.all.length; i++)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => s.tableIndex = i),
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [TableDesign.all[i].center, TableDesign.all[i].edge]),
                              border: Border.all(
                                color: s.tableIndex == i ? AppColors.gold : const Color(0x30FFFFFF),
                                width: s.tableIndex == i ? 2.5 : 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            TableDesign.all[i].name.split(' ').first,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: s.tableIndex == i ? AppColors.gold : AppColors.textDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            _Section('Игра'),
            _Switch(
              title: 'Только решаемые раскладки',
              subtitle: 'Около 85% случайных раздач «Скорпиона» не решаются. Эта опция даёт только выигрышные.',
              value: s.solvableOnly,
              onChanged: (v) => setState(() => s.solvableOnly = v),
            ),
            _Switch(
              title: 'Ход по нажатию',
              subtitle: 'Нажатие на карту само переносит её на подходящее место',
              value: s.tapToMove,
              onChanged: (v) => setState(() => s.tapToMove = v),
            ),
            _Switch(title: 'Показывать время', value: s.showTimer, onChanged: (v) => setState(() => s.showTimer = v)),
            const SizedBox(height: 8),
            _Section('Звук и отклик'),
            _Switch(title: 'Звуки', value: s.sound, onChanged: (v) => setState(() => s.sound = v)),
            _Switch(title: 'Вибрация', value: s.haptics, onChanged: (v) => setState(() => s.haptics = v)),
          ],
        ),
      ),
    );
  }

  Future<void> _askNumber() async {
    final ctrl = TextEditingController();
    final n = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Раскладка по номеру', style: display(21, color: AppColors.goldLight)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          decoration: const InputDecoration(hintText: '1 – 999999'),
          onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.ink),
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)),
            child: const Text('Играть'),
          ),
        ],
      ),
    );
    if (n != null && n > 0) widget.onDealByNumber(n);
  }
}

class _BackPreview extends CustomPainter {
  final BackDesign d;
  _BackPreview(this.d);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius((Offset.zero & size).shift(const Offset(0, 1.5)), const Radius.circular(4)),
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    CardPainterKit.paintBack(canvas, size, d);
  }

  @override
  bool shouldRepaint(covariant _BackPreview old) => old.d != d;
}

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(color: AppColors.gold, fontSize: 11.5, letterSpacing: 1.6, fontWeight: FontWeight.w600),
    ),
  );
}

class _Switch extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _Switch({required this.title, this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, color: AppColors.text)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.textFaint, height: 1.3)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1C2520),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: AppColors.gold, size: 24),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.text),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.textFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showRules(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Правила «Скорпиона»', style: display(24, color: AppColors.goldLight)),
              const SizedBox(height: 14),
              const Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    'Цель — собрать в колонках все четыре масти по порядку от короля до туза. '
                    'Собранная масть сама уходит в «дом».\n\n'
                    'Раздача. Колода в 52 карты раскладывается в 7 колонок по 7 карт. В первых четырёх '
                    'колонках по три нижние карты лежат рубашкой вверх. Оставшиеся три карты — резерв.\n\n'
                    'Ходы. Любую открытую карту можно переложить на карту той же масти на единицу старше '
                    '(например, 7♥ на 8♥). Вместе с ней переезжают все карты, лежащие поверх, — даже если '
                    'они не по порядку.\n\n'
                    'Пустая колонка. На освободившееся место можно положить только короля (со всем, что на нём лежит).\n\n'
                    'Резерв. В любой момент можно раздать три карты резерва — по одной на первые три колонки. '
                    'Это можно сделать только один раз.\n\n'
                    'Закрытые карты открываются, как только с них уходят все карты.\n\n'
                    'Управление. Перетаскивайте карты пальцем или просто нажмите на карту — она сама отправится '
                    'на подходящее место. «Подсказка» ищет ход, ведущий к победе, и показывает его на столе.',
                    style: TextStyle(color: AppColors.textDim, height: 1.5, fontSize: 14.5),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Понятно')),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
