import 'package:flutter/material.dart';

import '../models/room_detail.dart';
import 'bant_theme.dart';

class BantParticipantGrid extends StatelessWidget {
  final List<BantParticipant> participants;
  final String ownerId;
  final String currentUserId;

  const BantParticipantGrid({
    super.key,
    required this.participants,
    required this.ownerId,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700
            ? 4
            : constraints.maxWidth >= 520
                ? 4
                : 3;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: participants.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.84,
          ),
          itemBuilder: (context, index) {
            final person = participants[index];
            final isOwner = person.id == ownerId ||
                person.role == 'owner' ||
                person.role == 'host';
            final isCurrentUser = person.id == currentUserId;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border.all(
                  color: isCurrentUser
                      ? BantTheme.blue
                      : BantTheme.border,
                  width: isCurrentUser ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 31,
                        backgroundColor: const Color(0xFFE8F4FF),
                        backgroundImage: person.avatarUrl != null
                            ? NetworkImage(person.avatarUrl!)
                            : null,
                        child: person.avatarUrl == null
                            ? Text(
                                person.displayName.isEmpty
                                    ? 'B'
                                    : person.displayName.characters.first
                                        .toUpperCase(),
                                style: const TextStyle(
                                  color: BantTheme.blue,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: person.muted
                                ? BantTheme.danger
                                : const Color(0xFFE4E7EC),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            person.muted
                                ? Icons.mic_off_rounded
                                : Icons.mic_none_rounded,
                            size: 12,
                            color: person.muted
                                ? Colors.white
                                : BantTheme.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    person.displayName.split(' ').first,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BantTheme.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: [
                      _RoleBadge(
                        label: isOwner
                            ? 'OWNER'
                            : person.role == 'speaker'
                                ? 'SPEAKER'
                                : 'LISTENER',
                        owner: isOwner,
                      ),
                      if (isCurrentUser)
                        const _RoleBadge(label: 'YOU'),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  final bool owner;

  const _RoleBadge({
    required this.label,
    this.owner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: owner
            ? const Color(0xFFFFF4E5)
            : const Color(0xFFE8F4FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: owner ? const Color(0xFFB54708) : BantTheme.blue,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
