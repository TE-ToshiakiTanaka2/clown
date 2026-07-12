#!/usr/bin/env python3
"""Deterministic pixel-art sprite generator for the clown platformer.

Regenerates every PNG under ``game/assets/sprites/`` from small, readable
definitions (character grids + a char -> RGBA legend, or tiny procedural
drawing helpers for regular shapes like coins and tiles). Standard library
only: PNG encoding uses ``zlib`` (DEFLATE) + ``struct`` -- no PIL / Pillow.

Run:
    python3 game/tools/gen_sprites.py

Re-running always produces byte-identical PNGs (no timestamps, no random
data, fixed zlib compression level), so the generated assets can be
committed and diffed like any other source artifact.
"""
from __future__ import annotations

import struct
import zlib
from pathlib import Path
from typing import Dict, List, Sequence, Tuple

Color = Tuple[int, int, int, int]
Grid = List[List[Color]]

TOOLS_DIR = Path(__file__).resolve().parent
GAME_DIR = TOOLS_DIR.parent
SPRITES_DIR = GAME_DIR / "assets" / "sprites"

TRANSPARENT: Color = (0, 0, 0, 0)


# ---------------------------------------------------------------------------
# Minimal PNG writer: RGBA8, filter type 0 (None) per scanline, one IDAT.
# ---------------------------------------------------------------------------

def _chunk(tag: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + tag
        + data
        + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    )


def write_png(path: Path, pixels: Grid) -> None:
    """Write an RGBA8 PNG from a row-major grid of (r, g, b, a) tuples."""
    height = len(pixels)
    width = len(pixels[0]) if height else 0
    for row in pixels:
        if len(row) != width:
            raise ValueError(f"{path.name}: ragged grid, expected width {width}, got {len(row)}")

    raw = bytearray()
    for row in pixels:
        raw.append(0)  # filter type 0 (None) for every scanline
        for (r, g, b, a) in row:
            raw += bytes((r & 0xFF, g & 0xFF, b & 0xFF, a & 0xFF))

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    idat = zlib.compress(bytes(raw), 9)

    png = bytearray(b"\x89PNG\r\n\x1a\n")
    png += _chunk(b"IHDR", ihdr)
    png += _chunk(b"IDAT", idat)
    png += _chunk(b"IEND", b"")

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(bytes(png))


# ---------------------------------------------------------------------------
# Character-grid helper: rows of equal-length strings + a char->RGBA legend.
# ---------------------------------------------------------------------------

def rows_to_grid(name: str, rows: Sequence[str], legend: Dict[str, Color]) -> Grid:
    """Convert a list of equal-width row strings into a pixel grid.

    Raises immediately (with the sprite name + row index) if a row's length
    does not match the first row -- this is the safety net that lets the
    art below be authored as plain text without silently distorting a frame.
    """
    if not rows:
        raise ValueError(f"{name}: empty sprite definition")
    width = len(rows[0])
    grid: Grid = []
    for i, line in enumerate(rows):
        if len(line) != width:
            raise ValueError(
                f"{name}: row {i} has length {len(line)}, expected {width}: {line!r}"
            )
        pixel_row: List[Color] = []
        for ch in line:
            if ch not in legend:
                raise ValueError(f"{name}: unknown legend char {ch!r} in row {i}")
            pixel_row.append(legend[ch])
        grid.append(pixel_row)
    return grid


def blank_row(width: int) -> str:
    return "." * width


def mirror_rows(rows: Sequence[str]) -> List[str]:
    """Horizontally mirror every row (used to derive a left/right pose)."""
    return [line[::-1] for line in rows]


def overlay(rows: Sequence[str], overrides: Dict[Tuple[int, int], str]) -> List[str]:
    """Return a copy of ``rows`` with individual (row, col) chars replaced.

    Used for small features (eyes, eyebrows, spots) that are easiest to place
    by coordinate rather than by re-typing an entire row of ASCII art.
    """
    out = [list(line) for line in rows]
    for (r, c), ch in overrides.items():
        out[r][c] = ch
    return ["".join(line) for line in out]


# ---------------------------------------------------------------------------
# Shared silhouette: a 5-row "dome" used by goomba/turtle/mushroom caps.
# ---------------------------------------------------------------------------

DOME5 = [
    "....XXXXXXXX....",
    "..XXXXXXXXXXXX..",
    ".XXXXXXXXXXXXXX.",
    "XXXXXXXXXXXXXXXX",
    "XXXXXXXXXXXXXXXX",
]


def dome_rows(fill_char: str) -> List[str]:
    return [line.replace("X", fill_char) for line in DOME5]


# ---------------------------------------------------------------------------
# Player (16x24): red-cap hero in blue overalls. Original design -- no logo,
# no mustache, no brand marks.
# ---------------------------------------------------------------------------

PLAYER_LEGEND: Dict[str, Color] = {
    ".": TRANSPARENT,
    "R": (196, 44, 44, 255),   # cap main
    "r": (140, 24, 24, 255),   # cap brim shadow
    "S": (247, 200, 159, 255),  # skin
    "K": (30, 24, 20, 255),    # eyes / dark details
    "B": (40, 90, 200, 255),   # overalls main
    "W": (235, 235, 235, 255),  # glove cuffs
    "O": (96, 60, 32, 255),   # shoes
}

PLAYER_TORSO = [
    "....RRRRRRRR....",  # 0 cap crown
    "..RRRRRRRRRRRR..",  # 1 cap
    ".RRRRRRRRRRRRRR.",  # 2 cap
    ".rrrrrrrrrrrrrr.",  # 3 cap brim
    "...SSSSSSSSSS...",  # 4 forehead
    "...SSKSSSKSSS...",  # 5 eyes
    "...SSSSSSSSSS...",  # 6 cheeks
    "...SSSSSSSSSS...",  # 7 mouth area
    "....SSSSSSSS....",  # 8 neck
    "..BBBBBBBBBBBB..",  # 9 shoulders
    "." + "R" + "B" * 12 + "R" + ".",  # 10 sleeve cuffs
    "." + "R" + "B" * 12 + "R" + ".",  # 11 sleeve cuffs
    "." + "B" * 14 + ".",  # 12 torso
    "W" + "B" * 14 + "W",  # 13 gloves at side
    "." + "B" * 14 + ".",  # 14 torso
    "..BBBBBBBBBBBB..",  # 15 waist
    "..BBBBBBBBBBBB..",  # 16 waist
    "...BBBBBBBBBB...",  # 17 hips
]

PLAYER_LEGS_IDLE = [
    "...BBBB..BBBB...",  # 18
    "...BBBB..BBBB...",  # 19
    "...OOOO..OOOO...",  # 20
    "...OOOO..OOOO...",  # 21
    "..OOOOO..OOOOO..",  # 22
    "................",  # 23
]

PLAYER_LEGS_RUN_MID = [
    "....BBBBBBBB....",
    "....BBBBBBBB....",
    "....OOOOOOOO....",
    "....OOOOOOOO....",
    "...OOOOOOOOOO...",
    "................",
]

PLAYER_LEGS_RUN_STRIDE = [
    "..BBBB....BBBB..",
    "..BBBB....BBBB..",
    "..OOOO....BBBB..",
    "..OOOO..........",
    ".OOOOOO.........",
    "................",
]

PLAYER_LEGS_JUMP = [
    "...BBBB..BBBB...",
    "..BBBBB..BBBBB..",
    "..OOOOO..OOOOO..",
    "................",
    "................",
    "................",
]


def _player_frame(name: str, legs: Sequence[str]) -> Grid:
    rows = list(PLAYER_TORSO) + list(legs)
    return rows_to_grid(name, rows, PLAYER_LEGEND)


def build_player_sprites() -> Dict[str, Grid]:
    idle = _player_frame("player_idle", PLAYER_LEGS_IDLE)
    run_0 = _player_frame("player_run_0", PLAYER_LEGS_RUN_STRIDE)
    run_1 = _player_frame("player_run_1", PLAYER_LEGS_RUN_MID)
    run_2 = rows_to_grid(
        "player_run_2",
        list(PLAYER_TORSO) + mirror_rows(PLAYER_LEGS_RUN_STRIDE),
        PLAYER_LEGEND,
    )
    jump = _player_frame("player_jump", PLAYER_LEGS_JUMP)

    # Death: eyes closed (flat skin row instead of the eye row), a collapsed
    # stance re-using the "legs together" mid-run pose.
    eyes_closed = PLAYER_TORSO[4]
    death_torso = list(PLAYER_TORSO)
    death_torso[5] = eyes_closed
    death_torso[6] = eyes_closed
    death = rows_to_grid(
        "player_death", death_torso + list(PLAYER_LEGS_RUN_MID), PLAYER_LEGEND
    )

    return {
        "player_idle": idle,
        "player_run_0": run_0,
        "player_run_1": run_1,
        "player_run_2": run_2,
        "player_jump": jump,
        "player_death": death,
    }


# ---------------------------------------------------------------------------
# Super player (16x24, issue #7): SMALL -> SUPER power-up variant. Visual
# only (the collision shape never changes -- see docs/design/#7/design.md).
# Derived from the SMALL torso/legs: shoulders/torso widened to the edges of
# the 16px canvas (broader silhouette) and the blank last leg row filled in
# (no dead space at the bottom), so it reads as bulkier/taller at a glance
# despite sharing the exact same 16x24 canvas as the SMALL frames.
# ---------------------------------------------------------------------------

SUPER_TORSO: List[str] = PLAYER_TORSO[0:3] + ["R" * 16] + PLAYER_TORSO[4:9] + [
    "B" * 16,                       # 9 shoulders (full width)
    "R" * 2 + "B" * 12 + "R" * 2,   # 10 sleeve cuffs (full width)
    "R" * 2 + "B" * 12 + "R" * 2,   # 11 sleeve cuffs
    "B" * 16,                       # 12 torso
    "W" + "B" * 14 + "W",           # 13 gloves at side
    "B" * 16,                       # 14 torso
    "B" * 16,                       # 15 waist
    "B" * 16,                       # 16 waist
    "." + "B" * 14 + ".",           # 17 hips (widened from the SMALL 3px margin)
]


def _fill_last_row(legs: Sequence[str]) -> List[str]:
    """Replace the trailing blank leg row with a copy of the row above it,
    so SUPER poses use the full 24px canvas instead of leaving dead space."""
    return list(legs[:-1]) + [legs[-2]]


SUPER_LEGS_IDLE = _fill_last_row(PLAYER_LEGS_IDLE)
SUPER_LEGS_RUN_MID = _fill_last_row(PLAYER_LEGS_RUN_MID)
SUPER_LEGS_RUN_STRIDE = _fill_last_row(PLAYER_LEGS_RUN_STRIDE)
SUPER_LEGS_JUMP = _fill_last_row(PLAYER_LEGS_JUMP)


def _super_player_frame(name: str, legs: Sequence[str]) -> Grid:
    rows = list(SUPER_TORSO) + list(legs)
    return rows_to_grid(name, rows, PLAYER_LEGEND)


def build_super_player_sprites() -> Dict[str, Grid]:
    idle = _super_player_frame("super_idle", SUPER_LEGS_IDLE)
    run_0 = _super_player_frame("super_run_0", SUPER_LEGS_RUN_STRIDE)
    run_1 = _super_player_frame("super_run_1", SUPER_LEGS_RUN_MID)
    run_2 = rows_to_grid(
        "super_run_2",
        list(SUPER_TORSO) + mirror_rows(SUPER_LEGS_RUN_STRIDE),
        PLAYER_LEGEND,
    )
    jump = _super_player_frame("super_jump", SUPER_LEGS_JUMP)

    return {
        "super_idle": idle,
        "super_run_0": run_0,
        "super_run_1": run_1,
        "super_run_2": run_2,
        "super_jump": jump,
    }


# ---------------------------------------------------------------------------
# Goomba (16x16): brown walking-mushroom enemy.
# ---------------------------------------------------------------------------

GOOMBA_LEGEND: Dict[str, Color] = {
    ".": TRANSPARENT,
    "M": (121, 72, 40, 255),   # cap main
    "m": (90, 52, 28, 255),   # cap shade / feet
    "C": (235, 214, 179, 255),  # underside
    "K": (24, 20, 16, 255),   # pupils / eyebrows
    "W": (250, 250, 245, 255),  # eye sclera
}

GOOMBA_BODY = dome_rows("M") + [
    "MMMMMMMMMMMMMMMM",  # 5 brow ridge (overridden below)
    "MMMMMMMMMMMMMMMM",  # 6 eyes (overridden below)
    "MMMMMMMMMMMMMMMM",  # 7 cheeks
    "MMMMMMMMMMMMMMMM",  # 8 cheeks
    "CCCCCCCCCCCCCCCC",  # 9 underside
    "CCCCCCCCCCCCCCCC",  # 10 underside
    "MMCCCCCCCCCCCCMM",  # 11 belly edge
]

GOOMBA_BROW_EYE_OVERRIDES = {
    (5, 2): "K", (5, 3): "K", (5, 11): "K", (5, 12): "K",
    (6, 3): "W", (6, 4): "K", (6, 11): "K", (6, 12): "W",
}

GOOMBA_FEET_A = [
    "MM............MM",
    "MM............MM",
    "................",
]

GOOMBA_FEET_B = [
    "..MM........MM..",
    "..MM........MM..",
    "................",
]

GOOMBA_SQUASHED = [
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "..MMMMMMMMMMMM..",
    ".MMMMMMMMMMMMMM.",
    "MMMMMMMMMMMMMMMM",
    "MMCCCCCCCCCCCCMM",
    "MMMMMMMMMMMMMMMM",
    "................",
]


def build_goomba_sprites() -> Dict[str, Grid]:
    body = overlay(GOOMBA_BODY, GOOMBA_BROW_EYE_OVERRIDES)
    walk_0 = rows_to_grid("goomba_walk_0", body + GOOMBA_FEET_A, GOOMBA_LEGEND)
    walk_1 = rows_to_grid("goomba_walk_1", body + GOOMBA_FEET_B, GOOMBA_LEGEND)
    squashed = rows_to_grid("goomba_squashed", GOOMBA_SQUASHED, GOOMBA_LEGEND)
    return {
        "goomba_walk_0": walk_0,
        "goomba_walk_1": walk_1,
        "goomba_squashed": squashed,
    }


# ---------------------------------------------------------------------------
# Turtle (16x16): green shelled walker, pre-generated for issue #7.
# ---------------------------------------------------------------------------

TURTLE_LEGEND: Dict[str, Color] = {
    ".": TRANSPARENT,
    "G": (46, 140, 64, 255),   # shell main
    "g": (30, 100, 46, 255),   # shell shade
    "E": (226, 214, 150, 255),  # belly / trim
    "K": (24, 20, 16, 255),   # pupils
    "W": (250, 250, 245, 255),  # eye sclera
}

TURTLE_BODY = dome_rows("G") + [
    "GGGGGGGGGGGGGGGG",  # 5
    "GGGGGGGGGGGGGGGG",  # 6 eyes (overridden below)
    "GgGGgGGGGgGGgGGG",  # 7 shell seams
    "GGGGGGGGGGGGGGGG",  # 8
    "EEEEEEEEEEEEEEEE",  # 9 belly band
    "EEEEEEEEEEEEEEEE",  # 10 belly band
    "GGEEEEEEEEEEEEGG",  # 11 belly edge
]

TURTLE_EYE_OVERRIDES = {
    (6, 2): "W", (6, 3): "K", (6, 12): "K", (6, 13): "W",
}

TURTLE_FEET_A = [
    "GG............GG",
    "GG............GG",
    "................",
]

TURTLE_FEET_B = [
    "..GG........GG..",
    "..GG........GG..",
    "................",
]

TURTLE_SHELL_ONLY = [
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "..GGGGGGGGGGGG..",
    ".GGGGGGGGGGGGGG.",
    "GGGGGGGGGGGGGGGG",
    "GGEEEEEEEEEEEEGG",
    "GGGGGGGGGGGGGGGG",
    "................",
]


def build_turtle_sprites() -> Dict[str, Grid]:
    body = overlay(TURTLE_BODY, TURTLE_EYE_OVERRIDES)
    walk_0 = rows_to_grid("turtle_walk_0", body + TURTLE_FEET_A, TURTLE_LEGEND)
    walk_1 = rows_to_grid("turtle_walk_1", body + TURTLE_FEET_B, TURTLE_LEGEND)
    shell = rows_to_grid("turtle_shell", TURTLE_SHELL_ONLY, TURTLE_LEGEND)
    return {
        "turtle_walk_0": walk_0,
        "turtle_walk_1": walk_1,
        "turtle_shell": shell,
    }


# ---------------------------------------------------------------------------
# Coin (16x16, procedural): a spinning ellipse, 4 rotation frames.
# ---------------------------------------------------------------------------

COIN_GOLD = (255, 210, 64, 255)
COIN_GOLD_DARK = (206, 150, 34, 255)
COIN_GOLD_LIGHT = (255, 240, 170, 255)

# Half-width (in px) of the ellipse at each of the 4 spin frames: wide side
# view -> narrow -> edge-on sliver -> narrow (mirrors frame 1 to keep the
# rotation reading as continuous when looped 0-1-2-3-0).
COIN_HALF_WIDTHS = [6.0, 3.5, 1.2, 3.5]


def build_coin_frame(half_width: float) -> Grid:
    size = 16
    cx, cy = 7.5, 7.5
    ry = 6.5
    grid: Grid = [[TRANSPARENT] * size for _ in range(size)]
    for y in range(size):
        for x in range(size):
            dx = (x - cx) / half_width if half_width > 0 else 999.0
            dy = (y - cy) / ry
            dist = dx * dx + dy * dy
            if dist <= 1.0:
                if dist <= 0.35:
                    grid[y][x] = COIN_GOLD_LIGHT
                elif dist >= 0.75:
                    grid[y][x] = COIN_GOLD_DARK
                else:
                    grid[y][x] = COIN_GOLD
    return grid


def build_coin_sprites() -> Dict[str, Grid]:
    return {
        f"coin_{i}": build_coin_frame(hw) for i, hw in enumerate(COIN_HALF_WIDTHS)
    }


# ---------------------------------------------------------------------------
# Power-up items (16x16): mushroom + 1-up, sharing the dome silhouette.
# ---------------------------------------------------------------------------

def build_mushroom_grid(name: str, cap: str, cap_shade: str, spot: str) -> Grid:
    legend: Dict[str, Color] = {
        ".": TRANSPARENT,
        "R": (215, 60, 50, 255) if cap == "R" else (60, 160, 70, 255),
        "r": (150, 34, 30, 255) if cap == "R" else (36, 110, 46, 255),
        "W": (250, 250, 245, 255),
        "C": (238, 220, 185, 255),
    }
    body = dome_rows("R")
    body = overlay(
        body,
        {
            (1, 4): "W", (1, 5): "W",
            (2, 10): "W", (2, 11): "W",
            (3, 7): "W",
        },
    )
    rows = body + [
        "rrrrrrrrrrrrrrrr",  # 5 rim shade
        "..CCCCCCCCCCCC..",  # 6 stem top
        "...CCCCCCCCCC...",  # 7 stem
        "...CCCCCCCCCC...",  # 8 stem
        "...CCCCCCCCCC...",  # 9 stem
        blank_row(16),
        blank_row(16),
        blank_row(16),
        blank_row(16),
        blank_row(16),
        blank_row(16),
    ]
    return rows_to_grid(name, rows, legend)


def build_item_sprites() -> Dict[str, Grid]:
    return {
        "mushroom": build_mushroom_grid("mushroom", "R", "r", "W"),
        "one_up": build_mushroom_grid("one_up", "G", "g", "W"),
    }


# ---------------------------------------------------------------------------
# Flag (16x48, procedural): pole + tapering pennant near the top.
# ---------------------------------------------------------------------------

FLAG_POLE = (200, 200, 205, 255)
FLAG_POLE_CAP = (235, 200, 90, 255)
FLAG_CLOTH = (235, 90, 70, 255)
FLAG_CLOTH_DARK = (190, 60, 48, 255)


def build_flag_sprite() -> Grid:
    width, height = 16, 48
    pole_x0, pole_x1 = 5, 7  # 2px pole
    grid: Grid = [[TRANSPARENT] * width for _ in range(height)]

    for y in range(height):
        for x in range(pole_x0, pole_x1):
            grid[y][x] = FLAG_POLE

    # Gold ball cap on top of the pole.
    grid[0][pole_x0] = FLAG_POLE_CAP
    grid[0][pole_x1 - 1] = FLAG_POLE_CAP

    # Tapering pennant, attached at the pole, pointing right and down.
    flag_top, flag_span = 2, 13
    for i in range(flag_span):
        y = flag_top + i
        cloth_width = flag_span - i
        color = FLAG_CLOTH_DARK if i == flag_span - 1 else FLAG_CLOTH
        for x in range(pole_x1, min(width, pole_x1 + cloth_width)):
            grid[y][x] = color

    return grid


# ---------------------------------------------------------------------------
# Tile atlas (tiles.png, procedural, 16x16 cells, 8 columns x 2 rows).
# ---------------------------------------------------------------------------

TILE_SIZE = 16
TILE_COLUMNS = 8
TILE_ROWS = 2

GRASS_TOP = (86, 176, 74, 255)
GRASS_TOP_DARK = (66, 150, 58, 255)
DIRT = (150, 106, 60, 255)
DIRT_DARK = (124, 84, 46, 255)
BRICK = (176, 92, 58, 255)
BRICK_LINE = (120, 58, 34, 255)
QBLOCK = (240, 176, 46, 255)
QBLOCK_DIM = (214, 150, 38, 255)
QBLOCK_MARK = (255, 244, 220, 255)
QUSED = (140, 108, 78, 255)
QUSED_DARK = (112, 84, 58, 255)
PIPE = (72, 176, 96, 255)
PIPE_DARK = (48, 138, 70, 255)
PIPE_LIGHT = (120, 214, 140, 255)
SKY_CLOUD = (250, 250, 252, 255)
SKY_CLOUD_SHADE = (220, 224, 232, 255)
BUSH = (58, 150, 62, 255)
BUSH_DARK = (40, 120, 48, 255)
DARK_DIRT = (74, 58, 78, 255)
DARK_DIRT_SHADE = (58, 46, 64, 255)
DARK_BRICK = (96, 60, 92, 255)
DARK_BRICK_LINE = (66, 40, 66, 255)


def _fill(color: Color) -> Grid:
    return [[color for _ in range(TILE_SIZE)] for _ in range(TILE_SIZE)]


def tile_ground_grass() -> Grid:
    grid = _fill(DIRT)
    for y in range(0, 4):
        for x in range(TILE_SIZE):
            grid[y][x] = GRASS_TOP_DARK if (y == 3 or (x + y) % 5 == 0) else GRASS_TOP
    for y in range(4, TILE_SIZE):
        for x in range(TILE_SIZE):
            if (x * 3 + y * 5) % 11 == 0:
                grid[y][x] = DIRT_DARK
    return grid


def tile_dirt() -> Grid:
    grid = _fill(DIRT)
    for y in range(TILE_SIZE):
        for x in range(TILE_SIZE):
            if (x * 3 + y * 5) % 11 == 0:
                grid[y][x] = DIRT_DARK
    return grid


def tile_brick() -> Grid:
    grid = _fill(BRICK)
    for y in range(TILE_SIZE):
        for x in range(TILE_SIZE):
            offset = 4 if (y // 4) % 2 == 0 else 0
            on_mortar_row = y % 4 == 0
            on_mortar_col = (x + offset) % 8 == 0
            if on_mortar_row or on_mortar_col:
                grid[y][x] = BRICK_LINE
    return grid


def tile_question(bright: bool) -> Grid:
    base = QBLOCK if bright else QBLOCK_DIM
    grid = _fill(base)
    for x in range(TILE_SIZE):
        grid[0][x] = QBLOCK_MARK
        grid[TILE_SIZE - 1][x] = QBLOCK_DIM
    for y in range(TILE_SIZE):
        grid[y][0] = QBLOCK_DIM
        grid[y][TILE_SIZE - 1] = QBLOCK_DIM
    # simple "?" mark using a small block of highlight pixels
    mark_cells = [
        (4, 6), (4, 7), (4, 8),
        (5, 9),
        (6, 7), (6, 8),
        (7, 6), (7, 7),
        (9, 6), (9, 7),
    ]
    for (y, x) in mark_cells:
        grid[y][x] = QBLOCK_MARK
    return grid


def tile_question_used() -> Grid:
    grid = _fill(QUSED)
    for y in range(TILE_SIZE):
        for x in range(TILE_SIZE):
            if x == 0 or y == 0 or x == TILE_SIZE - 1 or y == TILE_SIZE - 1:
                grid[y][x] = QUSED_DARK
    return grid


def tile_pipe(quadrant: str) -> Grid:
    """quadrant in {'tl', 'tr', 'bl', 'br'} for a 2x2 pipe made of 4 tiles."""
    grid = _fill(PIPE)
    is_top = quadrant[0] == "t"
    is_left = quadrant[1] == "l"
    for y in range(TILE_SIZE):
        for x in range(TILE_SIZE):
            if is_top and y == 0:
                grid[y][x] = PIPE_DARK
            if is_left and x <= 2:
                grid[y][x] = PIPE_LIGHT
            if (not is_left) and x >= TILE_SIZE - 3:
                grid[y][x] = PIPE_DARK
    return grid


def tile_cloud(half: str) -> Grid:
    # Both halves sample one 32x16 ellipse centered on the shared seam so the
    # two tiles form a single contiguous cloud when placed side by side.
    grid: Grid = [[TRANSPARENT] * TILE_SIZE for _ in range(TILE_SIZE)]
    x_offset = 0 if half == "left" else TILE_SIZE
    for y in range(4, 13):
        for x in range(TILE_SIZE):
            dx = (x + x_offset - 15.5) / 14.0
            dy = (y - 8) / 5.0
            if dx * dx + dy * dy <= 1.0:
                grid[y][x] = SKY_CLOUD_SHADE if dy > 0.4 else SKY_CLOUD
    return grid


def tile_bush() -> Grid:
    grid: Grid = [[TRANSPARENT] * TILE_SIZE for _ in range(TILE_SIZE)]
    for y in range(6, 16):
        for x in range(TILE_SIZE):
            dx = (x - 7.5) / 8.0
            dy = (y - 11) / 5.5
            if dx * dx + dy * dy <= 1.0:
                grid[y][x] = BUSH_DARK if (x + y) % 6 == 0 else BUSH
    return grid


def tile_dark_dirt() -> Grid:
    grid = _fill(DARK_DIRT)
    for y in range(TILE_SIZE):
        for x in range(TILE_SIZE):
            if (x * 3 + y * 5) % 11 == 0:
                grid[y][x] = DARK_DIRT_SHADE
    return grid


def tile_dark_brick() -> Grid:
    grid = _fill(DARK_BRICK)
    for y in range(TILE_SIZE):
        for x in range(TILE_SIZE):
            offset = 4 if (y // 4) % 2 == 0 else 0
            if y % 4 == 0 or (x + offset) % 8 == 0:
                grid[y][x] = DARK_BRICK_LINE
    return grid


# Atlas layout, 8 columns x 2 rows. Column/row indices double as the
# TileSetAtlasSource atlas coordinates used in level_1.tscn.
TILE_LAYOUT: List[List[Tuple[str, Grid]]] = [
    [
        ("ground_grass", tile_ground_grass()),
        ("dirt", tile_dirt()),
        ("brick", tile_brick()),
        ("question_0", tile_question(True)),
        ("question_1", tile_question(False)),
        ("question_used", tile_question_used()),
        ("pipe_tl", tile_pipe("tl")),
        ("pipe_tr", tile_pipe("tr")),
    ],
    [
        ("pipe_bl", tile_pipe("bl")),
        ("pipe_br", tile_pipe("br")),
        ("cloud_left", tile_cloud("left")),
        ("cloud_right", tile_cloud("right")),
        ("bush", tile_bush()),
        ("dark_dirt", tile_dark_dirt()),
        ("dark_brick", tile_dark_brick()),
        ("empty", [[TRANSPARENT] * TILE_SIZE for _ in range(TILE_SIZE)]),
    ],
]


def build_tile_atlas() -> Grid:
    width = TILE_COLUMNS * TILE_SIZE
    height = TILE_ROWS * TILE_SIZE
    atlas: Grid = [[TRANSPARENT] * width for _ in range(height)]
    for row_idx, row in enumerate(TILE_LAYOUT):
        for col_idx, (_name, tile_grid) in enumerate(row):
            for ty in range(TILE_SIZE):
                for tx in range(TILE_SIZE):
                    atlas[row_idx * TILE_SIZE + ty][col_idx * TILE_SIZE + tx] = tile_grid[ty][tx]
    return atlas


# ---------------------------------------------------------------------------
# Entry point.
# ---------------------------------------------------------------------------

def main() -> None:
    sprites: Dict[str, Grid] = {}
    sprites.update(build_player_sprites())
    sprites.update(build_super_player_sprites())
    sprites.update(build_goomba_sprites())
    sprites.update(build_turtle_sprites())
    sprites.update(build_coin_sprites())
    sprites.update(build_item_sprites())
    sprites["flag"] = build_flag_sprite()
    sprites["tiles"] = build_tile_atlas()

    for name, grid in sorted(sprites.items()):
        write_png(SPRITES_DIR / f"{name}.png", grid)

    print(f"Wrote {len(sprites)} sprite(s) to {SPRITES_DIR}")


if __name__ == "__main__":
    main()
