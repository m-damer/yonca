import '../core/phone_split.dart';
import '../data/app_database.dart';
import 'contact_models.dart';

String _esc(String s) => s.replaceAll(r'\', r'\\').replaceAll(';', r'\;').replaceAll(',', r'\,').replaceAll('\n', r'\n');

String _unesc(String s) => s.replaceAll(r'\n', '\n').replaceAll(r'\N', '\n').replaceAll(r'\,', ',').replaceAll(r'\;', ';').replaceAll(r'\\', r'\');

/// One contact as a vCard 3.0 card.
/// With [compact] only the name, company, title, two numbers and two emails are written (small enough for a QR code).
String encodeVCard(ContactSummary s, {bool compact = false}) {
  final c = s.contact;
  final b = StringBuffer()
    ..writeln('BEGIN:VCARD')
    ..writeln('VERSION:3.0')
    ..writeln('N:${_esc(c.lastName)};${_esc(c.firstName)};;${_esc(c.prefix)};')
    ..writeln('FN:${_esc(s.displayName)}');
  if (c.company.isNotEmpty) b.writeln('ORG:${_esc(c.company)}${c.department.isEmpty ? '' : ';${_esc(c.department)}'}');
  if (c.jobTitle.isNotEmpty) b.writeln('TITLE:${_esc(c.jobTitle)}');
  if (!compact && c.nickname.isNotEmpty) b.writeln('NICKNAME:${_esc(c.nickname)}');
  for (final p in compact ? s.phones.take(2) : s.phones) {
    b.writeln('TEL;TYPE=${p.label == 'work' ? 'WORK' : (p.label == 'home' ? 'HOME' : 'CELL')}:${p.countryCode}${p.number}'.replaceAll(' ', ''));
  }
  for (final e in compact ? s.emails.take(2) : s.emails) {
    b.writeln('EMAIL;TYPE=INTERNET:${_esc(e.value)}');
  }
  for (final w in compact ? const <ContactEntry>[] : s.websites) {
    b.writeln('URL:${_esc(w.value)}');
  }
  for (final a in compact ? const <ContactEntry>[] : s.addresses) {
    b.writeln('ADR;TYPE=WORK:;;${_esc(a.value)};;;;');
  }
  if (!compact && c.requirements.isNotEmpty) b.writeln('NOTE:${_esc(c.requirements)}');
  b.writeln('END:VCARD');
  return b.toString().replaceAll('\n', '\r\n');
}

String encodeVCards(Iterable<ContactSummary> list) => list.map(encodeVCard).join();

/// Reads every card in [text]. Cards without a name, company or phone are skipped.
List<ContactInput> parseVCards(String text) {
  // Unfold continuation lines (a line starting with a space or tab continues the previous one).
  final lines = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').replaceAll(RegExp(r'\n[ \t]'), '').split('\n');
  final out = <ContactInput>[];
  Map<String, List<(String, String)>>? card;
  for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final upper = line.toUpperCase();
    if (upper == 'BEGIN:VCARD') {
      card = {};
      continue;
    }
    if (upper == 'END:VCARD') {
      final input = card == null ? null : _toInput(card);
      if (input != null) out.add(input);
      card = null;
      continue;
    }
    if (card == null) continue;
    final i = line.indexOf(':');
    if (i < 0) continue;
    final head = line.substring(0, i).split(';');
    final name = head.first.toUpperCase().split('.').last;
    final params = head.skip(1).join(';').toUpperCase();
    (card[name] ??= []).add((params, line.substring(i + 1)));
  }
  return out;
}

ContactInput? _toInput(Map<String, List<(String, String)>> c) {
  String first(String k) => (c[k]?.isNotEmpty ?? false) ? c[k]!.first.$2 : '';
  var firstName = '', lastName = '', prefix = '';
  final n = first('N');
  if (n.isNotEmpty) {
    final parts = n.split(';');
    lastName = _unesc(parts.isNotEmpty ? parts[0] : '');
    firstName = _unesc(parts.length > 1 ? parts[1] : '');
    prefix = _unesc(parts.length > 3 ? parts[3] : '');
  } else if (first('FN').isNotEmpty) {
    final fn = _unesc(first('FN')).trim();
    final sp = fn.indexOf(' ');
    firstName = sp < 0 ? fn : fn.substring(0, sp);
    lastName = sp < 0 ? '' : fn.substring(sp + 1);
  }
  final org = first('ORG').split(';');
  final phones = <PhoneInput>[];
  for (final t in c['TEL'] ?? const <(String, String)>[]) {
    final raw = t.$2.trim();
    if (raw.isEmpty) continue;
    final (code, number) = splitPhone(raw);
    final label = t.$1.contains('WORK') ? 'work' : (t.$1.contains('HOME') ? 'home' : 'mobile');
    phones.add(PhoneInput(number: number, countryCode: code, label: label));
  }
  final input = ContactInput(
    firstName: firstName.trim(),
    lastName: lastName.trim(),
    prefix: prefix.trim(),
    company: _unesc(org.first).trim(),
    department: org.length > 1 ? _unesc(org[1]).trim() : '',
    jobTitle: _unesc(first('TITLE')).trim(),
    nickname: _unesc(first('NICKNAME')).trim(),
    requirements: _unesc(first('NOTE')).trim(),
    phones: phones,
    emails: [for (final e in c['EMAIL'] ?? const <(String, String)>[]) if (e.$2.trim().isNotEmpty) EntryInput(value: _unesc(e.$2.trim()), label: e.$1.contains('HOME') ? 'home' : 'work')],
    websites: [for (final e in c['URL'] ?? const <(String, String)>[]) if (e.$2.trim().isNotEmpty) EntryInput(value: _unesc(e.$2.trim()))],
    addresses: [
      for (final e in c['ADR'] ?? const <(String, String)>[])
        if (e.$2.split(';').map(_unesc).where((p) => p.trim().isNotEmpty).isNotEmpty)
          EntryInput(value: e.$2.split(';').map(_unesc).where((p) => p.trim().isNotEmpty).join(', ')),
    ],
  );
  try {
    input.validate();
  } on ContactValidationException {
    return null;
  }
  return input;
}
