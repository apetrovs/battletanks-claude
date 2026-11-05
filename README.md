# Tank Battle

Оригинальная аркадная игра с видом сверху про танки (референс по духу: Battle City (Dendy)). Защищайте базу и уничтожьте все вражеские танки уровня. Godot 4.7.2, GDScript.

Текущий статус: этап 1 (MVP-прототип) — один уровень, один тип врага, процедурная графика, без звука. План — в `TASKS.md`, журнал — в `PROGRESS.md`.

## Требования

- Godot 4.7.x (стабильная). На macOS arm64 установлена через Homebrew: `brew install --cask godot`. Исходное задание рассчитано на Linux; команда `godot` одинакова.
- Рендерер: `gl_compatibility`.

## Запуск

```
godot --path .        # запустить игру
godot -e --path .     # открыть редактор
```

## Управление

| Клавиша | Действие |
|---|---|
| WASD / стрелки | движение |
| Space | выстрел |
| Esc | пауза |
| R | рестарт уровня |
| Enter | следующий этап (после победы) / повтор (после поражения) |

## Проверки

```
bash tools/check.sh
```

Скрипт выполняет импорт проекта, headless unit-тесты (`godot --headless --path . --script res://tests/test_runner.gd`) и smoke-прогон 900 кадров в headless-режиме. В песочнице macOS в логах могут быть безвредные ошибки про `user://`.

## Структура проекта

```
project.godot
scenes/        main.tscn, entities/ (player_tank, enemy_tank, bullet), fx/explosion.tscn
scripts/       game/ (game, enemy_spawner), level/ (level_data, battlefield),
               entities/ (tank, player_tank, enemy_tank, tank_stats, bullet, base),
               ui/hud.gd, fx/explosion.gd
data/tanks/    player.tres, enemy_basic.tres
levels/        level_01.txt
tests/         unit-тесты
tools/         check.sh
docs/          PRD.md, GAME_DESIGN.md, ARCHITECTURE.md, ACCEPTANCE_CRITERIA.md
builds/        результаты сборки (содержимое не коммитится)
```

Подробности — в `docs/ARCHITECTURE.md`.

## Формат файла уровня

Текст: заголовок `key=value`, затем строка `map:` и ровно 26 строк по 26 символов (клетка 8 px, карта 208x208 px). Строки, начинающиеся с `;`, и пустые строки в заголовке игнорируются.

Ключи заголовка: `name` (название), `max_active` (максимум одновременно живых врагов, по умолчанию 4, минимум 1), `enemies` (очередь типов через пробел, например `basic basic basic`).

Символы карты:

| Символ | Значение |
|---|---|
| `.` | пусто |
| `#` | кирпич (разрушаемый) |
| `@` | сталь (неразрушаемая) |
| `B` | база, ровно один блок 2x2 |
| `P` | спавн игрока (левая верхняя клетка свободной области 2x2) |
| `E` | точка появления врагов (левая верхняя клетка области 2x2), минимум одна |

Парсер: `LevelData.parse()`; ошибки формата накапливаются в `LevelData.errors`. Пример — `levels/level_01.txt`. Новые уровни нужно добавить в `Game.LEVELS`.

## Сборка под Android

Этап 4, пока не реализовано. Важно: уровни — файлы `.txt`, и Godot не включит их в экспорт автоматически. В пресете экспорта необходимо добавить в фильтр включаемых ресурсов (Resources > Filters to export non-resource files) значение `levels/*.txt`.
