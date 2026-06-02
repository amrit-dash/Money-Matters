# App icon assets

Vector masters for the Money Matters home-screen icon (hub-and-spoke network with ₹ center).

| File | Background |
|------|------------|
| `app-icon-master-light.svg` | Teal `#1a8990`, white line art |
| `app-icon-master-dark.svg` | Slate `#2C3338`, white line art |

## Export to iOS

```bash
./scripts/export_app_icons.sh
```

Requires [librsvg](https://formulae.brew.sh/formula/librsvg) (`brew install librsvg`) and Python Pillow (`pip3 install pillow`).

Writes all slots under `ios/Runner/Assets.xcassets/AppIcon.appiconset/`, including `*-dark.png` variants referenced from `Contents.json`.
