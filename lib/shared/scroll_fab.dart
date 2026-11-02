import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../theme/lucide.dart';

/// Holds whether the floating buttons below it are expanded. Scrolling down (content moving up)
/// shrinks them to the plus icon; scrolling up, or reaching the top, expands them again.
class FabScope extends StatefulWidget {
  const FabScope({super.key, required this.child});
  final Widget child;

  @override
  State<FabScope> createState() => _FabScopeState();
}

class _FabScopeState extends State<FabScope> {
  final _extended = ValueNotifier<bool>(true);

  @override
  void dispose() {
    _extended.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    if (n is UserScrollNotification) {
      if (n.direction == ScrollDirection.reverse) {
        _extended.value = false;
      } else if (n.direction == ScrollDirection.forward) {
        _extended.value = true;
      }
    } else if (n is ScrollUpdateNotification && n.metrics.pixels <= n.metrics.minScrollExtent) {
      _extended.value = true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => _FabState(
        notifier: _extended,
        child: NotificationListener<ScrollNotification>(onNotification: _onScroll, child: widget.child),
      );
}

class _FabState extends InheritedNotifier<ValueNotifier<bool>> {
  const _FabState({required ValueNotifier<bool> notifier, required super.child}) : super(notifier: notifier);
}

/// The floating "+" button of a screen: icon and label while extended, only the icon after scrolling down.
class ExpandingFab extends StatelessWidget {
  const ExpandingFab({super.key, required this.label, required this.onPressed, this.icon = Lu.plus});
  final String label;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final extended = context.dependOnInheritedWidgetOfExactType<_FabState>()?.notifier?.value ?? true;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: ScaleTransition(scale: anim, child: child)),
      child: extended
          ? FloatingActionButton.extended(key: const ValueKey('ext'), onPressed: onPressed, icon: Icon(icon), label: Text(label))
          : FloatingActionButton(key: const ValueKey('short'), tooltip: label, onPressed: onPressed, child: Icon(icon)),
    );
  }
}
