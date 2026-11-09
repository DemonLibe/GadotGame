# Hope Light

Хоррор от первого лица на Godot 4.3+ (GDScript).

Ты обходчик глухой станции метро «Тихая». Каждую смену — сто метров вниз по скобяной лестнице,
генератор, фильтры, паутина и поручения диспетчера по рации. Платят втрое: дочери Маше нужна операция.
Только с каждой ночью яснее, что в тоннеле ты не один, а в правой стене у ПК 2 есть пролом
в другую «Тихую» — дореволюционную, которой нет на схемах.

Игра всегда сложная, и с каждой сменой сложнее. Стиль — низкое разрешение, дизеринг, урезанная палитра, зерно.

## Скачать

Сборки для **Windows, Linux и macOS**: **https://github.com/DemonLibe/GadotGame/releases/latest**

## Запуск из исходников

1. Установи [Godot 4.3](https://godotengine.org/download) или новее (обычную, не .NET).
2. **Import** → `project.godot` → **F5**.

Для объёмного тумана на ПК переключи рендер на Forward+ (Project Settings → Rendering → Renderer).

## Управление

| Клавиша | Действие |
|---|---|
| WASD, мышь | идти, смотреть |
| Shift / C | бежать (громко) / присесть (тихо) |
| Space | прыжок; в шкафу — задержать дыхание |
| E | действие (удерживать — люк, фильтр, задвижка, вагонетка) |
| R | крутить ручку динамо фонаря (треск слышно) |
| G | бросить болт — отвлечь |
| F | налобный фонарь |
| 1–7, колесо | предмет в руках: горелка, фильтр, батарейка, рация, карта, пистолет, канистра |
| ЛКМ | использовать предмет (рация — подсказка или доклад) |
| Tab | весь список дел |
| Esc | пауза |

## Как играть

- **Смена** закрывается, когда всё из списка дел сделано и ты доложил диспетчеру по рации. Провал — смена
  начинается заново, уже внизу.
- **Генератор** на станции даёт свет и воздух. Работает — горят лампы в тоннеле и переноски в старой линии,
  а вентиляция продувает тоннель. Заглох (кончилось топливо или ему «помогли») — темно и через пару минут
  нечем дышать. В старой линии вентиляции нет: воздух уходит всегда, без генератора — вдвое быстрее.
- **Свет и страх.** Страх растёт в темноте; под лампами он спадает, один налобник лишь сдерживает его.
  Фонарь садится за 5 минут: батарейки, ручка динамо (полный заряд — 45 с).
- **Шум.** Существа почти слепы, но слышат шаги, бег, выстрелы и треск ручки. Присядь, брось болт,
  спрячься в железный шкаф и задержи дыхание.
- **Поручения** — сюжетные и из пула, каждый раз другие и в других местах; места отмечены на карте (5).
- **Старая линия** (с третьей смены) каждую ночь собирается заново: длинные коридоры, залы, закоулки.
  Там находки, за которые платят, если вынесешь их в тоннель, свои жители и свои правила. Провалил смену там —
  вещмешок останется, где упал, а уже подобранное не появится снова.
- **Служебки.** Иногда в старой линии попадается решётка на замке с биркой «С-N». Ключ лежит где-то в той же линии —
  обычно не на главном пути. Внутри — аптечка, батарейка, патроны и кое-что на продажу.
- **Деньги** не пропадают ни при провале, ни при новой игре. Платят по трудности поручения (один раз за смену)
  и за смену — чем глубже, тем больше; за убитых существ не платят. Шкафчик снабжения в дежурке: расходники
  на смену, снаряжение навсегда и копилка на операцию Маши — переводить на неё можно до 1000 ₽ за смену.
- **Записки** за дверями служебных комнат складываются в историю «Тихой». Концовок три.
- **Находки и достижения** сохраняются навсегда (18 достижений, экран — в меню).

## Разработка

- **Автотест:** `godot --headless -- --smoke` — меню, все смены, старая линия, концовки. CI — `.github/workflows/ci.yml`.
- **Релиз:** workflow `release.yml` (тег `vX.Y.Z` или вручную) собирает три платформы; описание — из
  `.github/release-notes/<тег>.md`.
- **Озвучка:** реплики — `voice/lines.json`; `voice.yml` синтезирует их голосом Piper с эффектом рации
  и коммитит `voice/*.ogg`. Живой голос — свои `voice/<id>.ogg` с теми же именами.

```
scenes/         splash, main_menu, main
scripts/        main (мир и смены), level (тоннель), lower_line (генератор старой линии), director (события),
                game / meta / settings / achievements (автозагрузки), player, stalker, hud, dispatcher,
                proc_tex, sfx, map_view; props/ — по скрипту на объект
assets/         набор ассетов Hope Light (модели, текстуры, материалы)
models/         модели с OpenGameArt
sounds/         звуки и музыка с OpenGameArt
voice/          озвучка диспетчера и Маши
```

## Ассеты и лицензии

**Набор Hope Light** (`assets/hope_light_assets_extra/`) — модели, пиксельные текстуры и материалы,
сделанные для игры: кирпич, кафель, обстановка дежурки, станции, комнат и старой линии. Описание и
генераторы — внутри набора.

**Модели с [OpenGameArt](https://opengameart.org)** (текстуры уменьшены, материалы задаёт код):

| Где | Набор | Автор | Лицензия |
|---|---|---|---|
| Вагонетка, путь | [Mine Object collection](https://opengameart.org/content/mine-object-collection) | loafbrr_1 | CC0 |
| Ползуны | [Alien Bug Animated](https://opengameart.org/content/alien-bug-animated) | CDmir | CC0 |
| Пауки | [Low Poly Spider (Glest)](https://opengameart.org/content/low-poly-spider-glest) | Wciow, John.d.h | [CC-BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/), изменённая `spider.glb` — на тех же условиях |
| «Другой» | [Angler Man 3D](https://opengameart.org/content/angler-man-3d) | piacenti | [CC-BY 3.0](https://creativecommons.org/licenses/by/3.0/), анимации добавлены |
| Слушатель | [Blind Hunter Creature](https://opengameart.org/content/blind-hunter-creature) | Mophs | [CC-BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/) / [4.0](https://creativecommons.org/licenses/by-sa/4.0/), изменённая `listener.obj` — на тех же условиях |
| Декорации | [Train Kit](https://opengameart.org/content/train-kit) | Kenney | CC0 |
| Останки | [3D Dungeon Debris — Skull and Bones](https://opengameart.org/content/3d-dungeon-debris-skull-and-bones) | Paul Wortmann | CC0 |
| Горелка, канистра | [Containers Pack](https://opengameart.org/content/containers-pack) | loafbrr_1 | CC0 |
| Пистолет | [Pistol](https://opengameart.org/content/pistol-5) | loafbrr_1 | CC0 |
| Батарейка | [Lowpoly Survival Item Pack](https://opengameart.org/content/lowpoly-survival-item-pack) | artie31 | CC0 |
| Рация | [Radio](https://opengameart.org/content/radio-0) | laleksic | CC0 |
| Двойник | [Universal Base Characters](https://quaternius.com) (Standard) | Quaternius | CC0 |
| Таблетки | [Pills 3D models](https://opengameart.org/content/pills-3d-models) | mxc2 | CC0 |

**Присланные автором проекта** (лицензия — та, под которой их скачали; в архивах её не было):
мусор — Trash and Debris (`models/trash/`), скамья, урна, схема, плакаты и вагон метро — Metro PSX
(`models/metro_psx/`), паук-охотник — Huntsman Spider (`models/huntsman/`).

**Звуки и музыка с [OpenGameArt](https://opengameart.org)**, все CC0 (остальное синтезируется кодом):

| Где | Источник | Автор |
|---|---|---|
| Гул подземелья | [Loopable Dungeon Ambience](https://opengameart.org/content/loopable-dungeon-ambience) | JaggedStone |
| Капель | [Dripping water loop](https://opengameart.org/content/dripping-water-loop) | qubodup |
| Тёмный пэд | [Dark Ambience Loop](https://opengameart.org/content/dark-ambience-loop) | Iwan Gabovitch (qubodup) |
| Стоны | [Ghost Monster Voice Moaning & Growling](https://opengameart.org/content/ghost-monster-voice-moaning-growling) | qubodup |
| Крик | [Horror scream1](https://opengameart.org/content/horror-scream1) | Vinrax |
| Шипение | [Insect or alien scream](https://opengameart.org/content/insect-or-alien-scream) | qubodup |
| Пауки, голос «Другого» | [80 CC0 creature SFX](https://opengameart.org/content/80-cc0-creature-sfx) | rubberduck |
| Шаги, скрип | [50 RPG sound effects](https://opengameart.org/content/50-rpg-sound-effects) | Kenney |
| Тревога | [Panic mode](https://opengameart.org/content/panic-mode) | Breadman |
| Музыка меню | [At the End of Hope](https://opengameart.org/content/at-the-end-of-hope) | Emma_MA |
| Лязг, перекладины, щелчки, выстрел, подбор, сердце, дыхание, дождь, ветер, гул, капель, замок, бумага | [500 game sound effects](sounds/LICENSES-500-game-sfx.txt) — подборка CC0 (Kenney, qubodup, Iwan Gabovitch и др.) | см. LICENSES |

Голоса диспетчера и Маши — нейросетевой синтез [Piper](https://github.com/rhasspy/piper).

**Шрифты** (`assets/fonts/`, [SIL OFL 1.1](https://openfontlicense.org)): [Oswald](https://github.com/googlefonts/OswaldFont)
(The Oswald Project Authors) — интерфейс, [PT Mono](https://www.paratype.com/public) (ParaType) — путевой лист.
