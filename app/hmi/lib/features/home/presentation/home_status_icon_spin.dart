import 'package:flutter/material.dart';

/// Corner connecting spinner for Home status-bar glyphs (does not own layout size).
class HomeStatusIconSpin extends StatefulWidget {
  const HomeStatusIconSpin({super.key, required this.size});

  final double size;

  @override
  State<HomeStatusIconSpin> createState() => _HomeStatusIconSpinState();
}

class _HomeStatusIconSpinState extends State<HomeStatusIconSpin>
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
