# Архитектура

## Дерево сцены (`scenes/main.tscn`)

```
Game (Node2D, game.gd)
  World (Node2D, position 96,8)
    Battlefield (Node2D, battlefield.gd)   сетка, коллизии, рисование карты
    Base (Node2D, base.gd)                 состояние и вид базы
    Entities (Node2D)                      танки, пули, взрывы (создаются в рантайме)
  Hud (Control, hud.gd)                    панели и оверлеи
```

Префабы: `scenes/entities/player_tank.tscn`, `enemy_tank.tscn` (с `stats` из `data/tanks/`), `bullet.tscn`, `scenes/fx/explosion.tscn`.

## Скрипты

| Скрипт | Ответственность |
|---|---|
| `scripts/game/game.gd` (`Game`) | раунд: загрузка уровня, спавн танков/пуль, `step(delta)`, жизни, респаун, победа/поражение, ввод pause/restart/confirm. Реестр `LEVELS`, `ENEMY_TYPES`. Статический `current_level` переживает рестарт. |
| `scripts/game/enemy_spawner.gd` (`EnemySpawner`) | когда и в какой точке следующий враг: очередь, таймер, `max_active`, ротация точек. Сам не создаёт танки. |
| `scripts/level/level_data.gd` (`LevelData`) | парсинг и валидация текстового уровня; не зависит от сцен. |
| `scripts/level/battlefield.gd` (`Battlefield`) | запросы к сетке, разрушение кирпича, сигнал `base_hit`, рисование. |
| `scripts/entities/tank.gd` (`Tank`) | общая логика танка: движение, поворот с выравниванием, огонь, урон, отрисовка. |
| `scripts/entities/player_tank.gd` | читает ввод в `_think`; `use_keyboard=false` для тестов/тач. |
| `scripts/entities/enemy_tank.gd` | ИИ (см. GAME_DESIGN.md). |
| `scripts/entities/tank_stats.gd` (`TankStats`) | ресурс параметров типа танка. |
| `scripts/entities/bullet.gd` (`Bullet`) | движение подшагами, коллизии с пулями, танками, картой. |
| `scripts/entities/base.gd` (`Base`) | флаг `is_destroyed`, отрисовка (поражение запускает `Game._on_base_hit` по сигналу `Battlefield.base_hit`). |
| `scripts/ui/hud.gd` (`Hud`) | отрисовка HUD, читает состояние `Game` (`hud.game = self`). |
| `scripts/fx/explosion.gd` (`Explosion`) | визуальный взрыв, живёт 0.3 с, не часть симуляции. |

## Поток данных

1. `Game._ready()` подключает `battlefield.base_hit`, и при `autostart` вызывает `start_level(current_level)`.
2. `start_level` -> `LevelData.load_file` -> `start_level_data`: очистка сущностей, `Battlefield.load_level`, `Base.reset`, `EnemySpawner`, спавн игрока.
3. `_physics_process` (60 Hz) -> `step(delta)`: обновление спавна и респауна -> `tick()` каждого танка -> `tick()` каждой пули. Тесты вызывают `step()` вручную (`autostart=false`, затем `start_level*`).
4. `Tank.tick`: таймеры -> `_think` (заполняет intents) -> поворот и движение -> `try_fire` -> `Game.spawn_bullet`.
5. `Bullet.tick` -> `_check_collisions`: пули противоположной команды, танки (`take_damage`), границы, `Battlefield.hit_by_bullet`.

Сигналы:
- `Tank.destroyed(tank)` -> `Game._on_tank_destroyed` (взрыв, жизни, респаун/конец раунда, счётчик убийств).
- `Battlefield.base_hit` -> `Game._on_base_hit` -> `Base.destroy()` -> поражение.

## Модель коллизий

Собственная, без физического движка. Все объекты — `Rect2` (танк 16x16 с центром в `position`, пуля 4x4).
- Танк: `Game.can_occupy(tank, rect)` = `Battlefield.blocks_tank` (за границей карты или в непустой клетке) и пересечение с другими живыми танками (разрешено, если пересечение уже есть).
- Пуля: `Battlefield.blocks_bullet`/`hit_by_bullet`; обход подшагами 2 px.
- Рёбра, касающиеся границы клетки, не считаются пересечением (EPS = 0.001).
- Выравнивание по сетке 8 px при повороте на 90°.

## Формат уровня

См. README.md (раздел «Формат файла уровня»). Валидация `LevelData`: ровно 26 строк по 26 символов, известные символы и ключи заголовка, один `P`, хотя бы один `E`, непустой список `enemies`, база ровно один блок 2x2, под спавнами свободная область 2x2. Ошибки собираются в `errors`; `Game.start_level` при невалидном файле пишет `push_error` и возвращает `false`.

## Точки расширения

- **Новый тип врага**: создать `data/tanks/<name>.tres` (ресурс `TankStats`), добавить запись в `Game.ENEMY_TYPES`, использовать имя в `enemies=` уровня. Для другого ИИ — подкласс `EnemyTank` и своя сцена.
- **Новый уровень**: файл `levels/level_NN.txt` + запись в `Game.LEVELS`. Для Android — фильтр экспорта `levels/*.txt`.
- **Новые типы клеток**: значение в `LevelData.Cell`, символ в `CHAR_TO_CELL`, обработка в `Battlefield` (`blocks_tank`/`blocks_bullet`/`hit_by_bullet`, `_draw`).
- **Новые виды снарядов**: расширить `Bullet` или добавить поля в `TankStats`; параметр `bullet_power` уже передаётся в `Battlefield.hit_by_bullet`, но пока не используется.
- **Тач-управление**: выставлять `PlayerTank.use_keyboard = false` и заполнять `move_intent`/`fire_intent`.
