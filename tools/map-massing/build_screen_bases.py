"""Massing bases to draw over: buildings as axis-aligned rectangular prisms,
roads as axis-aligned bands, in the vertical-oblique projection the game art
uses (ground read top-down, facades read front-on).

Screen coords: x east, y south, z up.  sx = x*PX_PER_M, sy = y*PX_PER_M - z*PX_PER_M*HEIGHT_K
"""
import json, math, os, statistics, sys
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SCRATCH = HERE
REPO = os.path.dirname(os.path.dirname(HERE))
OUT_DIR = os.path.join(REPO, "screen_bases")
os.makedirs(OUT_DIR, exist_ok=True)

# ---- tunables -------------------------------------------------------------
PX_PER_M = 4.0        # ground scale
HEIGHT_K = 1.1        # building heights squashed toward JRPG proportions
SOFT_H_M = 18.0       # heights past this compress, so towers stay drawable
TAPER_H = 0.2
SCREEN_K = 0.65       # shrinks every screen's extent off the requested tiles
CELL_M = 2.0          # rasterization / snap grid for building decomposition
MIN_RECT_M = 6.0      # drop prism slivers below this
MAX_RECTS = 6         # prisms per building
PLAYER_PX = 35        # on-screen character height, for the scale legend
PLAYER_BOX = (16, 6)  # overworld_collision.tres, in plate pixels
PLAYER_FOOT = 14      # ...and how far below the sprite origin it sits

# ---- palette (flat, low chroma; meant to be painted over) -----------------
C_OPEN     = (178, 176, 170)   # unspecified ground: neutral, not lawn
C_GRASS    = (138, 162, 128)
C_PLAZA    = (198, 194, 186)
C_SIDEWALK = (196, 193, 186)
C_ROAD     = (128, 128, 134)
C_ROAD_LN  = (208, 206, 196)
C_TOP      = (206, 202, 196)
C_FRONT    = (150, 146, 142)
C_OUTLINE  = (58, 56, 60)
C_BASE_LN  = (108, 106, 110)
C_TEXT     = (40, 38, 44)
C_GRID     = (0, 0, 0, 40)


def mpx(m):
    """metres -> plate pixels, so the placement margins below survive a retune"""
    return m * PX_PER_M


FONT_PATH = os.path.join(REPO, "assets/fonts/PixelOperator-Bold.ttf")
try:
    FONT = ImageFont.truetype(FONT_PATH, 16)
    FONT_S = ImageFont.truetype(FONT_PATH, 12)
except OSError:
    FONT = FONT_S = ImageFont.load_default()

# ---- rotation into the flattened Toronto grid -----------------------------
streets_raw = json.load(open(os.path.join(SCRATCH, "osm_streets.json"), encoding="utf-8"))
LAT0 = 43.6640
M_LON = 111320.0 * math.cos(math.radians(LAT0))
M_LAT = 110574.0
M_PER_TILE = 7.5
MARGIN = 8


def to_m(lon, lat):
    return (lon * M_LON, -lat * M_LAT)


_y = []
for el in streets_raw["elements"]:
    if el.get("tags", {}).get("name") == "Yonge Street":
        _y.extend(to_m(g["lon"], g["lat"]) for g in el.get("geometry", []))
_ys = [p[1] for p in _y]
_xs = [p[0] for p in _y]
my, mx = statistics.mean(_ys), statistics.mean(_xs)
a = sum((y - my) * (x - mx) for x, y in zip(_xs, _ys)) / sum((y - my) ** 2 for y in _ys)
theta = math.atan(a)
ct, st = math.cos(theta), math.sin(theta)


def rot(p):
    x, y = p[0] - mx, p[1] - my
    return (x * ct - y * st, x * st + y * ct)


def ll_to_grid(lon, lat):
    return rot(to_m(lon, lat))


def street_pts(names):
    pts = []
    for el in streets_raw["elements"]:
        if el.get("tags", {}).get("name") in names:
            pts.extend(ll_to_grid(g["lon"], g["lat"]) for g in el.get("geometry", []))
    return pts


bloor_y = statistics.median(p[1] for p in street_pts(["Bloor Street West", "Bloor Street East"]))
college_y = statistics.median(p[1] for p in street_pts(["College Street"]))
spadina_x = statistics.median(
    p[0] for p in street_pts(["Spadina Avenue", "Spadina Crescent"])
    if bloor_y < p[1] < college_y)


def tile_to_m(tx, ty):
    """master tile (pre-SCALE, 7.5 m) -> rotated meters"""
    return ((tx - MARGIN) * M_PER_TILE + spadina_x, (ty - MARGIN) * M_PER_TILE + bloor_y)


# ---- street bands ---------------------------------------------------------
# north half: reuse the hand-tuned flattened table
map_data = json.load(open(os.path.join(REPO, "assets/scripts/tools/toronto_map_data.json"),
                          encoding="utf-8"))
bands = []  # (orient, pos_m, half_width_m, start_m, end_m, name)
for key, s in map_data["streets"].items():
    pos_m = tile_to_m(s["pos"], s["pos"])[0 if s["orient"] == "NS" else 1]
    if s["orient"] == "EW":
        pos_m = tile_to_m(0, s["pos"])[1]
        lo = tile_to_m(s["start"], 0)[0]
        hi = tile_to_m(s["end"], 0)[0]
    else:
        pos_m = tile_to_m(s["pos"], 0)[0]
        lo = tile_to_m(0, s["start"])[1]
        hi = tile_to_m(0, s["end"])[1]
    bands.append([s["orient"], pos_m, s["width"] * M_PER_TILE / 2.0, lo, hi, key])

# south half (Yonge / Eaton Centre): flatten fresh into the same frame
WIDTH_BY_HW = {"primary": 14.0, "secondary": 12.0, "tertiary": 11.0,
               "residential": 9.0, "unclassified": 9.0, "living_street": 8.0,
               "pedestrian": 7.0}
eaton = json.load(open(os.path.join(SCRATCH, "osm_eaton_streets.json"), encoding="utf-8"))
by_name = {}
for el in eaton["elements"]:
    t = el.get("tags", {})
    name = t.get("name")
    if not name:
        continue
    pts = [ll_to_grid(g["lon"], g["lat"]) for g in el.get("geometry", [])]
    pts = [p for p in pts if p[1] > college_y + 40]  # south of the existing map only
    if len(pts) < 2:
        continue
    rec = by_name.setdefault(name, {"pts": [], "hw": t.get("highway")})
    rec["pts"].extend(pts)

for name, rec in by_name.items():
    pts = rec["pts"]
    if len(pts) < 2:
        continue
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    ew = (max(xs) - min(xs)) > (max(ys) - min(ys))
    w = WIDTH_BY_HW.get(rec["hw"], 9.0)
    if ew:
        bands.append(["EW", statistics.median(ys), w / 2, min(xs), max(xs), name])
    else:
        bands.append(["NS", statistics.median(xs), w / 2, min(ys), max(ys), name])

# ---- buildings ------------------------------------------------------------
DEFAULT_H = {"house": 7, "retail": 8, "commercial": 14, "apartments": 26,
             "office": 30, "university": 16, "hospital": 24, "church": 14,
             "school": 12, "industrial": 10, "parking": 12, "hotel": 30,
             "yes": 12}
SKIP_B = {"roof", "bridge", "service", "terrace", "carport", "shed"}

all_b = json.load(open(os.path.join(SCRATCH, "osm_all_buildings.json"), encoding="utf-8"))


def height_of(t):
    h = t.get("height")
    if h:
        try:
            v = float(str(h).split()[0])
            if v > 2:
                return v
        except ValueError:
            pass
    lv = t.get("building:levels")
    if lv:
        try:
            v = float(str(lv).split(";")[0]) * 3.5 + 1.5
            if v > 2:
                return v
        except ValueError:
            pass
    return DEFAULT_H.get(t.get("building"), 12)


def squash(h):
    return h if h <= SOFT_H_M else SOFT_H_M + (h - SOFT_H_M) * TAPER_H


subway = []
_sub_path = os.path.join(SCRATCH, "osm_subway.json")
if os.path.exists(_sub_path):
    for el in json.load(open(_sub_path, encoding="utf-8"))["elements"]:
        subway.append({"p": ll_to_grid(el["lon"], el["lat"]),
                       "name": el.get("tags", {}).get("name", "")})

GREEN_KEYS = {"park", "garden", "grass", "forest", "recreation_ground",
              "wood", "pitch", "playground"}
ground_polys = []
for el in json.load(open(os.path.join(SCRATCH, "osm_ground.json"), encoding="utf-8"))["elements"]:
    geom = el.get("geometry")
    if not geom or len(geom) < 4:
        continue
    t = el["tags"]
    kind = (t.get("leisure") or t.get("landuse") or t.get("natural")
            or t.get("place") or t.get("highway"))
    ring = [ll_to_grid(g["lon"], g["lat"]) for g in geom]
    xs = [p[0] for p in ring]
    ys = [p[1] for p in ring]
    ground_polys.append({
        "ring": ring,
        "color": C_GRASS if kind in GREEN_KEYS else C_PLAZA,
        "area": (max(xs) - min(xs)) * (max(ys) - min(ys)),
        "bbox": (min(xs), min(ys), max(xs), max(ys)),
    })
ground_polys.sort(key=lambda g: -g["area"])

buildings = []
for el in all_b["elements"]:
    t = el.get("tags", {})
    if t.get("building") in SKIP_B:
        continue
    geom = el.get("geometry")
    if not geom or len(geom) < 4:
        continue
    ring = [ll_to_grid(g["lon"], g["lat"]) for g in geom]
    xs = [p[0] for p in ring]
    ys = [p[1] for p in ring]
    hgt = height_of(t)
    if (max(xs) - min(xs)) * (max(ys) - min(ys)) > 2000 and hgt < 11:
        hgt = 11  # big-footprint blocks tagged implausibly flat
    buildings.append({
        "id": el["id"], "ring": ring, "h": squash(hgt),
        "name": t.get("name"),
        "bbox": (min(xs), min(ys), max(xs), max(ys)),
    })
print(f"{len(buildings)} buildings, {len(bands)} street bands")


# ---- polygon -> axis-aligned prisms ---------------------------------------
def point_in_ring(px, py, ring):
    inside = False
    n = len(ring)
    for i in range(n):
        x1, y1 = ring[i]
        x2, y2 = ring[(i + 1) % n]
        if (y1 > py) != (y2 > py):
            xint = (x2 - x1) * (py - y1) / (y2 - y1) + x1
            if px < xint:
                inside = not inside
    return inside


def largest_rect(grid, w, h):
    """maximal all-True axis-aligned rect in a boolean grid -> (x0,y0,x1,y1) exclusive"""
    best = (0, 0, 0, 0, 0)  # area,x0,y0,x1,y1
    heights = [0] * w
    for y in range(h):
        row = grid[y]
        for x in range(w):
            heights[x] = heights[x] + 1 if row[x] else 0
        stack = []
        for x in range(w + 1):
            cur = heights[x] if x < w else 0
            start = x
            while stack and stack[-1][1] >= cur:
                sx, sh = stack.pop()
                area = sh * (x - sx)
                if area > best[0]:
                    best = (area, sx, y - sh + 1, x, y + 1)
                start = sx
            stack.append((start, cur))
    return best


def decompose(ring):
    x0 = math.floor(min(p[0] for p in ring) / CELL_M) * CELL_M
    y0 = math.floor(min(p[1] for p in ring) / CELL_M) * CELL_M
    x1 = math.ceil(max(p[0] for p in ring) / CELL_M) * CELL_M
    y1 = math.ceil(max(p[1] for p in ring) / CELL_M) * CELL_M
    w = max(1, int(round((x1 - x0) / CELL_M)))
    h = max(1, int(round((y1 - y0) / CELL_M)))
    if w * h > 40000:
        return [(x0, y0, x1, y1)]
    grid = [[point_in_ring(x0 + (cx + 0.5) * CELL_M, y0 + (cy + 0.5) * CELL_M, ring)
             for cx in range(w)] for cy in range(h)]
    rects = []
    for _ in range(MAX_RECTS):
        area, ax, ay, bx, by = largest_rect(grid, w, h)
        if area == 0:
            break
        rw = (bx - ax) * CELL_M
        rh = (by - ay) * CELL_M
        if rw < MIN_RECT_M or rh < MIN_RECT_M:
            break
        rects.append((x0 + ax * CELL_M, y0 + ay * CELL_M,
                      x0 + bx * CELL_M, y0 + by * CELL_M))
        for cy in range(ay, by):
            for cx in range(ax, bx):
                grid[cy][cx] = False
    if not rects:
        rects = [(x0, y0, x1, y1)]
    return rects


# ---- view rotation --------------------------------------------------------
# The visible facade is always a prism's max-Y (screen-south) side, so rotating
# the world in 90 deg steps chooses which compass face fronts the camera.
FACING_K = {"S": 0, "W": 1, "N": 2, "E": 3}


def make_t(facing):
    k = FACING_K[facing]
    if k == 0:
        return lambda x, y: (x, y)
    if k == 1:
        return lambda x, y: (y, -x)
    if k == 2:
        return lambda x, y: (-x, -y)
    return lambda x, y: (-y, x)


def t_rect(T, x0, y0, x1, y1):
    pts = [T(x0, y0), T(x1, y0), T(x0, y1), T(x1, y1)]
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    return min(xs), min(ys), max(xs), max(ys)


def t_band(band, T, k):
    orient, pos, half, lo, hi, key = band
    if orient == "EW":
        r = t_rect(T, lo, pos - half, hi, pos + half)
    else:
        r = t_rect(T, pos - half, lo, pos + half, hi)
    new_orient = orient if k % 2 == 0 else ("NS" if orient == "EW" else "EW")
    if new_orient == "EW":
        return [new_orient, (r[1] + r[3]) / 2, half, r[0], r[2], key]
    return [new_orient, (r[0] + r[2]) / 2, half, r[1], r[3], key]


# ---- screens --------------------------------------------------------------
band_pos = {}
for orient, pos, half, lo, hi, key in bands:
    band_pos.setdefault(key, (orient, pos))


def m_to_tile(x, y):
    return ((x - spadina_x) / M_PER_TILE + MARGIN, (y - bloor_y) / M_PER_TILE + MARGIN)


def named(sub):
    hits = [b for b in buildings if b["name"] and sub.lower() in b["name"].lower()]
    if not hits:
        raise KeyError(sub)
    b = max(hits, key=lambda b: (b["bbox"][2] - b["bbox"][0]) * (b["bbox"][3] - b["bbox"][1]))
    return b["bbox"]


# Which compass face fronts the camera, i.e. which elevation you actually draw.
# Unlisted screens keep "S" (north-up). Chosen from tagged entrance counts where
# OSM has them, else the building's public frontage.
FACING = {
    "rom": "N",                # Lee-Chin Crystal fronts Bloor on the north
    "sidney_smith": "W",       # main entrance onto St George
    "convocation": "E",        # portico faces King's College Circle
    "gardiner": "W",
    "eaton_dundas": "E",       # 10 tagged entrances on Yonge vs 2 on the west
    "eaton_mid": "E",
    "eaton_queen": "E",
    "stn_bloor_yonge": "N",    # Bloor's retail frontage is the north side
    "stn_bay": "N",
}

# the fronted face sits this far down the plate, so the near half of the screen
# is the street you walk on and the far half is the mass you drew
FRONT_F = 0.55
# (bbox axis, sign) of the face the camera sees
FRONT_AXIS = {"S": (1, 1), "N": (1, -1), "E": (0, 1), "W": (0, -1)}


def extent(name, w, h):
    w, h = max(8, round(w * SCREEN_K)), max(8, round(h * SCREEN_K))
    # a 90 deg facing swaps the world axes, so swap the requested extent to keep
    # the plate landscape and the long frontage across the width
    if FACING.get(name, "S") in ("E", "W"):
        return h, w
    return w, h


def screen_on_building(name, sub, w, h, dx=0.0, dy=0.0):
    w, h = extent(name, w, h)
    bbox = named(sub)
    axis, sign = FRONT_AXIS[FACING.get(name, "S")]
    front = bbox[axis + 2] if sign > 0 else bbox[axis]
    span = (h if axis else w) * M_PER_TILE
    mid = [(bbox[0] + bbox[2]) / 2, (bbox[1] + bbox[3]) / 2]
    mid[axis] = front + sign * span * (0.5 - FRONT_F)
    cx, cy = m_to_tile(mid[0], mid[1])
    return (round(cx - w / 2 + dx), round(cy - h / 2 + dy), w, h)


def screen_on_xing(name, ew_key, ns_key, w, h, dx=0.0, dy=0.0):
    w, h = extent(name, w, h)
    ey = band_pos[ew_key][1]
    nx = band_pos[ns_key][1]
    cx, cy = m_to_tile(nx, ey)
    return (round(cx - w / 2 + dx), round(cy - h / 2 + dy), w, h)


SCREENS = {
    "rom":                screen_on_building("rom", "Royal Ontario Museum", 30, 26),
    "victoria_college":   screen_on_building("victoria_college", "Victoria College", 26, 22),
    "robarts":            screen_on_building("robarts", "Robarts Library", 28, 24),
    "sidney_smith":       screen_on_building("sidney_smith", "Sidney Smith Hall", 26, 22),
    "university_college": screen_on_building("university_college", "University College", 30, 26),
    "convocation":        screen_on_building("convocation", "Convocation Hall", 28, 24, dx=2, dy=4),
    "queens_park_lawn":   screen_on_building("queens_park_lawn", "Ontario Legislative", 32, 28),
    "stn_st_george":      screen_on_xing("stn_st_george", "bloor", "st_george", 26, 22),
    "stn_bay":            screen_on_xing("stn_bay", "bloor", "bay", 26, 22),
    "stn_bloor_yonge":    screen_on_xing("stn_bloor_yonge", "bloor", "yonge", 26, 22),
    "stn_wellesley":      screen_on_xing("stn_wellesley", "wellesley", "yonge", 26, 22),
    "stn_museum":         screen_on_xing("stn_museum", "bloor", "queens_park_n", 26, 22, dy=8),
    "stn_queens_park":    screen_on_xing("stn_queens_park", "college", "university", 28, 24),
    "eaton_dundas":       screen_on_xing("eaton_dundas", "Dundas Street West", "Yonge Street", 28, 24),
    "eaton_mid":          screen_on_xing("eaton_mid", "Dundas Street West", "Yonge Street", 28, 24, dy=22),
    "eaton_queen":        screen_on_xing("eaton_queen", "Queen Street West", "Yonge Street", 28, 24, dy=-4),
}


def render(name, rect_tiles, grid_overlay, facing="S"):
    tx, ty, tw, th = rect_tiles
    ax0, ay0 = tile_to_m(tx, ty)
    ax1, ay1 = tile_to_m(tx + tw, ty + th)
    T = make_t(facing)
    k = FACING_K[facing]
    wx0, wy0, wx1, wy1 = t_rect(T, ax0, ay0, ax1, ay1)
    world_w, world_h = wx1 - wx0, wy1 - wy0

    def overlaps(bb):
        return bb[2] > ax0 and bb[0] < ax1 and bb[3] > ay0 and bb[1] < ay1

    vis_buildings = []
    tall = 0.0
    for b in buildings:
        if not overlaps(b["bbox"]):
            continue
        ring = [T(px, py) for px, py in b["ring"]]
        xs = [p[0] for p in ring]
        ys = [p[1] for p in ring]
        vis_buildings.append({"id": b["id"], "ring": ring, "h": b["h"],
                              "name": b["name"],
                              "bbox": (min(xs), min(ys), max(xs), max(ys))})
        tall = max(tall, b["h"])
    vis_ground = []
    for gp in ground_polys:
        if not overlaps(gp["bbox"]):
            continue
        vis_ground.append({"ring": [T(px, py) for px, py in gp["ring"]],
                           "color": gp["color"]})
    vis_bands = [t_band(b, T, k) for b in bands]

    pad_top = tall * PX_PER_M * HEIGHT_K
    W = int(round(world_w * PX_PER_M))
    H = int(round(world_h * PX_PER_M + pad_top))

    def sx(x):
        return (x - wx0) * PX_PER_M

    def sy(y, z=0.0):
        return (y - wy0) * PX_PER_M + pad_top - z * PX_PER_M * HEIGHT_K

    img = Image.new("RGB", (W, H), C_OPEN)
    d = ImageDraw.Draw(img)

    # land cover (parks, lawns, plazas) before the street bands
    for gp in vis_ground:
        d.polygon([(sx(px), sy(py)) for px, py in gp["ring"]], fill=gp["color"])

    # ground: sidewalk aprons, then asphalt, then centre lines
    for pass_i in (0, 1):
        for orient, pos, half, lo, hi, key in vis_bands:
            sw = 5.0 if half >= 6 else 3.5
            hw = half + (sw if pass_i == 0 else 0)
            col = C_SIDEWALK if pass_i == 0 else C_ROAD
            if orient == "EW":
                if pos + hw < wy0 or pos - hw > wy1:
                    continue
                a0, a1 = max(lo, wx0), min(hi, wx1)
                if a1 <= a0:
                    continue
                d.rectangle([sx(a0), sy(pos - hw), sx(a1), sy(pos + hw)], fill=col)
            else:
                if pos + hw < wx0 or pos - hw > wx1:
                    continue
                a0, a1 = max(lo, wy0), min(hi, wy1)
                if a1 <= a0:
                    continue
                d.rectangle([sx(pos - hw), sy(a0), sx(pos + hw), sy(a1)], fill=col)
    for orient, pos, half, lo, hi, key in vis_bands:
        if orient == "EW":
            if pos < wy0 - half or pos > wy1 + half:
                continue
            y = sy(pos)
            x = max(lo, wx0)
            while x < min(hi, wx1):
                d.line([sx(x), y, sx(min(x + 3.0, wx1)), y], fill=C_ROAD_LN, width=2)
                x += 6.0
        else:
            if pos < wx0 - half or pos > wx1 + half:
                continue
            x = sx(pos)
            y = max(lo, wy0)
            while y < min(hi, wy1):
                d.line([x, sy(y), x, sy(min(y + 3.0, wy1))], fill=C_ROAD_LN, width=2)
                y += 6.0

    # prisms, painter-sorted by south edge
    prisms = []
    labels = []
    for b in vis_buildings:
        bx0, by0, bx1, by1 = b["bbox"]
        for (rx0, ry0, rx1, ry1) in decompose(b["ring"]):
            prisms.append((ry1, rx0, ry0, rx1, b["h"], b["id"]))
        if b["name"]:
            # clamp into the visible slice so big footprints still get labelled
            vx0, vx1 = max(bx0, wx0 + 6), min(bx1, wx1 - 6)
            vy0, vy1 = max(by0, wy0 + 6), min(by1, wy1 - 6)
            if vx1 > vx0 and vy1 > vy0:
                labels.append((b["name"], (vx0 + vx1) / 2, (vy0 + vy1) / 2, b["h"]))
    prisms.sort(key=lambda p: p[0])

    for (ry1, rx0, ry0, rx1, hgt, bid) in prisms:
        # taller massing reads lighter on top, so height is legible at a glance
        lift = int(min(38, hgt * 1.1))
        tint = (bid * 37) % 16 - 8
        top = tuple(max(0, min(255, c + tint + lift)) for c in C_TOP)
        front = tuple(max(0, min(255, c + tint)) for c in C_FRONT)
        d.polygon([(sx(rx0), sy(ry1)), (sx(rx1), sy(ry1)),
                   (sx(rx1), sy(ry1, hgt)), (sx(rx0), sy(ry1, hgt))],
                  fill=front, outline=C_OUTLINE)
        d.polygon([(sx(rx0), sy(ry0, hgt)), (sx(rx1), sy(ry0, hgt)),
                   (sx(rx1), sy(ry1, hgt)), (sx(rx0), sy(ry1, hgt))],
                  fill=top, outline=C_OUTLINE)
        # base line where the facade meets the ground
        d.line([sx(rx0), sy(ry1), sx(rx1), sy(ry1)], fill=C_OUTLINE, width=2)

    for text, lx, ly, lh in labels:
        d.text((sx(lx), sy(ly, lh)), text, font=FONT_S, fill=C_TEXT,
               anchor="mm", stroke_width=2, stroke_fill=(236, 234, 230))

    # ---- gameplay metadata in plate pixel coords --------------------------
    # the drawn mass hides the ground north of a prism, so the solid region is
    # the whole box (roof top down to base), not just the ground footprint
    collision = []
    for (ry1, rx0, ry0, rx1, hgt, bid) in prisms:
        cx0, cy0 = sx(rx0), sy(ry0, hgt)
        cx1, cy1 = sx(rx1), sy(ry1)
        if cx1 - cx0 >= mpx(1.0) and cy1 - cy0 >= mpx(1.0):
            collision.append([round(cx0), round(cy0), round(cx1), round(cy1)])

    pad_px = mpx(1.0)
    step_px = max(4, int(mpx(2.0)))
    edge_px = int(max(mpx(3.0), PLAYER_BOX[0]))

    # the collider sits below the origin, so a point test drops feet into walls
    def blocked(px, py):
        bx0 = px - PLAYER_BOX[0] / 2 - pad_px
        bx1 = px + PLAYER_BOX[0] / 2 + pad_px
        by0 = py + PLAYER_FOOT - PLAYER_BOX[1] / 2 - pad_px
        by1 = py + PLAYER_FOOT + PLAYER_BOX[1] / 2 + pad_px
        for c in collision:
            if c[0] < bx1 and c[2] > bx0 and c[1] < by1 and c[3] > by0:
                return True
        return False

    spawn = None
    best_d = 1e18
    for gy in range(int(pad_top) + edge_px, H - edge_px, step_px):
        for gx in range(edge_px, W - edge_px, step_px):
            if blocked(gx, gy):
                continue
            dd = (gx - W / 2) ** 2 + (gy - (pad_top + H) / 2) ** 2
            if dd < best_d:
                best_d, spawn = dd, [gx, gy]
    if spawn is None:
        spawn = [round(W / 2), round((pad_top + H) / 2)]

    stations = []
    for s in subway:
        wxp, wyp = T(*s["p"])
        if not (wx0 < wxp < wx1 and wy0 < wyp < wy1):
            continue
        px, py = round(sx(wxp)), round(sy(wyp))
        # edge-hugging entrances are unreachable behind the bounds walls
        keep = mpx(6.0)
        if px < keep or px > W - keep or py < pad_top + keep or py > H - keep:
            continue
        if blocked(px, py):
            continue
        if any(abs(px - q[0]) < mpx(5.0) and abs(py - q[1]) < mpx(5.0) for q in stations):
            continue
        stations.append([px, py])
    if not stations:
        # no tagged entrance here; synthesise one so the screen is never a dead end
        for off in (mpx(11), mpx(16), mpx(21), mpx(7.5)):
            cand = [round(spawn[0] + off), spawn[1]]
            if cand[0] < W - edge_px and not blocked(*cand):
                stations.append(cand)
                break
        if not stations:
            stations.append(list(spawn))
    for px, py in stations:
        d.ellipse([px - 13, py - 13, px + 13, py + 13], fill=(46, 44, 50),
                  outline=(236, 234, 230), width=2)
        d.text((px, py), "M", font=FONT, fill=(240, 238, 234), anchor="mm")

    img.save(os.path.join(OUT_DIR, name + ".png"))

    if grid_overlay:
        g = img.convert("RGBA")
        go = Image.new("RGBA", g.size, (0, 0, 0, 0))
        gd = ImageDraw.Draw(go)
        # ground footprints: where collision goes, hidden under the massing
        for (ry1, rx0, ry0, rx1, hgt, bid) in prisms:
            gd.rectangle([sx(rx0), sy(ry0), sx(rx1), sy(ry1)],
                         outline=(196, 64, 48, 150), width=2)
        step = 10.0 * PX_PER_M
        x = 0.0
        while x < W:
            gd.line([x, 0, x, H], fill=C_GRID, width=1)
            x += step
        y = pad_top
        while y < H:
            gd.line([0, y, W, y], fill=C_GRID, width=1)
            y += step
        # legend: 10 m bar + player height reference
        gd.rectangle([12, H - 40, 12 + step, H - 34], fill=(30, 30, 34, 230))
        gd.text((12, H - 60), "10 m", font=FONT, fill=(20, 20, 24, 255))
        gd.rectangle([12 + step + 20, H - 34 - PLAYER_PX, 12 + step + 36, H - 34],
                     fill=(40, 70, 150, 230))
        gd.text((12 + step + 44, H - 34 - PLAYER_PX), "player", font=FONT_S, fill=(20, 20, 24, 255))
        Image.alpha_composite(g, go).convert("RGB").save(
            os.path.join(OUT_DIR, name + "_grid.png"))
    return {"px": [W, H], "collision": collision, "spawn": spawn,
            "stations": stations, "facing": facing,
            "world_center": [round((ax0 + ax1) / 2, 1), round((ay0 + ay1) / 2, 1)]}


only = sys.argv[1:] or None
meta = {"px_per_m": PX_PER_M, "height_k": HEIGHT_K, "screens": {}}
for name, rect in SCREENS.items():
    if only and name not in only:
        continue
    facing = FACING.get(name, "S")
    info = render(name, rect, True, facing)
    info["master_tiles"] = list(rect)
    meta["screens"][name] = info
    W, H = info["px"]
    print(f"{name}: {W}x{H}px  facing {facing}  {len(info['collision'])} colliders"
          f"  {len(info['stations'])} station(s)")
json.dump(meta, open(os.path.join(OUT_DIR, "screens.json"), "w"), indent=1)
print("done")
