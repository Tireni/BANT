import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../models/room.dart';
import '../state/bant_app_state.dart';
import '../ui/bant_brand_header.dart';
import '../ui/bant_button.dart';
import '../ui/bant_room_card.dart';
import '../ui/bant_theme.dart';

class BantHomeScreen extends StatelessWidget {
  final BantAppState state;
  final BantProfile profile;
  final ValueChanged<BantRoom> onOpenRoom;
  final VoidCallback onStartRoom;
  final VoidCallback onNotifications;

  const BantHomeScreen({
    super.key,
    required this.state,
    required this.profile,
    required this.onOpenRoom,
    required this.onStartRoom,
    required this.onNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final publicRooms = state.publicRooms();
        final liveNow = publicRooms.take(5).toList();
        final popular = [...publicRooms]
          ..sort((a, b) => b.participantCount.compareTo(a.participantCount));
        final newest = [...publicRooms]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return RefreshIndicator(
          onRefresh: state.refreshRooms,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            children: [
              BantBrandHeader(
                profile: profile,
                unread: state.unreadNotifications,
                onNotifications: onNotifications,
              ),
              const SizedBox(height: 26),
              Text(
                "What's happening, ${profile.displayName.split(' ').first}?",
                style: const TextStyle(
                  color: BantTheme.text,
                  fontSize: 28,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Find the room for your mood.',
                style: TextStyle(
                  color: BantTheme.secondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              const _SectionLabel('LIVE NOW'),
              const SizedBox(height: 12),
              if (state.loading && state.rooms.isEmpty)
                const SizedBox(
                  height: 170,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (liveNow.isEmpty)
                _EmptyRooms(onStartRoom: onStartRoom)
              else
                SizedBox(
                  height: 205,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: liveNow.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final room = liveNow[index];
                      return BantRoomCard(
                        room: room,
                        compact: true,
                        onTap: () => onOpenRoom(room),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: BantTheme.blue,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Got something to say?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Start a room and invite people who get it.',
                      style: TextStyle(
                        color: Color(0xFFDDEFFF),
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    BantButton(
                      label: 'Start a room',
                      secondary: true,
                      onPressed: onStartRoom,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const _SectionLabel('POPULAR'),
              const SizedBox(height: 12),
              for (final room in popular.take(6)) ...[
                BantRoomCard(
                  room: room,
                  onTap: () => onOpenRoom(room),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 16),
              const _SectionLabel('NEW'),
              const SizedBox(height: 12),
              for (final room in newest.take(6)) ...[
                BantRoomCard(
                  room: room,
                  onTap: () => onOpenRoom(room),
                ),
                const SizedBox(height: 12),
              ],
              if (state.error != null) ...[
                const SizedBox(height: 10),
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
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF98A2B3),
        fontSize: 12,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w900,
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BantTheme.surface,
        border: Border.all(color: BantTheme.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text(
            'Nothing live right now.',
            style: TextStyle(
              color: BantTheme.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Start a room.',
            style: TextStyle(color: BantTheme.secondary),
          ),
          const SizedBox(height: 14),
          BantButton(
            label: 'Start a room',
            onPressed: onStartRoom,
          ),
        ],
      ),
    );
  }
}
