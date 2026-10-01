import 'package:flutter/material.dart';

import '../models/room.dart';
import 'bant_theme.dart';

class BantRoomCard extends StatelessWidget {
  final BantRoom room;
  final VoidCallback onTap;
  final bool compact;

  const BantRoomCard({
    super.key,
    required this.room,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = BantTheme.of(context);

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: compact ? 274 : double.infinity,
          constraints: const BoxConstraints(minWidth: 250),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: colors.soft,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      room.category,
                      style: TextStyle(
                        color: colors.blue,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (room.privacy == 'private')
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 16,
                      color: colors.secondary,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                room.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                room.description.isEmpty
                    ? 'A fresh BANT room.'
                    : room.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.secondary,
                  fontSize: 13,
                  height: 18 / 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Meta(
                    icon: Icons.mic_none_rounded,
                    label: '${room.speakerCount} talking',
                    color: colors.mint,
                    textColor: colors.secondary,
                  ),
                  _Meta(
                    icon: Icons.people_outline_rounded,
                    label: '${room.participantCount} here',
                    color: colors.blue,
                    textColor: colors.secondary,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Waveform(color: colors.mint),
                      const SizedBox(width: 8),
                      Text(
                        'Open',
                        style: TextStyle(
                          color: colors.blue,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;

  const _Meta({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Waveform extends StatelessWidget {
  final Color color;
  const _Waveform({required this.color});

  @override
  Widget build(BuildContext context) {
    const heights = <double>[6, 12, 18, 10, 15, 7];
    return SizedBox(
      width: 26,
      height: 20,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final height in heights)
            Container(
              width: 2,
              height: height,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}
