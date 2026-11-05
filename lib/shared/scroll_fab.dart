import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../theme/lucide.dart';
import '../theme/tokens.dart';

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

  static const _time = Duration(milliseconds: 260);
  static const _curve = AppMotion.curveSmooth;

  @override
  Widget build(BuildContext context) {
    final extended = context.dependOnInheritedWidgetOfExactType<_FabState>()?.notifier?.value ?? true;
    final theme = Theme.of(context);
    final t = theme.floatingActionButtonTheme;
    // One button that stays on screen: the plus icon keeps its place while the width opens and closes
    // around the label, so there is no swap between two buttons.
    return Tooltip(
      message: label,
      child: Material(
        color: t.backgroundColor,
        elevation: t.elevation ?? 4,
        shadowColor: theme.shadowColor,
        shape: t.shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: AppControl.xl - AppSpace.xs,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: AppControl.xl - AppSpace.xs, child: Center(child: Icon(icon, color: t.foregroundColor))),
              ClipRect(
                child: AnimatedAlign(
                  duration: _time,
                  curve: _curve,
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: extended ? 1 : 0,
                  child: AnimatedOpacity(
                    duration: _time,
                    curve: _curve,
                    opacity: extended ? 1 : 0,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: AppSpace.xl),
                      child: Text(label, maxLines: 1, softWrap: false, style: t.extendedTextStyle?.copyWith(color: t.foregroundColor)),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
