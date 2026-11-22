import 'package:flutter/material.dart';

class AppColors {
  static const gold = Color(0xFFE9C46A);
  static const goldLight = Color(0xFFFFE6A3);
  static const goldDark = Color(0xFFB48A2C);
  static const ink = Color(0xFF0D1210);
  static const panel = Color(0xF0141A17);
  static const panelLight = Color(0xFF1E2622);
  static const text = Color(0xFFF4EFE3);
  static const textDim = Color(0xB3F4EFE3);
  static const textFaint = Color(0x66F4EFE3);
  static const win = Color(0xFF8CF5B0);
  static const loss = Color(0xFFE5737F);
}

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.gold,
      brightness: Brightness.dark,
      primary: AppColors.gold,
      surface: const Color(0xFF151B18),
    ),
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.ink,
    textTheme: base.textTheme.apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.ink : AppColors.textDim,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.gold : const Color(0x33FFFFFF),
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF18201C)),
  );
}

TextStyle display(
  double size, {
  Color color = AppColors.text,
  FontWeight weight = FontWeight.w700,
  double spacing = 0,
}) => TextStyle(
  fontFamily: 'Playfair',
  fontSize: size,
  color: color,
  fontWeight: weight,
  fontVariations: [FontVariation('wght', weight.value.toDouble())],
  letterSpacing: spacing,
  height: 1.1,
);

String formatDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// Склонение: 1 ход, 2 хода, 5 ходов.
String plural(int n, String one, String few, String many) {
  final m10 = n % 10;
  final m100 = n % 100;
  if (m10 == 1 && m100 != 11) return one;
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return few;
  return many;
}

/// Золотая кнопка.
class GoldButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final bool filled;

  const GoldButton({super.key, required this.label, required this.onPressed, this.icon, this.filled = true});

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      ],
    );
    if (!filled) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.gold,
          side: const BorderSide(color: Color(0x80E9C46A)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: child,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE29A), Color(0xFFE2B04A), Color(0xFFC08F2E)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF2A1E05),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: child,
      ),
    );
  }
}
