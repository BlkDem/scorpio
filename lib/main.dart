import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'state/game_controller.dart';
import 'state/settings.dart';
import 'state/sfx.dart';
import 'state/stats.dart';
import 'ui/game_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final prefs = await SharedPreferences.getInstance();
  final settings = await Settings.load(prefs);
  final stats = await Stats.load(prefs);
  final sfx = Sfx(settings);
  final controller = GameController(settings: settings, stats: stats, sfx: sfx, prefs: prefs);
  runApp(ScorpionApp(controller: controller, settings: settings, stats: stats));
  // Звуки и партия загружаются после первого кадра — без задержки запуска.
  sfx.init();
  await controller.init();
}

class ScorpionApp extends StatelessWidget {
  final GameController controller;
  final Settings settings;
  final Stats stats;

  const ScorpionApp({super.key, required this.controller, required this.settings, required this.stats});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Скорпион',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: GameScreen(controller: controller, settings: settings, stats: stats),
    );
  }
}
