# Project guide

Design and implementation context for this Godot game. The repo/folder is named
**`aliengame`** for historical reasons — **the game is not about aliens.** See "Vision"
below for the real premise.

## 1. Vision

To be filled out.

---

## 2. Battle system

A queued-action, shared-turn-track system. The design payoff of
good ordering is the Momentum layer (Links + EN).

### 2.1 Turn flow (`battle_scene.gd::_run_battle`)

Each round:

1. **Build turn order** (`_build_turn_order`): all living combatants sorted by
   agility descending; ties break allies-first, then by side index. Rendered as
   bubbles in the top-right turn track.
2. **Enemy planning** (`_plan_enemy_turns`): every living enemy commits an action
   via `Enemy.plan_turn` *before* the player queues anything, stored in
   `_enemy_plans`. Plans are decided once per round and stay fixed across
   confirm/cancel cycles — that stability is what makes CHECK trustworthy.
3. **Planning phase** (`_party_queue_phase`): each living party member, in agility
   order, picks an action. Actions are stored, not executed. `X`/back steps to the
   previous member (menu state remembered per member via `_menu_memory`).
4. **Battle phase**: iterate the turn order; allies run their queued action
   (`_execute_queued`), enemies run their plan (`Enemy.execute_plan`). Damage,
   Links, and EN resolve here. Victory/defeat checked after every turn.

### 2.2 Action menu

`FIGHT · ABILITY · ITEM · TURN · CHECK`

- **FIGHT** — basic attack; pick an enemy target.
- **ABILITY** — pick target, then ability; costs EN, deducted at queue-time
  (or HP at cast time — §2.4b). Unaffordable → "Not enough EN." / "Not enough
  HP." and stay in the menu. `targets_self` / `targets_all` abilities skip the
  target step entirely.
- **ITEM** — placeholder (no items yet).
- **TURN** submenu: **Pass Turn** (see 2.4) or **Change Order** (see below).
- **CHECK** — free inspection; costs no turn and returns to the action menu.
  Browsing the enemy list shows each enemy's planned move in the right-hand
  label column, outlines the hovered enemy red and its planned victim white.
  Confirming drills into HP, effective ATK/DEF/AGI, the full plan
  (`move > target`), and the enemy's move list. Either key backs out.

**Change Order:** reorder ally slots only, bounded by Agility — an ally cannot move
ahead of any faster enemy. Moving an ally *later* is allowed and is the defensive
use: wedging an ally into a contiguous enemy run splits the enemy Link at that
point. Moving a fast lone ally back into the party run trades initiative for Link
depth.

### 2.3 Links (Momentum, passive)

Consecutive same-side actions with no opposing turn between them build a Link.

- Multiplier in `apply_damage`:
  `damage = max(1, int(damage * (1.0 + LINK_STEP * _link)))`, `LINK_STEP = 0.25`
  → +25% per step. Linked hits append ` (x1.25)` etc. to the message.
- `_link` increments after a damaging action resolves; both sides Link. A queued
  Pass also counts as a step (see 2.4).
- `_link` resets to 0 on a side flip and at the start of each battle phase.
- **`_link_boost`** is a one-turn addend (`_link + _link_boost` feeds both the
  damage factor and the Fight EN formula), zeroed at the top of every turn. Cache
  Hit spends into it rather than into `_link`, so the boost lifts its target's
  turn only and the rest of the run keeps its natural depth.
- **Kill-splitting:** killing a combatant mid-Link splits the run at the dead slot
  (`_link = 0` there; link panels re-split visually). `[A B C D]` with B killed
  becomes `[A]` + `[C D]`. Edge kills just trim. Kill-order is a tempo weapon for
  both sides.

### 2.4 EN economy (Momentum, the bank)

**EN = Energy**, spent on abilities. `_en`, clamped `0..EN_MAX (100)`, starts each
battle at `EN_START (0)`. Physical tempo generates EN; abilities spend it — the
"human = physical, AI = magic" split as mechanics.

- **Fight hit lands:** `+ EN_FIGHT_GAIN (4) + EN_LINK_BONUS (8) * _link`,
  credited when damage lands (via `_pending_fight_en` inside `apply_damage`).
  Gains per step: 4, 12, 20, 28… Deep Links are where EN comes from.
- **Pass Turn:** `+ EN_PASS_GAIN (8)` at queue-time, during planning — the only EN
  source spendable in the same round it's earned (Fight EN lands at damage
  resolution, too late for this round's queueing). Because planning runs in
  agility order, a Pass funds abilities only for slower allies queueing after it:
  fast allies are the party's batteries. A Pass also preserves and advances the
  Link — the slot deals no damage but counts as a step, so the next same-side
  action inherits one more multiplier step. Pass bubbles show Link numerals.
  Positional use (sacrificing a cheap early slot so a later heavy hit lands
  deeper) matters as much as the EN.
- **Abilities:** `Ability.en_cost` (default 20; spike 25), deducted at
  queue-time so affordability is always the number on screen. Back-navigation
  refunds the exact `en_delta` on the queued action. Refunds assume LIFO
  back-stepping: keep Change Order from interleaving with planning, or a
  refunded Pass can strand already-spent EN negative.

**Design constraint:** abilities are a reward for scheduling, never an opener
(EN starts at 0). Encounter design must not front-load enemy burst damage into
the poverty phase.

### 2.4b HP costs (Hime's economy)

`Ability.hp_cost_ratio > 0` swaps a move off the EN bank onto the caster's own
HP, as a fraction of **max** HP. The two economies never mix on one ability.

- **Paid at cast time**, not queue-time (unlike EN), inside
  `Ability.use_in_battle` via `BattleScene.pay_hp_cost`. So a caster mortally
  wounded *after* queueing still fires the move and just digs deeper.
- **Affordability** is `Combatant.can_pay_hp()` (`health > 0`), checked at
  queue-time through `Ability.affordable(user, en)`. There is nothing to refund
  on back-navigation, so no `en_delta` is stored.
- The ABILITY list legend switches to `HP` when every listed ability is
  HP-costed, `COST` when the kit is mixed. `cost_label` prints the resolved HP
  number (`hp_cost(user)`), not the ratio, so the player reads the exact HP the
  cast will take.

### 2.5 Damage & stats

- Basic attacks: `compute_damage = max(1, attacker.attack - defender.defense)`.
- Abilities: `Ability.calculate_damage(battle, user, target) -> int`, overridden
  per subclass (flat placeholder values for now; the hook exists for real math).
  Result is passed to `apply_damage` as `damage_override`.
- The Link multiplier applies on top of either path in `apply_damage`, folded
  into a single `factor` with any armed damage multiplier so the result is
  floored once. `apply_damage(..., silent)` suppresses the message for
  multi-hit moves that print their own running total; the actual numbers land in
  `last_damage` / `last_factor` (`damage_suffix()` renders the `(x1.25)` tail).
- **KO lines are a second line on the damage message**, not a timed follow-up —
  multi-target moves would otherwise stomp each other. `apply_damage` stores
  `last_ko` from `Combatant.ko_message()`; the non-silent path appends
  `ko_suffix()` itself, silent callers append it to their own total (see
  `triple_down.gd`). The message is per-character: the base is
  `* %s was defeated!`, Cora `* %s was hurt and beaten...`, Hime
  `* %s finally fell...` — which is also what her collapse prints, since
  collapsing is her only KO path (damage alone just makes her mortal).
- **Damage multipliers** (`queue_damage_multiplier`) arm at the *end* of the
  turn that queued them and survive until a turn actually spends one — so a
  multiplier covers every hit of one multi-hit action, and a Pass doesn't waste
  it. `_settle_damage_mult` runs that state machine.
- Stats (`CharacterStats`): `health/attack/defense/agility` with max variants;
  signal `stat_changed`. Defaults 20/1/0/10 (scenes override).

### 2.6 Animation & effect conventions

- **`idle` is a direction sheet, not a loop.** Frames 0/1/2/3 are
  right/left/up/down (`Combatant.VEC_TO_INT`). `Combatant.pose_idle(facing)`
  plays it, pauses, and seeks `IDLE_POSE_STEP * facing` to hold the one frame —
  playing it un-paused makes the character spin through all four directions.
  Any new overworld character sheet must follow that frame order, and its `idle`
  keys must sit far enough apart that `0.25 * facing` lands in the right bucket.
  `play()` on a posed (paused) `AnimationPlayer` resumes correctly, so battle's
  `idle_battle` and the walk clips take over without extra unpausing.
- **Loop-on-queue → cast-on-turn.** Queuing plays a looping wind-up
  (`attack_loop`, `<ability>_loop`); resolving plays the cast
  (`attack_cast`/`attack`, `<ability>_cast`). Missing clips fall back gracefully.
- **Hit effects:** `Combatant.hit_type` names a clip in `hit_effect.tscn`;
  attacks `await` the effect, so damage lands when the effect concludes. Empty
  `hit_type` = no effect, no delay.
- **Anti-softlock rule:** never `await animation_finished` on a possibly-looping
  clip — it never fires. Use the `loop_mode` check + timer fallback
  (`play_and_wait_first`, `_play_attack_anim`, `play_hurt`). A looping `attack`
  clip caused a real softlock; a looping `hurt` clip caused a real stuck pose
  (the combatant never left the hurt frame). Treat a **zero-length** clip the
  same way — `length > 0.0` is part of the same guard.
- **Missing-clip fallbacks are chains, not single names.** `play_and_wait_first`
  walks a candidate list and plays the first clip that exists, so a character
  with no cast animation still gets the beat: abilities try
  `<name>_cast → spell_cast → attack → idle_battle`, items
  `item_cast → spell_cast → idle_battle`, basic attacks
  `attack_cast → attack → idle_battle`.
- **Hurt is shared, on `Combatant.play_hurt(fatal)`.** It picks the contextual
  variant when a `<action>_loop` is playing (`<action>_hurt`), else plain
  `hurt`, and resumes the interrupted loop — or `idle_battle`/`idle` — unless
  the hit was fatal. It bails if another clip took over mid-wait, so a cast
  starting during the hurt is not clobbered. Cora, `PartyMember` and Hime all
  route through it; `PartyMember` still prefers a `damaged` clip when the sheet
  has one.

### 2.7 UI feel

- **Turn bubbles** (top-right): acted turns dim; KO'd-before-acting turns swap to
  the broken sprite immediately.
- **Link numerals:** bubbles inside a Link show tick marks counting the +25%
  steps for that slot; the first bubble in a run stays blank (x1.0). Applied per
  position-in-run in `_rebuild_link_panels`, so reorders and mid-Link kills
  renumber live. Depth is `position-in-run + Ability.link_bonus for that slot`,
  so a Cache Hit bumps only its target's numeral — later slots in the run keep
  their own depth, matching `_link_boost` (§2.3).
  `BattleScene._link_bonus_map()` builds that dict from unconsumed `_cache_hits`
  plus the round's queued actions, and only credits a queued Cache Hit whose
  target still has a turn left when the caster spends theirs — targeting someone
  earlier in the order carries the bonus to next round, and the numerals say so.
  It is passed into `show_order`, so it is frozen for the battle phase and
  numerals do not shift when a Cache Hit is actually consumed.
- Turn-track liveness goes through `Combatant.is_alive()` (`_base_tex`,
  `_link_broken`), so a mortal Hime keeps an unbroken bubble and links through,
  exactly as the turn loop treats her (§2.8).
- **Link panels** (`link_panel.tscn`, enemy variant) wrap contiguous same-side
  runs (≥2) live during Change Order — the predicted-Link feedback loop.
- **HP/EN bars** use a ghost-bar pattern (main and ghost move at different
  speeds depending on gain vs. loss). The battle phase waits for the HP ghost
  tween between turns only when the shown member actually took damage.

### 2.8 Outcomes

`_victory` → win message → `BattleManager.cleanup(true)`;
`_defeat` → `cleanup(false)` → death screen. Party is
`[Globals.cora] + Party.members()` — see §3.1.

**Winning revives.** `BattleManager.revive_party()` runs at the end of the won
branch of `cleanup` — after `fade_out`, so outline materials are already
restored and the dissolve shader is writable again — and calls
`Combatant.revive()` on Cora and every follower. The base lifts `health` to 1
only if it is at or below 0; `PartyMember` also undoes a dissolve (visible,
shader `progress` back to 0, re-pose) and `Hime` clears `_collapsed`,
`mortal_turns_left` and the mortal tint *before* `super()`, so the health write
is seen by a live combatant. Defeat does not revive — that path ends in the
death screen.

**Liveness is `Combatant.is_alive()`, never `stats.health > 0`.** Every turn-order,
targeting, party-wipe and turn-track check goes through it, because Hime stays
alive at or below 0 HP. `apply_damage` derives `killed` from `is_alive()` *after*
subtracting. New combatant code must follow the same rule.

`Combatant.on_turn_start(battle)` is awaited at the top of each turn; if the
combatant is no longer alive afterwards the slot is marked broken and the Link
splits there, exactly like a mid-round kill. The base implementation awaits a
process frame so overrides can be coroutines without a redundant-await warning.

### 2.9 Planned (agreed, not built)

- **Agility buffs/debuffs:** apply to the **next round's** turn order only; never
  reshuffle the current round's track (the track is a promise the player planned
  against). Cost these high — turn position feeds damage, EN, and
  enemy-Link-splitting simultaneously.
- **Enemy AI, incremental:** replace random `choose_target` with Link-aware
  targeting (prefer the target whose death splits the party's longest predicted
  run — reuse `_rebuild_link_panels` data). The planning half is built (see 2.1
  step 2); only the *choice* is still random.

---

## 3. Architecture — ownership model

Combatants own how they act; `BattleScene` is a shared service the actions call
into. When adding behaviour, put it on the actor, not the battle loop.

- **`Combatant`** (`characters/combatant.gd`, `CharacterBody2D`): base for
  everyone. Owns `attack`, `on_queue_attack`, `_play_attack_anim`, `knockback`,
  `face`, `hit_type`, `abilities`. Has `$CharacterStats`, `$AnimationPlayer`,
  `$Sprite`.
  - **`Cora`** (`characters/cora.gd`): the protagonist (Corazón), first party
    member. Overworld movement + a small internal idle/walk/battle state machine, battle
    overrides, contextual hurt variants.
  - **`PartyMember`** (`characters/party_member.gd`): allied AI construct;
    group `party`. Also owns the overworld **trail follow** (see §3.1).
    - **`Hime`** (`characters/hime.gd`): second playable character. Her whole
      kit is HP-costed (§2.4b) and she survives past 0 HP — see §3.2.
  - **`Enemy`** (`enemy/enemy_base.gd`): adds `plan_turn` (commits an action
    before the party queues; rolls `ability_chance` against its non-ally-targeting
    `abilities`, else fights), `execute_plan` (runs it, retargeting to the first
    living ally if the planned victim died first), `plan_move_name` / `move_names`
    (CHECK readout), `choose_target` (currently random living party member),
    dissolve-on-death; group `enemy`. Subclasses set stats/`hit_type` and may
    override `attack`.
- **`Ability`** (`abilities/ability.gd`, `Resource`): owns `on_queue`
  (wind-up), `use_in_battle` (cast), `apply_effect` (damage/heal/buff),
  `calculate_damage`. Fields `en_cost`, `hp_cost_ratio`, `cooldown`, `name`,
  `icon`, `targets_allies`, `targets_self`, `targets_all`. Targeting flags
  decide whether the queue phase asks for a target at all: `targets_self`
  binds to the caster, `targets_all` to the whole enemy side (the stored
  target is only a liveness anchor — the ability re-reads `living_enemies()`).
  Subclasses override `_init` and (for support abilities) `apply_effect`.
  Cora's kit: `Spike` (damage), `BasicPatch` (heal 25% max HP + base),
  `Escalate`/`Harden`/`Overclock` (attack/defense/agility +1 stage,
  ±33%/stage, clamp ±3; agility applies to next round's order), `CacheHit`
  (Link runs one step deeper at the target ally's turn).
  Hime's kit (all HP-costed): `TripleDown` (25% max HP, 3×30 in succession,
  one accumulating damage readout), `BloodRush` (50% max HP, self, arms a ×2
  that stacks multiplicatively with the Link on her next damaging turn),
  `Bloodbath` (100% max HP, 100 to every living enemy).
- **`BattleScene`** (`battle/battle_scene.gd`): the turn loop + rules + the
  facade services actions call — `apply_damage`, `compute_damage`,
  `set_message`, `play_and_wait`, `spawn_hit_effect`, `return_to_idle`,
  `living_party`, `gain_en`. Owns the selection state machine and input.
  Presentation is delegated to:
  - **`BattleUI`** (`battle/battle_ui.gd`, script on `battle_ui.tscn` root):
    all node painting — action menu, message box + scrolling lists/costs/legend,
    HP/EN bars (ghosts, white edges, EN preview pulse), carets, HP card,
    slide-in. Battle talks to it via `ui.<method>`; it never calls back.
  - **`TurnTrack`** (`battle/turn_track.gd`, script on `TurnOrderContainer`
    inside `battle_ui.tscn`): turn bubbles, link panels, link numerals,
    broken/acted states. `show_order(order, allies, highlight)` rebuilds;
    exposes `icon_rect()` for caret placement and re-links on `sort_children`.
- **`BattleManager`** (`world/battle_manager.gd`, autoload): pauses the world,
  builds the party, instances/tears down the battle scene, restores Cora
  and every follower to their original parent.
- **`Party`** (`world/party.gd`, autoload): the roster. `roster` is the list of
  recruited `PackedScene`s; `spawn_followers(cora)` rebuilds the overworld
  train, `members()` feeds `BattleManager`, `enter_battle()`/`leave_battle()`
  park and restart the follow.

### 3.1 Overworld party train

Followers retrace their leader's **exact route**, they don't steer toward them.
`PartyMember` records the leader's position into `_trail` whenever it has moved
`TRAIL_SAMPLE` px, then walks that polyline backwards `TRAIL_GAP` px of arc
length and snaps itself there (`_trail_point`, which also trims the consumed
tail). Corners are therefore turned, not cut, and the follower never needs
collision — the path it replays was already collision-valid.

**Follow in `_process`, not `_physics_process`.** Cora's movement state is
processed in `_process`, so a follower on the physics tick would be a frame
stale at any framerate above
60 Hz, which shows up as stutter *and* as the pair flickering past each other in
the y-sort when they overlap. `TRAIL_SAMPLE` is likewise tiny (0.01) so that
sampling never quantizes movement into visible jumps at high framerates, and the
walk/idle threshold is a **speed** (`MOVE_SPEED_EPSILON` px/s), not a per-frame
distance, for the same reason.

Facing uses axis hysteresis (`FACING_BIAS`): on a diagonal `|x| ~ |y|`, so a
plain comparison flips the facing every frame on float noise — the held axis
keeps priority until the other beats it by the bias.

**Keep follower transforms exact.** The project-level
`snap_2d_transforms_to_pixel` setting already snaps each final canvas transform
to the nearest pixel when rendering. Pre-rounding a follower's world position
against Cora applies a second, camera-dependent quantization pass. That only
matches the final canvas transform while the camera is centered exactly on
Cora; camera limits break the assumption and can turn the rounding error into
subtle transverse jitter. `_process` therefore writes the exact trail point to
`global_position` and leaves visual pixel snapping to the renderer.

**Run** (`run` action, default `X` — the same key as `cancel`, which is free in
the overworld): held, ramping ×1.5 immediately → ×2.0 at 1/3 s → ×2.25 at 2 s
(`Cora.RUN_RAMP`, last matching tier wins). `_run_held` only advances inside
`_on_walking_state_processing`, and resets on release *and* on entering Idling —
so the ramp measures time actually spent walking and cannot be banked by holding
the button while standing still. Pushing directly into a wall enters Idling and
resets the ramp; diagonal input that produces tangential motion still slides and
remains in Walking. The walk cycle plays at `RUN_ANIM_SCALE` (1.5)
while running — flat across all three tiers, not proportional — via
`AnimationPlayer.speed_scale`, reset to 1.0 on idle/battle entry. Followers get
it off the path like everything else: `_boost[i]` records the leader's
`run_multiplier()` at `_trail[i]` alongside `_pace[i]`, and `PartyMember`
re-exposes `run_multiplier()` for the stretch it is currently walking, so
member *n* chains off member *n-1*.

**Speed is read off the path, not off the leader.** Cora is deliberately faster
on diagonals (`_handle_movement` scales by the raw 8-way input sum, so a diagonal
is √2 ≈ 1.41× — intentional, do not "fix" it by normalizing). A fixed arc-length
gap would force `d(follower arc)/dt == d(leader arc)/dt`, handing the follower
that boost the instant Cora turned, while the follower was still on the straight
behind her. So `_pace[i]` records how fast the leader was moving when it reached
`_trail[i]`, and `_advance` walks each stretch at the speed *that stretch* was
walked at — the boost arrives when she reaches the diagonal, not before.

Consequences worth knowing: the spatial gap breathes (22 px on straights, ~31 px
on sustained diagonals — a constant delay in *time*, not distance), and
`TRAIL_GAP` is enforced as a **minimum** so a stopped leader is trailed rather
than walked into.
Followers chain: member *n* follows member *n-1*, the first follows Cora.

Because every scene re-instances Cora, the train is rebuilt per scene from
`Cora._ready` via `Party.spawn_followers.call_deferred(self)` — deferred
because `_ready` runs while the parent is still setting up children.
`_play_walk` plays `WALK_ANIMS[facing]` when that clip exists and otherwise
holds the **idle frame for the travel direction** — never another direction's
cycle, which reads as a bug. So a member with only `idle` + `walk_down` walks
properly downward and slides on a correct-facing pose elsewhere, and each new
directional clip upgrades itself the moment it's added. A `STOP_GRACE` delay
before posing keeps brief motion stalls from restarting the walk cycle on its
first frame.

### 3.2 Hime — the blood economy

Second playable character (Japanese *princess*, and a nod to *heme*). Her
abilities cost HP, never EN, which makes her the party's EN-independent
damage source: she can open a fight with `Bloodbath` on turn one, when the
Cora is still too poor to do anything but Fight.

- **She survives past 0 HP.** `CharacterStats.can_go_negative` widens the
  health clamp to `-max_health`; `Hime.is_alive()` returns `not _collapsed`, so
  she keeps her turn slot while `is_mortal()` (`health <= 0`).
- **`MORTAL_TURNS` (2) grace.** The counter burns at the *top* of her turns
  (`on_turn_start`), so bleeding out on her own action still buys the full two
  turns afterwards; the third finds the counter empty and she collapses without
  acting. Healing above 0 clears the counter outright — that is the counterplay.
- **Queue-time lockout:** `can_pay_hp()` is false at or below 0, so the mortal
  window is for finishing with what's already queued, not for spending more
  blood. HP is paid at cast time, so a hit that mortally wounds her *after*
  she's queued does not cancel the move (§2.4b).
- **`Dialogue`** (`dialogue/dialogue_manager.gd`, autoload): in-house dialogue
  system (replaced Dialogic). `Dialogue.start(id)` loads
  `assets/resources/dialogues/<id>.dlg`, pauses the tree, and runs
  `dialogue_box.tscn` (`DialogueBox`, `PROCESS_MODE_ALWAYS`); callers
  `await Dialogue.finished`. `.dlg` format: one `speaker_id: TEXT` per line,
  `#` comments, empty/invalid-identifier prefix = narration. Branching:
  `== label` defines a jump target, `-> label` jumps (`-> end` ends the
  dialogue), `* TEXT -> label` is a choice option — consecutive `*` lines
  form one choice, shown in a panel above the box (up/down + interact); an
  option without `->` falls through. The manager drives the box
  entry-by-entry (`show_line`/`show_choices`, awaiting
  `advanced`/`choice_selected`); `choice_npc.dlg` is a worked example.
  Line text goes through `tr()` — keys live in
  `assets/localization/dialogue.csv` (CSV → `.translation` on import; literal
  English also works) — then `{placeholder}` substitution from `variables`
  (`{player_name}` is the human at the keyboard, for fourth-wall lines — Cora is
  written literally; add more via `set_variable`). The pronoun/verb-agreement
  placeholder system was removed — the protagonist is Cora, and female; write she/her
  and her name directly in dialogue text.
  `DialogueBox` typewrites via `visible_characters`: punctuation/whitespace
  cadence in `EXTRA_DELAYS` (punctuation pauses only before whitespace/EOL),
  inline `{pause=sec}`/`{speed=mult}` tags; BBCode passes through and doesn't
  affect timing. "interact" skips the reveal, then advances. Speaker display
  names/colors register in `Dialogue.SPEAKERS` (Cora is the id `cora`); the
  manager resolves them per line but the box does not
  currently render a name tag (removed by request — data kept for
  portraits/inline names later). The box panel uses `default_theme.tres`
  (`style_box_normal.tres`), same as the battle textbox. `.dlg` files are
  non-imported resources — keep `*.dlg` in
  every export preset's `include_filter`.

---

## 4. Working conventions

- **Engine:** Godot 4.7, GDScript.
- **Godot executable (Windows desktop):**
  `F:\Repositories\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe`.
  On another machine, use the Godot 4.7 executable available there.
- **Strict typing:** `untyped_declaration = 2` is an **ERROR**. Type every var and
  loop iterator (`for m: Combatant in party:`). `current_animation` returns a
  `StringName` — wrap with `String(...)` before string ops feeding typed vars.
- **Compile check** (run after GDScript or scene edits, from the repository root):
  ```powershell
  & 'F:\Repositories\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe' `
    --headless --path . --quit 2>&1 |
    Select-String -Pattern 'SCRIPT ERROR|ERROR|Parse Error' |
    Where-Object { $_ -notmatch 'invalid UID' }
  ```
  Empty filtered output means the check is clean. Also inspect the process exit code.
- **New `class_name` scripts** must be scanned to register globally. If a headless
  compile reports `Could not find type "X"`, run `--import` once to regenerate the
  class cache.
- **Comments:** do not add change-narrating comments. Keep the user's own
  comments. Match surrounding comment density and idiom.
- **Tuning constants** live at the top of `battle_scene.gd` (`LINK_STEP`, `EN_*`,
  `LINK_MARGIN`, textures, `SLOT_LAYOUTS`).
- **World scene roots need `y_sort_enabled`.** Followers are added to Cora's
  parent at runtime, so without it they simply draw on top of her in tree order.
  The generated `screens/` roots ship with it on (`build_screens.gd` sets it);
  the `Plate` backdrop is `centered = false` at y=0, so it still sorts behind
  everything in the room.
- **Positioning:** `SLOT_LAYOUTS` spaces party (`Ally1..5`) and enemies
  (`Enemy1..5`) symmetrically across 5 markers by count.

---

## 5. Key files

| Area | File |
|---|---|
| Battle loop, momentum, rules | `assets/scripts/battle/battle_scene.gd` |
| Battle presentation | `assets/scripts/battle/battle_ui.gd` |
| Turn bubbles + link panels | `assets/scripts/battle/turn_track.gd` |
| Base combatant | `assets/scripts/characters/combatant.gd` |
| Stats | `assets/scripts/characters/character_stats.gd` |
| Cora (protagonist) | `assets/scripts/characters/cora.gd`, `assets/scenes/cora.tscn` |
| Party member (AI ally) + trail follow | `assets/scripts/characters/party_member.gd` |
| Hime | `assets/scripts/characters/hime.gd`, `assets/scenes/hime.tscn` |
| Party roster (autoload) | `assets/scripts/world/party.gd` |
| Enemy base + subclasses | `assets/scripts/enemy/*.gd` |
| Abilities | `assets/scripts/abilities/*.gd` |
| Hit effect | `assets/scripts/battle/hit_effect.gd` |
| Battle manager (autoload) | `assets/scripts/world/battle_manager.gd` |
| Battle UI scene | `assets/scenes/battle_ui.tscn` |
| Dialogue system | `assets/scripts/dialogue/*.gd`, `assets/scenes/dialogue_box.tscn` |
| Dialogue data / localization | `assets/resources/dialogues/*.dlg`, `assets/localization/dialogue.csv` |
