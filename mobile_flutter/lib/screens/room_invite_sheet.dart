import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/mobile_api.dart';
import '../models/room.dart';
import '../ui/bant_button.dart';
import '../ui/bant_theme.dart';

class RoomInviteSheet extends StatefulWidget {
  final MobileApi api;
  final BantRoom room;

  const RoomInviteSheet({
    super.key,
    required this.api,
    required this.room,
  });

  @override
  State<RoomInviteSheet> createState() => _RoomInviteSheetState();
}

class _RoomInviteSheetState extends State<RoomInviteSheet> {
  static const _shareChannel = MethodChannel('bant/share');

  bool loading = true;
  String? error;
  String? token;

  String get link =>
      token == null ? '' : 'https://bant-demo.vercel.app/r/$token';

  @override
  void initState() {
    super.initState();
    _createInvite();
  }

  Future<void> _createInvite() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final invite = await widget.api.createInvite(widget.room.id);
      if (!mounted) return;
      setState(() {
        token = invite['invite_token']?.toString();
        loading = false;
      });
      if (token == null || token!.isEmpty) {
        throw Exception('BANT could not create an invite link.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
        loading = false;
      });
    }
  }

  Future<void> _copy() async {
    if (link.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite link copied.')),
    );
  }

  Future<void> _share() async {
    if (link.isEmpty) return;
    final text =
        '${widget.room.title}\nJoin the conversation on BANT: $link';

    try {
      await _shareChannel.invokeMethod<void>(
        'shareText',
        {'text': text},
      );
    } catch (_) {
      await _copy();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = BantTheme.of(context);
    return SafeArea(
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
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'INVITE PEOPLE',
              style: TextStyle(
                color: colors.blue,
                fontSize: 11,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.room.title,
              style: TextStyle(
                color: colors.text,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share this short BANT link. People who already have the Android app can open the room directly.',
              style: TextStyle(
                color: colors.secondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    error!,
                    style: TextStyle(
                      color: colors.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  BantButton(
                    label: 'Try again',
                    secondary: true,
                    onPressed: _createInvite,
                  ),
                ],
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.background,
                  border: Border.all(color: colors.border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SelectableText(
                  link,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: BantButton(
                      label: 'Copy link',
                      secondary: true,
                      onPressed: _copy,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BantButton(
                      label: 'Share',
                      onPressed: _share,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
