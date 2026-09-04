# Round loop

`ch/round_manager.gd` is the session state machine. Shop, shooting, tally, and map travel all go through `enter_state()`.

## Happy path

```
START_START (difficulty select)
  → SHOP_START → SHOP_END
  → ROUND_START (show cash HUD, apply modifiers)
  → WAVE_START (spawn rocks, pulse egg)
      rocks clear → WAVE_END → CHECK_SCORE
        more waves → WAVE_START
        last wave  → ROUND_END
  → ROUND_END
      win  → TALLY_START
      fail → forfeit pool → TALLY_START (or skip tally on strikeout)
  → TALLY_END → SHOP_START
```

Range clear (last round of a place, first time): tally, then shop (no island map). Hold-out win: tally, then the next range in `level-beginner.txt` order (shop on that range). Surviving the last hold-out without a strikeout: tally, then the stage-complete screen (fade to black, stage name + cash, DONE → title screen). Shop back: ABANDON RUN? No stays in shop; Yes resets the run and reopens difficulty select. Boss win: tally, then map ceremony. Boss loss: shop in the boss arena.

## States (`RoundState`)

| State | What happens |
|---|---|
| `START_START` | Boot / abandon: hide start-menu clone, open difficulty select. |
| `SHOP_START` | `EventBus.instance.open_shop`. Reset modifiers. Shop balloons for the upcoming round. |
| `SHOP_END` | Prompts, then `ROUND_START`. |
| `ROUND_START` | `gl_PlayerState.next_round()`, modifiers, cash HUD, capture mouse. |
| `WAVE_START` | Round banner / checkpoint banner, start rocks, egg pulse. |
| `WAVE_END` | → `CHECK_SCORE`. |
| `CHECK_SCORE` | More waves → `WAVE_START`; else `ROUND_END`. |
| `ROUND_END` | Win: tally. Fail: forfeit pool then tally. |
| `TALLY_START` | `EventBus.instance.open_tally_card`. |
| `TALLY_END` | Fail: forfeit leftover pool + `lose_range_banked_cash()`. Save checkpoint. Back to shop or map. |
| `INACTIVE` / `PAUSE` / `RESUME` | Idle / timer pause. |

`BONUS_ROUND` is unused (`update_bonus_round` is a no-op). Bonus-type1 is a modifier on a normal round.

## How a round ends

- **Clear:** `EventBus.instance.all_rocks_destroyed` → `successful_round()` → `WAVE_END`. Endless ignores this and loops spawns. Hold-out: if the script still has work or a pineapple finale is active, stay open; otherwise stop the timer and win.
- **Miss / strike:** `EventBus.instance.add_strike` → strike HUD. At max strikes, `has_hit_three_strikes` → `handle_three_strikes()` → `unsuccessful_round_locked()`.
- **Strikeout:** forfeit unbanked pool, subtract range-banked from wallet, **keep multiplier**, skip tally, reopen shop (`_return_to_shop_after_strikeout()`).
- **Cancel:** in-round cancel action → `abort_round_to_shop()`.

## Level data

- Script: `sc/level-beginner.txt` (and `level-advanced` / `level-expert` / `level-mystery` / `level-challenge-0N` via difficulty). Parser fills `current_rock_sequence`.
- Layouts: `LAYOUT_PATH_BY_PLACE_INDEX` / `LAYOUT_PATH_BOSS_BY_ISLAND` → `sc/All_level_layouts/level_layout_*.tscn`.
- Environments: `ENV_PATH_BY_LEVEL` on the camera, not inside the layout.
- Round modifiers on the sequence dict: `no_lives`, `bonus` (e.g. protect), `shuffle`, `difficulty`, `max_strikes`, `hold_out_ms`.
- Pace: `pace-slowest` / `slow` / `normal` / `fast` / `fastest` / `impossible` mid-round. Sets `aim_launch_gravity_scale` for every rock from that line on (0.25 / 0.5 / 1.0 / 1.5 / 2.25 / 3.0). Replaces `difficulty-*` for launch speed. (`rock-avoider` always uses gravity 1.0; `rock-stay` ignores pace and flies straight then hangs. Multi-cell: `rock-stay 1 a1 a8 c8 c1 a4 1` visits those cells then exits to splash; trailing `0`/omit hangs on the last cell.)
- `rock-avoider-kill`: pop every live avoider (no strike). Avoiders do not block `wait` / `wait-until-clear`.
- Side lanes: `rock A0 A8` / `pineapple A0 A9` spawn just off-camera at column 0 (outside 1) or 9 (outside 8) and fly across. Out-of-bounds is ignored until the target has been on-screen.

## Special modes

- **Hold-out (`hold out 90000`):** countdown timer in milliseconds. Script plays **once** (no rock loop). Win if the script finishes and the sky clears (no `pineapples` gate), **or** if the timer hits 0. If the script has a `pineapples` keyword, either reaching it early or the timer hitting 0 jumps to that finale: stop the timer, fanfare + particles, launch the following `pineapple` / `wait` lines; midair rocks stay shootable as overtime (they no longer advance the script). When the pineapples are gone, wait 0.5s, then tally. Abort / Play again always restarts from the rock script, never mid-finale. Works on any range, including boss. After a non-boss hold-out tally, travel to the next `range` header in `level-beginner.txt`. Surviving the last range opens the stage-complete screen instead of the map. `boss-timer` is still accepted as an alias.
- **Boss:** hold-out in a boss arena. After tally, island map.
- **Endless:** looping rocks, count-up timer, no wave banners.
- **Level / round editor (D from shop, editor only):** sandbox under island `test`; does not write wallet unless forced.

## Collaborators

| Role | Node / script |
|---|---|
| Spawns | `rocks_container` (`ch/Rocks/rock_manager.gd`) |
| Shop UI | `shop_main_menu` + `EventBus.instance.open_shop` |
| Tally | `ch/Tally_card/tally_card_main.gd` + `EventBus.instance.open_tally_card` |
| Stage complete | `ch/canvas_layers/stage_complete_screen.gd` |
| Cash HUD | group `money_manager` (`ch/Money/money_labels.gd`) |
| Strikes | `wave_progress_feedback` |
| Player | `ch/Player/scripts/player.gd` |

## Do not

- Drive shop/tally/win from a second state machine.
- Load island meshes from `sc/2025_Levels/`.
- Award round cash except through `gl_PlayerState.add_to_cash_pool()` / `bank_cash_pool()` / `forfeit_cash_pool()`.
