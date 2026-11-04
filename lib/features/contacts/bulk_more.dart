import 'dart:io';

import 'package:flutter/material.dart';
import '../../shared/pickers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/text_normalize.dart';
import '../../data/app_database.dart';
import '../../domain/contact_models.dart';
import '../../domain/field_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../deals/deal_widgets.dart';
import '../../theme/lucide.dart';

String _csv(String v) => '"${v.replaceAll('"', '""')}"';

/// Writes the contacts to a .csv file (with a BOM so Excel reads Arabic) and opens the share sheet.
Future<void> shareCsv(List<ContactSummary> list) async {
  const head = ['First name', 'Middle name', 'Last name', 'Prefix', 'Suffix', 'Nickname', 'Company', 'Department', 'Job title', 'Phones', 'Emails', 'Websites', 'Addresses', 'Tags', 'Roles', 'Rating', 'Notes'];
  final rows = <String>[head.map(_csv).join(',')];
  for (final s in list) {
    final c = s.contact;
    rows.add([
      c.firstName,
      c.middleName,
      c.lastName,
      c.prefix,
      c.suffix,
      c.nickname,
      c.company,
      c.department,
      c.jobTitle,
      s.phones.map((p) => '${p.countryCode}${p.number}').join('; '),
      s.emails.map((e) => e.value).join('; '),
      s.websites.map((e) => e.value).join('; '),
      s.addresses.map((e) => e.value).join('; '),
      s.tags.map((t) => t.name).join('; '),
      s.roles.map((r) => r.name).join('; '),
      c.rating,
      c.requirements,
    ].map(_csv).join(','));
  }
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/contacts.csv');
  await f.writeAsString('﻿${rows.join('\r\n')}\r\n');
  await Share.shareXFiles([XFile(f.path, mimeType: 'text/csv')]);
}

/// One email to every selected contact that has an address, with the addresses in Bcc.
Future<bool> emailAll(List<ContactSummary> list) async {
  final emails = [for (final s in list) if (s.emails.isNotEmpty) s.emails.first.value.trim()];
  if (emails.isEmpty) return false;
  await launchUrl(Uri.parse('mailto:?bcc=${emails.join(',')}'));
  return true;
}

/// Which contact stays when the selected ones are merged.
Future<int?> showBulkPrimarySheet(BuildContext context, List<ContactSummary> list) {
  final l = AppLocalizations.of(context);
  return showGlassSheet<int>(
    context,
    builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetTitle(l.bulkMergePick),
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.sm),
        child: Text(l.bulkMergeSub, style: TextStyle(fontSize: AppFont.body, height: AppLine.loose, color: ctx.palette.text2)),
      ),
      Flexible(
        child: ListView(shrinkWrap: true, children: [
          for (var i = 0; i < list.length; i++)
            SheetItem(first: i == 0, icon: Lu.user, title: list[i].fullName, onTap: () => Navigator.of(ctx).pop(list[i].contact.id)),
        ]),
      ),
    ]),
  );
}

class BulkDealChoice {
  const BulkDealChoice(this.title, this.stageId, this.amount);
  final String title;
  final int stageId;
  final double? amount;
}

/// One deal for each selected contact, in the chosen stage.
Future<BulkDealChoice?> showBulkDealSheet(BuildContext context, {required int count, required List<DealStage> stages}) {
  final l = AppLocalizations.of(context);
  final title = TextEditingController();
  final amount = TextEditingController();
  var stageId = stages.first.id;
  return showGlassSheet<BulkDealChoice>(
    context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      return SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SheetTitle(l.bulkDeal, bottom: AppSpace.md),
          GlassField(controller: title, label: l.bulkDealTitle, autofocus: true, textCapitalization: TextCapitalization.sentences, onChanged: (_) => setS(() {})),
          const SizedBox(height: AppSpace.lg),
          GlassField(controller: amount, label: l.bulkAmount, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          SectionLabel(l.bulkDealStage, padding: const EdgeInsets.fromLTRB(0, AppSpace.lg, 0, AppSpace.sm)),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in stages) PillChip(label: stageLabel(l, s), selected: stageId == s.id, onTap: () => setS(() => stageId = s.id)),
          ]),
          const SizedBox(height: AppSpace.lg),
          SheetButtons(
            secondary: l.cancel,
            onSecondary: () => Navigator.of(ctx).pop(),
            primary: l.bulkCreateDeals(count),
            onPrimary: title.text.trim().isEmpty ? null : () => Navigator.of(ctx).pop(BulkDealChoice(title.text.trim(), stageId, double.tryParse(amount.text.trim().replaceAll(',', '.')))),
          ),
        ]),
      );
    }),
  );
}

class BulkFieldChoice {
  const BulkFieldChoice(this.fieldId, this.value);
  final int fieldId;
  final String value;
}

/// Pick a contact custom field and the value to set for every selected contact.
Future<BulkFieldChoice?> showBulkFieldSheet(BuildContext context, {required int count, required List<CustomField> fields}) {
  final l = AppLocalizations.of(context);
  if (fields.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.bulkFieldNone)));
    return Future.value();
  }
  CustomField? field;
  var value = '';
  final text = TextEditingController();
  return showGlassSheet<BulkFieldChoice>(
    context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      final type = field == null ? null : fieldTypeFromName(field!.type);
      Widget input() {
        switch (type) {
          case FieldType.bool:
            return ChipRow(chips: [
              PillChip(label: l.yesLabel, selected: value == '1', onTap: () => setS(() => value = '1')),
              PillChip(label: l.noLabel, selected: value == '0', onTap: () => setS(() => value = '0')),
            ]);
          case FieldType.date:
            final d = DateTime.tryParse(value);
            return GlassSelectField(
              label: l.bulkFieldValue,
              value: d == null ? ' ' : MaterialLocalizations.of(ctx).formatMediumDate(d),
              onTap: () async {
                final r = await pickDate(ctx, initialDate: d ?? DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime(2100));
                if (r != null) setS(() => value = DateTime(r.year, r.month, r.day).toIso8601String());
              },
            );
          case FieldType.choice:
            return Wrap(spacing: 8, runSpacing: 8, children: [
              for (final o in field!.options.split('\n').where((o) => o.isNotEmpty)) PillChip(label: o, selected: value == o, onTap: () => setS(() => value = o)),
            ]);
          default:
            return GlassField(
              controller: text,
              label: l.bulkFieldValue,
              keyboardType: type == FieldType.number ? const TextInputType.numberWithOptions(decimal: true) : null,
              onChanged: (v) => setS(() => value = v),
            );
        }
      }

      return SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SheetTitle(l.bulkFieldSet, bottom: AppSpace.md),
          SectionLabel(l.bulkFieldPick, padding: const EdgeInsets.fromLTRB(0, 0, 0, AppSpace.sm)),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final f in fields)
              PillChip(
                label: f.name,
                selected: field?.id == f.id,
                onTap: () => setS(() {
                  field = f;
                  value = '';
                  text.clear();
                }),
              ),
          ]),
          if (field != null) ...[
            const SizedBox(height: AppSpace.lg),
            input(),
          ],
          const SizedBox(height: AppSpace.lg),
          SheetButtons(
            secondary: l.cancel,
            onSecondary: () => Navigator.of(ctx).pop(),
            primary: l.bulkFieldApply(count),
            onPrimary: field == null || value.trim().isEmpty ? null : () => Navigator.of(ctx).pop(BulkFieldChoice(field!.id, value.trim())),
          ),
        ]),
      );
    }),
  );
}

/// A message to open in WhatsApp for each selected contact, one chat at a time.
Future<void> showBulkWhatsAppSheet(BuildContext context, List<ContactSummary> list) {
  final l = AppLocalizations.of(context);
  final withPhone = [for (final s in list) if (s.whatsAppPhones.isNotEmpty) s];
  if (withPhone.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.bulkWaNone)));
    return Future.value();
  }
  final msg = TextEditingController();
  final sent = <int>{};
  return showGlassSheet<void>(
    context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      final p = ctx.palette;
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetTitle(l.bulkWhatsApp, bottom: AppSpace.sm),
        GlassField(controller: msg, label: l.bulkWaMessage, maxLines: 3, textCapitalization: TextCapitalization.sentences),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, AppSpace.sm, 0, AppSpace.sm),
          child: Text(l.bulkWaHint, style: TextStyle(fontSize: AppFont.body, height: AppLine.loose, color: p.text2)),
        ),
        Flexible(
          child: ListView(shrinkWrap: true, children: [
            for (var i = 0; i < withPhone.length; i++)
              SheetItem(
                first: i == 0,
                icon: sent.contains(withPhone[i].contact.id) ? Lu.circleCheck : Lu.messageSquare,
                title: withPhone[i].fullName,
                onTap: () async {
                  final s = withPhone[i];
                  final ph = s.whatsAppPhone ?? s.whatsAppPhones.first;
                  final text = msg.text.trim();
                  final url = 'https://wa.me/${normalizePhone(ph.countryCode, ph.number)}${text.isEmpty ? '' : '?text=${Uri.encodeComponent(text)}'}';
                  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                  setS(() => sent.add(s.contact.id));
                },
              ),
          ]),
        ),
      ]);
    }),
  );
}
