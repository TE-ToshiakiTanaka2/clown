#!/usr/bin/env python3
"""Deterministic high-detail pixel-art generator for the clown platformer.

Every runtime PNG is authored from integer-aligned primitives and a restrained
shared palette.  The output is RGBA8, has no timestamps or random data, and is
byte-identical across runs.  Only the Python standard library is required.

Run:
    python3 game/tools/gen_sprites.py
"""
from __future__ import annotations

import struct
import zlib
from pathlib import Path
from typing import Dict, Iterable, List, Sequence, Tuple

Color = Tuple[int, int, int, int]
Grid = List[List[Color]]
Point = Tuple[int, int]

TOOLS_DIR = Path(__file__).resolve().parent
GAME_DIR = TOOLS_DIR.parent
SPRITES_DIR = GAME_DIR / "assets" / "sprites"

TRANSPARENT: Color = (0, 0, 0, 0)
OUTLINE: Color = (20, 30, 52, 255)
OUTLINE_SOFT: Color = (34, 44, 68, 255)
WHITE: Color = (248, 244, 226, 255)
CREAM: Color = (238, 205, 148, 255)
SKIN: Color = (238, 174, 116, 255)
SKIN_LIGHT: Color = (255, 209, 153, 255)
SKIN_SHADOW: Color = (190, 112, 76, 255)
RED: Color = (207, 52, 48, 255)
RED_LIGHT: Color = (242, 91, 57, 255)
RED_DARK: Color = (130, 34, 45, 255)
GOLD: Color = (242, 179, 50, 255)
GOLD_LIGHT: Color = (255, 230, 116, 255)
GOLD_DARK: Color = (178, 109, 30, 255)
BLUE: Color = (43, 93, 164, 255)
BLUE_LIGHT: Color = (67, 134, 196, 255)
BLUE_DARK: Color = (31, 55, 111, 255)
BROWN: Color = (132, 76, 43, 255)
BROWN_LIGHT: Color = (201, 126, 68, 255)
BROWN_DARK: Color = (82, 45, 36, 255)
GREEN: Color = (60, 151, 67, 255)
GREEN_LIGHT: Color = (116, 190, 79, 255)
GREEN_DARK: Color = (34, 91, 55, 255)
PURPLE: Color = (92, 60, 145, 255)
PURPLE_LIGHT: Color = (157, 104, 190, 255)
PURPLE_DARK: Color = (55, 39, 94, 255)
ORANGE: Color = (218, 96, 35, 255)
ORANGE_LIGHT: Color = (245, 153, 53, 255)
ORANGE_DARK: Color = (145, 57, 34, 255)
METAL: Color = (69, 82, 107, 255)
METAL_LIGHT: Color = (126, 143, 160, 255)
METAL_DARK: Color = (40, 48, 70, 255)
EMBER: Color = (244, 72, 29, 255)
EMBER_LIGHT: Color = (255, 231, 91, 255)


# ---------------------------------------------------------------------------
# Minimal PNG writer: RGBA8, filter 0, one deterministic IDAT.
# ---------------------------------------------------------------------------

def _chunk(tag: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + tag
        + data
        + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    )


def write_png(path: Path, pixels: Grid) -> None:
    if not pixels or not pixels[0]:
        raise ValueError(f"{path.name}: empty grid")
    height = len(pixels)
    width = len(pixels[0])
    for row in pixels:
        if len(row) != width:
            raise ValueError(f"{path.name}: ragged grid")
    raw = bytearray()
    for row in pixels:
        raw.append(0)
        for color in row:
            raw += bytes(channel & 0xFF for channel in color)
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    png = bytearray(b"\x89PNG\r\n\x1a\n")
    png += _chunk(b"IHDR", ihdr)
    png += _chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += _chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(bytes(png))


# ---------------------------------------------------------------------------
# Integer-aligned drawing helpers.  Curves are raster masks, never antialiased.
# ---------------------------------------------------------------------------

def canvas(width: int, height: int) -> Grid:
    return [[TRANSPARENT for _ in range(width)] for _ in range(height)]


def set_pixel(grid: Grid, x: int, y: int, color: Color) -> None:
    if 0 <= y < len(grid) and 0 <= x < len(grid[0]):
        grid[y][x] = color


def fill_rect(grid: Grid, x0: int, y0: int, x1: int, y1: int, color: Color) -> None:
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            set_pixel(grid, x, y, color)


def fill_ellipse(grid: Grid, cx: float, cy: float, rx: float, ry: float, color: Color) -> None:
    if rx <= 0 or ry <= 0:
        return
    for y in range(max(0, int(cy - ry - 1)), min(len(grid), int(cy + ry + 2))):
        for x in range(max(0, int(cx - rx - 1)), min(len(grid[0]), int(cx + rx + 2))):
            dx = (x + 0.5 - cx) / rx
            dy = (y + 0.5 - cy) / ry
            if dx * dx + dy * dy <= 1.0:
                grid[y][x] = color


def _inside_polygon(x: float, y: float, points: Sequence[Point]) -> bool:
    inside = False
    j = len(points) - 1
    for i, (xi, yi) in enumerate(points):
        xj, yj = points[j]
        if (yi > y) != (yj > y):
            crossing_x = (xj - xi) * (y - yi) / float(yj - yi) + xi
            if x < crossing_x:
                inside = not inside
        j = i
    return inside


def fill_polygon(grid: Grid, points: Sequence[Point], color: Color) -> None:
    if len(points) < 3:
        return
    min_x = max(0, min(x for x, _ in points))
    max_x = min(len(grid[0]) - 1, max(x for x, _ in points))
    min_y = max(0, min(y for _, y in points))
    max_y = min(len(grid) - 1, max(y for _, y in points))
    for y in range(min_y, max_y + 1):
        for x in range(min_x, max_x + 1):
            if _inside_polygon(x + 0.5, y + 0.5, points):
                grid[y][x] = color


def add_outline(grid: Grid, color: Color = OUTLINE) -> Grid:
    out = [row[:] for row in grid]
    height, width = len(grid), len(grid[0])
    for y in range(height):
        for x in range(width):
            if grid[y][x][3] != 0:
                continue
            for oy in (-1, 0, 1):
                for ox in (-1, 0, 1):
                    if ox == 0 and oy == 0:
                        continue
                    nx, ny = x + ox, y + oy
                    if 0 <= nx < width and 0 <= ny < height and grid[ny][nx][3] != 0:
                        out[y][x] = color
                        break
                if out[y][x][3] != 0:
                    break
    return out


def mirror(grid: Grid) -> Grid:
    return [row[::-1] for row in grid]


def mirror_below(grid: Grid, first_row: int) -> Grid:
    """Mirror a pose below the face so animation never changes gaze direction."""
    out = [row[:] for row in grid]
    for y in range(first_row, len(out)):
        out[y] = out[y][::-1]
    return out


def stamp_pixels(grid: Grid, pixels: Iterable[Tuple[int, int, Color]]) -> None:
    for x, y, color in pixels:
        set_pixel(grid, x, y, color)


# ---------------------------------------------------------------------------
# Original circus acrobat hero. SMALL is 24x24, SUPER is 24x32.
# ---------------------------------------------------------------------------

def player_frame(pose: str, *, super_form: bool = False, death: bool = False) -> Grid:
    width, height = 24, 32 if super_form else 24
    g = canvas(width, height)
    floor_y = height - 2
    torso_top = 13 if super_form else 11
    torso_bottom = 23 if super_form else 17

    if pose == "stride":
        fill_rect(g, 6, torso_bottom - 1, 10, floor_y - 3, BLUE_DARK)
        fill_rect(g, 14, torso_bottom - 1, 18, floor_y - 5, BLUE)
        fill_rect(g, 3, floor_y - 3, 9, floor_y - 1, BROWN_DARK)
        fill_rect(g, 16, floor_y - 5, 21, floor_y - 3, BROWN_DARK)
    elif pose == "jump":
        fill_rect(g, 7, torso_bottom - 1, 11, floor_y - 5, BLUE_DARK)
        fill_rect(g, 13, torso_bottom - 1, 17, floor_y - 5, BLUE)
        fill_rect(g, 4, floor_y - 6, 10, floor_y - 4, BROWN_DARK)
        fill_rect(g, 15, floor_y - 6, 20, floor_y - 4, BROWN_DARK)
    else:
        fill_rect(g, 7, torso_bottom - 1, 11, floor_y - 2, BLUE_DARK)
        fill_rect(g, 13, torso_bottom - 1, 17, floor_y - 2, BLUE)
        fill_rect(g, 5, floor_y - 2, 11, floor_y - 1, BROWN_DARK)
        fill_rect(g, 13, floor_y - 2, 19, floor_y - 1, BROWN_DARK)

    # Shirt, sash, suspenders and swinging arms.
    fill_rect(g, 7, torso_top, 17, torso_bottom, RED)
    fill_rect(g, 8, torso_top, 10, torso_bottom, RED_LIGHT)
    fill_rect(g, 7, torso_bottom - 4, 17, torso_bottom - 3, GOLD)
    fill_rect(g, 10, torso_bottom - 2, 14, torso_bottom, BLUE)
    if pose == "stride":
        fill_rect(g, 3, torso_top + 1, 7, torso_top + 4, RED_DARK)
        fill_rect(g, 2, torso_top + 4, 5, torso_top + 6, SKIN_LIGHT)
        fill_rect(g, 17, torso_top - 1, 20, torso_top + 3, RED)
        fill_rect(g, 19, torso_top - 3, 21, torso_top, SKIN_LIGHT)
    else:
        fill_rect(g, 4, torso_top + 1, 7, torso_top + 5, RED_DARK)
        fill_rect(g, 3, torso_top + 5, 6, torso_top + 7, SKIN_LIGHT)
        fill_rect(g, 17, torso_top + 1, 20, torso_top + 5, RED)
        fill_rect(g, 19, torso_top + 5, 22, torso_top + 7, SKIN_LIGHT)

    # Head, hair and cap.
    fill_ellipse(g, 12, 8, 6, 5, SKIN)
    fill_rect(g, 6, 6, 8, 10, BROWN_DARK)
    fill_rect(g, 7, 9, 9, 12, BROWN)
    fill_rect(g, 8, 4, 17, 5, RED_DARK)
    fill_ellipse(g, 12, 3.8, 7, 3.7, RED)
    fill_rect(g, 7, 5, 20, 7, RED_DARK)
    fill_rect(g, 8, 2, 13, 3, RED_LIGHT)
    stamp_pixels(g, [(12, 2, GOLD_LIGHT), (11, 3, GOLD), (12, 3, GOLD), (13, 3, GOLD)])
    if death:
        stamp_pixels(g, [(13, 8, OUTLINE), (15, 8, OUTLINE), (14, 9, OUTLINE)])
        fill_rect(g, 11, 11, 15, 11, OUTLINE)
    else:
        fill_rect(g, 14, 7, 15, 9, WHITE)
        set_pixel(g, 15, 8, OUTLINE)
        set_pixel(g, 17, 11, RED_DARK)
        set_pixel(g, 10, 10, SKIN_LIGHT)
    outlined = add_outline(g)
    if death:
        # A compact tilted silhouette reads better than only closing the eyes.
        outlined = mirror(outlined)
    return outlined


def build_player_sprites() -> Dict[str, Grid]:
    return {
        "player_idle": player_frame("idle"),
        "player_run_0": player_frame("stride"),
        "player_run_1": player_frame("idle"),
        "player_run_2": mirror_below(player_frame("stride"), 11),
        "player_jump": player_frame("jump"),
        "player_death": player_frame("idle", death=True),
        "super_idle": player_frame("idle", super_form=True),
        "super_run_0": player_frame("stride", super_form=True),
        "super_run_1": player_frame("idle", super_form=True),
        "super_run_2": mirror_below(player_frame("stride", super_form=True), 13),
        "super_jump": player_frame("jump", super_form=True),
    }


# ---------------------------------------------------------------------------
# Ground enemies (24x24).
# ---------------------------------------------------------------------------

def goomba_frame(step: int, *, squashed: bool = False) -> Grid:
    g = canvas(24, 24)
    if squashed:
        fill_ellipse(g, 12, 18, 9, 3, BROWN)
        fill_rect(g, 5, 18, 18, 20, CREAM)
        fill_rect(g, 7, 16, 16, 17, BROWN_LIGHT)
        fill_rect(g, 4, 21, 10, 22, BROWN_DARK)
        fill_rect(g, 14, 21, 20, 22, BROWN_DARK)
        return add_outline(g)
    foot_offsets = [(-1, 1), (0, 0), (1, -1)][step]
    fill_rect(g, 3 + foot_offsets[0], 20, 10 + foot_offsets[0], 22, BROWN_DARK)
    fill_rect(g, 14 + foot_offsets[1], 20, 21 + foot_offsets[1], 22, BROWN_DARK)
    fill_ellipse(g, 12, 15, 7, 7, CREAM)
    fill_rect(g, 6, 16, 17, 19, SKIN_SHADOW)
    fill_ellipse(g, 12, 8, 10, 7, BROWN)
    fill_ellipse(g, 10, 6, 6, 4, BROWN_LIGHT)
    fill_rect(g, 3, 10, 20, 13, BROWN_DARK)
    fill_rect(g, 7, 10, 10, 14, WHITE)
    fill_rect(g, 14, 10, 17, 14, WHITE)
    fill_rect(g, 9, 11, 10, 14, OUTLINE)
    fill_rect(g, 14, 11, 15, 14, OUTLINE)
    fill_rect(g, 6, 9, 10, 10, OUTLINE)
    fill_rect(g, 14, 9, 18, 10, OUTLINE)
    set_pixel(g, 12, 17, BROWN_DARK)
    return add_outline(g)


def turtle_frame(step: int, *, shell_only: bool = False) -> Grid:
    g = canvas(24, 24)
    if shell_only:
        fill_ellipse(g, 12, 16, 9, 6, GREEN_DARK)
        fill_ellipse(g, 12, 14, 8, 6, GREEN)
        fill_polygon(g, [(6, 15), (12, 9), (18, 15), (12, 20)], GREEN_LIGHT)
        fill_rect(g, 5, 19, 19, 21, GOLD_DARK)
        return add_outline(g)
    feet = [(4, 19, 8), (12, 19, 16), (7, 20, 11)][step]
    fill_rect(g, feet[0], feet[1], feet[2], 22, GOLD_DARK)
    fill_rect(g, 14, 20, 19, 22, GOLD_DARK)
    fill_ellipse(g, 10, 13, 8, 8, GREEN_DARK)
    fill_ellipse(g, 9, 11, 7, 7, GREEN)
    fill_polygon(g, [(4, 12), (9, 5), (15, 12), (9, 18)], GREEN_LIGHT)
    fill_rect(g, 4, 16, 15, 18, GOLD)
    fill_ellipse(g, 18, 13, 4, 5, CREAM)
    fill_rect(g, 18, 11, 21, 14, WHITE)
    fill_rect(g, 20, 12, 21, 14, OUTLINE)
    set_pixel(g, 21, 16, GOLD_DARK)
    return add_outline(g)


def build_ground_enemy_sprites() -> Dict[str, Grid]:
    return {
        "goomba_walk_0": goomba_frame(0),
        "goomba_walk_1": goomba_frame(1),
        "goomba_walk_2": goomba_frame(2),
        "goomba_squashed": goomba_frame(1, squashed=True),
        "turtle_walk_0": turtle_frame(0),
        "turtle_walk_1": turtle_frame(1),
        "turtle_walk_2": turtle_frame(2),
        "turtle_shell": turtle_frame(1, shell_only=True),
    }


# ---------------------------------------------------------------------------
# SwoopBat, Spiny and Cannon families.
# ---------------------------------------------------------------------------

def bat_frame(wing: int, *, dive: bool = False, defeated: bool = False) -> Grid:
    g = canvas(24, 24)
    if dive:
        fill_polygon(g, [(8, 8), (3, 4), (6, 15), (10, 18)], PURPLE_DARK)
        fill_polygon(g, [(16, 8), (21, 4), (18, 15), (14, 18)], PURPLE)
    else:
        tips = [3, 7, 11]
        tip_y = tips[wing]
        fill_polygon(g, [(10, 10), (6, 7), (1, tip_y), (3, 15), (9, 18)], PURPLE)
        fill_polygon(g, [(14, 10), (18, 7), (23, tip_y), (21, 15), (15, 18)], PURPLE_DARK)
        fill_polygon(g, [(6, 9), (2, tip_y + 2), (5, 15), (9, 14)], PURPLE_LIGHT)
    fill_ellipse(g, 12, 13, 5, 7, PURPLE_DARK)
    fill_ellipse(g, 12, 10, 4, 4, PURPLE)
    fill_polygon(g, [(9, 8), (9, 3), (12, 7)], PURPLE_LIGHT)
    fill_polygon(g, [(15, 8), (15, 3), (12, 7)], PURPLE)
    fill_rect(g, 9, 10, 11, 12, GOLD_LIGHT)
    fill_rect(g, 13, 10, 15, 12, GOLD_LIGHT)
    set_pixel(g, 11, 11, OUTLINE)
    set_pixel(g, 13, 11, OUTLINE)
    fill_rect(g, 10, 15, 14, 16, SKIN_SHADOW)
    set_pixel(g, 12, 16, OUTLINE)
    if defeated:
        g = list(reversed(g))
    return add_outline(g)


def spiny_frame(step: int, state: str = "walk") -> Grid:
    g = canvas(24, 24)
    if state == "windup":
        body_y = 15
        head_x = 18
    else:
        body_y = 13
        head_x = 19
    foot_shift = [-1, 0, 1][step]
    fill_rect(g, 3 + foot_shift, 19, 9 + foot_shift, 22, BROWN_DARK)
    fill_rect(g, 13, 19, 20, 22, BROWN_DARK)
    fill_ellipse(g, 11, body_y, 9, 7, ORANGE_DARK)
    fill_ellipse(g, 10, body_y - 2, 8, 6, ORANGE)
    fill_ellipse(g, head_x, 15, 4, 4, CREAM)
    fill_rect(g, head_x, 13, 21, 15, WHITE)
    set_pixel(g, 21, 14, OUTLINE)
    spikes = [(4, 10, 6, 3, 8, 10), (9, 7, 11, 1, 13, 7), (14, 9, 17, 3, 18, 11)]
    for x1, y1, x2, y2, x3, y3 in spikes:
        fill_polygon(g, [(x1, y1), (x2, y2), (x3, y3)], WHITE)
    fill_rect(g, 6, body_y - 1, 13, body_y, ORANGE_LIGHT)
    if state == "charge":
        fill_rect(g, 1, 20, 3, 21, CREAM)
        set_pixel(g, 0, 19, GOLD_LIGHT)
    return add_outline(g)


def cannon_frame(state: str) -> Grid:
    g = canvas(24, 24)
    glow = EMBER_LIGHT if state == "fire" else EMBER if state.startswith("warning") else METAL_DARK
    fill_rect(g, 3, 18, 20, 21, METAL_DARK)
    fill_rect(g, 5, 8, 15, 18, METAL)
    fill_rect(g, 7, 7, 13, 9, METAL_LIGHT)
    fill_rect(g, 12, 9, 21, 15, METAL)
    fill_ellipse(g, 20, 12, 3, 4, METAL_DARK)
    fill_ellipse(g, 20, 12, 2, 3, glow)
    fill_rect(g, 5, 12, 8, 15, OUTLINE_SOFT)
    fill_rect(g, 7, 13, 9, 14, METAL_LIGHT)
    fill_rect(g, 4, 19, 19, 19, METAL_LIGHT)
    if state == "warning_1":
        fill_rect(g, 17, 10, 18, 14, ORANGE)
    if state == "fire":
        set_pixel(g, 23, 10, GOLD_LIGHT)
        set_pixel(g, 23, 14, GOLD_LIGHT)
    return add_outline(g)


def ember_frame(frame: int) -> Grid:
    g = canvas(12, 12)
    tail = 1 if frame == 0 else 2
    fill_polygon(g, [(1, 6), (4 + tail, 3), (4 + tail, 9)], EMBER)
    fill_ellipse(g, 7, 6, 4, 4, EMBER)
    fill_ellipse(g, 8, 5, 2.5, 2.5, GOLD)
    fill_ellipse(g, 9, 5, 1.2, 1.2, EMBER_LIGHT)
    return add_outline(g)


def build_new_enemy_sprites() -> Dict[str, Grid]:
    return {
        "bat_fly_0": bat_frame(0),
        "bat_fly_1": bat_frame(1),
        "bat_fly_2": bat_frame(2),
        "bat_dive": bat_frame(1, dive=True),
        "bat_defeated": bat_frame(1, defeated=True),
        "spiny_walk_0": spiny_frame(0),
        "spiny_walk_1": spiny_frame(1),
        "spiny_walk_2": spiny_frame(2),
        "spiny_windup": spiny_frame(1, "windup"),
        "spiny_charge": spiny_frame(2, "charge"),
        "cannon_idle": cannon_frame("idle"),
        "cannon_warning_0": cannon_frame("warning_0"),
        "cannon_warning_1": cannon_frame("warning_1"),
        "cannon_fire": cannon_frame("fire"),
        "ember_0": ember_frame(0),
        "ember_1": ember_frame(1),
    }


# ---------------------------------------------------------------------------
# Coins, power-ups and flag. Existing geometry contracts remain 16px.
# ---------------------------------------------------------------------------

def coin_frame(half_width: float) -> Grid:
    g = canvas(16, 16)
    fill_ellipse(g, 7.5, 7.5, half_width, 6.5, GOLD_DARK)
    fill_ellipse(g, 7.5, 7.0, max(0.8, half_width - 1.2), 5.2, GOLD)
    if half_width > 2:
        fill_rect(g, 6, 3, 7, 10, GOLD_LIGHT)
        set_pixel(g, 8, 12, ORANGE_DARK)
    return add_outline(g)


def mushroom_frame(green: bool) -> Grid:
    g = canvas(16, 16)
    main = GREEN if green else RED
    light = GREEN_LIGHT if green else RED_LIGHT
    dark = GREEN_DARK if green else RED_DARK
    fill_ellipse(g, 8, 6, 7, 5, main)
    fill_rect(g, 2, 6, 13, 8, dark)
    fill_ellipse(g, 5, 4, 2, 2, WHITE)
    fill_ellipse(g, 11, 5, 1.5, 2, light)
    fill_rect(g, 5, 8, 11, 14, CREAM)
    fill_rect(g, 6, 9, 7, 11, WHITE)
    fill_rect(g, 9, 9, 10, 11, WHITE)
    set_pixel(g, 7, 10, OUTLINE)
    set_pixel(g, 9, 10, OUTLINE)
    return add_outline(g)


def flag_sprite() -> Grid:
    g = canvas(16, 48)
    fill_rect(g, 4, 2, 6, 47, METAL)
    fill_rect(g, 5, 2, 5, 47, METAL_LIGHT)
    fill_ellipse(g, 5, 2, 3, 2, GOLD)
    fill_polygon(g, [(7, 4), (15, 7), (10, 11), (15, 15), (7, 16)], RED)
    fill_polygon(g, [(7, 12), (15, 15), (7, 16)], RED_DARK)
    fill_rect(g, 8, 5, 9, 13, RED_LIGHT)
    return add_outline(g)


def build_pickup_sprites() -> Dict[str, Grid]:
    half_widths = [6.0, 3.5, 1.2, 3.5]
    sprites = {f"coin_{i}": coin_frame(width) for i, width in enumerate(half_widths)}
    sprites.update({"mushroom": mushroom_frame(False), "one_up": mushroom_frame(True)})
    sprites["flag"] = flag_sprite()
    return sprites


# ---------------------------------------------------------------------------
# 16x16 tile atlas. Same coordinates as the existing four stage scenes.
# ---------------------------------------------------------------------------

TILE_SIZE = 16
TILE_COLUMNS = 8
TILE_ROWS = 2
GRASS = (82, 177, 79, 255)
GRASS_LIGHT = (133, 211, 96, 255)
GRASS_DARK = (45, 119, 60, 255)
DIRT = (150, 96, 52, 255)
DIRT_LIGHT = (197, 133, 69, 255)
DIRT_DARK = (92, 54, 43, 255)
BRICK = (177, 79, 50, 255)
BRICK_LIGHT = (224, 123, 67, 255)
BRICK_DARK = (103, 43, 42, 255)
QBLOCK = (230, 157, 42, 255)
QBLOCK_LIGHT = (255, 220, 91, 255)
QBLOCK_DARK = (157, 89, 31, 255)
PIPE = (49, 149, 76, 255)
PIPE_LIGHT = (110, 205, 101, 255)
PIPE_DARK = (27, 91, 58, 255)
CLOUD = (248, 244, 226, 255)
CLOUD_SHADE = (190, 210, 214, 255)
DARK_DIRT = (74, 55, 78, 255)
DARK_DIRT_LIGHT = (112, 79, 107, 255)
DARK_DIRT_DARK = (43, 35, 57, 255)


def solid_tile(color: Color) -> Grid:
    return [[color for _ in range(TILE_SIZE)] for _ in range(TILE_SIZE)]


def tile_ground_grass() -> Grid:
    g = solid_tile(DIRT)
    fill_rect(g, 0, 0, 15, 2, GRASS_LIGHT)
    fill_rect(g, 0, 3, 15, 5, GRASS)
    for x in range(0, 16, 4):
        fill_polygon(g, [(x, 5), (x + 2, 8), (x + 3, 5)], GRASS_DARK)
    for y in range(7, 16):
        for x in range(16):
            if (x * 5 + y * 3) % 13 == 0:
                g[y][x] = DIRT_LIGHT
            elif (x * 3 + y * 7) % 17 == 0:
                g[y][x] = DIRT_DARK
    return g


def tile_dirt() -> Grid:
    g = solid_tile(DIRT)
    for y in range(16):
        for x in range(16):
            if (x * 5 + y * 3) % 13 == 0:
                g[y][x] = DIRT_LIGHT
            elif (x * 3 + y * 7) % 17 == 0:
                g[y][x] = DIRT_DARK
    return g


def tile_brick(dark: bool = False) -> Grid:
    base = DARK_DIRT_LIGHT if dark else BRICK
    light = DARK_DIRT if dark else BRICK_LIGHT
    line = DARK_DIRT_DARK if dark else BRICK_DARK
    g = solid_tile(base)
    for y in range(16):
        for x in range(16):
            offset = 4 if (y // 4) % 2 else 0
            if y % 4 == 0 or (x + offset) % 8 == 0:
                g[y][x] = line
            elif y % 4 == 1:
                g[y][x] = light
    return g


def tile_question(bright: bool) -> Grid:
    g = solid_tile(QBLOCK if bright else GOLD_DARK)
    fill_rect(g, 1, 1, 14, 2, QBLOCK_LIGHT if bright else QBLOCK)
    fill_rect(g, 1, 13, 14, 14, QBLOCK_DARK)
    fill_rect(g, 1, 1, 2, 14, QBLOCK_DARK)
    fill_rect(g, 13, 1, 14, 14, QBLOCK_DARK)
    mark = [(6, 4), (7, 4), (8, 4), (9, 5), (9, 6), (7, 7), (7, 8), (7, 10)]
    for x, y in mark:
        set_pixel(g, x, y, WHITE)
        set_pixel(g, x + 1, y, WHITE)
    return g


def tile_used() -> Grid:
    g = solid_tile(BROWN)
    fill_rect(g, 0, 0, 15, 1, BROWN_LIGHT)
    fill_rect(g, 0, 14, 15, 15, BROWN_DARK)
    fill_rect(g, 0, 0, 1, 15, BROWN_DARK)
    fill_rect(g, 14, 0, 15, 15, BROWN_DARK)
    return g


def tile_pipe(quadrant: str) -> Grid:
    g = solid_tile(PIPE)
    is_top = quadrant[0] == "t"
    is_left = quadrant[1] == "l"
    if is_top:
        fill_rect(g, 0, 0, 15, 2, PIPE_LIGHT)
        fill_rect(g, 0, 13, 15, 15, PIPE_DARK)
    if is_left:
        fill_rect(g, 1, 0, 4, 15, PIPE_LIGHT)
    else:
        fill_rect(g, 12, 0, 15, 15, PIPE_DARK)
    return g


def tile_cloud(half: str) -> Grid:
    g = canvas(16, 16)
    offset = 0 if half == "left" else 16
    for y in range(3, 14):
        for x in range(16):
            dx = (x + offset - 15.5) / 14.0
            dy = (y - 8.0) / 5.5
            if dx * dx + dy * dy <= 1.0:
                g[y][x] = CLOUD_SHADE if y >= 11 else CLOUD
    return g


def tile_bush() -> Grid:
    g = canvas(16, 16)
    fill_ellipse(g, 8, 12, 8, 5, GREEN_DARK)
    fill_ellipse(g, 5, 10, 4, 5, GREEN)
    fill_ellipse(g, 11, 10, 4, 5, GREEN_LIGHT)
    fill_rect(g, 2, 13, 13, 15, GREEN_DARK)
    return g


def tile_dark_dirt() -> Grid:
    g = solid_tile(DARK_DIRT)
    for y in range(16):
        for x in range(16):
            if (x * 5 + y * 3) % 13 == 0:
                g[y][x] = DARK_DIRT_LIGHT
            elif (x * 3 + y * 7) % 17 == 0:
                g[y][x] = DARK_DIRT_DARK
    return g


def build_tile_atlas() -> Grid:
    empty = canvas(16, 16)
    layout = [
        [tile_ground_grass(), tile_dirt(), tile_brick(), tile_question(True),
         tile_question(False), tile_used(), tile_pipe("tl"), tile_pipe("tr")],
        [tile_pipe("bl"), tile_pipe("br"), tile_cloud("left"), tile_cloud("right"),
         tile_bush(), tile_dark_dirt(), tile_brick(True), empty],
    ]
    atlas = canvas(TILE_COLUMNS * TILE_SIZE, TILE_ROWS * TILE_SIZE)
    for row_index, row in enumerate(layout):
        for column_index, tile in enumerate(row):
            for y in range(TILE_SIZE):
                for x in range(TILE_SIZE):
                    atlas[row_index * TILE_SIZE + y][column_index * TILE_SIZE + x] = tile[y][x]
    return atlas


# ---------------------------------------------------------------------------
# Entry point.
# ---------------------------------------------------------------------------

def main() -> None:
    sprites: Dict[str, Grid] = {}
    sprites.update(build_player_sprites())
    sprites.update(build_ground_enemy_sprites())
    sprites.update(build_new_enemy_sprites())
    sprites.update(build_pickup_sprites())
    sprites["tiles"] = build_tile_atlas()
    for name, grid in sorted(sprites.items()):
        write_png(SPRITES_DIR / f"{name}.png", grid)
    print(f"Wrote {len(sprites)} sprite(s) to {SPRITES_DIR}")


if __name__ == "__main__":
    main()
