import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/mobile_api.dart';
import '../models/room_detail.dart';
import '../state/bant_social_state.dart';
import '../ui/bant_button.dart';
import '../ui/bant_theme.dart';

class InRoomSocialSheet extends StatefulWidget {
  final MobileApi api;
  final BantParticipant participant;

  const InRoomSocialSheet({
    super.key,
    required this.api,
    required this.participant,
  });

  @override
  State<InRoomSocialSheet> createState() => _InRoomSocialSheetState();
}

class _InRoomSocialSheetState extends State<InRoomSocialSheet> {
  late final BantSocialState state;

  @override
  void initState() {
    super.initState();
    state = BantSocialState(
      api: widget.api,
      supabase: Supabase.instance.client,
      currentUserId: Supabase.instance.client.auth.currentUser?.id ?? '',
    );
    state.addListener(_onChanged);
    state.start();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    state.removeListener(_onChanged);
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final person = widget.participant;
    final friendship = state.stateFor(person.id);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: const Color(0xFFE8F4FF),
              backgroundImage:
                  person.avatarUrl == null ? null : NetworkImage(person.avatarUrl!),
              child: person.avatarUrl == null
                  ? Text(
                      person.displayName.isEmpty
                          ? 'B'
                          : person.displayName.characters.first.toUpperCase(),
                      style: const TextStyle(
                        color: BantTheme.blue,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              person.displayName,
              style: const TextStyle(
                color: BantTheme.text,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (person.username.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '@${person.username}',
                style: const TextStyle(
                  color: BantTheme.secondary,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (state.loading)
              const CircularProgressIndicator()
            else ...[
              BantButton(
                label: state.actionLabel(person.id),
                secondary: friendship == BantFriendshipState.friends,
                onPressed: friendship == BantFriendshipState.friends
                    ? null
                    : () => state.primaryAction(person.id),
              ),
              if (friendship == BantFriendshipState.pendingReceived) ...[
                const SizedBox(height: 10),
                BantButton(
                  label: 'Decline request',
                  secondary: true,
                  onPressed: () => state.declineIncoming(person.id),
                ),
              ],
            ],
            if (state.error != null) ...[
              const SizedBox(height: 12),
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: BantTheme.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
