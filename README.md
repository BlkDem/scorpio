# Скорпион

Пасьянс «Скорпион» на Flutter: реалистичные карты, плавные анимации, подсказки с решателем и статистика.

## Запуск

```
flutter pub get
flutter run
```

Сборка APK: `flutter build apk --release`.

Windows: `flutter run -d windows` или `flutter build windows --release` → `build/windows/x64/runner/Release/scorpion.exe` (нужны Visual Studio Build Tools с C++). Запускать нужно exe из папки `Release` целиком: рядом с ним лежат DLL движка и папка `data`.

## Что внутри

- `lib/game/` — правила, раздача по номеру (детерминированный ГПСЧ) и решатель (поиск в глубину с таблицей позиций).
- `lib/state/` — контроллер партии (ходы, отмена, автосбор мастей, сохранение), статистика, настройки, звуки.
- `lib/ui/art/` — карты целиком рисуются кодом: лица, фигуры J/Q/K, рубашки с гильошем и эмблемой.
- `lib/ui/board/` — стол: спрайты карт с 3D-переворотом, тенями, перетаскиванием, подсказками и победным каскадом.
- `lib/ui/` — экран игры, статистика, меню настроек, окно победы.

## Служебное

- Звуки синтезируются скриптом: `dart run tool/gen_sounds.dart`.
- Иконки приложения: `flutter test test/render/icon_render_test.dart --dart-define=ICONS=1`.
- Снимки экранов для проверки вёрстки: `flutter test test/render/game_render_test.dart --dart-define=OUT=<папка>`.
- Шрифты Playfair Display и Libre Baskerville — лицензия SIL OFL (`assets/fonts/`).
