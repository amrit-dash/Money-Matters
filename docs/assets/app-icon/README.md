# App icon assets

Masters for the Money Matters home-screen icon (hub-and-spoke network with ₹ center).

## Source of truth

Edit the **SVG masters only**. Do not hand-edit PNGs in `AppIcon.appiconset` or `LaunchImage.imageset`.

| File | Role |
|------|------|
| **`app-icon-master-light.svg`** | Teal `#1a8990` vector master (source of truth) |
| **`app-icon-master-dark.svg`** | Slate `#2C3338` vector master (source of truth) |
| `app-icon-master-1024.png` | 1024×1024 PNG derivative (regenerated from light SVG) |

Design brief: [`docs/app-icon-brief.md`](../../app-icon-brief.md).

## Export to iOS

```bash
./scripts/export_app_icons.sh
```

Requires [librsvg](https://formulae.brew.sh/formula/librsvg) (`brew install librsvg`) and Python Pillow (`pip3 install pillow`).

Regenerates:

- All slots under `ios/Runner/Assets.xcassets/AppIcon.appiconset/` (light PNGs + matching `*-dark.png` variants)
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/` (light master, same branding as the app icon)
- `app-icon-master-1024.png` (docs preview / README)
