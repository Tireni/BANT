import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/mobile_api.dart';
import '../state/bant_social_state.dart';
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
    } else if (tab == 'Requests') {
      final incomingIds = state.incoming.map((item) => item.senderId).toSet();
      source = source.where((person) => incomingIds.contains(person.id));
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

  @override
  Widget build(BuildContext context) {
    final people = visiblePeople;

    return RefreshIndicator(
      onRefresh: state.load,
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
          TextField(
            controller: search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search people',
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                for (final item in const ['Discover', 'Friends', 'Requests'])
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => tab = item),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        constraints: const BoxConstraints(minHeight: 42),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: tab == item ? BantTheme.blue : null,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item,
                          style: TextStyle(
                            color: tab == item
                                ? Colors.white
                                : BantTheme.secondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (state.loading && state.people.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 50),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.error != null && state.people.isEmpty)
            _StateMessage(
              icon: Icons.error_outline_rounded,
              title: 'Unable to load people',
              body: state.error!,
              action: TextButton(
                onPressed: state.load,
                child: const Text('Try again'),
              ),
            )
          else if (people.isEmpty)
            _StateMessage(
              icon: tab == 'Requests'
                  ? Icons.mark_email_unread_outlined
                  : Icons.people_outline_rounded,
              title: tab == 'Friends'
                  ? 'No friends yet.'
                  : tab == 'Requests'
                      ? 'No incoming requests.'
                      : 'Find people you vibe with.',
              body: tab == 'Friends'
                  ? 'Add people from Discover and they will appear here after they accept.'
                  : tab == 'Requests'
                      ? 'Incoming friend requests will appear here.'
                      : 'Add friends and jump into rooms together.',
            )
          else
            for (final person in people)
              _PersonRow(
                person: person,
                state: state,
                onPrimary: () => state.primaryAction(person.id),
                onDecline: state.stateFor(person.id) ==
                        BantFriendshipState.pendingReceived
                    ? () => state.declineIncoming(person.id)
                    : null,
              ),
          if (state.error != null && state.people.isNotEmpty) ...[
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

class _PersonRow extends StatelessWidget {
  final BantSocialPerson person;
  final BantSocialState state;
  final VoidCallback onPrimary;
  final VoidCallback? onDecline;

  const _PersonRow({
    required this.person,
    required this.state,
    required this.onPrimary,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final friendship = state.stateFor(person.id);
    final disabled = friendship == BantFriendshipState.friends;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: BantTheme.border),
        ),
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
                const SizedBox(height: 2),
                Text(
                  '@${person.username}',
                  style: const TextStyle(
                    color: BantTheme.secondary,
                    fontSize: 12,
                  ),
                ),
                if (person.bio.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    person.bio,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BantTheme.secondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onDecline != null) ...[
            TextButton(
              onPressed: onDecline,
              child: const Text('Decline'),
            ),
            const SizedBox(width: 4),
          ],
          FilledButton.tonal(
            onPressed: disabled ? null : onPrimary,
            child: Text(state.actionLabel(person.id)),
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
  final Widget? action;

  const _StateMessage({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
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
          if (action != null) ...[
            const SizedBox(height: 10),
            action!,
          ],
        ],
      ),
    );
  }
}
