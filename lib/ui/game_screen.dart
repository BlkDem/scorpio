import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/cards.dart';
import '../state/game_controller.dart';
import '../state/settings.dart';
import '../state/stats.dart';
import 'board/board_view.dart';
import 'board/layout.dart';
import 'felt.dart';
import 'settings_sheet.dart';
import 'stats_screen.dart';
import 'theme.dart';
import 'win_overlay.dart';

class GameScreen extends StatefulWidget {
  final GameController controller;
  final Settings settings;
  final Stats stats;

  const GameScreen({super.key, required this.controller, required this.settings, required this.stats});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  final _layout = ValueNotifier<BoardLayout?>(null);
  String? _toast;
  int _toastId = 0;
  bool _showWin = false;
  bool _winScheduled = false;

  GameController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c.addListener(_onChange);
    widget.settings.addListener(_onChange);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.removeListener(_onChange);
    widget.settings.removeListener(_onChange);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      c.resumeClock();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      c.pauseClock();
    }
  }

  void _onChange() {
    if (!mounted) return;
    if (c.won && !_winScheduled && c.lastRecord != null && c.event.kind == ChangeKind.collect) {
      // Окно победы появится после салюта.
      _winScheduled = true;
      Future.delayed(const Duration(milliseconds: 2600), () {
        if (mounted && c.won) setState(() => _showWin = true);
      });
    }
    if (!c.won) {
      _showWin = false;
      _winScheduled = false;
    }
    setState(() {});
  }

  void toast(String text) {
    final id = ++_toastId;
    setState(() => _toast = text);
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (mounted && _toastId == id) setState(() => _toast = null);
    });
  }

  // ---------------------------------------------------------------- Действия

  Future<void> _newGame() async {
    if (c.started && !c.won) {
      final ok = await _confirm('Новая партия', 'Текущая партия будет засчитана как поражение.', 'Начать');
      if (ok != true) return;
    }
    setState(() => _showWin = false);
    await c.newGame();
  }

  Future<void> _restart() async {
    if (c.started && !c.won) {
      final ok = await _confirm(
        'Переиграть раскладку',
        'Начать эту же раскладку заново? Текущая попытка будет засчитана как поражение.',
        'Переиграть',
      );
      if (ok != true) return;
    }
    setState(() => _showWin = false);
    c.restart();
  }

  Future<void> _hint() async {
    if (c.won) return;
    final h = await c.hint();
    if (h == null || !mounted) return;
    if (h.kind == HintKind.noMoves) {
      toast('Ходов больше нет — отмените ход или начните заново');
    } else if (h.winnable == false) {
      toast('Эта позиция уже не решается. Попробуйте отменить ходы');
    } else if (h.kind == HintKind.deal) {
      toast('Раздайте три карты из резерва');
    } else if (h.move != null) {
      final m = h.move!;
      final card = c.state.columns[m.from][m.index];
      final dst = c.state.columns[m.to];
      final where = dst.isEmpty ? 'в пустую колонку' : 'на ${cardLabel(dst.last)}';
      toast('${cardLabel(card)} → $where');
    }
  }

  Future<bool?> _confirm(String title, String text, String action) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: display(22, color: AppColors.goldLight)),
        content: Text(text, style: const TextStyle(color: AppColors.textDim, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.ink),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  void _openStats() {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, a, _) => StatsScreen(stats: widget.stats),
        transitionsBuilder: (_, a, _, child) {
          final curved = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _openMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => MenuSheet(
        settings: widget.settings,
        dealNumber: c.dealNumber,
        onRestart: () {
          Navigator.pop(ctx);
          _restart();
        },
        onDealByNumber: (n) {
          Navigator.pop(ctx);
          _playNumber(n);
        },
      ),
    );
  }

  Future<void> _playNumber(int n) async {
    if (c.started && !c.won) {
      final ok = await _confirm('Раскладка № $n', 'Текущая партия будет засчитана как поражение.', 'Играть');
      if (ok != true) return;
    }
    setState(() => _showWin = false);
    await c.newGame(seed: n);
  }

  // ---------------------------------------------------------------- Построение

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final pad = mq.padding;
    final wideScreen = mq.size.width > mq.size.height * 1.25;
    final toolbarH = wideScreen ? 56.0 : 66.0;
    final insets = EdgeInsets.only(
      top: pad.top + 4,
      bottom: pad.bottom + toolbarH + 4,
      left: pad.left,
      right: pad.right,
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFF0B100D),
      ),
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: FeltBackground(design: widget.settings.table)),
            Positioned.fill(
              child: BoardView(controller: c, settings: widget.settings, insets: insets, layoutOut: _layout),
            ),
            ValueListenableBuilder<BoardLayout?>(
              valueListenable: _layout,
              builder: (context, l, _) {
                if (l == null) return const Positioned(left: 0, top: 0, width: 0, height: 0, child: SizedBox());
                return Positioned.fromRect(
                  rect: l.infoRect,
                  child: IgnorePointer(
                    child: _InfoPanel(c: c, settings: widget.settings, wide: l.wide),
                  ),
                );
              },
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _Toolbar(
                height: toolbarH,
                bottomPad: pad.bottom,
                canUndo: c.canUndo,
                hintBusy: c.hintBusy,
                onNew: _newGame,
                onUndo: c.undo,
                onHint: _hint,
                onStats: _openStats,
                onMenu: _openMenu,
              ),
            ),
            // Нет ходов.
            if (c.isStuck && !c.preparing)
              Positioned(
                left: 16,
                right: 16,
                bottom: pad.bottom + toolbarH + 20,
                child: _StuckBanner(canUndo: c.canUndo, onUndo: c.undo, onRestart: _restart, onNew: _newGame),
              ),
            // Подготовка раскладки.
            if (c.preparing)
              const Positioned.fill(
                child: IgnorePointer(
                  child: Center(child: _Pill(text: 'Тасуем колоду…', spinner: true)),
                ),
              ),
            // Всплывающее сообщение.
            Positioned(
              left: 24,
              right: 24,
              bottom: pad.bottom + toolbarH + 16,
              child: IgnorePointer(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(a),
                      child: child,
                    ),
                  ),
                  child: _toast == null || c.isStuck
                      ? const SizedBox.shrink()
                      : Center(
                          key: ValueKey(_toastId),
                          child: _Pill(text: _toast!),
                        ),
                ),
              ),
            ),
            if (_showWin && c.lastRecord != null)
              Positioned.fill(
                child: WinOverlay(
                  record: c.lastRecord!,
                  news: c.lastNews,
                  stats: widget.stats,
                  onNewGame: () {
                    setState(() => _showWin = false);
                    c.newGame();
                  },
                  onStats: _openStats,
                  onClose: () => setState(() => _showWin = false),
                ),
              ),
            if (c.won && !_showWin && c.lastRecord != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: pad.bottom + toolbarH + 24,
                child: Center(
                  child: GoldButton(label: 'Новая партия', icon: Icons.replay_rounded, onPressed: () => c.newGame()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoPanel extends StatefulWidget {
  final GameController c;
  final Settings settings;
  final bool wide;
  const _InfoPanel({required this.c, required this.settings, required this.wide});

  @override
  State<_InfoPanel> createState() => _InfoPanelState();
}

/// Время и ходы; обновляется сам, не перестраивая весь экран.
class _InfoPanelState extends State<_InfoPanel> {
  Timer? _timer;

  GameController get c => widget.c;
  Settings get settings => widget.settings;
  bool get wide => widget.wide;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (c.started && !c.won && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cons) {
        final k = (cons.maxHeight / 80).clamp(0.7, 1.6);
        final moves = c.moves;
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: wide ? Alignment.topCenter : Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (settings.showTimer)
                Text(
                  formatDuration(c.elapsedSeconds),
                  style: display(24 * k, color: AppColors.goldLight).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    shadows: const [Shadow(color: Color(0x88000000), blurRadius: 6, offset: Offset(0, 2))],
                  ),
                ),
              SizedBox(height: 3 * k),
              Text(
                '$moves ${plural(moves, 'ход', 'хода', 'ходов')}',
                style: TextStyle(
                  fontSize: 12.5 * k,
                  color: AppColors.textDim,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
              SizedBox(height: 2 * k),
              Text(
                '№ ${c.dealNumber}',
                style: TextStyle(fontSize: 10.5 * k, color: AppColors.textFaint, letterSpacing: 0.8),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Toolbar extends StatelessWidget {
  final double height;
  final double bottomPad;
  final bool canUndo;
  final bool hintBusy;
  final VoidCallback onNew;
  final VoidCallback onUndo;
  final VoidCallback onHint;
  final VoidCallback onStats;
  final VoidCallback onMenu;

  const _Toolbar({
    required this.height,
    required this.bottomPad,
    required this.canUndo,
    required this.hintBusy,
    required this.onNew,
    required this.onUndo,
    required this.onHint,
    required this.onStats,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height + bottomPad,
      padding: EdgeInsets.only(bottom: bottomPad),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xB3060A08), Color(0xF2060A08)],
          stops: [0, 0.35, 1],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Row(
            children: [
              _ToolButton(icon: Icons.style_rounded, label: 'Новая', onTap: onNew),
              _ToolButton(icon: Icons.undo_rounded, label: 'Отмена', onTap: canUndo ? onUndo : null),
              _ToolButton(
                icon: Icons.lightbulb_outline_rounded,
                label: 'Подсказка',
                onTap: onHint,
                busy: hintBusy,
                accent: true,
              ),
              _ToolButton(icon: Icons.insights_rounded, label: 'Статистика', onTap: onStats),
              _ToolButton(icon: Icons.tune_rounded, label: 'Ещё', onTap: onMenu),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  final bool accent;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.busy = false,
    this.accent = false,
  });

  @override
  State<_ToolButton> createState() => _ToolButtonState();
}

class _ToolButtonState extends State<_ToolButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final color = !enabled ? AppColors.textFaint : (widget.accent ? AppColors.gold : AppColors.text);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: enabled
            ? (_) {
                setState(() => _down = false);
                widget.onTap!();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? 0.88 : 1,
          duration: const Duration(milliseconds: 120),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 26,
                child: widget.busy
                    ? const Padding(
                        padding: EdgeInsets.all(3),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                        ),
                      )
                    : Icon(widget.icon, color: color, size: 25),
              ),
              const SizedBox(height: 3),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500, letterSpacing: 0.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final bool spinner;
  const _Pill({required this.text, this.spinner = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xE6101613),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0x40E9C46A)),
        boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (spinner) ...[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _StuckBanner extends StatelessWidget {
  final bool canUndo;
  final VoidCallback onUndo;
  final VoidCallback onRestart;
  final VoidCallback onNew;

  const _StuckBanner({required this.canUndo, required this.onUndo, required this.onRestart, required this.onNew});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0, 1),
        child: Transform.translate(offset: Offset(0, 30 * (1 - v)), child: child),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: BoxDecoration(
              color: const Color(0xF0121815),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0x40E9C46A)),
              boxShadow: const [BoxShadow(color: Color(0xA0000000), blurRadius: 30, offset: Offset(0, 10))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Ходов больше нет', style: display(21, color: AppColors.goldLight)),
                const SizedBox(height: 6),
                const Text(
                  'Отмените несколько ходов или попробуйте снова.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textDim, fontSize: 13.5),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    if (canUndo)
                      GoldButton(label: 'Отменить', icon: Icons.undo_rounded, onPressed: onUndo, filled: false),
                    GoldButton(label: 'Заново', icon: Icons.restart_alt_rounded, onPressed: onRestart, filled: false),
                    GoldButton(label: 'Новая', icon: Icons.style_rounded, onPressed: onNew),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
