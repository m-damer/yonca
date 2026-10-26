# YONCA design snapshot (26 Oct 2026)

These folders are the published canvases, exported as HTML: light-part1, light-part2, dark-part1, dark-part2.

The files here are the source of truth. The Python generators in /tmp/yonca/build produced the first drafts, but later fixes were applied directly to the HTML (wording, crash dialog layout, calendar, chips, renumbered frame IDs). Do not regenerate a flow from the generators without re-applying them.

Dark canvases are generated from the light ones with build/darkgen.py (darkgen.build). Dark rules live there, so change them there and rebuild.

## Four Leaves restyle (26 Oct 2026)

All four canvases were restyled to the "Four Leaves" look: forest header bands, mint accent, solid cards (no glass or blur), the four logo greens on avatars. It is done in `leaf.css` (linked after `glass.css`, and after `glass_dark.css` in the dark folders); `leaf.css` holds both light and dark values. Two small HTML changes support it: a `band` wrapper around title rows and contact identity blocks, and a nickname line under the name on contact details.

The contact form screens (Con_*_Form, Cf_*_F1, F2, F3, Edit, FErr) follow the new field order and the "Add more info" sheet (F3). The older flow maps (Flow B to M, Main in light-part1) are earlier sketches, only recoloured to green.

Dark canvases: edit `leaf.css`, not darkgen.py, for the new colours.
