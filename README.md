# Shoot For Cash

Arcade shooter built in Godot 4.6.

## Requirements

- [Godot 4.6](https://godotengine.org/download)
- Windows 10+

## How to run

1. Open Godot 4.6.
2. Import this folder (the one that contains `project.godot`).
3. Press **F5** to play.

## Project layout

| Folder | What it holds |
|---|---|
| `ch/` | Characters, HUD, money, player, targets |
| `sc/` | Levels and scenes |
| `lib/` | Shared systems (game loop, autoloads, settings) |
| `res/` | Art, particles, textures |
| `sfx/` | Sound |

## Docs

| File | What it is for |
|---|---|
| [`AGENTS.md`](AGENTS.md) | Conventions for people and agents working in this repo |
| [`docs/round-loop.md`](docs/round-loop.md) | Shop → round → ladder → tally |

## Notes

- Main scene is set in Project Settings → Application → Run.
- Autoloads live in `project.godot` (`EventBus`, `GameSettings`, `GlobalPlayerMoney`, etc.).
