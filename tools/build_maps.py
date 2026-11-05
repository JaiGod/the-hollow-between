#!/usr/bin/env python3
"""Map authoring tool for The Hollow Between.

Maps are written here as plain ASCII art (easier to edit than JSON), then
exported to data/maps/<id>.json and validated: every row same width, every
spawn/entity/exit reachable on a walkable tile.

    python3 tools/build_maps.py

Legend (see scripts/art/TileBaker.gd):
  .  grass         ,  path          "  flowers       :  memory moss
  #  trees*        ~  water*        =  bridge        W  stone wall*
  f  plaza         h  house wall*   r  roof*         d  door*
  x  void*         *  starfield     b  shelves*      p  paper floor
  t  stump*        (* = solid)
"""
import json
import os
import sys

SOLID = set("#~Whrdxbt")
ROOT = os.path.join(os.path.dirname(__file__), "..", "data", "maps")

MAPS = {}

MAPS["glade_of_waking"] = {
    "name": "Glade of Waking",
    "region": "Memory Forest",
    "music": "forest",
    "outdoor": True,
    "tint": "#e8f0ff",
    "weather": "motes",
    "tiles": [
        "##########,,##############",
        "#########.,,.#############",
        "#######\"\".,,..\"\"##########",
        "#####\"\"...,,....\"\"..######",
        "####\"\"....,,.......\"\".####",
        "###\"...:::.,,....:...\"\".##",
        "###....::::.,,......::..##",
        "##.....:...,,,,.........##",
        "##........,,..,,........##",
        "##...~~~..,....,....\"\"..##",
        "##..~~~~~.,....,........##",
        "##...~~~...,..,....:....##",
        "###.........,,.....:::.###",
        "###..\"\"............::..###",
        "####..\"\"..........\"\"..####",
        "#####.......\"\"......######",
        "########.........#########",
        "##########################",
    ],
    "spawns": {"start": [12, 11, "up"], "from_forest": [10, 1, "down"]},
    "exits": [{"rect": [10, 0, 2, 1], "to": "forest_path", "spawn": "from_glade"}],
    "entities": [
        {"type": "npc", "id": "echo_glade", "sprite": "echo", "x": 15, "y": 9, "float": True, "dialogue": "echo_glade", "if": "!party:echo,!flag:echo_left"},
        {"type": "sign", "id": "glade_sign", "x": 8, "y": 3, "dialogue": "sign_glade"},
        {"type": "save", "id": "glade_lantern", "x": 17, "y": 12, "text": "A lantern burns without fuel. It feels like someone is remembering you."},
        {"type": "item", "id": "glade_berry", "item": "glowberry", "sprite": "shard", "x": 21, "y": 13, "text": "Tucked in the flowers: a Glowberry."},
    ],
}

MAPS["forest_path"] = {
    "name": "Whispering Path",
    "region": "Memory Forest",
    "music": "forest",
    "outdoor": True,
    "tint": "#dfe8ff",
    "weather": "fireflies",
    "tiles": [
        "#####################,,#################",
        "####################.,,.################",
        "###########\"\"......,,,,......###########",
        "#########\"\"........,..,........\"\"#######",
        "####.......::.....,,..,,...........#####",
        "###.........:....,,....,,.............##",
        "##.........,,,,,,,......,,,,,,,,,,,,,,,,",
        "##........,,.....................\"\"...,,",
        "##.......,,....~~~~.......:::.........##",
        "###..t...,,...~~~~~~......:::.....\"\"..##",
        ",,,,,,,,,,,...~~~~~~~...........##....##",
        "###......,,....~~~~~...........####...##",
        "###..\"\"...,,.......=.............##...##",
        "####.......,,,,,,,,=,,,,,,......\"\"....##",
        "#####..............~...,,.............##",
        "######...\"\"........~....,,....:::....###",
        "#######............~.....,,..::::...####",
        "#########.........~~~.....,,.......#####",
        "##############...~~~~~....,,.....#######",
        "##########################,,############",
    ],
    "spawns": {
        "from_glade": [26, 18, "up"],
        "from_village": [38, 6, "left"],
        "from_grove": [21, 1, "down"],
        "from_hollow": [2, 10, "right"],
    },
    "exits": [
        {"rect": [26, 19, 2, 1], "to": "glade_of_waking", "spawn": "from_forest"},
        {"rect": [39, 6, 1, 2], "to": "lanternrest", "spawn": "from_forest"},
        {"rect": [21, 0, 2, 1], "to": "archivist_grove", "spawn": "from_forest", "if": "flag:has_lantern",
         "blocked": ["The path north is pitch black. The trees lean in, whispering.", "You'll need a light that doesn't flicker. Maybe someone in Lanternrest has one."]},
        {"rect": [0, 10, 1, 1], "to": "hidden_hollow", "spawn": "start"},
    ],
    "entities": [
        {"type": "sign", "id": "stones_sign", "x": 7, "y": 7, "dialogue": "sign_stones"},
        {"type": "stone", "id": "stone_west", "puzzle": "forest_stones", "order": 1, "count": 3, "x": 4, "y": 5, "solved_flag": "puzzle.forest_stones",
         "solved_text": ["The three stones sing a single note together.", "To the west, the brambles unravel like old string."]},
        {"type": "stone", "id": "stone_east", "puzzle": "forest_stones", "order": 2, "count": 3, "x": 14, "y": 4, "solved_flag": "puzzle.forest_stones"},
        {"type": "stone", "id": "stone_water", "puzzle": "forest_stones", "order": 3, "count": 3, "x": 13, "y": 12, "solved_flag": "puzzle.forest_stones"},
        {"type": "blocker", "id": "brambles", "x": 2, "y": 10, "unless": "flag:puzzle.forest_stones", "text": "Thick brambles, woven tight. Something about them feels deliberate, like a lock."},
        {"type": "npc", "id": "pip", "sprite": "pip", "x": 31, "y": 15, "float": True, "dialogue": "pip", "if": "!flag:pip_home"},
        {"type": "item", "id": "gear", "item": "brass_gear", "sprite": "gear", "x": 36, "y": 11, "text": "A brass gear, warm as a hand. It ticks once, hopefully.", "do": {"quest_advance": "lost_gear"}},
        {"type": "enemy", "id": "fp_lostling_a", "enemy": "lostling", "x": 16, "y": 6, "wander": 28},
        {"type": "enemy", "id": "fp_lostling_b", "enemy": "lostling", "x": 26, "y": 9, "wander": 22},
        {"type": "enemy", "id": "fp_moth", "enemy": "thornmoth", "x": 30, "y": 4, "wander": 30},
        {"type": "npc", "id": "echo_path", "sprite": "echo", "x": 24, "y": 15, "float": True, "dialogue": "echo_path", "if": "!party:echo,flag:echo_left,!flag:echo_rejoined"},
    ],
}

MAPS["lanternrest"] = {
    "name": "Lanternrest",
    "region": "Memory Forest",
    "music": "village",
    "outdoor": True,
    "tint": "#fff4e8",
    "weather": "fireflies",
    "tiles": [
        "##################################",
        "##rrrrrr####rrrrrrrr####rrrrrr####",
        "##rrrrrr####rrrrrrrr####rrrrrr####",
        "##hhhdhh####hhhhdhhh####hhdhhh####",
        "##..,...\"\"...,,,,,,,...\"\"..,...\"##",
        "#...,,,,,,,,,ffffffff,,,,,,,.....#",
        "#.......,,..ffffffffff..,,.......#",
        ",,,,,,,,,...ffffffffff...,.......#",
        ",,.....,....ffffffffff...,...rrrr#",
        "#.....,.....ffffffffff...,...rrrr#",
        "#....,.......ffffffff....,...hdhh#",
        "#...\"\"....,,,,,,,,,,,,,,,,,,,,,..#",
        "#.....::.................\"\".....##",
        "##....::....~~~~~....\"\"........###",
        "###........~~~~~~~...........#####",
        "#####.......~~~~~..........#######",
        "##################################",
    ],
    "spawns": {"from_forest": [1, 7, "right"]},
    "exits": [{"rect": [0, 7, 1, 2], "to": "forest_path", "spawn": "from_village"}],
    "entities": [
        {"type": "npc", "id": "clockmaker", "sprite": "clockmaker", "x": 16, "y": 4, "dialogue": "clockmaker", "if": "!party:clockmaker", "face": True},
        {"type": "npc", "id": "mira", "sprite": "mira", "x": 26, "y": 6, "dialogue": "mira", "face": True},
        {"type": "npc", "id": "oskar", "sprite": "villager", "x": 6, "y": 5, "dialogue": "oskar", "face": True},
        {"type": "npc", "id": "juniper", "sprite": "villager", "x": 31, "y": 11, "dialogue": "juniper", "face": True, "flip": True},
        {"type": "save", "id": "village_lantern", "x": 16, "y": 8, "text": "The village lantern. Warm light pools around it like spilled honey."},
        {"type": "sign", "id": "village_sign", "x": 3, "y": 6, "dialogue": "sign_village"},
    ],
}

MAPS["archivist_grove"] = {
    "name": "The Archive Grove",
    "region": "Memory Forest",
    "music": "forest",
    "outdoor": False,
    "tint": "#d8c8b8",
    "weather": "ink",
    "tiles": [
        "##########################",
        "##bbbbbbbbbbbbbbbbbbbbbb##",
        "##bppppppppppppppppppppb##",
        "##bpppppbbbppppbbbpppppb##",
        "##bppppppppppppppppppppb##",
        "##bpppbpppppppppppppbppb##",
        "##bpppbppppppppppppbpppb##",
        "##bppppppppppppppppppppb##",
        "###bpppppppppppppppppbb###",
        "####bbbpppppppppppbbb#####",
        "######bpppppppppppb#######",
        "######b...........b#######",
        "#######....,,,....########",
        "########...,,,...#########",
        "#########..,,,..##########",
        "##########.,,,.###########",
        "###########,,,############",
        "###########,,,############",
    ],
    "spawns": {"from_forest": [12, 16, "up"]},
    "exits": [{"rect": [11, 17, 3, 1], "to": "forest_path", "spawn": "from_grove"}],
    "entities": [
        {"type": "save", "id": "grove_lantern", "x": 9, "y": 12, "text": "A lantern among the books. The pages nearby are blank, as if waiting for you."},
        {"type": "enemy", "id": "grove_shade_a", "enemy": "ink_shade", "x": 7, "y": 7, "wander": 26},
        {"type": "enemy", "id": "grove_shade_b", "enemy": "ink_shade", "x": 18, "y": 7, "wander": 26},
        {"type": "enemy", "id": "archivist", "enemy": "archivist", "x": 12, "y": 3, "wander": 0, "dialogue": "archivist_pre"},
        {"type": "sign", "id": "grove_sign", "x": 15, "y": 10, "dialogue": "sign_grove"},
    ],
}

MAPS["hidden_hollow"] = {
    "name": "Between the Between",
    "region": "???",
    "music": "title",
    "outdoor": False,
    "tint": "#c8c0ff",
    "weather": "stars",
    "tiles": [
        "xxxxxxxxxxxxxxxxxx",
        "x****************x",
        "x****************x",
        "x****************x",
        "x****************x",
        "x****************x",
        "x****************x",
        "x****************x",
        "x****************x",
        "*****************x",
        "x****************x",
        "xxxxxxxxxxxxxxxxxx",
    ],
    "spawns": {"start": [1, 9, "right"]},
    "exits": [{"rect": [0, 9, 1, 1], "to": "forest_path", "spawn": "from_hollow"}],
    "entities": [
        {"type": "npc", "id": "unfinished", "sprite": "unfinished", "x": 11, "y": 4, "float": True, "dialogue": "unfinished"},
        {"type": "item", "id": "hollow_shard", "sprite": "shard", "x": 14, "y": 8, "text": "A shard of someone's memory. It hums your name.",
         "do": {"secret": "hollow", "achievement": "secret_hollow", "give": {"memory_tonic": 1}}},
    ],
}


def validate(map_id, m):
    errors = []
    rows = m["tiles"]
    w = len(rows[0])
    for i, r in enumerate(rows):
        if len(r) != w:
            errors.append(f"row {i} width {len(r)} != {w}: {r}")
    h = len(rows)

    def tile(x, y):
        if 0 <= y < h and 0 <= x < len(rows[y]):
            return rows[y][x]
        return "#"

    def walkable(x, y):
        return tile(x, y) not in SOLID

    for name, sp in m.get("spawns", {}).items():
        if not walkable(sp[0], sp[1]):
            errors.append(f"spawn {name} at {sp[:2]} on solid '{tile(sp[0], sp[1])}'")
    for e in m.get("entities", []):
        if not walkable(e["x"], e["y"]):
            errors.append(f"entity {e.get('id')} at ({e['x']},{e['y']}) on solid '{tile(e['x'], e['y'])}'")
    for ex in m.get("exits", []):
        x, y, ew, eh = ex["rect"]
        if not any(walkable(x + i, y + j) for i in range(ew) for j in range(eh)):
            errors.append(f"exit to {ex['to']} has no walkable tile")
        if ex["to"] not in MAPS:
            errors.append(f"exit to unknown map {ex['to']}")
        elif ex.get("spawn", "start") not in MAPS[ex["to"]].get("spawns", {}):
            errors.append(f"exit to {ex['to']} uses unknown spawn {ex.get('spawn')}")

    # Reachability: flood-fill from the first spawn, treating blocking
    # entities (NPCs, signs, lanterns, stones) as walls but ignoring blockers
    # (they open later). Everything must be reachable or adjacent-reachable.
    blocking = {(e["x"], e["y"]) for e in m.get("entities", []) if e["type"] in ("npc", "sign", "save", "stone")}
    first = next(iter(m["spawns"].values()))
    seen, stack = set(), [(first[0], first[1])]
    while stack:
        x, y = stack.pop()
        if (x, y) in seen or not walkable(x, y) or (x, y) in blocking:
            continue
        seen.add((x, y))
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]

    def near(x, y):
        return any(p in seen for p in [(x, y), (x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])

    for e in m.get("entities", []):
        if not near(e["x"], e["y"]):
            errors.append(f"entity {e.get('id')} unreachable")
    for name, sp in m["spawns"].items():
        if not near(sp[0], sp[1]):
            errors.append(f"spawn {name} unreachable")
    return errors


def main():
    os.makedirs(ROOT, exist_ok=True)
    bad = False
    for map_id, m in MAPS.items():
        errs = validate(map_id, m)
        for e in errs:
            print(f"[{map_id}] {e}")
        bad = bad or bool(errs)
        with open(os.path.join(ROOT, map_id + ".json"), "w") as f:
            json.dump(m, f, indent="\t")
    print("maps:", ", ".join(MAPS), "-> FAILED" if bad else "-> OK")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
