import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/mobile_api.dart';
import '../core/voice_service.dart';
import '../models/room.dart';
import '../models/room_detail.dart';
import '../state/room_chat_controller.dart';
import '../state/room_moderation_controller.dart';
import '../ui/bant_button.dart';
import '../ui/bant_participant_grid.dart';
import '../ui/bant_theme.dart';
import '../ui/room_moderation_panel.dart';
import 'in_room_social_sheet.dart';
import 'room_invite_sheet.dart';

class BantRoomScreen extends StatefulWidget {
  final MobileApi api;
  final BantRoom room;
  final Future<void> Function()? onRoomChanged;
  final Future<void> Function()? onExit;

  const BantRoomScreen({
    super.key,
    required this.api,
    required this.room,
    this.onRoomChanged,
    this.onExit,
  });

  @override
  State<BantRoomScreen> createState() => _BantRoomScreenState();
}

class _BantRoomScreenState extends State<BantRoomScreen> {
  final message = TextEditingController();
  late final VoiceService voice;
  late final RoomChatController chat;
  late final RoomModerationController moderation;

  BantRoomDetail? detail;
  bool loading = true;
  bool joining = false;
  bool leaving = false;
  String? error;
  String? roomActivity;
  dynamic _membersChannel;
  dynamic _roomChannel;

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
    voice = VoiceService(Supabase.instance.client);
    voice.addListener(_onVoiceChanged);
    chat = RoomChatController(
      api: widget.api,
      supabase: Supabase.instance.client,
      roomId: widget.room.id,
      currentUserId: currentUserId,
    );
    chat.addListener(_onChatChanged);
    moderation = RoomModerationController(
      api: widget.api,
      supabase: Supabase.instance.client,
      roomId: widget.room.id,
      currentUserId: currentUserId,
    );
    moderation.addListener(_onModerationChanged);
    moderation.start();
    _subscribeRealtime();
    _openRoom();
  }

  void _onVoiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onChatChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onModerationChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    final client = Supabase.instance.client;
    if (_membersChannel != null) {
      client.removeChannel(_membersChannel);
    }
    if (_roomChannel != null) {
      client.removeChannel(_roomChannel);
    }
    voice.removeListener(_onVoiceChanged);
    voice.dispose();
    chat.removeListener(_onChatChanged);
    chat.dispose();
    moderation.removeListener(_onModerationChanged);
    moderation.dispose();
    message.dispose();
    super.dispose();
  }

  void _subscribeRealtime() {
    final client = Supabase.instance.client;

    _membersChannel = client
        .channel('mobile-room-members:${widget.room.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'room_members',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: widget.room.id,
          ),
          callback: (payload) {
            _handleMemberRealtime(payload);
          },
        )
        .subscribe();

    _roomChannel = client
        .channel('mobile-room:${widget.room.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'rooms',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.room.id,
          ),
          callback: (payload) async {
            final next = payload.newRecord;
            if (next['status']?.toString() == 'ended') {
              await voice.disconnect();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Room ended.')),
              );
              await widget.onRoomChanged?.call();
              if (!mounted) return;
              if (widget.onExit != null) {
                await widget.onExit!.call();
              } else {
                Navigator.of(context).pop();
              }
              return;
            }
            _refresh();
          },
        )
        .subscribe();
  }

  Future<void> _handleMemberRealtime(PostgresChangePayload payload) async {
    final record = payload.newRecord.isNotEmpty
        ? payload.newRecord
        : payload.oldRecord;
    final userId = record['user_id']?.toString() ?? '';

    String name = 'Someone';
    if (userId.isNotEmpty) {
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('display_name,username')
            .eq('id', userId)
            .maybeSingle();
        if (profile != null) {
          name = (profile['display_name'] ??
                  profile['username'] ??
                  'Someone')
              .toString();
        }
      } catch (_) {}
    }

    String? activity;
    if (payload.eventType == PostgresChangeEvent.insert) {
      activity = userId == currentUserId ? 'You joined the room.' : '$name joined the room.';
    } else if (payload.eventType == PostgresChangeEvent.update) {
      final leftAt = payload.newRecord['left_at'];
      final role = payload.newRecord['role']?.toString();
      if (leftAt != null) {
        activity = userId == currentUserId ? 'You left the room.' : '$name left the room.';
      } else if (role != null) {
        activity = userId == currentUserId
            ? 'Your role changed to $role.'
            : '$name is now a $role.';
      }
    }

    await _refreshRoomOnly();

    if (userId == currentUserId && payload.newRecord.isNotEmpty) {
      await voice.setAdminMuted(payload.newRecord['is_muted'] == true);
    }

    if (!mounted || activity == null) return;
    setState(() => roomActivity = activity);
    Future<void>.delayed(const Duration(seconds: 4), () {
      if (mounted && roomActivity == activity) {
        setState(() => roomActivity = null);
      }
    });
  }

  Future<void> _refreshRoomOnly() async {
    try {
      final room = BantRoomDetail.fromJson(
        await widget.api.room(widget.room.id),
      );
      final membership = room.participantFor(currentUserId);
      await voice.setAdminMuted(membership?.muted ?? false);
      if (!mounted) return;
      setState(() {
        detail = room;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
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

      final membership = room.participantFor(currentUserId);
      final role = membership?.role ?? 'speaker';

      if (!mounted) return;
      setState(() {
        detail = room;
        loading = false;
        joining = false;
      });

      await Future.wait([
        chat.start(),
        voice.connect(
          widget.room.id,
          publishMicrophone: role != 'listener',
          startMuted: membership?.muted ?? false,
        ),
      ]);
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
      if (!mounted) return;
      setState(() {
        detail = room;
        error = null;
      });
      await chat.reload();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _switchRole() async {
    final membership = currentMembership;
    if (membership == null || isOwner) return;

    final nextRole = membership.role == 'listener' ? 'speaker' : 'listener';

    try {
      await widget.api.joinRoom(widget.room.id, role: nextRole);
      await _refresh();

      final membership = currentMembership;
      await voice.reconnectForRole(
        widget.room.id,
        publishMicrophone: nextRole != 'listener',
        startMuted: membership?.muted ?? false,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextRole == 'speaker'
                ? 'You are now a speaker and can use your microphone.'
                : 'You are now a listener.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _sendMessage() async {
    final body = message.text.trim();
    if (body.isEmpty) {
      setState(() => error = 'Type a message first.');
      return;
    }

    final sent = await chat.send(body);
    if (sent) {
      message.clear();
      if (mounted) {
        setState(() => error = null);
      }
    } else if (chat.error != null && mounted) {
      setState(() => error = chat.error);
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
      await voice.disconnect();

      if (owner) {
        await widget.api.endRoom(widget.room.id);
      } else {
        await widget.api.leaveRoom(widget.room.id);
      }

      await widget.onRoomChanged?.call();

      if (!mounted) return;
      if (widget.onExit != null) {
        await widget.onExit!.call();
      } else {
        Navigator.of(context).pop();
      }
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
      body: Stack(
        children: [
          SafeArea(
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
                                  if (roomActivity != null) ...[
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 9,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F4FF),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.bolt_rounded,
                                            size: 16,
                                            color: BantTheme.blue,
                                          ),
                                          const SizedBox(width: 7),
                                          Expanded(
                                            child: Text(
                                              roomActivity!,
                                              style: const TextStyle(
                                                color: BantTheme.blue,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  _RoomIntro(
                                    room: room,
                                    currentRole:
                                        currentMembership?.role ?? 'speaker',
                                    voiceStatus: voice.status,
                                    voiceError: voice.error,
                                    remoteCount: voice.remoteCount,
                                    onSwitchRole:
                                        isOwner ? null : _switchRole,
                                  ),
                                  const SizedBox(height: 18),
                                  if (isOwner) ...[
                                    RoomModerationPanel(
                                      selectionMode:
                                          moderation.selectionMode,
                                      busy: moderation.busy,
                                      selectedCount:
                                          moderation.selectedUserIds.length,
                                      noiseControlEnabled:
                                          room.noiseControlEnabled,
                                      onToggleSelection:
                                          moderation.toggleSelectionMode,
                                      onMuteSelected: () async {
                                        if (await moderation.moderate('mute')) {
                                          await _refreshRoomOnly();
                                        }
                                      },
                                      onReleaseSelected: () async {
                                        if (await moderation
                                            .moderate('unmute')) {
                                          await _refreshRoomOnly();
                                        }
                                      },
                                      onMuteAll: () async {
                                        if (await moderation.moderate(
                                          'mute',
                                          all: true,
                                        )) {
                                          await _refreshRoomOnly();
                                        }
                                      },
                                      onReleaseAll: () async {
                                        if (await moderation.moderate(
                                          'unmute',
                                          all: true,
                                        )) {
                                          await _refreshRoomOnly();
                                        }
                                      },
                                      onWarnSelected: () async {
                                        await moderation.warn();
                                      },
                                      onWarnAll: () async {
                                        await moderation.warn(all: true);
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                  ],
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
                                            connectedVoiceUserIds:
                                                voice.connectedUserIds,
                                            activeSpeakerIds:
                                                voice.activeSpeakerIds,
                                            mutedVoiceUserIds:
                                                voice.mutedVoiceUserIds,
                                            moderationMode:
                                                moderation.selectionMode,
                                            selectedUserIds:
                                                moderation.selectedUserIds,
                                            onToggleUser: (userId) {
                                              moderation.toggleUser(
                                                userId,
                                                ownerId: room.ownerId,
                                              );
                                            },
                                            onUserPressed: (participant) {
                                              showModalBottomSheet<void>(
                                                context: context,
                                                isScrollControlled: true,
                                                backgroundColor:
                                                    BantTheme.surface,
                                                shape:
                                                    const RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.vertical(
                                                    top: Radius.circular(24),
                                                  ),
                                                ),
                                                builder: (_) =>
                                                    InRoomSocialSheet(
                                                  api: widget.api,
                                                  participant: participant,
                                                ),
                                              );
                                            },
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
                                        if (chat.loading)
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            child: Row(
                                              children: [
                                                SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                ),
                                                SizedBox(width: 10),
                                                Text(
                                                  'Loading messages...',
                                                  style: TextStyle(
                                                    color: BantTheme.secondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        else if (chat.messages.isEmpty)
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
                                          for (final item in chat.messages
                                              .reversed
                                              .take(12)
                                              .toList()
                                              .reversed)
                                            _MessageBubble(
                                              item: item,
                                              mine: item['sender_id']
                                                      ?.toString() ==
                                                  currentUserId,
                                            ),
                                        if (chat.error != null) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  chat.error!,
                                                  style: const TextStyle(
                                                    color: BantTheme.danger,
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: chat.reload,
                                                child: const Text('Retry'),
                                              ),
                                            ],
                                          ),
                                        ],
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
                                                onPressed: chat.sending
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
                                                child: chat.sending
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
                                  if (moderation.error != null) ...[
                                    const SizedBox(height: 14),
                                    Text(
                                      moderation.error!,
                                      style: const TextStyle(
                                        color: BantTheme.danger,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
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
                            role: currentMembership?.role ?? 'speaker',
                            voiceStatus: voice.status,
                            muted: voice.muted,
                            adminMuted: voice.adminMuted,
                            speakerOn: voice.speakerOn,
                            onVoice: () async {
                              if (voice.status == BantVoiceStatus.error ||
                                  voice.status == BantVoiceStatus.idle) {
                                final role =
                                    currentMembership?.role ?? 'speaker';
                                await voice.connect(
                                  widget.room.id,
                                  publishMicrophone: role != 'listener',
                                  startMuted:
                                      currentMembership?.muted ?? false,
                                );
                                return;
                              }
                              if ((currentMembership?.role ?? 'speaker') !=
                                  'listener') {
                                await voice.toggleMute();
                              }
                            },
                            onSpeaker: voice.toggleSpeaker,
                            onLeaveOrEnd: _leaveOrEnd,
                            onInvite: () {
                              showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: BantTheme.surface,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(24),
                                  ),
                                ),
                                builder: (_) => RoomInviteSheet(
                                  api: widget.api,
                                  room: widget.room,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
          ),
          if (moderation.warningMessage != null)
            Positioned(
              top: 14,
              left: 20,
              right: 20,
              child: NoiseWarningToast(
                message: moderation.warningMessage!,
              ),
            ),
        ],
      ),
    );
  }
}

class _RoomIntro extends StatelessWidget {
  final BantRoomDetail room;
  final String currentRole;
  final BantVoiceStatus voiceStatus;
  final String? voiceError;
  final int remoteCount;
  final VoidCallback? onSwitchRole;

  const _RoomIntro({
    required this.room,
    required this.currentRole,
    required this.voiceStatus,
    required this.voiceError,
    required this.remoteCount,
    this.onSwitchRole,
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
          if (onSwitchRole != null) ...[
            OutlinedButton.icon(
              onPressed: onSwitchRole,
              icon: Icon(
                currentRole == 'listener'
                    ? Icons.mic_none_rounded
                    : Icons.headphones_rounded,
              ),
              label: Text(
                currentRole == 'listener'
                    ? 'Become speaker'
                    : 'Become listener',
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Icon(
                voiceStatus == BantVoiceStatus.connected
                    ? Icons.graphic_eq_rounded
                    : voiceStatus == BantVoiceStatus.reconnecting
                        ? Icons.sync_rounded
                        : voiceStatus == BantVoiceStatus.error
                            ? Icons.error_outline_rounded
                            : Icons.hourglass_top_rounded,
                size: 16,
                color: voiceStatus == BantVoiceStatus.connected
                    ? BantTheme.mint
                    : voiceStatus == BantVoiceStatus.error
                        ? BantTheme.danger
                        : BantTheme.secondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  voiceStatus == BantVoiceStatus.connected
                      ? 'Live audio connected · $remoteCount other media participant${remoteCount == 1 ? '' : 's'}'
                      : voiceStatus == BantVoiceStatus.reconnecting
                          ? 'Reconnecting live audio...'
                          : voiceStatus == BantVoiceStatus.connecting
                              ? 'Connecting live audio...'
                              : voiceStatus == BantVoiceStatus.error
                                  ? (voiceError ?? 'Live audio connection failed.')
                                  : 'Live audio is not connected.',
                  style: TextStyle(
                    color: voiceStatus == BantVoiceStatus.connected
                        ? BantTheme.mint
                        : voiceStatus == BantVoiceStatus.error
                            ? BantTheme.danger
                            : BantTheme.secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoomControls extends StatelessWidget {
  final bool owner;
  final bool leaving;
  final String role;
  final BantVoiceStatus voiceStatus;
  final bool muted;
  final bool adminMuted;
  final bool speakerOn;
  final Future<void> Function() onVoice;
  final Future<void> Function() onSpeaker;
  final VoidCallback onLeaveOrEnd;
  final VoidCallback onInvite;

  const _RoomControls({
    required this.owner,
    required this.leaving,
    required this.role,
    required this.voiceStatus,
    required this.muted,
    required this.adminMuted,
    required this.speakerOn,
    required this.onVoice,
    required this.onSpeaker,
    required this.onLeaveOrEnd,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    final listener = role == 'listener';
    final connected = voiceStatus == BantVoiceStatus.connected;
    final connecting = voiceStatus == BantVoiceStatus.connecting ||
        voiceStatus == BantVoiceStatus.reconnecting;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
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
                onPressed: connecting || adminMuted ? null : onVoice,
                icon: Icon(
                  listener
                      ? Icons.headphones_rounded
                      : muted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                  size: 18,
                  color: connected ? BantTheme.blue : BantTheme.secondary,
                ),
                label: Text(
                  connecting
                      ? 'Joining'
                      : adminMuted
                          ? 'Host muted'
                          : listener
                              ? (connected ? 'Listening' : 'Listen')
                              : muted
                                  ? 'Unmute'
                                  : 'Mute',
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: connected ? onSpeaker : null,
                icon: Icon(
                  speakerOn
                      ? Icons.volume_up_rounded
                      : Icons.hearing_rounded,
                  size: 18,
                ),
                label: Text(speakerOn ? 'Speaker' : 'Earpiece'),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onInvite,
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Invite'),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: FilledButton(
                onPressed: leaving ? null : onLeaveOrEnd,
                style: FilledButton.styleFrom(
                  backgroundColor: BantTheme.danger,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  leaving
                      ? 'Wait'
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
