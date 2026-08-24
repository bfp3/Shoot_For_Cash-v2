# Agent notes — Shoot For Cash

Godot **4.6** GDScript. Do not edit `.godot/` or `addons/` unless the task is the addon itself.

## Read first

| Working on | Open |
|---|---|
| Round / shop / tally / strikes / checkpoints | [`docs/round-loop.md`](docs/round-loop.md) |
| Cash HUD, pool, BANK, multiplier | `ch/Money/money_labels.gd` header + `lib/player_state.gd` |

## Owners (do not bypass)

- **Game loop:** `ch/round_manager.gd` — not `lib/Game Loop Manager_v2/` (dead).
- **Run data / cash / save:** `lib/player_state.gd` (`gl_PlayerState`).
- **Prices / rock values / unlock costs:** `lib/data_set.gd` (`gl_DataSet`).
- **Signals:** `scripts/EventBus.gd` via `EventBus.instance`.
- **Level script:** `sc/island-shipper.txt` through `lib/parser.gd` (`Parser`).
- **Island scenery:** `sc/All_level_layouts/` only. Never point `RoundManager` at `sc/2025_Levels/`.

## Cash

Hits go through `gl_PlayerState.add_to_cash_pool()`. Do not write `dataset.bonus_cash` or `dataset.cash` for round gains. Shop spend is wallet (`dataset.cash`) plus `EventBus.instance.update_money`.

## Conventions

- Prefer `EventBus` signals over new cross-node refs.
- Match existing GDScript style in the file you touch. No drive-by refactors.
- Editor-only tools (`ch/debug/`, D-key editors) must stay behind `OS.has_feature("editor")`.
- Persist: editor defaults to `PersistMode.TEST` (no disk). Exported builds use `PersistMode.LOAD` (`user://shoot_for_cash_progress.cfg`).
