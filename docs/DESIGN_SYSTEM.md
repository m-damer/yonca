# YONCA design system

Everything visual is defined in **three files**. Screens never write a raw size, radius, spacing or colour, so a
change in one of these files changes the whole app. `test/design_system_test.dart` fails CI if a screen
sneaks in a raw `fontSize:`, `Radius.circular(8)` or `Color(0x…)`.

| What | File | How screens use it |
|---|---|---|
| Colours that change between light and dark | `lib/theme/palette.dart` | `context.palette.primary`, `.text2`, `.surface2` … |
| Type sizes, corner radii, spacing, tag colours, print colours | `lib/theme/tokens.dart` | `AppFont.body`, `AppRadius.md`, `AppSpace.lg`, `AppIcon.md`, `AppLine.normal`, `AppControl.lg`, `AppTint.tags`, `PrintInk.ink` |
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
2. Size, radius, space: `AppFont.*`, `AppRadius.*`, `AppSpace.*`, `AppIcon.*`, `AppLine.*`, `AppControl.*`. A value that is not there yet goes into `tokens.dart` first.
3. Repeated layout (header, badge, handle, link): use or add a component in `ds.dart`.
4. Run `flutter test test/design_system_test.dart`; it lists the offending lines.

## Scales

Every value snaps to a scale, and the guard test (`test/design_system_test.dart`) fails if a screen writes a raw number for one of them.

- `AppFont`: 11, 12, 13, 14, 15, 16, 17, 18, 20, 22, 24, 28, 34, 56, 72.
- `AppRadius`: 2, 4, 6, 8, 12, 16.
- `AppSpace`: 4-point grid (4 to 56), plus `fabClear` for the bottom of lists.
- `AppIcon`: 12, 16, 20, 24, 28, 32, 40.
- `AppLine`: line height ratios 1.2, 1.3, 1.4, 1.5, 1.6, 2.0.
- `AppControl`: button and field heights 32, 40, 48, 56, and compact button widths.

## Known leftovers

- Some top bars (forms, deal and contact details) still build their own header because they carry extra buttons.
- Sizes of avatars, logos, QR codes and illustrations are set where they are drawn.
