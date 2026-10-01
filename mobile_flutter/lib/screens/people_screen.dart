import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/mobile_api.dart';
import '../state/bant_social_state.dart';
import '../ui/bant_button.dart';
import '../ui/bant_theme.dart';

class BantPeopleScreen extends StatefulWidget {
  final MobileApi api;

  const BantPeopleScreen({
    super.key,
    required this.api,
  });

  @override
  State<BantPeopleScreen> createState() => _BantPeopleScreenState();
}

class _BantPeopleScreenState extends State<BantPeopleScreen> {
  late final BantSocialState state;
  final search = TextEditingController();
  String tab = 'Discover';
  List<Map<String, dynamic>> notifications = const [];
  bool notificationsLoading = false;

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
    _loadNotifications();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadNotifications() async {
    if (mounted) setState(() => notificationsLoading = true);
    try {
      final items = await widget.api.notifications();
      if (!mounted) return;
      setState(() {
        notifications = items;
        notificationsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => notificationsLoading = false);
    }
  }

  Future<void> _markRead() async {
    await widget.api.markNotificationsRead();
    await _loadNotifications();
  }

  @override
  void dispose() {
    search.dispose();
    state.removeListener(_onChanged);
    state.dispose();
    super.dispose();
  }

  List<BantSocialPerson> get visiblePeople {
    final query = search.text.trim().toLowerCase();

    Iterable<BantSocialPerson> source = state.people;
    if (tab == 'Friends') {
      source = source.where((person) => state.friendIds.contains(person.id));
    } else if (tab == 'Blocked') {
      source = state.blockedPeople;
    }

    if (query.isNotEmpty) {
      source = source.where((person) {
        return '${person.displayName} ${person.username}'
            .toLowerCase()
            .contains(query);
      });
    }

    return source.toList();
  }

  Future<void> _openSafety(BantSocialPerson person) async {
    final description = TextEditingController();
    String reason = 'unsafe';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final colors = BantTheme.of(context);
          return SafeArea(
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
                    'Safety options',
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Block this user or send a report to BANT.',
                    style: TextStyle(
                      color: colors.secondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),
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
                          selectedColor: colors.blue,
                          backgroundColor: colors.soft,
                          side: BorderSide(
                            color:
                                reason == item ? colors.blue : colors.border,
                          ),
                          labelStyle: TextStyle(
                            color: reason == item
                                ? Colors.white
                                : colors.secondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                          onSelected: (_) =>
                              setSheetState(() => reason = item),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: description,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 1200,
                    style: TextStyle(color: colors.text),
                    decoration: const InputDecoration(
                      hintText: 'Optional report details',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      await widget.api.reportUser(
                        userId: person.id,
                        reason: reason,
                        description: description.text,
                      );
                      if (!sheetContext.mounted || !mounted) return;
                      Navigator.of(sheetContext).pop();
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(content: Text('Report submitted')),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.danger,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Report user',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () async {
                      final ok = await state.blockUser(person.id);
                      if (!sheetContext.mounted || !mounted || !ok) return;
                      Navigator.of(sheetContext).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      foregroundColor: colors.blue,
                      side: BorderSide(color: colors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Block user',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    description.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = BantTheme.of(context);
    final people = visiblePeople;

    return RefreshIndicator(
      color: colors.blue,
      onRefresh: () async {
        await state.load();
        await _loadNotifications();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
        children: [
          Text(
            'People',
            style: TextStyle(
              color: colors.text,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (tab != 'Notifications') ...[
            const SizedBox(height: 12),
            TextField(
              controller: search,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: colors.text),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search people',
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colors.soft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                for (final item in const [
                  'Discover',
                  'Friends',
                  'Blocked',
                  'Notifications',
                ])
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        setState(() => tab = item);
                        if (item == 'Notifications') {
                          await _markRead();
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        constraints: const BoxConstraints(minHeight: 42),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: tab == item ? colors.blue : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            item,
                            style: TextStyle(
                              color: tab == item
                                  ? Colors.white
                                  : colors.secondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (tab == 'Notifications')
            _NotificationsList(
              api: widget.api,
              loading: notificationsLoading,
              items: notifications,
              colors: colors,
              onChanged: () async {
                await state.load();
                await _loadNotifications();
              },
            )
          else if (state.loading && state.people.isEmpty && tab != 'Blocked')
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 50),
              child: Center(
                child: CircularProgressIndicator(color: colors.blue),
              ),
            )
          else if (people.isEmpty)
            _StateMessage(
              colors: colors,
              icon: tab == 'Blocked'
                  ? Icons.block_rounded
                  : Icons.people_outline_rounded,
              title: tab == 'Friends'
                  ? 'No friends yet.'
                  : tab == 'Blocked'
                      ? 'No blocked users.'
                      : 'Find people you vibe with.',
              body: tab == 'Friends'
                  ? 'Add people from Discover and they will appear here after they accept.'
                  : tab == 'Blocked'
                      ? 'People you block will appear here so you can unblock them later.'
                      : 'Add friends and jump into rooms together.',
            )
          else
            for (final person in people)
              _PersonRow(
                colors: colors,
                person: person,
                state: state,
                blocked: tab == 'Blocked',
                onPrimary: tab == 'Blocked'
                    ? () => state.unblockUser(person.id)
                    : () => state.primaryAction(person.id),
                onSafety:
                    tab == 'Blocked' ? null : () => _openSafety(person),
                onDecline: tab != 'Blocked' &&
                        state.stateFor(person.id) ==
                            BantFriendshipState.pendingReceived
                    ? () => state.declineIncoming(person.id)
                    : null,
              ),
          if (state.error != null) ...[
            const SizedBox(height: 12),
            Text(
              state.error!,
              style: TextStyle(
                color: colors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationsList extends StatelessWidget {
  final MobileApi api;
  final bool loading;
  final List<Map<String, dynamic>> items;
  final BantPalette colors;
  final Future<void> Function() onChanged;

  const _NotificationsList({
    required this.api,
    required this.loading,
    required this.items,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 50),
        child: Center(
          child: CircularProgressIndicator(color: colors.blue),
        ),
      );
    }
    if (items.isEmpty) {
      return _StateMessage(
        colors: colors,
        icon: Icons.notifications_none_rounded,
        title: "You're all caught up.",
        body: 'Friend requests and room activity will show here.',
      );
    }

    return Column(
      children: [
        for (final item in items)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['body']?.toString() ?? 'BANT notification',
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 20 / 14,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item['created_at']?.toString() ?? '',
                  style: TextStyle(
                    color: colors.secondary,
                    fontSize: 12,
                  ),
                ),
                if (item['type']?.toString() == 'friend_request' &&
                    item['target_id'] != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: () async {
                          await api.acceptFriendRequest(
                            item['target_id'].toString(),
                          );
                          await onChanged();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.blue,
                        ),
                        child: const Text('Accept'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () async {
                          await api.declineFriendRequest(
                            item['target_id'].toString(),
                          );
                          await onChanged();
                        },
                        child: const Text('Decline'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _PersonRow extends StatelessWidget {
  final BantPalette colors;
  final BantSocialPerson person;
  final BantSocialState state;
  final bool blocked;
  final VoidCallback onPrimary;
  final VoidCallback? onDecline;
  final VoidCallback? onSafety;

  const _PersonRow({
    required this.colors,
    required this.person,
    required this.state,
    required this.blocked,
    required this.onPrimary,
    required this.onDecline,
    required this.onSafety,
  });

  @override
  Widget build(BuildContext context) {
    final friendship = state.stateFor(person.id);
    final disabled = !blocked && friendship == BantFriendshipState.friends;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.border),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: colors.blue,
            backgroundImage:
                person.avatarUrl == null ? null : NetworkImage(person.avatarUrl!),
            child: person.avatarUrl == null
                ? Text(
                    _initials(person.displayName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${person.username}',
                  style: TextStyle(
                    color: colors.secondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (onDecline != null)
            TextButton(
              onPressed: onDecline,
              child: const Text('Decline'),
            ),
          if (onSafety != null)
            IconButton(
              onPressed: onSafety,
              icon: Icon(
                Icons.shield_outlined,
                color: colors.danger,
                size: 20,
              ),
            ),
          FilledButton.tonal(
            onPressed: disabled ? null : onPrimary,
            style: FilledButton.styleFrom(
              backgroundColor: colors.soft,
              foregroundColor: colors.blue,
            ),
            child: Text(
              blocked ? 'Unblock' : state.actionLabel(person.id),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
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

class _StateMessage extends StatelessWidget {
  final BantPalette colors;
  final IconData icon;
  final String title;
  final String body;

  const _StateMessage({
    required this.colors,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 46),
      child: Column(
        children: [
          Icon(icon, size: 42, color: colors.secondary),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.secondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
