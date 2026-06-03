# App icon masters (SVG)

**Status:** Awaiting new SVG artwork. Previous hub-and-spoke masters were removed; they did not match the product direction.

## Where to place files

Add approved 1024×1024 SVG masters here (see [`docs/app-icon-brief.md`](../../app-icon-brief.md)):

| File | Purpose |
|------|---------|
| `app-icon-master-light.svg` | Light background variant |
| `app-icon-master-dark.svg` | Dark background variant |

Do not commit PNG masters in this folder. PNGs are generated only into `ios/Runner/Assets.xcassets/` via the export script.

## After adding SVGs

```bash
./scripts/export_app_icons.sh   # requires librsvg + Python Pillow
./scripts/build_ipa.sh          # or Xcode → Run on device
```

**Note:** `AppIcon.appiconset` may still contain PNGs from an older export until you run the script with the new masters.
