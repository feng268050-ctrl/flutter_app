import 'dart:async';

import 'package:flutter/material.dart';
import 'package:os_settings/app/os_settings_app.dart';
import 'package:os_settings/chrome/settings_chrome.dart';
import 'package:os_settings/l10n/app_localizations.dart';
import 'package:os_settings/util/storage_capacity.dart';

/// Storage — capacity bar only (Secrets Seal lives on Operating System → Security).
class StoragePage extends StatefulWidget {
  const StoragePage({super.key});

  @override
  State<StoragePage> createState() => _StoragePageState();
}

class _StoragePageState extends State<StoragePage> {
  StorageCapacitySummary _summary = const StorageCapacitySummary(
    segments: [],
    usedBytes: 0,
    availableBytes: 0,
    totalBytes: 0,
  );
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_load());
    });
  }

  Future<void> _load() async {
    try {
      final services = OsSettingsScope.of(context);
      final snap = await services.sysInfo().snapshot();
      if (!mounted) return;
      setState(() {
        _summary = summarizeStorage(snap.storage);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  String _mountLabel(AppLocalizations l10n, String mp) => switch (mp) {
        '/' => l10n.storageMountSystem,
        '/userdata' => l10n.storageMountUserData,
        _ => mp,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsScaffold(
      title: l10n.storageTitle,
      body: SettingsScrollView(
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            SettingsGroup(
              bottomInset: 0,
              children: [
                Padding(
                  padding: SettingsDimens.rowPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.storageTitle,
                        style: SettingsTextStyles.title,
                      ),
                      const SizedBox(height: 8),
                      if (!_summary.hasData)
                        Text(
                          kUnavailableDash,
                          style: SettingsTextStyles.value,
                        )
                      else ...[
                        Text(
                          l10n.storageUsedOfTotal(
                            formatStorageBytes(_summary.usedBytes),
                            formatStorageBytes(_summary.totalBytes),
                          ),
                          style: SettingsTextStyles.value,
                        ),
                        const SizedBox(height: 12),
                        _StorageBar(summary: _summary),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: [
                            for (final seg in _summary.segments)
                              _Legend(
                                color: seg.color,
                                label:
                                    '${_mountLabel(l10n, seg.mountPoint)}  ${formatStorageBytes(seg.usedBytes)}',
                              ),
                            _Legend(
                              color: StorageBarColors.available,
                              label:
                                  '${l10n.storageAvailableLegend}  ${formatStorageBytes(_summary.availableBytes)}',
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StorageBar extends StatelessWidget {
  const _StorageBar({required this.summary});

  final StorageCapacitySummary summary;

  static const _height = 22.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final total = summary.totalBytes.toDouble();
        if (width <= 0 || total <= 0) {
          return const SizedBox(height: _height);
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: _height,
            width: width,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final seg in summary.segments)
                  if (seg.usedBytes > 0)
                    SizedBox(
                      width: (seg.usedBytes / total * width).clamp(0.0, width),
                      child: ColoredBox(color: seg.color),
                    ),
                const Expanded(
                  child: ColoredBox(color: StorageBarColors.available),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: SettingsTextStyles.supporting),
      ],
    );
  }
}
