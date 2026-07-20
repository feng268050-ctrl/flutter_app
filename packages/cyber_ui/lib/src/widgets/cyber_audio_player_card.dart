import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';

String cyberFormatAudioTime(Duration d) {
  final total = d.inSeconds.clamp(0, 99 * 3600);
  final m = (total ~/ 60).toString().padLeft(2, '0');
  final s = (total % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Transport + seek + time labels (lws-ui `FrostAudioPlayerCard` stand-in).
///
/// Presentation only — App owns [MediaAudioController] / seek capability.
class CyberAudioPlayerCard extends StatelessWidget {
  const CyberAudioPlayerCard({
    super.key,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.onPlayPause,
    this.onRewind,
    this.onFastForward,
    this.onSeek,
    this.seekEnabled = false,
    this.enabled = true,
  });

  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final VoidCallback onPlayPause;
  final VoidCallback? onRewind;
  final VoidCallback? onFastForward;
  final ValueChanged<Duration>? onSeek;
  final bool seekEnabled;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final safeDurationMs = duration.inMilliseconds.clamp(1, 1 << 30);
    final progress = ((position.inMilliseconds * 1000) / safeDurationMs)
        .round()
        .clamp(0, 1000);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: enabled ? onRewind : null,
                icon: const Icon(Icons.replay_10),
                iconSize: 32,
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: enabled
                    ? () {
                        CyberClickSoundRegistry.playClick();
                        onPlayPause();
                      }
                    : null,
                icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle),
                iconSize: 56,
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: enabled ? onFastForward : null,
                icon: const Icon(Icons.forward_10),
                iconSize: 32,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: progress.toDouble(),
            min: 0,
            max: 1000,
            onChanged: seekEnabled && enabled && onSeek != null
                ? (v) {
                    final ms = ((v / 1000) * safeDurationMs).round();
                    onSeek!(Duration(milliseconds: ms));
                  }
                : null,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                cyberFormatAudioTime(position),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                cyberFormatAudioTime(duration),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
