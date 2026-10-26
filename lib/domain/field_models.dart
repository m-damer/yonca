enum FieldScope { contact, deal }

enum FieldType { text, number, date, bool, choice }

FieldType fieldTypeFromName(String s) => FieldType.values.firstWhere((t) => t.name == s, orElse: () => FieldType.text);

const maxFieldsPerScope = 15;
const maxChoiceOptions = 20;

class FieldValidationException implements Exception {
  const FieldValidationException(this.problem);
  final String problem;
  @override
  String toString() => problem;
}

class FieldInput {
  const FieldInput({
    required this.scope,
    required this.name,
    this.type = FieldType.text,
    this.unit = '',
    this.options = const [],
    this.required = false,
    this.showInReports = true,
  });
  final FieldScope scope;
  final String name;
  final FieldType type;
  final String unit;
  final List<String> options;
  final bool required;
  final bool showInReports;

  String? problem() {
    final n = name.trim();
    if (n.isEmpty || n.length > 30) return 'name';
    if (type == FieldType.choice) {
      final o = options.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (o.isEmpty) return 'options';
      if (o.length > maxChoiceOptions) return 'options';
    }
    return null;
  }
}
