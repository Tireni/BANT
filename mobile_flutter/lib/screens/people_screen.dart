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
    setState(() => notificationsLoading = true);
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
      backgroundColor: BantTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                  'Safety options for ${person.displayName}',
                  style: const TextStyle(
                    color: BantTheme.text,
                    fontSize: 22,
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
                        onSelected: (_) => setSheetState(() => reason = item),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: description,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 1200,
                  decoration: const InputDecoration(
                    hintText: 'Optional report details',
                  ),
                ),
                const SizedBox(height: 10),
                BantButton(
                  label: 'Report user',
                  onPressed: () async {
                    await widget.api.reportUser(
                      userId: person.id,
                      reason: reason,
                      description: description.text,
                    );
                    if (!mounted) return;
                    Navigator.of(sheetContext).pop();
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('Report submitted.')),
                    );
                  },
                ),
                const SizedBox(height: 10),
                BantButton(
                  label: 'Block user',
                  secondary: true,
                  onPressed: () async {
                    final ok = await state.blockUser(person.id);
                    if (!mounted || !ok) return;
                    Navigator.of(sheetContext).pop();
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('User blocked.')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    description.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final people = visiblePeople;

    return RefreshIndicator(
      onRefresh: () async {
        await state.load();
        await _loadNotifications();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
        children: [
          const Text(
            'People',
            style: TextStyle(
              color: BantTheme.text,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          if (tab != 'Notifications')
            TextField(
              controller: search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search people',
              ),
            ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final item in const [
                  'Discover',
                  'Friends',
                  'Blocked',
                  'Notifications',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(item),
                      selected: tab == item,
                      selectedColor: BantTheme.blue,
                      labelStyle: TextStyle(
                        color: tab == item ? Colors.white : BantTheme.secondary,
                        fontWeight: FontWeight.w900,
                      ),
                      onSelected: (_) async {
                        setState(() => tab = item);
                        if (item == 'Notifications') {
                          await _markRead();
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (tab == 'Notifications')
            _NotificationsList(
              loading: notificationsLoading,
              items: notifications,
            )
          else if (state.loading && state.people.isEmpty && tab != 'Blocked')
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 50),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (people.isEmpty)
            _StateMessage(
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
                      ? 'People you block will appear here.'
                      : 'Add friends and jump into rooms together.',
            )
          else
            for (final person in people)
              _PersonRow(
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
              style: const TextStyle(
                color: BantTheme.danger,
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
  final bool loading;
  final List<Map<String, dynamic>> items;

  const _NotificationsList({
    required this.loading,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 50),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (items.isEmpty) {
      return const _StateMessage(
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
              color: BantTheme.surface,
              border: Border.all(color: BantTheme.border),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['body']?.toString() ?? 'BANT notification',
                  style: const TextStyle(
                    color: BantTheme.text,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item['created_at']?.toString() ?? '',
                  style: const TextStyle(
                    color: BantTheme.secondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PersonRow extends StatelessWidget {
  final BantSocialPerson person;
  final BantSocialState state;
  final bool blocked;
  final VoidCallback onPrimary;
  final VoidCallback? onDecline;
  final VoidCallback? onSafety;

  const _PersonRow({
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
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: BantTheme.border)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 23,
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
                      fontWeight: FontWeight.w900,
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
                  style: const TextStyle(
                    color: BantTheme.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '@${person.username}',
                  style: const TextStyle(
                    color: BantTheme.secondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (onDecline != null)
            TextButton(onPressed: onDecline, child: const Text('Decline')),
          if (onSafety != null)
            IconButton(
              onPressed: onSafety,
              icon: const Icon(
                Icons.shield_outlined,
                color: BantTheme.danger,
              ),
            ),
          FilledButton.tonal(
            onPressed: disabled ? null : onPrimary,
            child: Text(blocked ? 'Unblock' : state.actionLabel(person.id)),
          ),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _StateMessage({
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
          Icon(icon, size: 42, color: BantTheme.secondary),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: BantTheme.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: BantTheme.secondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
