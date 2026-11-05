# Combat Design Document

## Turn structure
**Player turn** → choose one:
| Command | Effect |
|---|---|
| **FIGHT** | A cursor sweeps a bar. Damage = max(1, ATK − DEF) × (0.35 + accuracy), ×1.8 inside the gold crit window. Hits above 62% accuracy chain a combo (up to 3, each faster, combo hits ×0.6). Attacking lowers mercy by 10. |
| **TALK** | Reason · Joke · Comfort · Intimidate · Question. Each enemy defines mercy gain, a reply, and optional effects (`atk`, `difficulty`, story `do`). Repeats give 30%. Bosses override talk per phase. |
| **DEFEND** | Halve damage this turn, +10 Focus. With *Counterweight*, counterattack for ATK × 0.6. |
| **SPECIAL** | Spend Focus (see below). |
| **ITEM** | Heal / restore Focus. |
| **MERCY** | Spare at 100 mercy (gold "MERCY*"); Flee 70% (never vs bosses). |

**Enemy turn** → the box resizes to fit the attack; steer your soul. I-frames 0.9s. Damage = enemy ATK × multiplier (beams ×1.3) − DEF/2, min 1. A no-hit turn gives +8 Focus.

## Focus & grazing
Passing within 11px of a bullet without being hit = a **graze**: +4 Focus (more with Ranger/Chronomancer). This rewards risky, skilled play and funds Specials.

| Special | Cost | Source |
|---|---|---|
| Mend (heal 40%) | 20 | Always |
| Time Slow (next attack ×0.55 speed) | 35 | Chronomancer 1 |
| Energy Shield (block 3 hits) | 30 | Guardian 2 |
| Illusions (2 decoys, 40% of hits miss, aimed shots may target decoys) | 30 | Mystic 2 |
| Reflection (next 2 hits bounce back for damage) | 40 | Mystic 3 |
| Spirit Summon (each companion acts: heal / slow / damage / mercy) | 40 | Any companion in party |

## Patterns (`scripts/battle/patterns/`)
| Key | Description | Teaches |
|---|---|---|
| `rain` | Falling shards with drift | Basic dodging |
| `orbit` | Rings close in on the center — each has a gap | Reading gaps |
| `beam` | Blinking warning → beam sweep | Telegraphs |
| `mines` | Pulse faster, burst into rings | Spacing |
| `wave` | Walls with a gap riding a sine wave | Tracking |
| `gravity` | Soul falls; UP/Z jumps over floor thorns | Mode switch |
| `teleport` | Eyes blink in and fire aimed spreads | Moving on cue |
| `pages` | Spinning pages bearing words from your history | The Archivist's story |

`difficulty` = enemy base + 0.25/phase + talk effects + 0.04/turn (+0.25 vs bosses if you've killed 3+), clamped 0.5–2.4. Later turns and boss phases may combine two patterns.

## Bosses
`phases` list in `enemies.json`. A phase triggers at `hp_below` **or** at `turn` — so a pacifist who only talks still sees every phase. Each phase can set patterns, taunts, talk overrides, `companion_lines`, and raises music intensity. `mercy_per_turn` lets bosses soften as you endure.

**The Archivist:** 170 HP, 3 phases (pages+rain → pages/beam/orbit → pages/gravity/teleport/mines). Spare route: Question in phase 2 (it reveals you were filed), Comfort in phase 3.

**Future bosses** (designs): *Forgotten King* — box shape changes each turn. *Puppeteer* — takes control of a companion's summon and uses it against you. *Hollow Beast* — multi-screen, 5 phases. *Final boss* — builds its patterns from `GameState.history`.

## Progression
XP curve: 10, 30, 60, 100, 160, 240, 350, 500, 700, 1000. Each level: +4 max HP, +2 ATK, +1 DEF, 1 talent point. Sparing gives 50% XP so pacifist players still grow.

## Adding an enemy
```json
"my_enemy": {
  "name": "...", "sprite": "...", "hp": 30, "atk": 5, "def": 1, "xp": 9, "shards": 5,
  "difficulty": 1.0, "patterns": ["rain", "wave"], "bg": "#3a2050",
  "intro": "...", "flavor": ["..."], "taunts": ["..."],
  "talk": {"comfort": {"text": "...", "reply": "...", "mercy": 40}},
  "spare_text": "...", "kill_text": "..."
}
```
Then place `{"type": "enemy", "id": "unique_id", "enemy": "my_enemy", "x": 5, "y": 5}` on a map.
