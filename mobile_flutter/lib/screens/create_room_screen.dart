import 'package:flutter/material.dart';

import '../core/mobile_api.dart';
import '../core/room_options.dart';
import '../models/room.dart';
import '../ui/bant_button.dart';
import '../ui/bant_theme.dart';

class CreateRoomScreen extends StatefulWidget {
  final MobileApi api;
  final Future<void> Function()? onCreatedRefresh;

  const CreateRoomScreen({
    super.key,
    required this.api,
    this.onCreatedRefresh,
  });

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final title = TextEditingController();
  final description = TextEditingController();

  String category = 'General';
  String privacy = 'public';
  int maxParticipants = bantDefaultRoomCapacity;
  bool noiseControl = false;
  bool creating = false;
  String? error;

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> create() async {
    final roomTitle = title.text.trim();
    final roomDescription = description.text.trim();

    if (roomTitle.isEmpty) {
      setState(() => error = 'Name the room first.');
      return;
    }
    if (roomTitle.length < 3 || roomTitle.length > 80) {
      setState(() => error = 'Room name must be between 3 and 80 characters.');
      return;
    }
    if (roomDescription.length > 280) {
      setState(() => error = 'Description must be 280 characters or fewer.');
      return;
    }
    if (maxParticipants < bantMinRoomCapacity ||
        maxParticipants > bantMaxRoomCapacity) {
      setState(
        () => error = 'Choose a room size between 5 and 100 participants.',
      );
      return;
    }

    setState(() {
      creating = true;
      error = null;
    });

    try {
      final raw = await widget.api.createRoom(
        title: roomTitle,
        description: roomDescription,
        category: category,
        privacy: privacy,
        maxParticipants: maxParticipants,
        noiseControl: noiseControl,
      );
      final room = BantRoom.fromJson(raw);
      await widget.onCreatedRefresh?.call();

      if (!mounted) return;
      Navigator.of(context).pop(room);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => creating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = BantTheme.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: IconButton(
                        onPressed:
                            creating ? null : () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          color: colors.text,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Start a room',
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    children: [
                      _Field(
                        colors: colors,
                        label: 'Room name',
                        child: TextField(
                          controller: title,
                          maxLength: 80,
                          textInputAction: TextInputAction.next,
                          style: TextStyle(color: colors.text),
                          decoration: const InputDecoration(
                            hintText: 'What are we talking about?',
                            counterText: '',
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      _Field(
                        colors: colors,
                        label: 'Optional description',
                        child: TextField(
                          controller: description,
                          maxLength: 280,
                          minLines: 3,
                          maxLines: 5,
                          style: TextStyle(color: colors.text),
                          decoration: const InputDecoration(
                            hintText: 'Give people a reason to join...',
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      _Field(
                        colors: colors,
                        label: 'Category',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final item in bantRoomCategories)
                              InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: () => setState(() => category = item),
                                child: Container(
                                  constraints:
                                      const BoxConstraints(minHeight: 38),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: category == item
                                        ? colors.blue
                                        : colors.surface,
                                    border: Border.all(
                                      color: category == item
                                          ? colors.blue
                                          : colors.border,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    item,
                                    style: TextStyle(
                                      color: category == item
                                          ? Colors.white
                                          : colors.secondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      _Field(
                        colors: colors,
                        label: 'Privacy',
                        child: Row(
                          children: [
                            Expanded(
                              child: _PrivacyCard(
                                colors: colors,
                                icon: Icons.public_rounded,
                                title: 'Public',
                                body: 'Anyone can discover and join.',
                                selected: privacy == 'public',
                                onTap: () => setState(() => privacy = 'public'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _PrivacyCard(
                                colors: colors,
                                icon: Icons.lock_outline_rounded,
                                title: 'Private',
                                body:
                                    'Only people with an invitation can join.',
                                selected: privacy == 'private',
                                onTap: () => setState(() => privacy = 'private'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      _Field(
                        colors: colors,
                        label: 'Maximum participants',
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            border: Border.all(color: colors.border),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$maxParticipants',
                                style: TextStyle(
                                  color: colors.text,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final value in bantRoomCapacityOptions)
                                    InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () {
                                        setState(
                                          () => maxParticipants = value,
                                        );
                                      },
                                      child: Container(
                                        constraints:
                                            const BoxConstraints(minWidth: 54),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: maxParticipants == value
                                              ? colors.blue
                                              : colors.background,
                                          border: Border.all(
                                            color: maxParticipants == value
                                                ? colors.blue
                                                : colors.border,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '$value',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: maxParticipants == value
                                                ? Colors.white
                                                : colors.text,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      _Field(
                        colors: colors,
                        label: 'Noise Control',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => setState(
                                () => noiseControl = !noiseControl,
                              ),
                              child: Container(
                                constraints:
                                    const BoxConstraints(minHeight: 52),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: noiseControl
                                      ? colors.mint
                                      : colors.surface,
                                  border: Border.all(color: colors.border),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  noiseControl ? 'ON' : 'OFF',
                                  style: TextStyle(
                                    color: noiseControl
                                        ? const Color(0xFF0B1F1F)
                                        : colors.text,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'When enabled, the host can send quiet warnings to participants.',
                              style: TextStyle(
                                color: colors.secondary,
                                fontSize: 12,
                                height: 18 / 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colors.danger.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            error!,
                            style: TextStyle(
                              color: colors.danger,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: colors.background,
                border: Border(
                  top: BorderSide(color: colors.border),
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: BantButton(
                      label: 'Start room',
                      loading: creating,
                      onPressed: create,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final BantPalette colors;
  final String label;
  final Widget child;

  const _Field({
    required this.colors,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.text,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  final BantPalette colors;
  final IconData icon;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;

  const _PrivacyCard({
    required this.colors,
    required this.icon,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? colors.mintSoft : colors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 138),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? colors.mint : colors.border,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? colors.blue : colors.secondary,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                style: TextStyle(
                  color: colors.secondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
