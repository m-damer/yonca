# YONCA design snapshot (26 Oct 2026)

These folders are the published canvases, exported as HTML: light-part1, light-part2, dark-part1, dark-part2.

The files here are the source of truth. The Python generators in /tmp/yonca/build produced the first drafts, but later fixes were applied directly to the HTML (wording, crash dialog layout, calendar, chips, renumbered frame IDs). Do not regenerate a flow from the generators without re-applying them.

Dark canvases are generated from the light ones with build/darkgen.py (darkgen.build). Dark rules live there, so change them there and rebuild.
