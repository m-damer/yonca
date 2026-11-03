import 'dart:convert';

import '../../data/app_database.dart';
import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';

/// One line that can go into a QR code: a [kind] (prefix, first, last, job, dept, company, phone, email,
/// website, address, custom), the [label] shown to the person, and the [value].
class QrField {
  const QrField(this.kind, this.label, this.value);
  final String kind;
  final String label;
  final String value;

  Map<String, dynamic> toJson() => {'k': kind, 'l': label, 'v': value};
  factory QrField.fromJson(Map<String, dynamic> j) => QrField(j['k'] as String, j['l'] as String, j['v'] as String);
}

/// The fields of an app contact, in the order the checklist shows them. Empty values are left out.
List<QrField> qrFieldsFromContact(AppLocalizations l, ContactSummary s, {Map<String, String> custom = const {}}) {
  final c = s.contact;
  return [
    QrField('prefix', l.fieldPrefix, c.prefix),
    QrField('first', l.fieldFirstName, c.firstName),
    QrField('last', l.fieldLastName, c.lastName),
    QrField('job', l.fieldJobTitle, c.jobTitle),
    QrField('dept', l.fieldDepartment, c.department),
    QrField('company', l.fieldCompany, c.company),
    for (final p in s.phones) QrField('phone', l.fieldPhone, '${p.countryCode}${p.number}'.replaceAll(' ', '')),
    for (final e in s.emails) QrField('email', l.fieldEmail, e.value),
    for (final w in s.websites) QrField('website', l.fieldWebsite, w.value),
    for (final a in s.addresses) QrField('address', l.fieldAddress, a.value),
    for (final e in custom.entries) QrField('custom', e.key, e.value),
  ].where((f) => f.value.trim().isNotEmpty).toList();
}

String _esc(String s) => s.replaceAll(r'\', r'\\').replaceAll(';', r'\;').replaceAll(',', r'\,').replaceAll('\n', r'\n');

/// The vCard text of the chosen fields.
String qrVCard(List<QrField> f) {
  String one(String k) => f.where((x) => x.kind == k).map((x) => x.value).firstOrNull ?? '';
  final first = one('first'), last = one('last'), prefix = one('prefix'), company = one('company');
  final name = [prefix, first, last].where((e) => e.isNotEmpty).join(' ');
  final b = StringBuffer('BEGIN:VCARD\r\nVERSION:3.0\r\n');
  b.write('N:${_esc(last)};${_esc(first)};;${_esc(prefix)};\r\n');
  b.write('FN:${_esc(name.isEmpty ? company : name)}\r\n');
  if (company.isNotEmpty || one('dept').isNotEmpty) b.write('ORG:${_esc(company)}${one('dept').isEmpty ? '' : ';${_esc(one('dept'))}'}\r\n');
  if (one('job').isNotEmpty) b.write('TITLE:${_esc(one('job'))}\r\n');
  for (final x in f) {
    switch (x.kind) {
      case 'phone':
        b.write('TEL;TYPE=${x.label == 'landline' ? 'VOICE' : 'CELL'}:${x.value.replaceAll(' ', '')}\r\n');
      case 'email':
        b.write('EMAIL;TYPE=INTERNET:${_esc(x.value)}\r\n');
      case 'website':
        b.write('URL:${_esc(x.value)}\r\n');
      case 'address':
        b.write('ADR;TYPE=WORK:;;${_esc(x.value)};;;;\r\n');
      case 'custom':
        b.write('NOTE:${_esc('${x.label}: ${x.value}')}\r\n');
    }
  }
  b.write('END:VCARD\r\n');
  return b.toString();
}

/// A saved code. Kept as JSON in the settings table, so no database change is needed.
class SavedQr {
  SavedQr({required this.id, required this.title, required this.createdAt, required this.fields, this.logoPath = '', this.includeLogo = false});
  final int id;
  String title;
  final DateTime createdAt;
  final List<QrField> fields;
  String logoPath;
  bool includeLogo;

  String get data => qrVCard(fields);

  Map<String, dynamic> toJson() => {
        'id': id,
        't': title,
        'at': createdAt.millisecondsSinceEpoch,
        'f': [for (final x in fields) x.toJson()],
        'logo': logoPath,
        'inc': includeLogo,
      };

  factory SavedQr.fromJson(Map<String, dynamic> j) => SavedQr(
        id: j['id'] as int,
        title: j['t'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
        fields: [for (final x in j['f'] as List) QrField.fromJson(x as Map<String, dynamic>)],
        logoPath: j['logo'] as String? ?? '',
        includeLogo: j['inc'] as bool? ?? false,
      );
}

class QrStore {
  QrStore(this.db);
  final AppDatabase db;
  static const _key = 'qr.saved';

  Future<List<SavedQr>> load() async {
    final raw = await db.getSetting(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = [for (final x in jsonDecode(raw) as List) SavedQr.fromJson(x as Map<String, dynamic>)];
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(List<SavedQr> l) => db.putSetting(_key, jsonEncode([for (final x in l) x.toJson()]));

  Future<SavedQr> add({required String title, required List<QrField> fields, String logoPath = '', bool includeLogo = false}) async {
    final all = await load();
    final id = all.fold<int>(0, (m, e) => e.id > m ? e.id : m) + 1;
    final q = SavedQr(id: id, title: title, createdAt: DateTime.now(), fields: fields, logoPath: logoPath, includeLogo: includeLogo);
    await _write([...all, q]);
    return q;
  }

  Future<void> update(SavedQr q) async {
    final all = await load();
    await _write([for (final x in all) x.id == q.id ? q : x]);
  }

  Future<void> remove(int id) async {
    final all = await load();
    await _write([for (final x in all) if (x.id != id) x]);
  }
}
