# App icon concepts — Money Matters

Three vector concepts for review. **Default on iOS:** `concept_a.svg` (Bloom Insight) — exported to `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.

**Production icon:** **Concept A — Bloom Insight** (`concept_a.svg`), also referenced in the root README and [`docs/assets/app-icon-preview.png`](../../../docs/assets/app-icon-preview.png). iOS PNGs live in [`AppIcon.appiconset`](../../../ios/Runner/Assets.xcassets/AppIcon.appiconset/) per `Contents.json`. Rebuild with [`scripts/build_ipa.sh`](../../../scripts/build_ipa.sh) or Xcode to refresh the home-screen icon after changes.

| File | Name | Idea |
|------|------|------|
| `concept_a.svg` | **Bloom Insight** | SMS bubble with message lines “blooms” into ascending chart bars |
| `concept_b.svg` | **Stack & Sort** | One SMS pill cascades into colorful category tiles |
| `concept_c.svg` | **Signal Garden** | Orbiting message bubbles flow inward to a central insight pinwheel |

## Quick comparison

| | A — Bloom Insight | B — Stack & Sort | C — Signal Garden |
|---|-------------------|------------------|-------------------|
| **Metaphor** | Messages → growth chart | Messages → organized categories | Scattered SMS → unified dashboard |
| **Composition** | Diagonal, bottom-left anchor | Diagonal cascade, top-left → bottom-right | Radial / orbital, centered |
| **Energy** | Upward, optimistic | Dynamic, playful scatter | Calm convergence, “everything in one place” |
| **Small-size read** | Strong (3 bars + bubble) | Good (big tiles; more elements) | Good (bold pinwheel; orbit may soften) |
| **Distinctiveness** | Most “finance-adjacent” of the three | Most original / least bank-like | Most “product story” (many SMS → one view) |
| **Palette** | Coral, amber, violet on warm cream | Rose, sky, apricot, lilac on lavender-peach | Full spectrum pinwheel on soft radial bg |

## Shared traits

- No typography or letters
- Multicolor, rounded shapes — friendly, not corporate banking
- Warm palette (coral, amber, rose, violet, sky) — avoids green/teal finance-app clichés
- 1024×1024 viewBox; iOS squircle mask applied at export time

## Rationale (one-liners)

- **A** — Clearest “SMS becomes spending insight” at a glance; feels upbeat and simple.
- **B** — Best fit for “categorized ledger” without looking like a bank app; most playful.
- **C** — Best for the Shortcuts/multi-SMS origin story; strong hero mark when centered.

## Next steps

1. To switch to B or C, re-export from that SVG into `AppIcon.appiconset` (same `Contents.json` slots).
2. Regenerate `docs/assets/app-icon-preview.png` if the final art diverges from concept A (512px PNG is enough for README).
3. Optional: align accent colors with app theme if you move off default Material teal seed.
