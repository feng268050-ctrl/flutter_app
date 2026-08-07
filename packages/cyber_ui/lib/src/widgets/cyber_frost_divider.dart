import 'package:flutter/material.dart';

/// lws-ui `frost_divider` — center hairline fading to transparent edges.
///
/// Uses frost gray center (`#9968686C`), not [CyberColors.dividerCenter]
/// (that token is a bright glass rim for dark Monitor/Settings panels).
///
/// Shared by warn dialogs, tip prompts, and Safety Tips.
class CyberFrostDivider extends StatelessWidget {
  const CyberFrostDivider({super.key});

  static const _center = Color(0x9968686C);
  static const _edge = Color(0x0068686C);

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 1,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              _edge,
              _center,
              _edge,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }
}
