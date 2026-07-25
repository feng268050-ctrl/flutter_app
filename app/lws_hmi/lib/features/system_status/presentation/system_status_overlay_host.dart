import 'package:flutter/material.dart';
import 'package:lws_hmi/features/settings/application/misc_settings_store.dart';
import 'package:lws_hmi/features/system_status/presentation/system_status_card.dart';

/// Left-centered [SystemStatusCard] when [store.showSystemStatusOverlay] is on.
class SystemStatusOverlayHost extends StatelessWidget {
  const SystemStatusOverlayHost({
    super.key,
    required this.store,
    required this.child,
  });

  final MiscSettingsStore store;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (!store.showSystemStatusOverlay) {
          return child;
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 10),
                child: SystemStatusCard(),
              ),
            ),
          ],
        );
      },
    );
  }
}
