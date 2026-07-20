import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Shared Material stand-ins for lws-ui InsetList / FrostCard settings chrome.
///
/// Interactive rows call [CyberClickSoundRegistry.playClick] (lws-ui pattern:
/// product chrome / listeners invoke the same backend as Frost controls).
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white70,
              letterSpacing: 0.6,
            ),
      ),
    );
  }
}

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i < children.length - 1) {
        items.add(const Divider(height: 1, indent: 20, endIndent: 20));
      }
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(children: items),
    );
  }
}

class SettingsNavRow extends StatelessWidget {
  const SettingsNavRow({
    super.key,
    required this.title,
    this.value,
    this.leading,
    this.onTap,
  });

  final String title;
  final String? value;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      minVerticalPadding: 16,
      leading: leading,
      title: Text(title, style: const TextStyle(fontSize: 18)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null && value!.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                value!,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 16,
                ),
              ),
            ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.45)),
        ],
      ),
      onTap: onTap == null
          ? null
          : () {
              CyberClickSoundRegistry.playClick();
              onTap!();
            },
    );
  }
}

class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      title: Text(title, style: const TextStyle(fontSize: 18)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: CyberSwitch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

/// Radio / check-style option row (language, unit, screen-off, …).
class SettingsOptionTile extends StatelessWidget {
  const SettingsOptionTile({
    super.key,
    required this.title,
    this.selected = false,
    this.onTap,
    this.clickSoundEnabled = true,
  });

  final String title;
  final bool selected;
  final VoidCallback? onTap;
  final bool clickSoundEnabled;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      title: Text(title),
      trailing: selected
          ? const Icon(Icons.check, color: Colors.lightBlueAccent)
          : null,
      onTap: onTap == null
          ? null
          : () {
              if (clickSoundEnabled) {
                CyberClickSoundRegistry.playClick();
              }
              onTap!();
            },
    );
  }
}

/// Phone-style vertical list with bounce overscroll.
class SettingsScrollView extends StatelessWidget {
  const SettingsScrollView({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: padding ?? const EdgeInsets.only(bottom: 32),
      children: children,
    );
  }
}

/// Push a settings sub-page with a platform-like slide transition.
Future<T?> pushSettingsPage<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(
    CupertinoPageRoute<T>(builder: (_) => page),
  );
}

class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
        automaticallyImplyLeading: false,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
                onPressed: () {
                  CyberClickSoundRegistry.playClick();
                  Navigator.of(context).maybePop();
                },
              )
            : null,
      ),
      body: body,
    );
  }
}
