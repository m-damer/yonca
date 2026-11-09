import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/tokens.dart';

class BentoDestination {
  const BentoDestination(this.icon, this.selectedIcon, this.label, {this.dot = false});
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// A small dot on the icon: something here needs a look (an update is waiting).
  final bool dot;
}

/// Full-width bottom bar on the surface colour with a hairline on top; the active item has a blue line above it.
class BentoNavBar extends StatelessWidget {
  const BentoNavBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<BentoDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.navBar,
        border: Border(top: BorderSide(color: p.separator)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppSize.s64,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _Item(
                    destination: destinations[i],
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.destination, required this.selected, required this.onTap});
  final BentoDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = selected ? p.primary : p.text2;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            // The selected item gets a 2 px line along the top edge, 64% of the item wide.
            Positioned(
              top: -1,
              left: 0,
              right: 0,
              child: FractionallySizedBox(
                widthFactor: 1,
                child: Container(height: AppStroke.regular, color: selected ? p.primary : Colors.transparent),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.sm, AppSpace.xs, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: AppSpace.x3,
                    child: Center(
                      child: Stack(clipBehavior: Clip.none, children: [
                        Icon(selected ? destination.selectedIcon : destination.icon, size: AppIcon.lg, color: color),
                        if (destination.dot)
                          PositionedDirectional(
                            top: 0,
                            end: 0,
                            child: Container(width: AppSize.s8, height: AppSize.s8, decoration: BoxDecoration(color: p.error, shape: BoxShape.circle)),
                          ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      destination.label,
                      maxLines: 1,
                      style: TextStyle(fontSize: AppFont.tiny, height: AppLine.snug, fontWeight: selected ? AppWeight.semibold : AppWeight.regular, color: color),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
