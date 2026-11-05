import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/lucide.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../settings/settings_widgets.dart';
import 'qr_models.dart';

class _Pair {
  _Pair(this.kind, {String label = ''}) : label = TextEditingController(text: label);
  final String kind;
  final TextEditingController label;
  final value = TextEditingController();

  void dispose() {
    label.dispose();
    value.dispose();
  }
}

/// Manual entry: a full contact form (name parts, job, company, several phones, emails, websites, addresses
/// and custom fields). Continue returns the filled lines to the checklist step.
class QrManualPage extends StatefulWidget {
  const QrManualPage({super.key});

  @override
  State<QrManualPage> createState() => _QrManualPageState();
}

class _QrManualPageState extends State<QrManualPage> {
  final _single = {for (final k in ['prefix', 'first', 'last', 'job', 'dept', 'company']) k: TextEditingController()};
  final _rows = <_Pair>[_Pair('phone'), _Pair('email')];

  @override
  void dispose() {
    for (final c in _single.values) {
      c.dispose();
    }
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _add(String kind) => setState(() => _rows.add(_Pair(kind)));

  List<QrField> _result(AppLocalizations l) {
    final labels = {
      'prefix': l.fieldPrefix,
      'first': l.fieldFirstName,
      'last': l.fieldLastName,
      'job': l.fieldJobTitle,
      'dept': l.fieldDepartment,
      'company': l.fieldCompany,
      'phone': l.fieldPhone,
      'email': l.fieldEmail,
      'website': l.fieldWebsite,
      'address': l.fieldAddress,
    };
    return [
      for (final e in _single.entries) QrField(e.key, labels[e.key]!, e.value.text.trim()),
      for (final k in ['phone', 'email', 'website', 'address'])
        for (final r in _rows.where((r) => r.kind == k)) QrField(k, labels[k]!, r.value.text.trim()),
      for (final r in _rows.where((r) => r.kind == 'custom'))
        QrField('custom', r.label.text.trim().isEmpty ? l.qrCustomField : r.label.text.trim(), r.value.text.trim()),
    ].where((f) => f.value.isNotEmpty).toList();
  }

  Widget _section(AppLocalizations l, String kind, String label, String addLabel, {TextInputType? type}) {
    final rows = _rows.where((r) => r.kind == kind).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.md),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (kind == 'custom') ...[
              SizedBox(width: AppControl.hero * 1.5, child: GlassField(controller: r.label, label: l.qrLabel)),
              const SizedBox(width: AppSpace.md),
            ],
            Expanded(child: GlassField(controller: r.value, label: kind == 'custom' ? l.qrValue : label, keyboardType: type, forceLtr: kind != 'custom' && kind != 'address')),
            if (rows.length > 1 || kind == 'custom') ...[
              const SizedBox(width: AppSpace.sm),
              GlassIconButton(icon: Lu.x, onTap: () => setState(() {
                    _rows.remove(r);
                    r.dispose();
                  })),
            ],
          ]),
        ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: InkWell(
          onTap: () => _add(kind),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Lu.plus, size: AppIcon.md, color: context.palette.primary),
              const SizedBox(width: AppSpace.sm),
              Text(addLabel, style: TextStyle(fontSize: AppFont.body, fontWeight: AppWeight.semibold, color: context.palette.primary)),
            ]),
          ),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget f(String k, String label) => Padding(padding: const EdgeInsets.only(bottom: AppSpace.md), child: GlassField(controller: _single[k]!, label: label));
    final any = _result(l).isNotEmpty;
    return SettingsScaffold(
      title: l.qrSrcManual,
      children: [
        const SizedBox(height: AppSpace.sm),
        f('prefix', l.fieldPrefix),
        f('first', l.fieldFirstName),
        f('last', l.fieldLastName),
        f('job', l.fieldJobTitle),
        f('dept', l.fieldDepartment),
        f('company', l.fieldCompany),
        _section(l, 'phone', l.fieldPhone, l.addPhone, type: TextInputType.phone),
        _section(l, 'email', l.fieldEmail, l.addEmail, type: TextInputType.emailAddress),
        _section(l, 'website', l.fieldWebsite, l.addWebsite, type: TextInputType.url),
        _section(l, 'address', l.fieldAddress, l.addAddress),
        _section(l, 'custom', l.qrCustomField, l.qrAddCustom),
        const SizedBox(height: AppSpace.lg),
        PillButton(label: l.qrContinue, height: AppControl.lg, onPressed: () {
          final r = _result(l);
          if (r.isNotEmpty) Navigator.of(context).pop(r);
        }),
        if (!any) const SizedBox.shrink(),
      ],
    );
  }
}
