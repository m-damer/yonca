import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../../core/format.dart';

import '../../data/stats_repository.dart';
import '../../domain/stats_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../settings/settings_widgets.dart' show SegControl;
import 'stats_labels.dart';

/// Set targets (one row per metric, weekly or monthly) with the history of past periods.
class TargetsPage extends StatefulWidget {
  const TargetsPage({super.key, required this.stats});
  final StatsRepository stats;

  @override
  State<TargetsPage> createState() => _TargetsPageState();
}

class _TargetsPageState extends State<TargetsPage> {
  final _controllers = {for (final m in Metric.values) m: TextEditingController()};
  final _period = {for (final m in Metric.values) m: StatsPeriod.week};
  Map<Metric, List<(DateTime, double)>> _history = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ts = await widget.stats.targets();
    final hist = <Metric, List<(DateTime, double)>>{};
    for (final t in ts) {
      _controllers[t.metric]!.text = formatNumber(t.value);
      _period[t.metric] = t.period;
      hist[t.metric] = await widget.stats.history(t);
    }
    if (mounted) {
      setState(() {
        _history = hist;
        _loaded = true;
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final nav = Navigator.of(context);
    for (final m in Metric.values) {
      final v = double.tryParse(_controllers[m]!.text.trim().replaceAll(',', ''));
      await widget.stats.setTarget(m, _period[m]!, v);
    }
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    final locale = Localizations.localeOf(context).toString();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          HeaderBand(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Row(children: [
              GlassIconButton(icon: Icons.close, onHeader: true, onTap: () => Navigator.of(context).maybePop()),
              const SizedBox(width: 12),
              Expanded(child: Text(l.setTargets, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: pal.onHeader))),
              SizedBox(width: 77.5, child: PillButton(label: l.save, height: 44, onPressed: _loaded ? _save : null)),
            ]),
          ),
          Expanded(
            child: !_loaded
                ? const SizedBox.shrink()
                : ListView(padding: const EdgeInsets.fromLTRB(24, 14, 24, 40), children: [
                    Text(l.targetEmpty, style: TextStyle(fontSize: 15, height: 21 / 15, color: pal.text2)),
                    const SizedBox(height: 12),
                    for (final m in Metric.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GlassCard(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Row(children: [
                              Expanded(child: Text(metricLabel(l, m), style: const TextStyle(fontSize: 15, height: 21 / 15, fontWeight: FontWeight.w500))),
                              SizedBox(
                                width: 110,
                                height: 46,
                                child: TextField(
                                  controller: _controllers[m],
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 16),
                                  decoration: InputDecoration(
                                    hintText: l.targetNone,
                                    filled: true,
                                    fillColor: pal.glass,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: pal.glassBorder)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: pal.primary, width: 1.5)),
                                  ),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 12),
                            SegControl(
                              pillHeight: 34,
                              labels: [l.targetWeekly, l.targetMonthly],
                              selected: _period[m] == StatsPeriod.week ? 0 : 1,
                              onSelect: (i) => setState(() => _period[m] = i == 0 ? StatsPeriod.week : StatsPeriod.month),
                            ),
                            if ((_history[m] ?? const []).isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '${l.targetHistory}: ${[
                                    for (final h in _history[m]!)
                                      '${_period[m] == StatsPeriod.month ? dfmt(DateFormat.MMM(locale), h.$1) : dfmt(DateFormat.MMMd(locale), h.$1)} ${formatNumber(h.$2)}'
                                  ].join(' · ')}',
                                  style: TextStyle(fontSize: 12, color: pal.text2),
                                ),
                              ),
                          ]),
                        ),
                      ),
                  ]),
          ),
        ]),
      ),
    );
  }
}
