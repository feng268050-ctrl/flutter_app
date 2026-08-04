import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_l10n.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('MaterialTypeAliases maps Chinese Excel names for English UI', () {
    expect(
      MaterialTypeAliases.localizeStored('不锈钢', l10n),
      'Stainless Steel',
    );
    expect(
      MaterialTypeAliases.localizeStored('不锈钢-2mm', l10n),
      'Stainless Steel-2mm',
    );
    expect(
      MaterialTypeAliases.resolve('碳钢'),
      MaterialType.carbonSteel,
    );
  });

  test('ProcessPreset prefers localized material over Chinese materialName', () {
    final preset = ProcessPreset(
      uuid: 't',
      name: '不锈钢',
      kind: ProcessPresetKind.engineerPreset,
      source: 'test',
      isBuiltin: true,
      processType: ProcessType.continuousWelding,
      materialType: MaterialType.stainlessSteel,
      materialName: '不锈钢',
      thickness: 1,
      parameters: const ProcessParameters.empty(),
      createdAtMs: 0,
      updatedAtMs: 0,
    );
    expect(preset.displayMaterialLabel(l10n), 'Stainless Steel');
    expect(preset.displayProcessName(l10n), 'Stainless Steel');
  });
}
