# Лабораторія хімічних дослідів

Навчальна 2D-гра для Windows. Працює перша інтерактивна лабораторія: перетягування, ручне переливання й демонстрація CO2. [Керування та перевірки](docs/LABORATORY.md).

## Середовище

- Точна версія: **Godot 4.7.2 stable**, офіційна збірка `ed1daf0bf`.
- Звичайна версія Godot, GDScript; .NET не потрібен.
- Рендерер: Compatibility. Вікно: 1280 × 720.
- Зовнішніх бібліотек і плагінів немає.

## Запуск

1. Відкрити Godot 4.7.2.
2. У менеджері проєктів вибрати Import і файл `project.godot` із цієї папки.
3. Відкрити проєкт і натиснути F6 для поточної сцени або F5 для всього проєкту.
4. Очікуваний результат: лабораторія з трьома склянками. Перетягнути по 10 мл кожного розчину до приймальної склянки праворуч; очікується 1,000 ммоль CO2.
5. Зупинити запуск клавішею F8 у редакторі.

## Перевірка без графічного вікна

Запустити виконуваний файл Godot із параметрами `--headless --path <повний_шлях_до_проєкту> --editor --import --quit`, а потім `--headless --path <повний_шлях_до_проєкту> --quit-after 10`.
Це перевіряє імпорт і короткий запуск; вигляд екрана потрібно перевірити окремо.

## Windows-експорт

Профіль `Windows Desktop` у `export_presets.cfg` налаштований для Windows x86_64 з вбудованим пакетом ресурсів. Ресурси scripts/scenes і data/*.json включаються профілем; tests, docs і builds виключено.

Потрібні Windows x64 export templates **4.7.2 stable**, що відповідають редактору. У поточному середовищі встановлено debug і release шаблони з офіційного архіву після перевірки SHA512.

Для збірки запустити Godot з параметрами `--headless --path <project> --export-release "Windows Desktop" builds/windows/laboratory.exe` або скористатися Project → Export. Каталог `builds/windows` має існувати. Збірки та `.godot/` виключені з Git.

2026-11-07: release-експорт завершився успішно. Запуск створеного `builds/windows/laboratory.exe` заблоковано системною політикою Windows Application Control. Після зміни налаштування користувачем повторний запуск успішний: exit code 0, OpenGL 3.3 NVIDIA, без помилок у журналі. Вигляд екрана ще не перевірено візуально. Політики безпеки автоматично не змінювалися.

## Документи

- [План](PLAN.md)
- [Прогрес](PROGRESS.md)
- [Правила для агентів](AGENTS.md)

- [Специфікація симулятора](docs/DESIGN.md)

## Тести моделі суміші

З кореня проєкту виконати Godot 4.7.2 з параметрами:

```text
--headless --path . --editor --import --quit
--headless --path . --script res://tests/run_mixture_tests.gd
```

Перший виклик реєструє класи, другий запускає тести. Перевірено: `Mixture tests: 34 checks, 0 failures`, exit code 0. Плагіни не потрібні. Модель підключена до лабораторної сцени.

## Тести каталогу

Після імпорту класів запустити Godot із `--headless --path . --script res://tests/run_catalog_tests.gd`. Перевірено 110 перевірок, 0 помилок. Попередження `Exponent too high` очікуване для навмисно некоректного тестового числа.

Опис формату та обмежень: [CATALOG_SCHEMA.md](docs/CATALOG_SCHEMA.md). JSON у tests/fixtures — тестовий, не готовий каталог гри. Перевірка структури й балансу не замінює перевірку хімічних джерел.

## Тести розрахунку реакцій

Після імпорту класів: `--headless --path . --script res://tests/run_reaction_tests.gd`. Перевірено: `Reaction tests: 54 checks, 0 failures`. Контракт і межі: [REACTION_CALCULATION.md](docs/REACTION_CALCULATION.md). Розрахунок підключено через ReactionEngine; див. docs/LABORATORY.md.


Тести застосування: --headless --path . --script res://tests/run_application_tests.gd. Інтеграційний тест: --headless --path . --script res://tests/run_lab_tests.gd. Для графічного тесту прибрати --headless.
