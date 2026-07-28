import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';

/// Engineer Mode process-type tab bar (lws-ui `EngineerTab`, five tabs).
///
/// U2 skeleton: tab chrome + selection only; content panels are placeholders.
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
    final activeColor = ProcessModeTokens.tabActiveColor(type);
    final labelColor =
        selected ? activeColor : ProcessModeTokens.tabInactiveText;

    return InkWell(
      key: ValueKey('engineer-tab-${type.name}'),
      onTap: () {
        CyberClickSoundRegistry.playClick();
        onTap();
      },
      child: Column(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  selected
                      ? EngineerProcessTabs.iconOn(type)
                      : EngineerProcessTabs.iconOff(type),
                  width: ProcessModeDimens.engineerTabIconSize,
                  height: ProcessModeDimens.engineerTabIconSize,
                  filterQuality: FilterQuality.medium,
                ),
                const SizedBox(width: ProcessModeDimens.engineerTabIconGap),
                Flexible(
                  child: Text(
                    ProcessModeLabels.engineerTabLabel(type),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: labelColor,
                      fontSize: ProcessModeDimens.engineerTabLabelSize,
                      height: 1.0,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ProcessModeDimens.engineerTabUnderlineInset,
            ),
            child: SizedBox(
              height: ProcessModeDimens.engineerTabUnderlineHeight,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selected ? activeColor : Colors.transparent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
