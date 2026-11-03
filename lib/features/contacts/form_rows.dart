import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/lucide.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import 'contact_widgets.dart';
import 'country_sheet.dart';

/// Shared building blocks of the contact form and the My Profile form, so both look and behave the same.

/// One phone row: country code, number, type.
class PhoneFormRow {
  PhoneFormRow({this.code = '+963', String number = '', this.label = 'mobile'}) : number = TextEditingController(text: number);
  String code;
  final TextEditingController number;
  final FocusNode focus = FocusNode();
  String label;
  void dispose() {
    number.dispose();
    focus.dispose();
  }
}

/// One email, website or address row. Addresses also use [map] for the map link.
class EntryFormRow {
  EntryFormRow({String value = '', this.label = 'work', String map = ''})
      : value = TextEditingController(text: value),
        map = TextEditingController(text: map);
  final TextEditingController value;
  final TextEditingController map;
  final FocusNode focus = FocusNode();
  String label;
  void dispose() {
    value.dispose();
    map.dispose();
    focus.dispose();
  }
}

String entryKindLabel(AppLocalizations l, String kind) =>
    switch (kind) { 'email' => l.fieldEmail, 'website' => l.fieldWebsite, 'relation' => l.fieldRelation, 'im' => l.fieldIm, _ => l.fieldAddress };

String entryAddText(AppLocalizations l, String kind) =>
    switch (kind) { 'email' => l.addEmail, 'website' => l.addWebsite, 'relation' => l.addRelation, 'im' => l.addIm, _ => l.addAddress };

/// Opens the type list of a typed field. [options] are type keys; returns the chosen key.
Future<String?> chooseFormLabel(BuildContext context, String title, List<String> options, String current, {String kind = ''}) {
  final l = AppLocalizations.of(context);
  return showGlassSheet<String>(
    context,
    builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetTitle(title),
      for (var i = 0; i < options.length; i++)
        SheetItem(
          first: i == 0,
          title: entryLabelText(l, kind, options[i]),
          bold: current == options[i],
          selected: current == options[i],
          onTap: () => Navigator.of(ctx).pop(options[i]),
        ),
    ]),
  );
}

/// Asks where the photo comes from. Returns null when cancelled, '' to remove the photo, else the saved file path.
Future<String?> pickFormPhoto(BuildContext context, {required bool hasPhoto, String prefix = ''}) async {
  final l = AppLocalizations.of(context);
  final v = await showGlassSheet<String>(
    context,
    builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetTitle(l.photoTitle),
      SheetItem(first: true, icon: Lu.camera, title: l.photoTake, onTap: () => Navigator.of(ctx).pop('camera')),
      SheetItem(icon: Lu.images, title: l.photoGallery, onTap: () => Navigator.of(ctx).pop('gallery')),
      if (hasPhoto) SheetItem(icon: Lu.trash2, title: l.photoRemove, danger: true, onTap: () => Navigator.of(ctx).pop('remove')),
    ]),
  );
  if (v == null) return null;
  if (v == 'remove') return '';
  try {
    final x = await ImagePicker().pickImage(source: v == 'camera' ? ImageSource.camera : ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
    if (x == null) return null;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/contact_photos');
    await dir.create(recursive: true);
    final dest = '${dir.path}/$prefix${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(x.path).copy(dest);
    return dest;
  } catch (_) {
    return null;
  }
}

/// The photo at the top of a form: the picture or a dashed camera box, and "Add photo" / "Change photo" under it.
class FormPhoto extends StatelessWidget {
  const FormPhoto({super.key, required this.photo, required this.onTap});
  final String? photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final has = photo != null && photo!.isNotEmpty;
    return Center(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Column(children: [
          if (has && File(photo!).existsSync())
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Image.file(File(photo!), width: AppControl.hero, height: AppControl.hero, fit: BoxFit.cover),
            )
          else
            CustomPaint(
              painter: _DashedRRect(color: p.outline, radius: AppRadius.md),
              child: SizedBox(width: AppControl.hero, height: AppControl.hero, child: Icon(Lu.camera, color: p.primary)),
            ),
          const SizedBox(height: AppSpace.md),
          Text(has ? l.changePhoto : l.addPhoto,
              style: TextStyle(color: p.primary, fontWeight: FontWeight.w600, fontSize: AppFont.bodyL, height: AppLine.normal)),
        ]),
      ),
    );
  }
}

class _DashedRRect extends CustomPainter {
  _DashedRRect({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(RRect.fromRectAndRadius((Offset.zero & size).deflate(.75), Radius.circular(radius)));
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 3), paint);
        d += 6;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRect old) => old.color != color || old.radius != radius;
}

/// "+ Add ..." link under a group of fields: blue with a small plus.
class FormAddLink extends StatelessWidget {
  const FormAddLink({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.md, AppSpace.xs, 0),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Lu.plus, size: AppIcon.md, color: p.primary),
          const SizedBox(width: AppSpace.sm),
          Text(label, style: TextStyle(fontSize: AppFont.bodyL, height: AppLine.normal, fontWeight: FontWeight.w500, color: p.primary)),
        ]),
      ),
    );
  }
}

/// The remove (minus) button, centred on the input box: it skips the label and gap above it.
class FormRemoveButton extends StatelessWidget {
  const FormRemoveButton({super.key, required this.onTap, this.tooltip});
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.x3),
      child: SizedBox(
        height: AppControl.lg,
        child: Center(
          child: IconButton(
            tooltip: tooltip,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            onPressed: onTap,
            icon: Icon(Lu.circleMinus, color: p.error.withValues(alpha: .8)),
          ),
        ),
      ),
    );
  }
}

/// A field with a type (Google Contacts style): while it is not being edited the type shows in the label.
class TypedFieldRow extends StatelessWidget {
  const TypedFieldRow({
    super.key,
    required this.open,
    required this.label,
    required this.typeText,
    required this.field,
    required this.onPickType,
    required this.onRemove,
    this.below,
  });
  final bool open;
  final String label;
  final String typeText;
  final GlassField Function(String shownLabel) field;
  final VoidCallback onPickType;
  final VoidCallback onRemove;
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          field(open ? label : '$label ($typeText)'),
          AnimatedSize(
            duration: const Duration(milliseconds: 150),
            alignment: Alignment.topCenter,
            child: open
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpace.md),
                    child: GlassSelectField(label: l.phoneLabel, value: typeText, onTap: onPickType),
                  )
                : const SizedBox(width: double.infinity),
          ),
          if (below != null) Padding(padding: const EdgeInsets.only(top: AppSpace.md), child: below),
        ]),
      ),
      const SizedBox(width: AppSpace.xs),
      FormRemoveButton(onTap: onRemove, tooltip: l.delete),
    ]);
  }
}

/// A phone row: country code, number and type.
class PhoneRowField extends StatelessWidget {
  const PhoneRowField({
    super.key,
    required this.row,
    required this.open,
    required this.short,
    required this.onRemove,
    required this.onPickType,
    required this.onPickCode,
    required this.onChanged,
  });
  final PhoneFormRow row;
  final bool open;
  final bool short;
  final VoidCallback onRemove;
  final VoidCallback onPickType;
  final VoidCallback onPickCode;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return TypedFieldRow(
      open: open,
      label: l.fieldPhone,
      typeText: entryLabelText(l, '', row.label),
      onRemove: onRemove,
      onPickType: onPickType,
      field: (shown) => GlassField(
        controller: row.number,
        focusNode: row.focus,
        label: shown,
        keyboardType: TextInputType.phone,
        textDirection: TextDirection.ltr,
        forceLtr: true,
        leading: CountrySelector(code: row.code, onTap: onPickCode),
        prefixText: row.code,
        error: short ? l.errPhoneShort : null,
        onChanged: (_) => onChanged(),
      ),
    );
  }
}

/// An email, website or address row (an address also has a map link under it).
class EntryRowField extends StatelessWidget {
  const EntryRowField({super.key, required this.kind, required this.row, required this.open, required this.onRemove, required this.onPickType});
  final String kind;
  final EntryFormRow row;
  final bool open;
  final VoidCallback onRemove;
  final VoidCallback onPickType;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return TypedFieldRow(
      open: open,
      label: entryKindLabel(l, kind),
      typeText: entryLabelText(l, kind, row.label),
      onRemove: onRemove,
      onPickType: onPickType,
      field: (shown) => GlassField(
        controller: row.value,
        focusNode: row.focus,
        label: shown,
        maxLines: kind == 'address' ? 3 : 1,
        textCapitalization: kind == 'relation' ? TextCapitalization.words : TextCapitalization.none,
        keyboardType: switch (kind) {
          'email' => TextInputType.emailAddress,
          'website' => TextInputType.url,
          'relation' => TextInputType.name,
          'im' => TextInputType.text,
          _ => TextInputType.streetAddress,
        },
        textDirection: kind == 'address' || kind == 'relation' ? null : TextDirection.ltr,
      ),
      below: kind == 'address'
          ? GlassField(
              controller: row.map,
              label: l.fieldMapLink,
              hint: l.mapLinkHint,
              keyboardType: TextInputType.url,
              textDirection: TextDirection.ltr,
            )
          : null,
    );
  }
}
