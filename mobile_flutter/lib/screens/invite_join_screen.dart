import 'package:flutter/material.dart';

import '../core/mobile_api.dart';
import '../models/room.dart';
import '../ui/bant_button.dart';
import '../ui/bant_theme.dart';

class InviteJoinScreen extends StatefulWidget {
  final MobileApi api;
  final String token;

  const InviteJoinScreen({
    super.key,
    required this.api,
    required this.token,
  });

  @override
  State<InviteJoinScreen> createState() => _InviteJoinScreenState();
}

class _InviteJoinScreenState extends State<InviteJoinScreen> {
  Map<String, dynamic>? preview;
  bool loading = true;
  bool joining = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadAndJoin();
  }

  Future<void> _loadAndJoin() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final nextPreview = await widget.api.invitePreview(widget.token);
      if (!mounted) return;

      if (nextPreview == null) {
        setState(() {
          loading = false;
          error = 'This invite is invalid.';
        });
        return;
      }

      setState(() {
        preview = nextPreview;
        loading = false;
      });

      final inviteStatus = nextPreview['invite_status']?.toString();
      final roomStatus = nextPreview['room_status']?.toString();

      if (inviteStatus == 'expired') {
        setState(() => error = 'This invite has expired.');
        return;
      }
      if (inviteStatus != 'active' || roomStatus != 'live') {
        setState(() => error = 'This invite is no longer available.');
        return;
      }

      setState(() => joining = true);

      final roomId = await widget.api.joinInvite(widget.token);
      final rawRoom = await widget.api.room(roomId);

      if (!mounted) return;
      final room = BantRoom.fromJson({
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

      Navigator.of(context).pop(room);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        joining = false;
        loading = false;
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = preview?['room_title']?.toString() ?? 'Room invite';
    final category = preview?['room_category']?.toString();
    final privacy = preview?['room_privacy']?.toString();
    final description = preview?['room_description']?.toString();

    return Scaffold(
      backgroundColor: BantTheme.background,
      appBar: AppBar(
        backgroundColor: BantTheme.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: BantTheme.surface,
                  border: Border.all(color: BantTheme.border),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (loading || joining)
                      const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text(
                      'BANT ROOM INVITE',
                      style: TextStyle(
                        color: BantTheme.blue,
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: BantTheme.text,
                        fontSize: 28,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (category != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '$category · ${privacy == 'private' ? 'Private room' : 'Public room'}',
                        style: const TextStyle(
                          color: BantTheme.secondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      description == null || description.isEmpty
                          ? 'Join the conversation on BANT.'
                          : description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: BantTheme.secondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (joining)
                      const Text(
                        'Joining you to the room...',
                        style: TextStyle(
                          color: BantTheme.mint,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    else if (error != null)
                      Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: BantTheme.danger,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    if (error != null) ...[
                      const SizedBox(height: 14),
                      BantButton(
                        label: 'Try again',
                        secondary: true,
                        onPressed: _loadAndJoin,
                      ),
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
