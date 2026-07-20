import 'package:flutter/material.dart';

/// lws-ui `fragment_process_video` — table header + empty list stand-in.
class VideosTab extends StatelessWidget {
  const VideosTab({super.key});

  static const _headers = <(String, double)>[
    ('Recording Time', 232),
    ('Work Mode', 196),
    ('Material', 229),
    ('Duration', 157),
    ('Operations', 0),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(24, 16, 48, 0),
          padding: const EdgeInsets.fromLTRB(12, 28, 12, 24),
          decoration: BoxDecoration(
            color: const Color(0x332E3653),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              for (final (label, width) in _headers)
                if (width > 0)
                  SizedBox(
                    width: width * (MediaQuery.sizeOf(context).width / 1280)
                        .clamp(0.55, 1.0),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam_outlined, size: 64, color: Colors.white24),
                const SizedBox(height: 16),
                const Text(
                  'No recordings',
                  style: TextStyle(color: Colors.white54, fontSize: 18),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Process video list will appear here (P4.1 MediaMTX).',
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 72),
      ],
    );
  }
}
