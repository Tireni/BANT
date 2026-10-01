import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/mobile_api.dart';
import '../models/room.dart';
import '../models/room_detail.dart';
import '../ui/bant_button.dart';
import '../ui/bant_participant_grid.dart';
import '../ui/bant_theme.dart';

class BantRoomScreen extends StatefulWidget {
  final MobileApi api;
  final BantRoom room;
  final Future<void> Function()? onRoomChanged;

  const BantRoomScreen({
    super.key,
    required this.api,
    required this.room,
    this.onRoomChanged,
  });

  @override
  State<BantRoomScreen> createState() => _BantRoomScreenState();
}

class _BantRoomScreenState extends State<BantRoomScreen> {
  final message = TextEditingController();

  BantRoomDetail? detail;
  List<Map<String, dynamic>> messages = const [];
  bool loading = true;
  bool joining = false;
  bool sending = false;
  bool leaving = false;
  String? error;

  String get currentUserId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  bool get isOwner {
    final room = detail;
    if (room == null || currentUserId.isEmpty) return false;
    return room.ownerId == currentUserId ||
        room.participantFor(currentUserId)?.role == 'owner' ||
        room.participantFor(currentUserId)?.role == 'host';
  }

  BantParticipant? get currentMembership =>
      detail?.participantFor(currentUserId);

  @override
  void initState() {
    super.initState();
    _openRoom();
  }

  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  Future<void> _openRoom() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      var room = BantRoomDetail.fromJson(
        await widget.api.room(widget.room.id),
      );

      if (room.status != 'live') {
        throw Exception('This room has ended.');
      }

      if (room.participantFor(currentUserId) == null) {
        setState(() => joining = true);
        await widget.api.joinRoom(widget.room.id, role: 'speaker');
        room = BantRoomDetail.fromJson(
          await widget.api.room(widget.room.id),
        );
      }

      final roomMessages = await widget.api.messages(widget.room.id);

      if (!mounted) return;
      setState(() {
        detail = room;
        messages = roomMessages;
        loading = false;
        joining = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
        loading = false;
        joining = false;
      });
    }
  }

  Future<void> _refresh() async {
    try {
      final room = BantRoomDetail.fromJson(
        await widget.api.room(widget.room.id),
      );
      final roomMessages = await widget.api.messages(widget.room.id);
      if (!mounted) return;
      setState(() {
        detail = room;
        messages = roomMessages;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _sendMessage() async {
    final body = message.text.trim();
    if (body.isEmpty || sending) return;

    setState(() => sending = true);
    try {
      await widget.api.sendMessage(widget.room.id, body);
      message.clear();
      final roomMessages = await widget.api.messages(widget.room.id);
      if (!mounted) return;
      setState(() => messages = roomMessages);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _leaveOrEnd() async {
    if (leaving) return;

    final owner = isOwner;
    final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(owner ? 'End this room?' : 'Leave this room?'),
            content: Text(
              owner
                  ? 'Ending the room will remove everyone and close the conversation.'
                  : 'You can rejoin while the room is still live.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(owner ? 'End room' : 'Leave'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldContinue || !mounted) return;

    setState(() => leaving = true);

    try {
      if (owner) {
        await widget.api.endRoom(widget.room.id);
      } else {
        await widget.api.leaveRoom(widget.room.id);
      }

      await widget.onRoomChanged?.call();

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => leaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = detail;

    return Scaffold(
      backgroundColor: BantTheme.background,
      appBar: AppBar(
        backgroundColor: BantTheme.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: leaving ? null : _leaveOrEnd,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              room?.title ?? widget.room.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: BantTheme.text,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (room != null)
              Text(
                '${room.category} · ${room.participantCount} / ${room.maxParticipants}',
                style: const TextStyle(
                  color: BantTheme.secondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        actions: [
          if (isOwner)
            Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'HOST',
                style: TextStyle(
                  color: Color(0xFFB54708),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: loading
            ? _LoadingRoom(joining: joining)
            : error != null && room == null
                ? _RoomError(
                    message: error!,
                    retry: _openRoom,
                  )
                : room == null
                    ? const SizedBox.shrink()
                    : Column(
                        children: [
                          Expanded(
                            child: RefreshIndicator(
                              onRefresh: _refresh,
                              child: ListView(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  8,
                                  20,
                                  116,
                                ),
                                children: [
                                  _RoomIntro(
                                    room: room,
                                    currentRole:
                                        currentMembership?.role ?? 'speaker',
                                  ),
                                  const SizedBox(height: 18),
                                  _Panel(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const _SectionLabel('ROOM'),
                                        const SizedBox(height: 12),
                                        if (room.participants.isEmpty)
                                          const Text(
                                            'No active participants yet.',
                                            style: TextStyle(
                                              color: BantTheme.secondary,
                                            ),
                                          )
                                        else
                                          BantParticipantGrid(
                                            participants: room.participants,
                                            ownerId: room.ownerId,
                                            currentUserId: currentUserId,
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  const _SectionLabel('CHAT'),
                                  const SizedBox(height: 12),
                                  _Panel(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (messages.isEmpty)
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 10,
                                            ),
                                            child: Text(
                                              'No messages yet. Start the room chat.',
                                              style: TextStyle(
                                                color: BantTheme.secondary,
                                              ),
                                            ),
                                          )
                                        else
                                          for (final item
                                              in messages.reversed.take(8).toList().reversed)
                                            _MessageBubble(
                                              item: item,
                                              mine: item['sender_id']
                                                      ?.toString() ==
                                                  currentUserId,
                                            ),
                                        const SizedBox(height: 10),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: message,
                                                maxLength: 500,
                                                minLines: 1,
                                                maxLines: 4,
                                                decoration:
                                                    const InputDecoration(
                                                  hintText:
                                                      'Message the room',
                                                  counterText: '',
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            SizedBox(
                                              width: 52,
                                              height: 52,
                                              child: FilledButton(
                                                onPressed: sending
                                                    ? null
                                                    : _sendMessage,
                                                style: FilledButton.styleFrom(
                                                  padding: EdgeInsets.zero,
                                                  shape:
                                                      RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                  ),
                                                ),
                                                child: sending
                                                    ? const SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child:
                                                            CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                      )
                                                    : const Icon(
                                                        Icons.send_rounded,
                                                      ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (error != null) ...[
                                    const SizedBox(height: 14),
                                    Text(
                                      error!,
                                      style: const TextStyle(
                                        color: BantTheme.danger,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          _RoomControls(
                            owner: isOwner,
                            leaving: leaving,
                            onLeaveOrEnd: _leaveOrEnd,
                            onInvite: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Invitations will be enabled in the invitations batch.',
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
      ),
    );
  }
}

class _RoomIntro extends StatelessWidget {
  final BantRoomDetail room;
  final String currentRole;

  const _RoomIntro({
    required this.room,
    required this.currentRole,
  });

  @override
  Widget build(BuildContext context) {
    final roleLabel = currentRole == 'owner' || currentRole == 'host'
        ? 'OWNER'
        : currentRole.toUpperCase();

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                room.privacy == 'private'
                    ? Icons.lock_outline_rounded
                    : Icons.public_rounded,
                size: 16,
                color: BantTheme.blue,
              ),
              _Pill(
                label: room.privacy == 'private' ? 'Private' : 'Public',
                color: BantTheme.blue,
              ),
              _Pill(
                label: roleLabel,
                color: currentRole == 'owner' || currentRole == 'host'
                    ? const Color(0xFFB54708)
                    : BantTheme.blue,
              ),
              if (room.noiseControlEnabled)
                const _Pill(
                  label: 'Noise Control 🤫',
                  color: Color(0xFFB54708),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            room.description.isEmpty
                ? 'Live room discussion.'
                : room.description,
            style: const TextStyle(
              color: BantTheme.secondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.people_outline_rounded,
                size: 17,
                color: BantTheme.blue,
              ),
              const SizedBox(width: 5),
              Text(
                '${room.participantCount} / ${room.maxParticipants} participants',
                style: const TextStyle(
                  color: BantTheme.secondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 14),
              const Icon(
                Icons.record_voice_over_outlined,
                size: 17,
                color: BantTheme.mint,
              ),
              const SizedBox(width: 5),
              Text(
                '${room.speakerCount} speaker${room.speakerCount == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: BantTheme.secondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Room access is active. Android voice connection is added in Batch 5.',
            style: TextStyle(
              color: BantTheme.secondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomControls extends StatelessWidget {
  final bool owner;
  final bool leaving;
  final VoidCallback onLeaveOrEnd;
  final VoidCallback onInvite;

  const _RoomControls({
    required this.owner,
    required this.leaving,
    required this.onLeaveOrEnd,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        color: BantTheme.surface,
        border: Border(top: BorderSide(color: BantTheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.mic_none_rounded),
                label: const Text('Voice'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onInvite,
                icon: const Icon(Icons.share_outlined),
                label: const Text('Invite'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: leaving ? null : onLeaveOrEnd,
                style: FilledButton.styleFrom(
                  backgroundColor: BantTheme.danger,
                ),
                icon: Icon(
                  owner
                      ? Icons.stop_circle_outlined
                      : Icons.logout_rounded,
                ),
                label: Text(
                  leaving
                      ? 'Please wait'
                      : owner
                          ? 'End'
                          : 'Leave',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool mine;

  const _MessageBubble({
    required this.item,
    required this.mine,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: mine ? BantTheme.blue : const Color(0xFFEFF4F8),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mine ? 'You' : item['sender_name']?.toString() ?? 'BANT user',
              style: TextStyle(
                color: mine ? Colors.white : BantTheme.blue,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item['body']?.toString() ?? '',
              style: TextStyle(
                color: mine ? Colors.white : BantTheme.text,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BantTheme.surface,
        border: Border.all(color: BantTheme.border),
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;

  const _Pill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
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

class _LoadingRoom extends StatelessWidget {
  final bool joining;

  const _LoadingRoom({required this.joining});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(joining ? 'Joining room...' : 'Opening room...'),
        ],
      ),
    );
  }
}

class _RoomError extends StatelessWidget {
  final String message;
  final Future<void> Function() retry;

  const _RoomError({
    required this.message,
    required this.retry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 44,
                color: BantTheme.danger,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: BantTheme.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              BantButton(
                label: 'Try again',
                onPressed: retry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
