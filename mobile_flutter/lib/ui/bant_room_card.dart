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
    return Material(
      color: BantTheme.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          width: compact ? 274 : double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: BantTheme.border),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _CategoryBadge(label: room.category),
                  const Spacer(),
                  if (room.privacy == 'private')
                    const Icon(
                      Icons.lock_outline,
                      size: 17,
                      color: BantTheme.secondary,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                room.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: BantTheme.text,
                  fontSize: 18,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                room.description.isEmpty
                    ? 'Live room discussion.'
                    : room.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: BantTheme.secondary,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Meta(
                    icon: Icons.mic_none_rounded,
                    label: '${room.speakerCount} talking',
                    color: BantTheme.mint,
                  ),
                  _Meta(
                    icon: Icons.people_outline_rounded,
                    label: '${room.participantCount} here',
                    color: BantTheme.blue,
                  ),
                  const _Meta(
                    icon: Icons.graphic_eq_rounded,
                    label: 'Open',
                    color: BantTheme.blue,
                    strong: true,
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

class _CategoryBadge extends StatelessWidget {
  final String label;
  const _CategoryBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F4FF),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: BantTheme.blue,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool strong;

  const _Meta({
    required this.icon,
    required this.label,
    required this.color,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: strong ? BantTheme.blue : BantTheme.secondary,
            fontSize: 12,
            fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
