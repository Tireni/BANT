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
    final colors = BantTheme.of(context);

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
          color: colors.blue,
          onRefresh: state.refreshRooms,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
            children: [
              BantBrandHeader(
                profile: profile,
                unread: state.unreadNotifications,
                onNotifications: onNotifications,
              ),
              const SizedBox(height: 26),
              Text(
                "What's happening, ${profile.displayName.split(' ').first}?",
                style: TextStyle(
                  color: colors.text,
                  fontSize: 28,
                  height: 34 / 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Find the room for your mood.',
                style: TextStyle(
                  color: colors.secondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 26),
              _SectionLabel('LIVE NOW', color: colors.muted),
              const SizedBox(height: 12),
              if (state.loading && state.rooms.isEmpty)
                SizedBox(
                  height: 170,
                  child: Center(
                    child: CircularProgressIndicator(color: colors.blue),
                  ),
                )
              else if (liveNow.isEmpty)
                _EmptyRooms(
                  onStartRoom: onStartRoom,
                  colors: colors,
                )
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
              const SizedBox(height: 26),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.blue,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: Theme.of(context).brightness == Brightness.dark
                            ? 0.28
                            : 0.08,
                      ),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Got something to say?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Start a room and invite people who get it.',
                      style: TextStyle(
                        color: Color(0xDBFFFFFF),
                        fontSize: 14,
                        height: 20 / 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    BantButton(
                      label: 'Start a room',
                      variant: BantButtonVariant.secondary,
                      onPressed: onStartRoom,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              _SectionLabel('POPULAR', color: colors.muted),
              const SizedBox(height: 12),
              for (final room in popular.take(6)) ...[
                BantRoomCard(
                  room: room,
                  onTap: () => onOpenRoom(room),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 14),
              _SectionLabel('NEW', color: colors.muted),
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
                  style: TextStyle(
                    color: colors.danger,
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
  final Color color;

  const _SectionLabel(this.label, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 12,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w800,
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            'Nothing live right now.',
            style: TextStyle(
              color: colors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Start a room.',
            style: TextStyle(color: colors.secondary),
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
