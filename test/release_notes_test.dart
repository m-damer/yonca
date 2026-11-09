import 'package:flutter_test/flutter_test.dart';
import 'package:yonca/features/settings/updates_page.dart';

void main() {
  const both = '- New widgets\n- Fixes\n---AR---\n- ودجات جديدة\n- إصلاحات';
  test('Arabic app shows the Arabic notes', () => expect(releaseNoteLines(both, 'ar'), ['ودجات جديدة', 'إصلاحات']));
  test('English app shows the English notes', () => expect(releaseNoteLines(both, 'en'), ['New widgets', 'Fixes']));
  test('notes in one language are shown as they are', () => expect(releaseNoteLines('- Only English', 'ar'), ['Only English']));
  test('an empty Arabic part falls back to English', () => expect(releaseNoteLines('- A\n---AR---\n', 'ar'), ['A']));
}
