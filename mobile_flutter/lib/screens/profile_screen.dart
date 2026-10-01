import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth_service.dart';
import '../core/avatar_service.dart';
import '../core/mobile_api.dart';
import '../core/theme_controller.dart';
import '../models/profile.dart';
import '../state/bant_app_state.dart';
import '../ui/bant_button.dart';
import '../ui/bant_theme.dart';

class BantProfileScreen extends StatefulWidget {
  final AuthService auth;
  final MobileApi api;
  final BantProfile profile;
  final BantThemeController themeController;
  final BantAppState appState;

  const BantProfileScreen({
    super.key,
    required this.auth,
    required this.api,
    required this.profile,
    required this.themeController,
    required this.appState,
  });

  @override
  State<BantProfileScreen> createState() => _BantProfileScreenState();
}

class _BantProfileScreenState extends State<BantProfileScreen> {
  late BantProfile profile;
  late final AvatarService avatarService;
  int friendCount = 0;
  int unreadCount = 0;
  int activeRoomCount = 0;

  @override
  void initState() {
    super.initState();
    profile = widget.profile;
    avatarService = AvatarService(Supabase.instance.client);
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _refreshProfile(),
      _refreshStats(),
      widget.appState.refreshRooms(),
    ]);
  }

  Future<void> _refreshProfile() async {
    try {
      final data = await widget.api.profile();
      if (!mounted) return;
      setState(() => profile = BantProfile.fromJson(data));
    } catch (_) {}
  }

  Future<void> _refreshStats() async {
    try {
      final social = await widget.api.peopleState();
      final notifications = await widget.api.notifications();
      final userId = Supabase.instance.client.auth.currentUser?.id;

      var active = 0;
      if (userId != null) {
        final rows = await Supabase.instance.client
            .from('room_members')
            .select('room_id')
            .eq('user_id', userId)
            .isFilter('left_at', null);
        active = (rows as List).length;
      }

      if (!mounted) return;
      setState(() {
        friendCount =
            List<dynamic>.from(social['friend_ids'] ?? const []).length;
        unreadCount = notifications
            .where((item) => item['read_at'] == null)
            .length;
        activeRoomCount = active;
      });
    } catch (_) {}
  }

  Future<void> _editProfile() async {
    final name = TextEditingController(text: profile.displayName);
    final username = TextEditingController(text: profile.username);
    final bio = TextEditingController(text: profile.bio);
    String? avatarUrl = profile.avatarUrl;
    bool saving = false;
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Edit profile',
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 43,
                            backgroundColor: colors.blue,
                            backgroundImage: avatarUrl == null
                                ? null
                                : NetworkImage(avatarUrl!),
                            child: avatarUrl == null
                                ? Text(
                                    _initials(profile.displayName),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: IconButton.filled(
                              style: IconButton.styleFrom(
                                backgroundColor: colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: saving
                                  ? null
                                  : () async {
                                      try {
                                        final uploaded =
                                            await avatarService.pickAndUpload();
                                        if (uploaded == null) return;
                                        setSheetState(
                                          () => avatarUrl = uploaded,
                                        );
                                      } catch (e) {
                                        setSheetState(() {
                                          error = e
                                              .toString()
                                              .replaceFirst('Exception: ', '');
                                        });
                                      }
                                    },
                              icon: const Icon(Icons.camera_alt_rounded),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: name,
                      maxLength: 60,
                      style: TextStyle(color: colors.text),
                      decoration:
                          const InputDecoration(hintText: 'Display name'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: username,
                      autocorrect: false,
                      textCapitalization: TextCapitalization.none,
                      maxLength: 24,
                      style: TextStyle(color: colors.text),
                      decoration:
                          const InputDecoration(hintText: 'Username'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: bio,
                      minLines: 3,
                      maxLines: 5,
                      maxLength: 160,
                      style: TextStyle(color: colors.text),
                      decoration: const InputDecoration(hintText: 'Bio'),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        error!,
                        style: TextStyle(
                          color: colors.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    BantButton(
                      label: 'Save profile',
                      loading: saving,
                      onPressed: () async {
                        setSheetState(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          final data = await widget.api.updateProfile(
                            displayName: name.text.trim(),
                            username: username.text.trim().toLowerCase(),
                            bio: bio.text.trim(),
                            avatarUrl: avatarUrl,
                          );
                          if (!mounted) return;
                          setState(() => profile = BantProfile.fromJson(data));
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        } catch (e) {
                          setSheetState(() {
                            error = e
                                .toString()
                                .replaceFirst('Exception: ', '');
                          });
                        } finally {
                          if (sheetContext.mounted) {
                            setSheetState(() => saving = false);
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    name.dispose();
    username.dispose();
    bio.dispose();
  }

  Future<void> _openFeedback() async {
    final message = TextEditingController();
    String category = 'suggestion';
    bool saving = false;
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
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
                  Text(
                    'Send feedback',
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'CATEGORY',
                    style: TextStyle(
                      color: colors.muted,
                      fontSize: 11,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in const [
                        'bug',
                        'feature',
                        'suggestion',
                        'complaint',
                        'other',
                      ])
                        ChoiceChip(
                          label: Text(item),
                          selected: category == item,
                          selectedColor: colors.blue,
                          backgroundColor: colors.soft,
                          labelStyle: TextStyle(
                            color: category == item
                                ? Colors.white
                                : colors.secondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                          onSelected: (_) =>
                              setSheetState(() => category = item),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: message,
                    minLines: 4,
                    maxLines: 6,
                    maxLength: 1200,
                    style: TextStyle(color: colors.text),
                    decoration: const InputDecoration(
                      hintText: 'Tell us what to improve',
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: TextStyle(
                        color: colors.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  BantButton(
                    label: 'Submit feedback',
                    loading: saving,
                    onPressed: () async {
                      setSheetState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await widget.api.submitFeedback(
                          category: category,
                          message: message.text.trim(),
                        );
                        if (!sheetContext.mounted) return;
                        Navigator.of(sheetContext).pop();
                      } catch (e) {
                        setSheetState(() {
                          error = e
                              .toString()
                              .replaceFirst('Exception: ', '');
                        });
                      } finally {
                        if (sheetContext.mounted) {
                          setSheetState(() => saving = false);
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    message.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = BantTheme.of(context);
    final liveRoomCount =
        widget.appState.rooms.where((room) => room.isLive).length;

    return RefreshIndicator(
      color: colors.blue,
      onRefresh: _refreshAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 43,
                  backgroundColor: colors.blue,
                  backgroundImage: profile.avatarUrl == null
                      ? null
                      : NetworkImage(profile.avatarUrl!),
                  child: profile.avatarUrl == null
                      ? Text(
                          _initials(profile.displayName),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  profile.displayName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${profile.username}',
                  style: TextStyle(
                    color: colors.secondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (profile.bio.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    profile.bio,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.secondary,
                      fontSize: 13,
                      height: 19 / 13,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _editProfile,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.blue,
                    backgroundColor: colors.soft,
                    side: BorderSide(color: colors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Edit profile',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  colors: colors,
                  label: 'Friends',
                  value: '$friendCount',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Stat(
                  colors: colors,
                  label: 'Active rooms',
                  value: '$activeRoomCount',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Stat(
                  colors: colors,
                  label: 'Live rooms',
                  value: '$liveRoomCount',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _AppearanceCard(themeController: widget.themeController),
          const SizedBox(height: 14),
          _SettingsTile(
            colors: colors,
            icon: Icons.person_outline_rounded,
            title: 'Profile setup',
            onTap: _editProfile,
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            colors: colors,
            icon: Icons.sell_outlined,
            title: 'Interests',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Interest editing will use the same onboarding picker.',
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            colors: colors,
            icon: Icons.notifications_outlined,
            title: unreadCount > 0
                ? 'Notifications ($unreadCount)'
                : 'Notifications',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Open People → Notifications.'),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            colors: colors,
            icon: Icons.message_outlined,
            title: 'Send feedback',
            onTap: _openFeedback,
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            colors: colors,
            icon: Icons.shield_outlined,
            title: 'Safety',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Use Safety on the People screen.'),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            colors: colors,
            icon: Icons.info_outline_rounded,
            title: 'About BANT',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('A safe place to just talk')),
              );
            },
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: widget.auth.signOut,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              foregroundColor: colors.blue,
              backgroundColor: colors.soft,
              side: BorderSide(color: colors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Log out',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'B';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}

class _Stat extends StatelessWidget {
  final BantPalette colors;
  final String label;
  final String value;

  const _Stat({
    required this.colors,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: colors.text,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                color: colors.secondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceCard extends StatelessWidget {
  final BantThemeController themeController;

  const _AppearanceCard({
    required this.themeController,
  });

  @override
  Widget build(BuildContext context) {
    final colors = BantTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Appearance',
            style: TextStyle(
              color: colors.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colors.soft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                for (final option in BantThemePreference.values)
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => themeController.setPreference(option),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        constraints: const BoxConstraints(minHeight: 42),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: themeController.preference == option
                              ? colors.blue
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          option.name[0].toUpperCase() +
                              option.name.substring(1),
                          style: TextStyle(
                            color: themeController.preference == option
                                ? Colors.white
                                : colors.secondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final BantPalette colors;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.colors,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: colors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
