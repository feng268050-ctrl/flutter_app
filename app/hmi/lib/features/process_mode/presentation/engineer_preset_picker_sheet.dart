import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';

/// Flutter [showModalBottomSheet] preset picker (built-in + user).
Future<ProcessPreset?> showEngineerPresetPickerSheet({
  required BuildContext context,
  required List<ProcessPreset> presets,
  required String? selectedUuid,
}) {
  return showModalBottomSheet<ProcessPreset>(
    context: context,
    backgroundColor: const Color(0xFF12142A),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.55,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'Favorites',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: presets.isEmpty
                    ? const Center(
                        child: Text(
                          'No processes for this type',
                          style: TextStyle(color: Color(0x99FFFFFF)),
                        ),
                      )
                    : ListView.separated(
                        itemCount: presets.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          color: Color(0x22FFFFFF),
                        ),
                        itemBuilder: (context, index) {
                          final preset = presets[index];
                          final selected = preset.uuid == selectedUuid;
                          return ListTile(
                            key: ValueKey('engineer-preset-${preset.uuid}'),
                            selected: selected,
                            selectedTileColor: ProcessModeTokens.tabActiveColor(
                              preset.processType,
                            ).withOpacity(0.18),
                            leading: Icon(
                              preset.isBuiltin
                                  ? Icons.lock_outline
                                  : Icons.bookmark_outline,
                              color: Colors.white70,
                            ),
                            title: Text(
                              preset.name,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              preset.isBuiltin ? 'Built-in' : 'User',
                              style: const TextStyle(color: Color(0x99FFFFFF)),
                            ),
                            trailing: selected
                                ? const Icon(Icons.check, color: Colors.white)
                                : null,
                            onTap: () {
                              CyberClickSoundRegistry.playClick();
                              Navigator.pop(context, preset);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
