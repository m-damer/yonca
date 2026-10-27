import 'package:flutter/material.dart';

import '../theme/palette.dart';

class BentoDestination {
  const BentoDestination(this.icon, this.selectedIcon, this.label);
  final IconData icon;
  final IconData selectedIcon;
  final String label;
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
        child: Padding(
          padding: EdgeInsets.zero,
          child: Row(
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
            // The selected item gets a 2 px line along its top edge.
            Positioned.fill(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(height: 2, color: selected ? p.primary : Colors.transparent),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 8, 2, 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(selected ? destination.selectedIcon : destination.icon, size: 24, color: color),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      destination.label,
                      maxLines: 1,
                      style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: color),
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
