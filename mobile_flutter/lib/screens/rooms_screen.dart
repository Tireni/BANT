import 'package:flutter/material.dart';

import '../core/room_options.dart';
import '../models/room.dart';
import '../state/bant_app_state.dart';
import '../ui/bant_room_card.dart';
import '../ui/bant_theme.dart';

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
    final colors = BantTheme.of(context);

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
              color: colors.blue,
              onRefresh: widget.state.refreshRooms,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                children: [
                  Text(
                    'Explore rooms',
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: search,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(color: colors.text),
                    decoration: const InputDecoration(
                      hintText: 'Search conversations',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: bantRoomCategories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final item = bantRoomCategories[index];
                        final selected = category == item;
                        return InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => setState(() => category = item),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 38),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color:
                                  selected ? colors.blue : colors.surface,
                              border: Border.all(
                                color:
                                    selected ? colors.blue : colors.border,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              item,
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : colors.secondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
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
                          colors: colors,
                          onTap: () => setState(() => filter = item),
                        ),
                        if (item != 'New') const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (widget.state.loading && widget.state.rooms.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 70),
                      child: Center(
                        child: CircularProgressIndicator(color: colors.blue),
                      ),
                    )
                  else if (rooms.isEmpty)
                    _EmptyRooms(
                      onStartRoom: widget.onStartRoom,
                      colors: colors,
                    )
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
                      style: TextStyle(
                        color: colors.danger,
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
                backgroundColor: colors.blue,
                foregroundColor: Colors.white,
                elevation: Theme.of(context).brightness == Brightness.dark
                    ? 6
                    : 4,
                onPressed: widget.onStartRoom,
                child: const Icon(Icons.add_rounded, size: 28),
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
  final BantPalette colors;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? colors.blue : colors.soft,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : colors.secondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyRooms extends StatelessWidget {
  final VoidCallback onStartRoom;
  final BantPalette colors;

  const _EmptyRooms({
    required this.onStartRoom,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(
            Icons.forum_outlined,
            size: 36,
            color: colors.blue,
          ),
          const SizedBox(height: 12),
          Text(
            'Nothing live right now.',
            style: TextStyle(
              color: colors.text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Start a room.',
            style: TextStyle(color: colors.secondary),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onStartRoom,
            style: FilledButton.styleFrom(backgroundColor: colors.blue),
            child: const Text('Start a room'),
          ),
        ],
      ),
    );
  }
}
