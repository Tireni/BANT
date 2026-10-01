import 'package:flutter/material.dart';

import '../models/room_detail.dart';
import 'bant_theme.dart';

class BantParticipantGrid extends StatelessWidget {
  final List<BantParticipant> participants;
  final String ownerId;
  final String currentUserId;
  final Set<String> connectedVoiceUserIds;
  final Set<String> activeSpeakerIds;
  final Set<String> mutedVoiceUserIds;
  final bool moderationMode;
  final Set<String> selectedUserIds;
  final ValueChanged<String>? onToggleUser;
  final ValueChanged<BantParticipant>? onUserPressed;

  const BantParticipantGrid({
    super.key,
    required this.participants,
    required this.ownerId,
    required this.currentUserId,
    this.connectedVoiceUserIds = const <String>{},
    this.activeSpeakerIds = const <String>{},
    this.mutedVoiceUserIds = const <String>{},
    this.moderationMode = false,
    this.selectedUserIds = const <String>{},
    this.onToggleUser,
    this.onUserPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = BantTheme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 520 ? 4 : 3;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: participants.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            mainAxisExtent: moderationMode ? 188 : 164,
          ),
          itemBuilder: (context, index) {
            final person = participants[index];
            final isOwner = person.id == ownerId ||
                person.role == 'owner' ||
                person.role == 'host';
            final isCurrentUser = person.id == currentUserId;
            final voiceConnected = connectedVoiceUserIds.contains(person.id);
            final activelySpeaking = activeSpeakerIds.contains(person.id);
            final voiceMuted =
                person.muted || mutedVoiceUserIds.contains(person.id);
            final selectable = moderationMode && !isOwner;
            final selected = selectedUserIds.contains(person.id);

            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: selectable
                  ? () => onToggleUser?.call(person.id)
                  : isCurrentUser
                      ? null
                      : () => onUserPressed?.call(person),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border.all(
                    color: selected
                        ? colors.warning
                        : activelySpeaking
                            ? colors.mint
                            : isCurrentUser
                                ? colors.blue
                                : colors.border,
                    width:
                        selected || activelySpeaking || isCurrentUser ? 1.8 : 1,
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
                          backgroundColor: colors.blue,
                          backgroundImage: person.avatarUrl != null
                              ? NetworkImage(person.avatarUrl!)
                              : null,
                          child: person.avatarUrl == null
                              ? Text(
                                  _initials(person.displayName),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
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
                              color: voiceMuted
                                  ? colors.danger
                                  : voiceConnected
                                      ? colors.mint
                                      : colors.border,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colors.surface,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              voiceMuted
                                  ? Icons.mic_off_rounded
                                  : voiceConnected
                                      ? Icons.graphic_eq_rounded
                                      : Icons.mic_none_rounded,
                              size: 12,
                              color: voiceMuted || voiceConnected
                                  ? Colors.white
                                  : colors.secondary,
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
                      style: TextStyle(
                        color: colors.text,
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
                        if (isCurrentUser) const _RoleBadge(label: 'YOU'),
                        _RoleBadge(
                          label: voiceMuted
                              ? 'MUTED'
                              : activelySpeaking
                                  ? 'TALKING'
                                  : voiceConnected
                                      ? 'VOICE'
                                      : 'OFFLINE',
                          color: voiceMuted
                              ? colors.danger
                              : activelySpeaking || voiceConnected
                                  ? colors.mint
                                  : colors.secondary,
                        ),
                      ],
                    ),
                    if (selectable) ...[
                      const SizedBox(height: 6),
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 18,
                        color: selected ? colors.warning : colors.secondary,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'B';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  final bool owner;
  final Color? color;

  const _RoleBadge({
    required this.label,
    this.owner = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = BantTheme.of(context);
    final badgeColor = color ?? colors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: owner
            ? colors.warning.withValues(alpha: 0.10)
            : badgeColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: owner ? colors.warning : badgeColor,
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
