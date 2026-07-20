import 'package:flutter/material.dart';

/// Deferred Advanced Settings (Modbus / Room product params).
class AdvancedSettingsTab extends StatelessWidget {
  const AdvancedSettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderPane(
      title: 'Advanced Settings',
      body:
          'Offset, power/temperature thresholds, AI assistance, and dangerous '
          'operation overrides will land with the product domain migration. '
          'This tab is reserved to match lws-ui Settings structure.',
    );
  }
}

class _PlaceholderPane extends StatelessWidget {
  const _PlaceholderPane({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(body, style: theme.textTheme.bodyLarge),
      ],
    );
  }
}
