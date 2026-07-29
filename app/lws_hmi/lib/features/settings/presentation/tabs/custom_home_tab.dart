import 'package:flutter/material.dart';

/// Custom Home tab placeholder — content deferred to a later plan.
///
/// Keeps the Settings top-tab entry (lws-ui `placeholder` icon) while the
/// body stays blank until Home metric layout lands.
class CustomHomeTab extends StatelessWidget {
  const CustomHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand();
  }
}
