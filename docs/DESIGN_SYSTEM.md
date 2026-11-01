# YONCA design system

Everything visual is defined in **three files**. Screens never write a raw size, radius, spacing or colour, so a
change in one of these files changes the whole app. `test/design_system_test.dart` fails CI if a screen
sneaks in a raw `fontSize:`, `Radius.circular(8)` or `Color(0x…)`.

| What | File | How screens use it |
|---|---|---|
| Colours that change between light and dark | `lib/theme/palette.dart` | `context.palette.primary`, `.text2`, `.surface2` … |
| Type sizes, corner radii, spacing, tag colours, print colours | `lib/theme/tokens.dart` | `AppFont.body`, `AppRadius.md`, `AppSpace.lg`, `AppTint.tags`, `PrintInk.ink` |
| Shared building blocks | `lib/shared/ds.dart`, `lib/shared/glass_widgets.dart`, `lib/theme/glass.dart` | `PageHeader`, `CountBadge`, `LinkButton`, `DragHandle`, `PillButton`, `GlassCard` … |

## Change the look

- **Brand colour / dark theme:** edit `light` and `dark` in `palette.dart` (`primary`, `accent`, `header`, `surface2` …).
- **Text size everywhere:** edit `AppFont` (for example `body = 16` makes all body text 16).
- **Rounder or squarer UI:** edit `AppRadius` (`md` is cards, rows and fields; `sm` is buttons and chips; `lg` is sheets).
- **Spacing rhythm:** edit `AppSpace` (`lg` is 16, `xl` is 20 side margins).
- **Font family:** `lib/theme/theme.dart` (`family` / `fallback`).
- **A component** (page header, badge, link button, drag handle): edit it once in `lib/shared/ds.dart`.

## Rules for new code

1. Colour: `context.palette.<token>`. Need a new colour? Add a field to `YoncaPalette` with a light and a dark value.
2. Size, radius, space: `AppFont.*`, `AppRadius.*`, `AppSpace.*`. A value that is not there yet goes into `tokens.dart` first.
3. Repeated layout (header, badge, handle, link): use or add a component in `ds.dart`.
4. Run `flutter test test/design_system_test.dart`; it lists the offending lines.

## Known leftovers

- Half-step sizes (`nano` 10.5, `tiny2` 11.5, `hint` 12.5, `meta2` 13.5, `lead2` 19) and radii (`xs2` 5, `md2` 9, `lg2` 15) exist
  because the canvas was matched pixel for pixel. They can be merged into the main scale once you agree on the rounding.
- Many paddings keep odd numbers (10.5, 14, 17.3) for the same reason; only the standard steps 4/8/12/16/20/24 are tokens.
- Some top bars (forms, deal and contact details) still build their own header because they carry extra buttons.
