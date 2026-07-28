import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_library/application/process_library_controller.dart';
import 'package:lws_hmi/features/process_library/application/process_library_importer.dart';
import 'package:lws_hmi/features/process_library/application/process_library_package_scanner.dart';
import 'package:lws_hmi/features/process_library/application/process_library_scope.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Device Information → Update Process Library (offline USB / OTA drop-in).
final class ProcessLibraryImportPage extends StatefulWidget {
  const ProcessLibraryImportPage({super.key});

  @override
  State<ProcessLibraryImportPage> createState() =>
      _ProcessLibraryImportPageState();
}

final class _ProcessLibraryImportPageState
    extends State<ProcessLibraryImportPage> {
  List<ProcessLibraryPackageCandidate> _candidates = const [];
  bool _scanning = true;
  bool _importing = false;
  String? _scanError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_scan());
    });
  }

  ProcessLibraryController get _library => ProcessLibraryScope.of(context);

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _scanError = null;
    });
    try {
      final list = await _library.scanImportCandidates();
      if (!mounted) {
        return;
      }
      setState(() {
        _candidates = list;
        _scanning = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _scanning = false;
        _scanError = '$error';
        _candidates = const [];
      });
    }
  }

  Future<void> _import(ProcessLibraryPackageCandidate candidate) async {
    if (_importing) {
      return;
    }
    CyberClickSoundRegistry.playClick();
    setState(() => _importing = true);
    final audit = await _library.importExternal(candidate);
    if (!mounted) {
      return;
    }
    setState(() => _importing = false);
    await _showAudit(audit);
  }

  Future<void> _showAudit(ProcessLibraryImportAudit audit) async {
    final l10n = AppLocalizations.of(context)!;
    final statusLabel = switch (audit.status) {
      ProcessLibraryImportStatus.imported => l10n.processLibraryAuditImported,
      ProcessLibraryImportStatus.current => l10n.processLibraryAuditCurrent,
      ProcessLibraryImportStatus.rejected => l10n.processLibraryAuditRejected,
      ProcessLibraryImportStatus.noCompatibleLibrary =>
        l10n.processLibraryAuditNoCompatible,
    };
    await showCyberDialog<void>(
      context: context,
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.processLibraryAuditTitle,
              style: const TextStyle(
                fontSize: 20,
                color: CyberColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              statusLabel,
              style: TextStyle(
                color: audit.isSuccess
                    ? CyberColors.textPrimary
                    : CyberColors.buttonSecondaryText,
                fontSize: 16,
              ),
            ),
            if (audit.fromVersion != null || audit.toVersion != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.processLibraryAuditFromTo(
                  audit.fromVersion ?? '—',
                  audit.toVersion ?? '—',
                ),
                style: const TextStyle(color: CyberColors.textSecondary),
              ),
            ],
            if (audit.rowCount != null) ...[
              const SizedBox(height: 4),
              Text(
                l10n.processLibraryAuditRows(audit.rowCount!),
                style: const TextStyle(color: CyberColors.textSecondary),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              l10n.processLibraryAuditUsersKept(audit.preservedUserCount),
              style: const TextStyle(color: CyberColors.textSecondary),
            ),
            if (audit.packagePath != null) ...[
              const SizedBox(height: 4),
              Text(
                l10n.processLibraryAuditPath(audit.packagePath!),
                style: const TextStyle(
                  color: CyberColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
            if (audit.errors.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                audit.errors.join('\n'),
                style: const TextStyle(
                  color: CyberColors.buttonSecondaryText,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 20),
            CyberButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.closeText),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsScaffold(
      title: l10n.processLibraryImportTitle,
      body: SettingsScrollView(
        children: [
          SettingsHelpFooter(l10n.processLibraryScanHint),
          if (_scanning || _importing)
            const Padding(
              padding: EdgeInsets.all(SettingsDimens.inset),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_scanError != null)
            SettingsHelpFooter(_scanError!)
          else if (_candidates.isEmpty)
            SettingsHelpFooter(l10n.processLibraryNoPackages)
          else
            SettingsGroup(
              children: [
                for (final candidate in _candidates)
                  SettingsNavRow(
                    title: candidate.libraryVersion,
                    value: candidate.modelMatched
                        ? l10n.processLibraryModelMatch
                        : l10n.processLibraryModelMismatch,
                    showChevron: false,
                    onTap: _importing
                        ? null
                        : () => unawaited(_import(candidate)),
                    trailingExtra: Text(
                      l10n.processLibraryImportAction,
                      style: const TextStyle(
                        color: CyberColors.buttonPrimaryFill,
                        fontSize: 16,
                      ),
                    ),
                  ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SettingsDimens.inset,
              8,
              SettingsDimens.inset,
              SettingsDimens.inset,
            ),
            child: Center(
              child: SizedBox(
                width: 280,
                height: CyberDimens.actionButtonHeight,
                child: CyberButton(
                  onPressed: (_scanning || _importing)
                      ? null
                      : () => unawaited(_scan()),
                  child: Text(
                    _importing
                        ? l10n.processLibraryImporting
                        : l10n.processLibraryRescan,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
