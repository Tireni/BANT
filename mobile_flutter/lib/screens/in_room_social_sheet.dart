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
    final colors = BantTheme.of(context);
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
              backgroundColor: colors.soft,
              backgroundImage:
                  person.avatarUrl == null ? null : NetworkImage(person.avatarUrl!),
              child: person.avatarUrl == null
                  ? Text(
                      person.displayName.isEmpty
                          ? 'B'
                          : person.displayName.characters.first.toUpperCase(),
                      style: TextStyle(
                        color: colors.blue,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              person.displayName,
              style: TextStyle(
                color: colors.text,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (person.username.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '@${person.username}',
                style: TextStyle(
                  color: colors.secondary,
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
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final details = TextEditingController();
                String reason = 'unsafe';
                await showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (sheetContext) => StatefulBuilder(
                    builder: (context, setSheetState) => SafeArea(
                      top: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          20,
                          20,
                          20 + MediaQuery.viewInsetsOf(context).bottom,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Report participant',
                              style: TextStyle(
                                color: colors.text,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final item in const [
                                  'spam',
                                  'harassment',
                                  'unsafe',
                                  'impersonation',
                                  'other',
                                ])
                                  ChoiceChip(
                                    label: Text(item),
                                    selected: reason == item,
                                    onSelected: (_) =>
                                        setSheetState(() => reason = item),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: details,
                              minLines: 3,
                              maxLines: 5,
                              maxLength: 1200,
                              decoration: const InputDecoration(
                                hintText: 'Optional report details',
                              ),
                            ),
                            BantButton(
                              label: 'Submit report',
                              onPressed: () async {
                                await widget.api.reportUser(
                                  userId: person.id,
                                  reason: reason,
                                  description: details.text,
                                );
                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
                details.dispose();
              },
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Report'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final ok = await state.blockUser(person.id);
                if (!context.mounted || !ok) return;
                Navigator.of(context).pop();
              },
              icon: Icon(Icons.block_rounded, color: colors.danger),
              label: const Text('Block user'),
            ),
            if (state.error != null) ...[
              const SizedBox(height: 12),
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.danger,
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
