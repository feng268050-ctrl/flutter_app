import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_assets.dart';

/// Full-screen CNC running shell (lws-ui `CNCRunning`).
final class CncRunningOverlay extends StatelessWidget {
  const CncRunningOverlay({
    super.key,
    required this.onExitPressed,
  });

  final VoidCallback onExitPressed;

  static const _borderBlue = Color(0xFF0741BA);

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Material(
        key: const ValueKey('quick-mode-cnc-running'),
        color: Colors.black,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _borderBlue, width: 8),
            ),
            child: Column(
              children: [
                const SizedBox(height: 104),
                Image.asset(
                  ProcessModeAssets.cncBlueLink,
                  width: 120,
                  height: 120,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 44),
                const Text(
                  'CNC Mode Active\nOperate on the CNC equipment',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 130),
                GestureDetector(
                  onTap: onExitPressed,
                  child: SizedBox(
                    width: 564,
                    height: 80,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage(ProcessModeAssets.cncExitBtn),
                          fit: BoxFit.fill,
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'Exit CNC Mode',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
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
