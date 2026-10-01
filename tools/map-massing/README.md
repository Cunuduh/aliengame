# Massing bases

Generates flat massing plates for the overworld location screens — buildings as
axis-aligned rectangular prisms, roads as axis-aligned bands — meant to be
painted over, not shipped.

    python build_screen_bases.py              # all screens
    python build_screen_bases.py rom victoria_college

Needs Pillow. Output goes to `screen_bases/` at the repo root (gdignored and
gitignored). Two files per screen: `<name>.png` (clean plate) and
`<name>_grid.png` (adds a 10 m grid, red ground-footprint outlines showing where
collision goes, a 10 m scale bar and a player-height swatch).

## Projection

Vertical oblique — the JRPG convention the game art uses. Ground reads top-down,
facades read front-on:

    screen_x = x * PX_PER_M
    screen_y = y * PX_PER_M - z * PX_PER_M * HEIGHT_K

The visible facade is always a prism's max-Y (screen-south) side; its roof is the
footprint shifted up. Prisms are painter-sorted by that edge, so nearer buildings
occlude further ones.

## Facing

Screens are not locked north-up. The `FACING` dict picks which compass face
fronts the camera per screen, by rotating the world 90 deg at a time before
projection; unlisted screens default to `"S"` (north-up). Rotation is applied to
the geometry, so roads, land cover and labels all stay consistent.

| Screen | Facing | Why |
|---|---|---|
| `rom` | N | Lee-Chin Crystal fronts Bloor on the north |
| `sidney_smith` | W | main entrance onto St George |
| `convocation` | E | portico faces King's College Circle |
| `eaton_*` | E | 10 tagged entrances on Yonge vs 2 on the west; the long face |
| `stn_bay`, `stn_bloor_yonge` | N | Bloor's retail frontage is the north side |

Choices come from tagged `entrance=main`/`yes` node counts per building side
where OSM has them (`osm_entrances.json`), else the building's public frontage.
Coverage is patchy — most buildings have none — so treat these as a starting
point and edit `FACING` when a screen shows the wrong elevation.

Facing also frames the screen. A building screen is centred on the fronted face,
not on the footprint centroid: that face lands `FRONT_F` down the plate, so the
near half is the street you walk on and the far half is the mass. Without it a
tight crop on a big landmark is nothing but roof. An E/W facing swaps the world
axes, so `extent()` swaps the requested tiles to keep the plate landscape.

## Tunables (top of the script)

| Const | Default | Effect |
|---|---|---|
| `PX_PER_M` | 4.0 | ground scale. 320x240 viewport = 80x60 m |
| `HEIGHT_K` | 1.1 | height squash, relative to the ground scale |
| `SOFT_H_M` | 18.0 | heights past this compress by `TAPER_H` |
| `TAPER_H` | 0.2 | so a 300 m tower draws ~74 m of facade, not 300 |
| `SCREEN_K` | 0.65 | shrinks every screen's extent off the requested tiles |
| `CELL_M` | 2.0 | decomposition/snap grid for footprints |
| `MIN_RECT_M` | 6.0 | drop prism slivers below this |
| `MAX_RECTS` | 6 | prisms per building |

Scale is RPG, not surveyed: at the defaults a 16 m building draws a ~70 px facade
against a 35 px character, about 2:1, and a whole screen covers ~130 m of real
city in ~550 px — buildings deliberately undersized relative to the player, per
the usual JRPG cheat. Placement margins are written in metres through `mpx()`, so
retuning `PX_PER_M` keeps spawns and station entrances where they were.

## Geometry sources

Real geometry, rotated 16.94 deg so Toronto's grid is axis-aligned (same
flattening `assets/scripts/tools/build_toronto_map.gd` uses), then footprints are
decomposed into axis-aligned rectangles via maximal-rectangle extraction — so
L-shaped wings and courtyards survive as separate prisms instead of collapsing
to a bounding box.

- `osm_streets.json` — street centrelines (north of College)
- `osm_eaton_streets.json` — Yonge/Dundas/Queen street network
- `osm_all_buildings.json` — 3190 footprints with `height` / `building:levels`
- `osm_ground.json` — parks, lawns, plazas
- `../../assets/scripts/tools/toronto_map_data.json` — the hand-tuned flattened
  street table, reused so bands match the existing map

Heights come from OSM tags where present, else a per-type default; footprints
over 2000 m^2 tagged under 11 m are floored (several malls are tagged flat).

Screens are defined at the bottom of the script by named building
(`screen_on_building`) or street intersection (`screen_on_xing`) rather than
hardcoded rects, so they stay centred on real geometry. Add one and re-run.
