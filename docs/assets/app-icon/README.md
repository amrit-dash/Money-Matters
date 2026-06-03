# App icon masters (SVG)

**Status:** Approved hub-and-spoke mark (teal `#1a8990`, white line art). Light master embeds the approved 1024×1024 artwork; dark master uses slate `#2C3338` with the same white artwork layer.

## Files

| File | Purpose |
|------|---------|
| `app-icon-master-light.svg` | Teal background variant (approved artwork) |
| `app-icon-master-dark.svg` | Dark slate background (`#2C3338`), same white art |
| `app-icon-master-1024.png` | Regenerated preview (from export script; optional in git) |

PNG slot exports live only under `ios/Runner/Assets.xcassets/` (see below).

## Regenerate iOS assets

```bash
./scripts/export_app_icons.sh   # requires librsvg + Python Pillow
./scripts/build_ipa.sh          # or Xcode → Run on device
```

Updates `AppIcon.appiconset` (light + `-dark` variants), `LaunchImage.imageset`, and `app-icon-master-1024.png`.

Design brief (historical exploration notes): [`docs/app-icon-brief.md`](../../app-icon-brief.md).
