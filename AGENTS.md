# AGENTS.md — инструкции для ИИ-агентов

## Обзор проекта

«Tank Battle» — оригинальная аркадная игра с видом сверху про танки (по духу близка к классическим консольным играм жанра, референс: Battle City (Dendy)). Игрок защищает базу и уничтожает вражеские танки. Движок: Godot 4.7.2, язык: GDScript. Целевые платформы: desktop (разработка), Android (этап 4).

Ассетов-картинок и звука пока нет: графика рисуется процедурно через `_draw()`. Названия и графику существующих коммерческих игр не копируем.

## Структура

```
project.godot            настройки (400x224, canvas_items/keep, gl_compatibility, input map)
scenes/main.tscn         главная сцена (Game > World > Battlefield/Base/Entities, Hud)
scenes/entities/*.tscn   player_tank, enemy_tank, bullet
scenes/fx/explosion.tscn визуальный взрыв
scripts/game/            game.gd (раунд), enemy_spawner.gd
scripts/level/           level_data.gd (парсер уровня), battlefield.gd (сетка, коллизии)
scripts/entities/        tank.gd, player_tank.gd, enemy_tank.gd, tank_stats.gd, bullet.gd, base.gd
scripts/ui/hud.gd        HUD и оверлеи
scripts/fx/explosion.gd  эффект взрыва
data/tanks/*.tres        TankStats по типам танков
levels/level_NN.txt      уровни в текстовом формате
tests/                   unit-тесты (пишутся отдельно)
tools/check.sh           полная проверка
docs/                    PRD, GAME_DESIGN, ARCHITECTURE, ACCEPTANCE_CRITERIA
```

## Архитектурные соглашения

- **Симуляция управляется `Game.step(delta)`** с фиксированным шагом 60 Hz (вызывается из `_physics_process`, пока нет паузы). Тесты вызывают `step()` напрямую, поэтому логика детерминирована. Не используйте физический движок Godot, `RigidBody2D`, `Area2D`, таймеры `Timer`/`await` в игровой логике.
- **Кинематика собственная, на сетке 8 px.** Танк 16x16 (2x2 клетки), пуля 4x4. При повороте на 90° танк прижимается к сетке 8 px.
- **Намерения (intents).** `Tank` содержит общую логику (движение, огонь, урон, отрисовку). Подклассы (`PlayerTank`, `EnemyTank`) только заполняют `move_intent` / `fire_intent` в `_think(delta)`. Для тестов и будущего тач-управления у `PlayerTank` есть `use_keyboard = false`.
- **Типы танков — ресурсы `TankStats`** (`data/tanks/*.tres`): speed, max_hp, fire_cooldown, bullet_speed, bullet_power, max_bullets, цвета. Новый тип врага = новый `.tres` + запись в `Game.ENEMY_TYPES`.
- **Формат уровня — текст** (`levels/*.txt`), разбирается `LevelData.parse()` без зависимости от сцен. Новый уровень = файл + запись в `Game.LEVELS`. Новые типы клеток добавляются в `LevelData.Cell` и `CHAR_TO_CELL`.
- **`Battlefield` отвечает за запросы к сетке:** `blocks_tank`, `blocks_bullet`, `hit_by_bullet`, `contains_cell`, `is_inside`. Координаты — локальные пиксели карты, `(0,0)` — левый верхний угол.
- Взаимодействие между танками (`can_occupy`, `is_area_free`) идёт через `Game`.
- Эффекты (`Explosion`) не часть симуляции и анимируются в `_process`.
- Стиль: GDScript со статической типизацией, `class_name` для скриптов-типов, комментарии только там, где неочевидно «почему».

## Команды проверки

```
bash tools/check.sh                                              # импорт + юнит-тесты + smoke-прогон 900 кадров
godot --headless --path . --import                               # только импорт ресурсов
godot --headless --path . --script res://tests/test_runner.gd    # только юнит-тесты
godot --path .                                                   # запустить игру
godot -e --path .                                                # открыть редактор
```

В песочнице macOS запись в `user://` (~/Library) может блокироваться: ошибки про `user://` в логах безвредны.

## Правила

1. Git: только локальные коммиты (и только по явной просьбе пользователя). Никогда не выполнять `push`, `pull`, `fetch`, не менять remote.
2. Не добавлять новых зависимостей (аддоны, плагины, внешние библиотеки, ассеты со сторонней лицензией).
3. Этапы (см. `TASKS.md`): к следующему этапу переходить только после одобрения пользователя. Не реализовывать функциональность следующих этапов заранее.
4. Документацию (`README.md`, `AGENTS.md`, `TASKS.md`, `PROGRESS.md`, `docs/*`) держать в синхроне с кодом в том же изменении.
5. Не утверждать, что проверка пройдена, если вы её не запускали; указывать реальный вывод. Чекбоксы «проверки» в `TASKS.md` отмечаются только после фактического прогона.
6. Не копировать названия, графику и звуки существующих коммерческих игр.
7. Документация пишется по-русски; идентификаторы, команды и пути — на английском.
