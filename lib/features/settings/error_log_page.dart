import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/crash_log.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/ds.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/state_views.dart';
import '../../theme/glass.dart';
import '../../theme/lucide.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';

/// Every error the app recorded on this phone: read it, copy it, share it or clear it.
class ErrorLogPage extends StatefulWidget {
  const ErrorLogPage({super.key});

  @override
  State<ErrorLogPage> createState() => _ErrorLogPageState();
}

class _ErrorLogPageState extends State<ErrorLogPage> {
  List<String>? _entries;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await CrashLog.instance?.history() ?? const <String>[];
    if (mounted) setState(() => _entries = list);
  }

  Future<void> _copy(String text) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(SnackBar(content: Text(l.crashCopied)));
  }

  Future<void> _clear() async {
    final l = AppLocalizations.of(context);
    final ok = await showGlassSheet<bool>(
      context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetTitle(l.logClearTitle),
        SheetItem(first: true, icon: Lu.trash2, title: l.logClear, danger: true, onTap: () => Navigator.of(ctx).pop(true)),
      ]),
    );
    if (ok != true) return;
    await CrashLog.instance?.clearHistory();
    await _load();
  }

  Future<void> _open(String entry) async {
    final l = AppLocalizations.of(context);
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        backgroundColor: Colors.transparent,
        body: GlassBackdrop(
          child: Column(children: [
            PageHeader(
              title: l.logEntry,
              actions: [
                GlassIconButton(icon: Lu.copy, onHeader: true, tooltip: l.crashCopy, onTap: () => _copy(entry)),
                GlassIconButton(icon: Lu.share2, onHeader: true, onTap: () => Share.share(entry)),
              ],
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.md, AppSpace.xl, AppSpace.xxl), children: [
                SelectableText(entry, textDirection: TextDirection.ltr, style: TextStyle(fontFamily: 'monospace', fontSize: AppFont.meta, height: AppLine.normal, color: Theme.of(context).colorScheme.onSurface)),
              ]),
            ),
          ]),
        ),
      ),
    ));
  }

  /// The time and the first line of the error, for the list.
  (String, String) _summary(String entry) {
    final lines = entry.split('\n');
    final time = lines.firstWhere((x) => x.startsWith('Time:'), orElse: () => '').replaceFirst('Time:', '').trim();
    final idx = lines.indexWhere((x) => x.startsWith('Platform:'));
    final msg = idx >= 0 && idx + 2 < lines.length ? lines[idx + 2] : lines.first;
    return (time.length >= 16 ? time.substring(0, 16).replaceFirst('T', '  ') : time, msg);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final entries = _entries;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          PageHeader(
            title: l.logTitle,
            actions: [
              if (entries != null && entries.isNotEmpty) ...[
                GlassIconButton(icon: Lu.copy, onHeader: true, tooltip: l.logCopyAll, onTap: () => _copy(entries.join('\n\n----------\n\n'))),
                GlassIconButton(icon: Lu.trash2, onHeader: true, tooltip: l.logClear, onTap: _clear),
              ],
            ],
          ),
          Expanded(
            child: entries == null
                ? const LoadingView()
                : entries.isEmpty
                    ? EmptyState(icon: Lu.fileText, title: l.logEmpty, body: l.logEmptyBody)
                    : ListView(padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.md, AppSpace.xl, AppSpace.xxl), children: [
                        for (final e in entries)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpace.md),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              onTap: () => _open(e),
                              child: GlassCard(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(_summary(e).$1, textDirection: TextDirection.ltr, style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: p.text2)),
                                  const SizedBox(height: AppSpace.xs),
                                  Text(_summary(e).$2, maxLines: 3, overflow: TextOverflow.ellipsis, textDirection: TextDirection.ltr, style: TextStyle(fontSize: AppFont.label, height: AppLine.normal, color: p.text)),
                                ]),
                              ),
                            ),
                          ),
                      ]),
          ),
        ]),
      ),
    );
  }
}
