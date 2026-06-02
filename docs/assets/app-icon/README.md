# App icon assets

Masters for the Money Matters home-screen icon (hub-and-spoke network with ₹ center).

| File | Role |
|------|------|
| **`app-icon-master-1024.png`** | **Canonical 1024×1024 export** (used by `./scripts/export_app_icons.sh`) |
| `app-icon-master-light.svg` | Teal `#1a8990` vector fallback |
| `app-icon-master-dark.svg` | Slate `#2C3338` vector fallback (SVG export only) |

## Export to iOS

```bash
./scripts/export_app_icons.sh
```

Requires [librsvg](https://formulae.brew.sh/formula/librsvg) (`brew install librsvg`) and Python Pillow (`pip3 install pillow`).

Writes all slots under `ios/Runner/Assets.xcassets/AppIcon.appiconset/`, including `*-dark.png` variants referenced from `Contents.json`.
