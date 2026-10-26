import '../../domain/field_models.dart';
import '../../l10n/app_localizations.dart';

String fieldTypeLabel(AppLocalizations l, FieldType t) => switch (t) {
      FieldType.text => l.ftText,
      FieldType.number => l.ftNumber,
      FieldType.date => l.ftDate,
      FieldType.bool => l.ftBool,
      FieldType.choice => l.ftChoice,
    };
