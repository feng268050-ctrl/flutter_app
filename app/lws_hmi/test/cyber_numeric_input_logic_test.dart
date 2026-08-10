import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/engineer_parameter_input_copy.dart';
import 'package:lws_hmi/l10n/app_localizations_en.dart';
import 'package:lws_hmi/ui/cyber/cyber_ime_numeric_input_dialog.dart';

void main() {
  group('CyberNumericInputLogic', () {
    test('integer step clamps at bounds', () {
      expect(
        CyberNumericInputLogic.applyStep(
          currentInput: '0',
          increment: false,
          decimalStep: false,
          decimalStepSize: 0.1,
          minValue: 0,
          maxValue: 100,
        ),
        '0',
      );
      expect(
        CyberNumericInputLogic.applyStep(
          currentInput: '99',
          increment: true,
          decimalStep: false,
          decimalStepSize: 0.1,
          minValue: 0,
          maxValue: 100,
        ),
        '100',
      );
    });

    test('decimal step uses 0.1', () {
      expect(
        CyberNumericInputLogic.applyStep(
          currentInput: '1',
          increment: true,
          decimalStep: true,
          decimalStepSize: 0.1,
          minValue: 0,
          maxValue: 6,
        ),
        '1.1',
      );
    });

    test('formatDefaultInput strips trailing .0', () {
      expect(
        CyberNumericInputLogic.formatDefaultInput(
          '150.0',
          decimalStep: false,
        ),
        '150',
      );
    });
  });

  group('EngineerParameterInputCopy', () {
    final l10n = AppLocalizationsEn();
    final gasSpec = ProcessParameterCatalog.byKey['process.blowing_delay']!;

    test('gas pre-flow title and description match lws-ui', () {
      expect(
        EngineerParameterInputCopy.titleWithUnit(
          l10n,
          l10n.paramGasPreFlow,
          gasSpec.unit,
        ),
        'Gas Pre-Flow (ms)',
      );
      expect(
        EngineerParameterInputCopy.descriptionFor(
          key: gasSpec.key,
          processType: ProcessType.continuousWelding,
          l10n: l10n,
          spec: gasSpec,
        ),
        'Gas pre-flow time before laser emission. Range: 0–10000 ms.',
      );
    });

    test('wide cleaning raises swing width max to 30', () {
      expect(
        EngineerParameterInputCopy.effectiveMax(
          'process.swing_width',
          ProcessType.wideCleaning,
          6,
        ),
        30,
      );
    });
  });
}
