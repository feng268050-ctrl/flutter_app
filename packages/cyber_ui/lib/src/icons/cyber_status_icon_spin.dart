import 'package:flutter/material.dart';

/// Corner connecting spinner for status-bar glyphs (does not own layout size).
class CyberStatusIconSpin extends StatefulWidget {
  const CyberStatusIconSpin({super.key, required this.size});

  final double size;

  @override
  State<CyberStatusIconSpin> createState() => _CyberStatusIconSpinState();
}

class _CyberStatusIconSpinState extends State<CyberStatusIconSpin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _ctrl,
      child: Icon(
        Icons.sync,
        size: widget.size,
        color: Colors.lightBlueAccent,
      ),
    );
  }
}
