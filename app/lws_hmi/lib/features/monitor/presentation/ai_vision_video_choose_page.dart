import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_repository.dart';
import 'package:lws_hmi/features/process_video/infrastructure/sqlite_process_video_repository.dart';
import 'package:lws_hmi/features/process_video/presentation/process_video_format.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/features/status_bar/product_page_status_bar.dart';
import 'package:lws_hmi/features/work_mode/domain/work_mode_accent.dart';
import 'package:lws_hmi/features/work_mode/presentation/work_mode_status_bar.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';
import 'package:lws_hmi/ui/hmi/word_boundary_label.dart';

/// lws-ui `AiVisionVideoChooseActivity` — table pick → [ProcessVideoRecord].
///
/// Body matches Monitor → Videos ([DataTable], no cover thumbnails).
class AiVisionVideoChoosePage extends StatefulWidget {
  const AiVisionVideoChoosePage({super.key, this.repository});

  final ProcessVideoRepository? repository;

  static const pageSize = 10;

  @override
  State<AiVisionVideoChoosePage> createState() =>
      _AiVisionVideoChoosePageState();
}

class _AiVisionVideoChoosePageState extends State<AiVisionVideoChoosePage> {
  static const _horizontalInset = 24.0;

  late final ProcessVideoRepository _repo =
      widget.repository ?? SqliteProcessVideoRepository();
  final List<ProcessVideoRecord> _rows = [];
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  @override
  void dispose() {
    if (widget.repository == null) {
      unawaited(_repo.close());
    }
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      await _repo.open();
      final total = await _repo.count();
      final page = await _repo.list(
        limit: AiVisionVideoChoosePage.pageSize,
        offset: 0,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _total = total;
        _rows
          ..clear()
          ..addAll(page);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _total = 0;
        _rows.clear();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _rows.length >= _total) {
      return;
    }
    setState(() => _loadingMore = true);
    try {
      final page = await _repo.list(
        limit: AiVisionVideoChoosePage.pageSize,
        offset: _rows.length,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _rows.addAll(page);
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  void _select(ProcessVideoRecord record) {
    CyberClickSoundRegistry.playClick();
    Navigator.of(context).pop(record);
  }

  TextStyle _headingStyle(BuildContext context) =>
      context.hmiTypography.sectionTitle.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w500,
      );

  TextStyle _cellStyle(BuildContext context) =>
      context.hmiTypography.settingsRowTitle.copyWith(
        color: Colors.white,
        height: 1.15,
      );

  List<DataColumn> _columns(AppLocalizations l10n) => [
        DataColumn(label: Text(l10n.processVideoRecordingTime)),
        DataColumn(label: Text(l10n.processVideoWorkMode)),
        DataColumn(label: Text(l10n.processVideoMaterial)),
        DataColumn(label: Text(l10n.processVideoDuration)),
        DataColumn(label: Text(l10n.processVideoOperations)),
      ];

  DataRow _dataRow(
    BuildContext context,
    ProcessVideoRecord row,
    AppLocalizations l10n,
  ) {
    return DataRow(
      cells: [
        DataCell(
          Center(
            child: Text(
              ProcessVideoFormat.recordingTime(row),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(
          Center(
            child: WordBoundaryLabel(
              text: ProcessVideoFormat.workMode(row.processType, l10n),
              style: _cellStyle(context),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ),
        ),
        DataCell(
          Center(
            child: WordBoundaryLabel(
              text: ProcessVideoFormat.material(row, l10n),
              style: _cellStyle(context),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ),
        ),
        DataCell(
          Center(
            child: Text(
              ProcessVideoFormat.duration(row.durationMs),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        DataCell(
          Center(
            child: HmiButton(
              label: l10n.aiVisionSelectBtn,
              size: HmiButtonSize.medium,
              variant: CyberButtonVariant.primary,
              shape: CyberButtonShape.rounded,
              onPressed: () => _select(row),
            ),
          ),
        ),
      ],
    );
  }

  Widget _themedTable({
    required BuildContext context,
    required ThemeData theme,
    required AppLocalizations l10n,
    required List<DataRow> rows,
  }) {
    return Theme(
      data: theme.copyWith(
        dataTableTheme: DataTableThemeData(
          headingTextStyle: _headingStyle(context),
          dataTextStyle: _cellStyle(context),
          dividerThickness: 1,
          headingRowColor: WidgetStateProperty.all(Colors.transparent),
          dataRowColor: WidgetStateProperty.all(Colors.transparent),
          headingRowHeight: 56,
          dataRowMinHeight: 72,
          dataRowMaxHeight: 96,
          headingRowAlignment: MainAxisAlignment.center,
        ),
        dividerColor: const Color(0x33FFFFFF),
      ),
      child: DataTable(
        showCheckboxColumn: false,
        columnSpacing: 24,
        horizontalMargin: 8,
        columns: _columns(l10n),
        rows: rows,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Shared app-level σ bake; dim specular bands above the plate.
    return SettingsBlurredPageShell(
      blurSigma: SettingsPerspectiveChrome.blurSigma,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x16000000), Color(0x26000000)],
                ),
              ),
              child: SizedBox.expand(),
            ),
          ),
          Scaffold(
        backgroundColor: Colors.transparent,
        appBar: ProductPageStatusBar(
          title: l10n.aiVisionChooseBtn,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          toolbarHeight: WorkModeStatusBarDimens.height,
          backLabel: l10n.equipmentStatusBack,
          backAccent: WorkModeAccent.weld,
          onBack: () => Navigator.of(context).maybePop(),
        ),
        body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _rows.isEmpty
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              _horizontalInset,
                              8,
                              _horizontalInset,
                              0,
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return SizedBox(
                                  width: constraints.maxWidth,
                                  child: _themedTable(
                                    context: context,
                                    theme: theme,
                                    l10n: l10n,
                                    rows: const [],
                                  ),
                                );
                              },
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                l10n.processVideoEmptyTitle,
                                style: context.hmiTypography.body.copyWith(
                                  color: Colors.white54,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          if (n.metrics.pixels >=
                              n.metrics.maxScrollExtent - 80) {
                            unawaited(_loadMore());
                          }
                          return false;
                        },
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final tableWidth =
                                constraints.maxWidth - _horizontalInset * 2;
                            return SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                _horizontalInset,
                                8,
                                _horizontalInset,
                                16,
                              ),
                              child: SizedBox(
                                width: tableWidth,
                                child: _themedTable(
                                  context: context,
                                  theme: theme,
                                  l10n: l10n,
                                  rows: [
                                    for (final row in _rows)
                                      _dataRow(context, row, l10n),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
          if (!_loading && _rows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                l10n.processVideoLoadedCount(_rows.length, _total),
                style: context.hmiTypography.technicalMeta.copyWith(
                  color: Colors.white38,
                ),
              ),
            )
          else
            const SizedBox(height: 24),
        ],
      ),
      ),
        ],
      ),
    );
  }
}
