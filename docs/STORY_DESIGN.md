# Story Design Document

## Premise
The Hollow Between is where forgotten things go: memories, unfinished stories, people nobody thinks about anymore. You fall into it with no memory. Over the game you learn the truth — **you weren't lost. You were filed. On purpose. By request.** The final question of the game is whose request, and why (the Secret ending reveals: your own).

**Tone:** gentle, funny, melancholy. Enemies are frightened rather than evil. Humor keeps the sadness light.

## Themes
- Being remembered vs. remembering
- Mercy as understanding — you spare people by *learning who they were*
- The cost of erasing things (kills are "erasures"; the world notices)

## Characters
| Character | Role |
|---|---|
| **{player}** | Fell into the Hollow. Default name Wren. |
| **Echo** | A living memory fragment — "a footprint that wants to walk somewhere." Healer companion. Loyalty drops when you kill. Personal quest (Ch2): who was she? |
| **The Clockmaker** | Lanternrest's tinkerer. Time & puzzles. Refuses to join if you've killed 3+. |
| **The Wanderer** *(Ch2)* | High damage, mysterious past, Silent City. |
| **Nyra** *(Ch3)* | Light powers; her summon raises mercy. |
| **Mira & Pip** | Siblings separated by forgetting. Reuniting them is Chapter 1's heart. |
| **The Archivist** | Keeper of every forgotten record. Lonely. First boss. |
| **The Unfinished** | A half-drawn figure in a secret area. The game's creator, still waiting. |

## World
| Region | Identity | Status |
|---|---|---|
| Memory Forest | Living memories, Lostlings | **Chapter 1 — playable** |
| Silent City | Abandoned civilization, no sound | Ch2 |
| Glass Desert | Reflection puzzles | Ch3 |
| Broken Observatory | Time distortions | Ch4 |
| Dreaming Ocean | Reality unstable | Ch5 |
| Heart of the Hollow | Endgame | Finale |

## Chapter 1 beats
1. Wake in the glade; Echo finds you (trust / question / walk away; recruit or go alone — if alone, she follows anyway and you choose again).
2. Whispering Path: Lostlings, a Thornmoth, Pip lost by a tree, a stone puzzle guarding a secret.
3. Lanternrest: the stopped clock (Clockmaker quest), Mira (Pip quest), a nervous villager who's heard about you if you've been killing, a forgetful shopkeeper.
4. Either quest earns a light that never flickers → the path north opens.
5. The Archive Grove: Ink Shades, then the Archivist, who reads your kill/spare count aloud.
6. Spare → it gives you a blank page and tells you that you were filed. Kill → a half-burned page that says FILED, and Echo is shaken.

## Endings
| Ending | Chapter 1 condition |
|---|---|
| **Developer Mystery** | Named WARDEN, asked the Unfinished all 3 questions, and already seen any ending on this device |
| **Secret** | True Hope conditions + found the hidden hollow's shard + finished the Unfinished's conversation |
| **True Hope** | 0 kills, Archivist spared, both quests done, Echo loyalty ≥ 40 |
| **Corruption** | 4+ kills, or Archivist killed with 3+ kills |
| **Isolation** | No companions with you and helped no one |
| **Balance** | Everything else |

The full game keeps these six and adds conditions per chapter (companion endings, faction betrayals, saved settlements).

## Writing dialogue
`data/dialogue/<id>.json`:
```json
{
  "start": "start",
  "portraits": {"Echo": "echo"},
  "voices": {"Echo": 1.35},
  "nodes": {
    "start": {"branch": [{"if": "flag:met", "next": "again"}, {"next": "hello"}]},
    "hello": {
      "speaker": "Echo",
      "text": ["Line one.", "Line two, {player}."],
      "do": {"set": {"met": true}},
      "choices": [
        {"text": "Trust her.", "do": {"loyalty": {"echo": 15}}, "next": "trust"},
        {"text": "Secret option", "if": "item:shard", "next": "secret"}
      ]
    }
  }
}
```
Node keys: `speaker`, `portrait`, `text` (string or list of pages), `next`, `choices`, `branch`, `if`/`else`, `do` (effects), `battle` (start a fight afterward), `event` (`chapter_end`, `refresh`, `heal`, `title`). Placeholders: `{player}`, `{spared}`, `{killed}`.

Style: short lines (≤ 2 sentences per page), one joke per scene, let silence land.
