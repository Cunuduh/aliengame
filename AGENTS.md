# Repository instructions

These instructions apply to the entire repository.

## Project context

- This is a Godot 4.7 RPG written in GDScript.
- The repository name `aliengame` is historical; do not infer the game's premise from it.
- Read the relevant parts of `PROJECT_GUIDE.md` before changing battle rules,
  characters, abilities, dialogue, UI, party following, or overworld behavior. That
  document is the source of truth for design intent, architecture, edge cases, and key
  files; do not load unrelated sections when the task is narrow.
- `BATTLE_UI.md` is the detailed battle UI specification.

## Working approach

- Preserve existing user changes. This worktree may be heavily modified or contain
  untracked assets; touch only files required for the current task.
- Inspect the relevant scripts, scenes, resources, and their callers before editing.
  Godot behavior is often split between a `.gd` file and serialized `.tscn`/`.tres`
  properties.
- Prefer focused changes that follow the existing architecture. Combatants own how they
  act; `BattleScene` owns the turn loop and shared battle services; `BattleUI` and
  `TurnTrack` own presentation.
- Use `rg`/`rg --files` for repository searches. Do not edit generated `.godot/` data or
  `.uid` files by hand.
- Keep the user's comments. Do not add comments that merely narrate a change; match the
  surrounding comment density and idiom.

## GDScript and game invariants

- Strict typing is enforced: `gdscript/warnings/untyped_declaration=2`. Type variables,
  collections, return values, and loop iterators. Convert `StringName` to `String` before
  string operations when a typed `String` is required.
- Use `Combatant.is_alive()` for liveness checks, never `stats.health > 0`; Hime remains
  alive while mortal at non-positive HP.
- Never await `animation_finished` without proving the animation is non-looping and has
  positive length. Use the existing guarded animation helpers and fallback chains.
- Keep battle tuning constants with the existing constants at the top of
  `assets/scripts/battle/battle_scene.gd`.
- World scene roots that host party followers need `y_sort_enabled`.
- Keep `*.dlg` in every export preset's `include_filter`.

## Verification

After changing GDScript, scenes, resources, or project settings, run a headless Godot
check from the repository root:

```powershell
$godotExe = 'F:\Repositories\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe'
& $godotExe --headless --path . --quit 2>&1 |
  Select-String -Pattern 'SCRIPT ERROR|ERROR|Parse Error' |
  Where-Object { $_ -notmatch 'invalid UID' }
```

Empty filtered output means no relevant engine error was reported; also inspect the
process exit code. On another machine, use its Godot 4.7 executable.

If a new `class_name` is not found, run one headless `--import` pass to refresh Godot's
class cache, then rerun the check. Report any pre-existing errors separately from errors
caused by the current change.

Temporary test harnesses may be added when needed for verification. Keep them narrowly
scoped and remove them before handoff unless the user asks to retain them.
