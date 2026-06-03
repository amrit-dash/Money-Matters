#!/usr/bin/env bash
# Export docs/assets/app-icon SVG masters into ios/Runner/Assets.xcassets PNGs.
# Expects app-icon-master-{light,dark}.svg (see docs/assets/app-icon/README.md).
# Does not run without both SVGs — add new masters before exporting.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICON_DIR="${ROOT}/docs/assets/app-icon"
LIGHT_SVG="${ICON_DIR}/app-icon-master-light.svg"
DARK_SVG="${ICON_DIR}/app-icon-master-dark.svg"
OUT_DIR="${ROOT}/ios/Runner/Assets.xcassets/AppIcon.appiconset"
LAUNCH_DIR="${ROOT}/ios/Runner/Assets.xcassets/LaunchImage.imageset"
TMP="${ROOT}/build/icon-export"

python3 -c "from PIL import Image" 2>/dev/null || {
  echo "ERROR: Python Pillow required. Run: pip3 install pillow"
  exit 1
}

mkdir -p "$TMP" "$OUT_DIR" "$LAUNCH_DIR"

if [[ -f "$LIGHT_SVG" && -f "$DARK_SVG" ]]; then
  if ! command -v rsvg-convert >/dev/null 2>&1; then
    echo "ERROR: rsvg-convert not found. Install: brew install librsvg"
    exit 1
  fi
  echo "==> Rendering 1024 masters from SVG"
  rsvg-convert -w 1024 -h 1024 "$LIGHT_SVG" -o "${TMP}/light-1024.png"
  rsvg-convert -w 1024 -h 1024 "$DARK_SVG" -o "${TMP}/dark-1024.png"
else
  echo "ERROR: Missing SVG masters."
  echo "  Add: ${LIGHT_SVG}"
  echo "  Add: ${DARK_SVG}"
  echo "  See: ${ICON_DIR}/README.md and docs/app-icon-brief.md"
  exit 1
fi

export ROOT
python3 <<'PY'
import os
from pathlib import Path
from PIL import Image

root = Path(os.environ["ROOT"])
tmp = root / "build/icon-export"
out = root / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
launch = root / "ios/Runner/Assets.xcassets/LaunchImage.imageset"

slots = [
    ("Icon-App-20x20@2x.png", 40),
    ("Icon-App-20x20@3x.png", 60),
    ("Icon-App-29x29@1x.png", 29),
    ("Icon-App-29x29@2x.png", 58),
    ("Icon-App-29x29@3x.png", 87),
    ("Icon-App-40x40@2x.png", 80),
    ("Icon-App-40x40@3x.png", 120),
    ("Icon-App-60x60@2x.png", 120),
    ("Icon-App-60x60@3x.png", 180),
    ("Icon-App-20x20@1x.png", 20),
    ("Icon-App-29x29@1x.png", 29),
    ("Icon-App-40x40@1x.png", 40),
    ("Icon-App-76x76@1x.png", 76),
    ("Icon-App-76x76@2x.png", 152),
    ("Icon-App-83.5x83.5@2x.png", 167),
    ("Icon-App-1024x1024@1x.png", 1024),
]

launch_slots = [
    ("LaunchImage.png", 120),
    ("LaunchImage@2x.png", 240),
    ("LaunchImage@3x.png", 360),
]

def export_set(master: Path, suffix: str) -> None:
    base = Image.open(master).convert("RGB")
    for filename, px in slots:
        out_name = filename.replace(".png", f"{suffix}.png") if suffix else filename
        base.resize((px, px), Image.Resampling.LANCZOS).save(
            out / out_name, format="PNG", optimize=True
        )
        print(f"  {out_name} ({px}px)")

print("==> Light variants")
export_set(tmp / "light-1024.png", "")
print("==> Dark variants")
export_set(tmp / "dark-1024.png", "-dark")

print("==> LaunchImage (light)")
base = Image.open(tmp / "light-1024.png").convert("RGBA")
for filename, px in launch_slots:
    base.resize((px, px), Image.Resampling.LANCZOS).save(
        launch / filename, format="PNG", optimize=True
    )
    print(f"  {filename} ({px}px)")
PY

cp "${TMP}/light-1024.png" "${ICON_DIR}/app-icon-master-1024.png"
echo "==> Preview: ${ICON_DIR}/app-icon-master-1024.png"
echo "==> Exported to ${OUT_DIR} and ${LAUNCH_DIR}"
