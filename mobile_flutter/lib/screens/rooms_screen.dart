import 'package:flutter/material.dart';

import '../models/room.dart';
import '../state/bant_app_state.dart';
import '../ui/bant_room_card.dart';
import '../ui/bant_theme.dart';

const bantRoomCategories = <String>[
  'Feed',
  'Gaming',
  'Anime',
  'Art',
  'Philosophy',
  'Music',
  'Technology',
  'Movies',
  'Sports',
  'Books',
  'Fashion',
  'Culture',
  'Relationships',
  'Business',
  'Comedy',
  'Science',
  'Lifestyle',
  'Food',
  'Travel',
  'General',
];

class BantRoomsScreen extends StatefulWidget {
  final BantAppState state;
  final ValueChanged<BantRoom> onOpenRoom;
  final VoidCallback onStartRoom;

  const BantRoomsScreen({
    super.key,
    required this.state,
    required this.onOpenRoom,
    required this.onStartRoom,
  });

  @override
  State<BantRoomsScreen> createState() => _BantRoomsScreenState();
}

class _BantRoomsScreenState extends State<BantRoomsScreen> {
  final search = TextEditingController();
  String category = 'Feed';
  String filter = 'Live';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final rooms = widget.state.publicRooms(
          category: category,
          query: search.text,
          filter: filter,
        );

        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: widget.state.refreshRooms,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                children: [
                  const Text(
                    'Explore rooms',
                    style: TextStyle(
                      color: BantTheme.text,
                      fontSize: 30,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search conversations',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: bantRoomCategories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final item = bantRoomCategories[index];
                        final selected = category == item;
                        return ChoiceChip(
                          label: Text(item),
                          selected: selected,
                          selectedColor: BantTheme.blue,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : BantTheme.text,
                            fontWeight: FontWeight.w800,
                          ),
                          side: BorderSide(
                            color: selected ? BantTheme.blue : BantTheme.border,
                          ),
                          onSelected: (_) => setState(() => category = item),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final item in const ['Live', 'Popular', 'New']) ...[
                        _FilterChip(
                          label: item,
                          selected: filter == item,
                          onTap: () => setState(() => filter = item),
                        ),
                        if (item != 'New') const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (widget.state.loading && widget.state.rooms.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 70),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (rooms.isEmpty)
                    _EmptyRooms(onStartRoom: widget.onStartRoom)
                  else
                    for (final room in rooms) ...[
                      BantRoomCard(
                        room: room,
                        onTap: () => widget.onOpenRoom(room),
                      ),
                      const SizedBox(height: 12),
                    ],
                  if (widget.state.error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      widget.state.error!,
                      style: const TextStyle(
                        color: BantTheme.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              right: 22,
              bottom: 22,
              child: FloatingActionButton(
                heroTag: 'bant-create-room',
                backgroundColor: BantTheme.blue,
                foregroundColor: Colors.white,
                onPressed: widget.onStartRoom,
                child: const Icon(Icons.add_rounded, size: 29),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? BantTheme.blue : const Color(0xFFEFF4F8),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : BantTheme.secondary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyRooms extends StatelessWidget {
  final VoidCallback onStartRoom;
  const _EmptyRooms({required this.onStartRoom});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: BantTheme.surface,
        border: Border.all(color: BantTheme.border),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.forum_outlined,
            size: 36,
            color: BantTheme.blue,
          ),
          const SizedBox(height: 12),
          const Text(
            'Nothing live right now.',
            style: TextStyle(
              color: BantTheme.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Start a room.',
            style: TextStyle(color: BantTheme.secondary),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onStartRoom,
            child: const Text('Start a room'),
          ),
        ],
      ),
    );
  }
}
