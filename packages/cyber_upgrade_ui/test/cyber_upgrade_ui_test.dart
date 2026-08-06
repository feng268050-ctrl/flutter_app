import 'package:cyber_upgrade_ui/cyber_upgrade_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UpgradePolicy / checker gate', () {
    test('hostForce skips version check', () {
      expect(UpgradePolicy.hostForce.checkVersion, isFalse);
      expect(UpgradePolicy.hostForce.requireConfirm, isFalse);
      expect(shouldRunVersionCheck(UpgradePolicy.hostForce), isFalse);
    });

    test('operator policy requires version check', () {
      expect(shouldRunVersionCheck(UpgradePolicy.operator), isTrue);
    });
  });

  group('UpgradeCheckCard', () {
    testWidgets('shows available headline', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: UpgradeCheckCard(
                state: UpgradeCheckUiState.available,
                availableHeadline: 'New version 2.0',
                availableBody: 'Notes',
              ),
            ),
          ),
        ),
      );
      expect(find.text('New version 2.0'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
    });

    testWidgets('checking shows spinner label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: UpgradeCheckCard(
                state: UpgradeCheckUiState.checking,
                checkingLabel: 'Checking…',
              ),
            ),
          ),
        ),
      );
      expect(find.text('Checking…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('unavailable does not claim up to date', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: UpgradeCheckCard(
                state: UpgradeCheckUiState.unavailable,
                unavailableMessage: 'Check unavailable',
                upToDateMessage: 'Already up to date',
              ),
            ),
          ),
        ),
      );
      expect(find.text('Check unavailable'), findsOneWidget);
      expect(find.text('Already up to date'), findsNothing);
    });
  });

  group('UpgradePhaseProgressView', () {
    const phases = [
      UpgradePhase(id: 'download', label: 'Download'),
      UpgradePhase(id: 'verify', label: 'Verify'),
      UpgradePhase(id: 'write', label: 'Write'),
    ];

    testWidgets('multi-phase shows status and percent', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: UpgradePhaseProgressView(
                phases: phases,
                progress: UpgradeProgress(
                  activePhaseId: 'download',
                  percent: 42,
                ),
                statusLabel: 'Downloading',
              ),
            ),
          ),
        ),
      );
      expect(find.text('Downloading'), findsOneWidget);
      expect(find.text('42%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('single-phase progress', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: UpgradePhaseProgressView(
                phases: [
                  UpgradePhase(id: 'transferring', label: 'Transferring'),
                ],
                progress: UpgradeProgress(
                  activePhaseId: 'transferring',
                  percent: 80,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Transferring'), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);
    });

    testWidgets('indeterminate hides percent bar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: UpgradePhaseProgressView(
                phases: phases,
                progress: UpgradeProgress(
                  activePhaseId: 'download',
                  indeterminate: true,
                ),
                statusLabel: 'Preparing',
              ),
            ),
          ),
        ),
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('UpgradeCompletionTip', () {
    testWidgets('OTA auto-reboot success shows reboot notice', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UpgradeCompletionTip(
              progress: UpgradeProgress(
                activePhaseId: 'arm',
                isTerminalOk: true,
              ),
              config: UpgradeCompletionConfig.autoReboot(
                rebootNotice: 'Rebooting…',
                failureBody: 'Failed',
              ),
            ),
          ),
        ),
      );
      expect(find.text('Rebooting…'), findsOneWidget);
      expect(find.text('Failed'), findsNothing);
    });

    testWidgets('no-reboot success shows body without reboot notice',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UpgradeCompletionTip(
              progress: UpgradeProgress(
                activePhaseId: 'transferring',
                isTerminalOk: true,
              ),
              config: UpgradeCompletionConfig.noReboot(
                successBody: 'Firmware written.',
              ),
            ),
          ),
        ),
      );
      expect(find.text('Firmware written.'), findsOneWidget);
      expect(find.text('Rebooting…'), findsNothing);
    });

    testWidgets('failure does not claim success', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UpgradeCompletionTip(
              progress: UpgradeProgress(
                activePhaseId: 'write',
                isTerminalFail: true,
                errorMessage: 'verify failed',
              ),
              config: UpgradeCompletionConfig.autoReboot(
                rebootNotice: 'All good',
                failureBody: 'Upgrade failed',
              ),
            ),
          ),
        ),
      );
      expect(find.text('Upgrade failed'), findsOneWidget);
      expect(find.text('All good'), findsNothing);
    });
  });

  group('UpgradeCompletionConfig', () {
    test('autoReboot sets postApplyAction.autoReboot', () {
      const c = UpgradeCompletionConfig.autoReboot(rebootNotice: 'reboot');
      expect(c.willAutoReboot, isTrue);
      expect(c.postApplyAction, UpgradePostApplyAction.autoReboot);
      expect(c.successHint, 'reboot');
      expect(c.autoRebootDelay, const Duration(milliseconds: 1500));
    });

    test('noReboot does not auto-reboot', () {
      const c = UpgradeCompletionConfig.noReboot(successBody: 'ok');
      expect(c.willAutoReboot, isFalse);
      expect(c.postApplyAction, UpgradePostApplyAction.none);
      expect(c.successHint, isNull);
    });
  });

  group('UpgradePostApplyListener', () {
    testWidgets('invokes onAutoReboot after delay once', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: UpgradePostApplyListener(
            progress: const UpgradeProgress(
              activePhaseId: 'arm',
              isTerminalOk: true,
            ),
            config: const UpgradeCompletionConfig.autoReboot(
              rebootNotice: 'bye',
              autoRebootDelay: Duration(milliseconds: 50),
            ),
            onAutoReboot: () async {
              calls++;
            },
            child: const SizedBox.shrink(),
          ),
        ),
      );
      expect(calls, 0);
      await tester.pump(const Duration(milliseconds: 60));
      expect(calls, 1);
      await tester.pump(const Duration(milliseconds: 60));
      expect(calls, 1);
    });
  });
}
