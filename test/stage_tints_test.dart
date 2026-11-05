import 'package:flutter_test/flutter_test.dart';
import 'package:yonca/domain/deal_models.dart';
import 'package:yonca/theme/tokens.dart';

void main() {
  test('the ten stage tints are all different, in light and in dark', () {
    expect(AppTint.stagesLight.length, stageTintCount);
    expect(AppTint.stagesDark.length, stageTintCount);
    expect(AppTint.stagesLight.toSet().length, stageTintCount);
    expect(AppTint.stagesDark.toSet().length, stageTintCount);
  });

  test('the twelve tag colours are all different', () {
    expect(AppTint.tags.toSet().length, AppTint.tags.length);
  });
}
