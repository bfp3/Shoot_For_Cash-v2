# Round loop

`ch/round_manager.gd` is the session state machine. Shop, shooting, ladder, tally, and map travel all go through `enter_state()`.

## Happy path

```
START_START (island map)
  → SHOP_START → SHOP_END
  → ROUND_START (show cash HUD, apply modifiers)
  → WAVE_START (spawn rocks, pulse egg)
      rocks clear → WAVE_END → CHECK_SCORE
        more waves → WAVE_START
        last wave  → ROUND_END
  → ROUND_END
      win  → BANK / x+1 balloons → TALLY_START
      fail → forfeit pool → TALLY_START (or skip tally on strikeout)
  → TALLY_END → SHOP_START
```

Range clear (last round of a place, first time): tally, then island map + unlock stamp. Boss win: tally, then map ceremony. Boss loss: shop in the boss arena.

## States (`RoundState`)

| State | What happens |
|---|---|
| `START_START` | Boot: hide start-menu clone, open island map. |
| `SHOP_START` | `EventBus.instance.open_shop`. Reset modifiers. Shop balloons for the upcoming round. |
| `SHOP_END` | Prompts, then `ROUND_START`. |
| `ROUND_START` | `gl_PlayerState.next_round()`, modifiers, cash HUD, capture mouse. |
| `WAVE_START` | Round banner / checkpoint banner, start rocks, egg pulse. |
| `WAVE_END` | → `CHECK_SCORE`. |
| `CHECK_SCORE` | More waves → `WAVE_START`; else `ROUND_END`. |
| `ROUND_END` | Win: `_offer_ladder_choice()` then tally. Fail: forfeit pool then tally. |
| `TALLY_START` | `EventBus.instance.open_tally_card`. |
| `TALLY_END` | Fail: forfeit leftover pool + `lose_range_banked_cash()`. Save checkpoint. Back to shop or map. |
| `INACTIVE` / `PAUSE` / `RESUME` | Idle / timer pause. |

`BONUS_ROUND` is unused (`update_bonus_round` is a no-op). Bonus-type1 is a modifier on a normal round.

## How a round ends

- **Clear:** `EventBus.instance.all_rocks_destroyed` → `successful_round()` → `WAVE_END`. Boss/endless ignore this and loop spawns.
- **Miss / strike:** `EventBus.instance.add_strike` → strike HUD. At max strikes, `has_hit_three_strikes` → `handle_three_strikes()` → `unsuccessful_round_locked()`.
- **Strikeout:** forfeit unbanked pool, subtract range-banked from wallet, **keep multiplier**, skip tally, reopen shop (`_return_to_shop_after_strikeout()`).
- **Cancel:** in-round cancel action → `abort_round_to_shop()`.

## Ladder (`balloon-mult` / `balloon-bank`)

Script commands. Default poses: BANK CASH left (`-2.8, 3.5, 22.5`), +1 Multiplier right (`2.8, 3.5, 22.5`).

- `balloon-bank` → `bank_cash_pool()`, then `reset_cash_multiplier()`.
- `balloon-mult` → keep pool, `increase_cash_multiplier()`.
- Shoot one; the other leaves. Place both next to `balloon-check` so they appear together.

## Level data

- Script: `sc/island-shipper.txt` (`LEVEL_FILE_PATH`). Parser fills `current_rock_sequence`.
- Layouts: `LAYOUT_PATH_BY_PLACE_INDEX` / `LAYOUT_PATH_BOSS_BY_ISLAND` → `sc/All_level_layouts/level_layout_*.tscn`.
- Environments: `ENV_PATH_BY_LEVEL` on the camera, not inside the layout.
- Round modifiers on the sequence dict: `no_lives`, `bonus` (e.g. protect), `shuffle`, `difficulty`, `max_strikes`.

## Special modes

- **Boss:** looping rocks, survival timer. Win = timer, not clearing rocks. After tally, island map.
- **Endless:** looping rocks, count-up timer, no wave banners.
- **Level / round editor (D from shop, editor only):** sandbox under island `test`; does not write wallet unless forced.

## Collaborators

| Role | Node / script |
|---|---|
| Spawns | `rocks_container` (`ch/Rocks/rock_manager.gd`) |
| Shop UI | `shop_main_menu` + `EventBus.instance.open_shop` |
| Tally | `ch/Tally_card/tally_card_main.gd` + `EventBus.instance.open_tally_card` |
| Cash HUD | group `money_manager` (`ch/Money/money_labels.gd`) |
| Strikes | `wave_progress_feedback` |
| Player | `ch/Player/scripts/player.gd` |

## Do not

- Drive shop/tally/win from a second state machine.
- Load island meshes from `sc/2025_Levels/`.
- Award round cash except through `gl_PlayerState.add_to_cash_pool()` / `bank_cash_pool()` / `forfeit_cash_pool()`.
