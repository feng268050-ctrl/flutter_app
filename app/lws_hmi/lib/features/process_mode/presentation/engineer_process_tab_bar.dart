import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/hmi_tab_metrics.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/hmi/hmi_primary_tab_content.dart';

/// Engineer Mode process-type tab bar (lws-ui `EngineerTab`, five tabs).
///
/// Icon + label form one compact group centered in each flex cell; selection
/// only changes color/weight and the cell underline.
final class EngineerProcessTabBar extends StatelessWidget {
  const EngineerProcessTabBar({
    super.key,
    required this.processType,
    required this.onChanged,
    this.enabled = true,
  });

  final ProcessType processType;
  final ValueChanged<ProcessType> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = EngineerProcessTabs.types.contains(processType)
        ? processType
        : EngineerProcessTabs.types.first;

    return SizedBox(
      key: const ValueKey('engineer-process-tab-bar'),
      height: ProcessModeDimens.engineerTabBarHeight,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(EngineerProcessTabs.tabBackground(active)),
            fit: BoxFit.fill,
          ),
        ),
        child: IgnorePointer(
          ignoring: !enabled,
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: Row(
              children: [
                for (var i = 0; i < EngineerProcessTabs.types.length; i++)
                  Expanded(
                    flex: ProcessModeDimens.engineerTabWeights[i],
                    child: _EngineerTabItem(
                      type: EngineerProcessTabs.types[i],
                      selected: EngineerProcessTabs.types[i] == active,
                      onTap: () => onChanged(EngineerProcessTabs.types[i]),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _EngineerTabItem extends StatelessWidget {
  const _EngineerTabItem({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final ProcessType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final activeColor = ProcessModeTokens.tabActiveColor(type);
    final labelColor =
        selected ? activeColor : ProcessModeTokens.tabInactiveText;

    return InkWell(
      key: ValueKey('engineer-tab-${type.name}'),
      onTap: () {
        CyberClickSoundRegistry.playClick();
        onTap();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: HmiPrimaryTabContent(
              icon: Image.asset(
                selected
                    ? EngineerProcessTabs.iconOn(type)
                    : EngineerProcessTabs.iconOff(type),
                width: HmiTabMetrics.iconSize,
                height: HmiTabMetrics.iconSize,
                filterQuality: FilterQuality.medium,
              ),
              label: ProcessModeLabels.engineerTabLabel(type, l10n),
              color: labelColor,
              selected: selected,
            ),
          ),
          Positioned(
            left: ProcessModeDimens.engineerTabUnderlineInset,
            right: ProcessModeDimens.engineerTabUnderlineInset,
            bottom: 0,
            height: ProcessModeDimens.engineerTabUnderlineHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selected ? activeColor : Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
