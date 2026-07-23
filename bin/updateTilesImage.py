#!/usr/bin/env python3
"""
Update all raster layers in _z_ao_packages-world-tiles.xcf from the *_tile_list files.

Each tile list maps to a same-named RGBA layer in the XCF. This script:
  1. Reads every *_tile_list file and computes pixel rects for each tile
  2. Generates a Script-Fu program that clears each layer and repaints it
  3. Calls gimp-console to execute the Script-Fu and save the XCF
"""

import re, sys, subprocess, tempfile
from pathlib import Path

SCRIPT_DIR   = Path(__file__).resolve().parent
BASE_DIR     = SCRIPT_DIR.parent
XCF_PATH     = BASE_DIR / "_z_ao_packages-world-tiles.xcf"
TILE_LIST_RE = re.compile(r"^([+-]\d+)([+-]\d+)\.dsf$")

IMG_W, IMG_H = 1872, 938   # XCF canvas size

# RGB colours sampled from each existing layer (alpha always 255)
LAYER_COLORS = {
    "afr-n":     (122, 167, 136),
    "afr-s":     (102,  39, 103),
    "asi-c":     (117, 148, 151),
    "asi-n":     (128,  55, 141),
    "asi-s":     ( 74, 107,  75),
    "aus-pac":   (159, 128,  52),
    "eur-e":     ( 49,  77, 129),
    "eur-w":     (142, 159,  72),
    "greenland": ( 78,  91, 116),
    "na-n":      ( 51, 138,  46),
    "na-s":      ( 47,  46, 138),
    "sa":        ( 46, 138, 138),
    "ca":        (191,  87,  63),
}


def parse_tile_list(path: Path):
    tiles = []
    with open(path) as f:
        for line in f:
            m = TILE_LIST_RE.match(line.strip())
            if m:
                tiles.append((int(m.group(1)), int(m.group(2))))
    return tiles


LAT_RANGE = 150  # background map covers 90°N to 60°S


def tile_rect(lat, lon):
    """Return (x, y, w, h) pixel rect for a 1°×1° tile."""
    x0 = int((lon     + 180) * IMG_W / 360)
    x1 = int((lon + 1 + 180) * IMG_W / 360) + 1
    y0 = int((90 - lat - 1)  * IMG_H / LAT_RANGE)
    y1 = int((90 - lat)      * IMG_H / LAT_RANGE) + 1
    x0 = max(0, min(IMG_W, x0));  x1 = max(0, min(IMG_W, x1))
    y0 = max(0, min(IMG_H, y0));  y1 = max(0, min(IMG_H, y1))
    return x0, y0, max(1, x1 - x0), max(1, y1 - y0)


def build_script_fu(xcf: str, layers: list) -> str:
    """
    layers: [(layer_name, (r,g,b), [(x,y,w,h), ...]), ...]
    Returns Script-Fu (Scheme) that repaints each layer then saves the XCF.
    Uses select-rectangle + fill (CHANNEL-OP-ADD=0, FILL-FOREGROUND=0).
    No external PNG files needed — avoids gimp-edit-paste issues in GIMP 3.
    """
    def q(s):
        return s.replace("\\", "\\\\").replace('"', '\\"')

    lines = [
        f'(define xcf-image (car (gimp-file-load RUN-NONINTERACTIVE "{q(xcf)}" "{q(xcf)}")))',
        "",
        "; update-layer: clear layer, union-select all tile rects, fill once",
        "; Uses GIMP 3 API: gimp-drawable-edit-clear, gimp-drawable-edit-fill, 0=CHANNEL-OP-ADD, 0=FILL-FOREGROUND",
        "(define (update-layer layer-name r g b rects)",
        "  (let ((layer (car (gimp-image-get-layer-by-name xcf-image layer-name))))",
        "    (gimp-drawable-edit-clear layer)",
        "    (gimp-selection-none xcf-image)",
        "    (gimp-context-set-foreground (list r g b))",
        "    (for-each",
        "      (lambda (rect)",
        "        (gimp-image-select-rectangle xcf-image 0",
        "          (car rect) (cadr rect) (caddr rect) (cadddr rect)))",
        "      rects)",
        "    (gimp-drawable-edit-fill layer 0)",
        "    (gimp-selection-none xcf-image)))",
        "",
    ]

    for name, (r, g, b), rects in layers:
        rect_strs = " ".join(f"({x} {y} {w} {h})" for x, y, w, h in rects)
        lines.append(f'(update-layer "{q(name)}" {r} {g} {b} (quote ({rect_strs})))')

    lines += [
        "",
        "(gimp-selection-none xcf-image)",
        "(gimp-image-clean-all xcf-image)",
        f'(gimp-xcf-save 0 xcf-image "{q(xcf)}")',
        "(gimp-image-delete xcf-image)",
    ]
    return "\n".join(lines)


def main():
    if not XCF_PATH.exists():
        sys.exit(f"ERROR: XCF not found: {XCF_PATH}")

    tile_lists = sorted(BASE_DIR.glob("*_tile_list"))
    if not tile_lists:
        sys.exit(f"ERROR: no *_tile_list files found in {BASE_DIR}")

    layers = []
    for tl_path in tile_lists:
        name = tl_path.name.replace("_tile_list", "")
        if name not in LAYER_COLORS:
            print(f"  skip {name} (no layer colour defined)")
            continue
        tiles  = parse_tile_list(tl_path)
        rects  = [tile_rect(lat, lon) for lat, lon in tiles]
        color  = LAYER_COLORS[name]
        layers.append((name, color, rects))
        print(f"  {name}: {len(tiles)} tiles")

    with tempfile.TemporaryDirectory(prefix="updateTilesImage_") as tmpdir:
        scm_path = f"{tmpdir}/update.scm"
        with open(scm_path, "w") as f:
            f.write(build_script_fu(str(XCF_PATH), layers))

        print(f"\nRunning gimp-console…")
        result = subprocess.run(
            [
                "gimp-console",
                "--no-data", "--no-fonts", "--quit",
                "--batch-interpreter=plug-in-script-fu-eval",
                "-b", f'(load "{scm_path}")',
            ],
            capture_output=True, text=True,
        )

        for line in result.stderr.splitlines():
            if any(x in line for x in ("surfacemap", "gjs", "WARNING: Unknown input", "INFO:", "gimp_wire_read")):
                continue
            if line.strip():
                print(f"  gimp: {line}", file=sys.stderr)

        if "execution error" in result.stderr:
            sys.exit("gimp-console reported a Script-Fu execution error (see above)")

        print(f"Done — updated {XCF_PATH}")


if __name__ == "__main__":
    main()
