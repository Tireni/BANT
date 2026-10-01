import 'package:flutter/material.dart';

import '../core/mobile_api.dart';
import '../models/room.dart';
import '../ui/bant_button.dart';
import '../ui/bant_theme.dart';
import 'room_screen.dart';

class PendingInviteGate extends StatefulWidget {
  final MobileApi api;
  final String token;
  final Future<void> Function() onFinished;

  const PendingInviteGate({
    super.key,
    required this.api,
    required this.token,
    required this.onFinished,
  });

  @override
  State<PendingInviteGate> createState() => _PendingInviteGateState();
}

class _PendingInviteGateState extends State<PendingInviteGate> {
  Map<String, dynamic>? preview;
  BantRoom? room;
  bool loading = true;
  bool joining = false;
  String? error;
  bool terminal = false;

  @override
  void initState() {
    super.initState();
    _continueInvite();
  }

  Future<void> _continueInvite() async {
    setState(() {
      loading = true;
      joining = false;
      error = null;
      terminal = false;
    });

    try {
      final nextPreview = await widget.api.invitePreview(widget.token);
      if (!mounted) return;

      if (nextPreview == null) {
        setState(() {
          loading = false;
          terminal = true;
          error = 'This invite is invalid.';
        });
        return;
      }

      preview = nextPreview;
      final inviteStatus = nextPreview['invite_status']?.toString();
      final roomStatus = nextPreview['room_status']?.toString();

      if (inviteStatus == 'expired') {
        setState(() {
          loading = false;
          terminal = true;
          error = 'This invite has expired.';
        });
        return;
      }

      if (inviteStatus != 'active' || roomStatus != 'live') {
        setState(() {
          loading = false;
          terminal = true;
          error = 'This invite is no longer available.';
        });
        return;
      }

      setState(() {
        loading = false;
        joining = true;
      });

      final roomId = await widget.api.joinInvite(widget.token);
      final rawRoom = await widget.api.room(roomId);

      final nextRoom = BantRoom.fromJson({
        ...rawRoom,
        'participant_count': (rawRoom['room_members'] as List?)?.length ?? 0,
        'speaker_count': (rawRoom['room_members'] as List?)
                ?.where((item) {
                  if (item is! Map) return false;
                  final role = item['role']?.toString();
                  return role == 'owner' ||
                      role == 'host' ||
                      role == 'speaker';
                })
                .length ??
            0,
      });

      if (!mounted) return;
      setState(() {
        room = nextRoom;
        joining = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        joining = false;
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = BantTheme.of(context);
    final joinedRoom = room;
    if (joinedRoom != null) {
      return BantRoomScreen(
        api: widget.api,
        room: joinedRoom,
        onRoomChanged: widget.onFinished,
        onExit: widget.onFinished,
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border.all(color: colors.border),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (loading || joining)
                      const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'BANT ROOM INVITE',
                      style: TextStyle(
                        color: colors.blue,
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      preview?['room_title']?.toString() ?? 'Opening room...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (preview?['room_category'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${preview!['room_category']} · ${preview!['room_privacy'] == 'private' ? 'Private room' : 'Public room'}',
                        style: TextStyle(
                          color: colors.secondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      preview?['room_description']?.toString().isNotEmpty == true
                          ? preview!['room_description'].toString()
                          : 'Join the conversation on BANT.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.secondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    if (joining) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Your account is ready. Joining the invited room...',
                        style: TextStyle(
                          color: colors.mint,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.danger,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (!terminal)
                        BantButton(
                          label: 'Try again',
                          onPressed: _continueInvite,
                        ),
                      if (terminal || error != null) ...[
                        const SizedBox(height: 10),
                        BantButton(
                          label: 'Go to BANT',
                          secondary: true,
                          onPressed: widget.onFinished,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
