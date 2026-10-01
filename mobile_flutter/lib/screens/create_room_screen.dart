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
      setState(() => error = 'Choose a room size between 5 and 100 participants.');
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
    return Scaffold(
      backgroundColor: BantTheme.background,
      appBar: AppBar(
        backgroundColor: BantTheme.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: creating ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'Start a room',
          style: TextStyle(
            color: BantTheme.text,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _Field(
                    label: 'Room name',
                    child: TextField(
                      controller: title,
                      maxLength: 80,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'What are we talking about?',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _Field(
                    label: 'Optional description',
                    child: TextField(
                      controller: description,
                      maxLength: 280,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Give people a reason to join...',
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _Field(
                    label: 'Category',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in bantRoomCategories)
                          ChoiceChip(
                            label: Text(item),
                            selected: category == item,
                            selectedColor: BantTheme.blue,
                            backgroundColor: BantTheme.surface,
                            side: BorderSide(
                              color: category == item
                                  ? BantTheme.blue
                                  : BantTheme.border,
                            ),
                            labelStyle: TextStyle(
                              color: category == item
                                  ? Colors.white
                                  : BantTheme.secondary,
                              fontWeight: FontWeight.w800,
                            ),
                            onSelected: (_) => setState(() => category = item),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _Field(
                    label: 'Privacy',
                    child: Row(
                      children: [
                        Expanded(
                          child: _PrivacyCard(
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
                            icon: Icons.lock_outline_rounded,
                            title: 'Private',
                            body: 'Only people with an invitation can join.',
                            selected: privacy == 'private',
                            onTap: () => setState(() => privacy = 'private'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _Field(
                    label: 'Maximum participants',
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: BantTheme.surface,
                        border: Border.all(color: BantTheme.border),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$maxParticipants',
                            style: const TextStyle(
                              color: BantTheme.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final value in bantRoomCapacityOptions)
                                ChoiceChip(
                                  label: Text('$value'),
                                  selected: maxParticipants == value,
                                  selectedColor: BantTheme.blue,
                                  backgroundColor: BantTheme.background,
                                  side: BorderSide(
                                    color: maxParticipants == value
                                        ? BantTheme.blue
                                        : BantTheme.border,
                                  ),
                                  labelStyle: TextStyle(
                                    color: maxParticipants == value
                                        ? Colors.white
                                        : BantTheme.text,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  onSelected: (_) {
                                    setState(() => maxParticipants = value);
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _Field(
                    label: 'Noise Control',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () =>
                              setState(() => noiseControl = !noiseControl),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 54),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: noiseControl
                                  ? const Color(0xFFDFF7EA)
                                  : BantTheme.surface,
                              border: Border.all(
                                color: noiseControl
                                    ? BantTheme.mint
                                    : BantTheme.border,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  noiseControl ? 'ON' : 'OFF',
                                  style: const TextStyle(
                                    color: BantTheme.text,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const Spacer(),
                                Switch(
                                  value: noiseControl,
                                  onChanged: (value) {
                                    setState(() => noiseControl = value);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'When enabled, the host can send quiet warnings to participants.',
                          style: TextStyle(
                            color: BantTheme.secondary,
                            fontSize: 12,
                            height: 1.5,
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
                        color: const Color(0xFFFFE9E7),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        error!,
                        style: const TextStyle(
                          color: BantTheme.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: const BoxDecoration(
                color: BantTheme.background,
                border: Border(
                  top: BorderSide(color: BantTheme.border),
                ),
              ),
              child: BantButton(
                label: 'Start room',
                loading: creating,
                onPressed: create,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final Widget child;

  const _Field({
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
          style: const TextStyle(
            color: BantTheme.text,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;

  const _PrivacyCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFDFF7EA) : BantTheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 138),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? BantTheme.mint : BantTheme.border,
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
                color: selected ? BantTheme.blue : BantTheme.secondary,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  color: BantTheme.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                style: const TextStyle(
                  color: BantTheme.secondary,
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
