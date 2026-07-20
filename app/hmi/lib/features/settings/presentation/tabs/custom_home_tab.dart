import 'package:flutter/material.dart';

/// Deferred Custom Home layout editor (stat card order).
class CustomHomeTab extends StatelessWidget {
  const CustomHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Custom Home Page', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(
          'Home metric card layout customization is deferred until product '
          'Home stat cards are implemented. This tab keeps the lws-ui '
          'Settings shell intact.',
          style: theme.textTheme.bodyLarge,
        ),
      ],
    );
  }
}
