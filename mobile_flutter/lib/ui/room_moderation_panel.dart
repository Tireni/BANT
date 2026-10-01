import 'package:flutter/material.dart';

import '../ui/bant_theme.dart';

class RoomModerationPanel extends StatelessWidget {
  final bool selectionMode;
  final bool busy;
  final int selectedCount;
  final bool noiseControlEnabled;
  final VoidCallback onToggleSelection;
  final VoidCallback onMuteSelected;
  final VoidCallback onReleaseSelected;
  final VoidCallback onMuteAll;
  final VoidCallback onReleaseAll;
  final VoidCallback onWarnSelected;
  final VoidCallback onWarnAll;

  const RoomModerationPanel({
    super.key,
    required this.selectionMode,
    required this.busy,
    required this.selectedCount,
    required this.noiseControlEnabled,
    required this.onToggleSelection,
    required this.onMuteSelected,
    required this.onReleaseSelected,
    required this.onMuteAll,
    required this.onReleaseAll,
    required this.onWarnSelected,
    required this.onWarnAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BantTheme.surface,
        border: Border.all(color: BantTheme.border),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'OWNER MODERATION',
                  style: TextStyle(
                    color: BantTheme.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: busy ? null : onToggleSelection,
                icon: Icon(
                  selectionMode
                      ? Icons.close_rounded
                      : Icons.checklist_rounded,
                  size: 18,
                ),
                label:
                    Text(selectionMode ? 'Cancel selection' : 'Select people'),
              ),
            ],
          ),
          if (selectionMode) ...[
            const SizedBox(height: 8),
            Text(
              '$selectedCount selected',
              style: const TextStyle(
                color: BantTheme.secondary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed:
                      busy || selectedCount == 0 ? null : onMuteSelected,
                  icon: const Icon(Icons.mic_off_rounded, size: 18),
                  label: const Text('Mute selected'),
                ),
                FilledButton.tonalIcon(
                  onPressed:
                      busy || selectedCount == 0 ? null : onReleaseSelected,
                  icon: const Icon(Icons.mic_rounded, size: 18),
                  label: const Text('Release selected'),
                ),
                if (noiseControlEnabled)
                  FilledButton.tonalIcon(
                    onPressed:
                        busy || selectedCount == 0 ? null : onWarnSelected,
                    icon: const Icon(Icons.volume_down_rounded, size: 18),
                    label: const Text('Warn selected 🤫'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: busy ? null : onMuteAll,
                icon: const Icon(Icons.mic_off_rounded, size: 18),
                label: const Text('Mute all'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : onReleaseAll,
                icon: const Icon(Icons.mic_rounded, size: 18),
                label: const Text('Release all'),
              ),
              if (noiseControlEnabled)
                OutlinedButton.icon(
                  onPressed: busy ? null : onWarnAll,
                  icon: const Icon(Icons.volume_down_rounded, size: 18),
                  label: const Text('Warn everyone 🤫'),
                ),
            ],
          ),
          if (noiseControlEnabled) ...[
            const SizedBox(height: 10),
            const Text(
              'Noise Control sends a warning only. It never mutes anyone.',
              style: TextStyle(
                color: BantTheme.secondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class NoiseWarningToast extends StatelessWidget {
  final String message;

  const NoiseWarningToast({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: BantTheme.surface,
            border: Border.all(color: const Color(0xFFF79009)),
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(
                blurRadius: 14,
                offset: Offset(0, 6),
                color: Color(0x26000000),
              ),
            ],
          ),
          child: Text(
            '🤫 $message',
            style: const TextStyle(
              color: BantTheme.text,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
