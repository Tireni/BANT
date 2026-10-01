import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth_service.dart';
import '../core/avatar_service.dart';
import '../core/mobile_api.dart';
import '../models/profile.dart';
import '../ui/bant_button.dart';
import '../ui/bant_theme.dart';

class BantProfileScreen extends StatefulWidget {
  final AuthService auth;
  final MobileApi api;
  final BantProfile profile;

  const BantProfileScreen({
    super.key,
    required this.auth,
    required this.api,
    required this.profile,
  });

  @override
  State<BantProfileScreen> createState() => _BantProfileScreenState();
}

class _BantProfileScreenState extends State<BantProfileScreen> {
  late BantProfile profile;
  late final AvatarService avatarService;

  @override
  void initState() {
    super.initState();
    profile = widget.profile;
    avatarService = AvatarService(Supabase.instance.client);
    _refreshProfile();
  }

  Future<void> _refreshProfile() async {
    try {
      final data = await widget.api.profile();
      if (!mounted) return;
      setState(() => profile = BantProfile.fromJson(data));
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
      backgroundColor: BantTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
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
                  const Text(
                    'Edit profile',
                    style: TextStyle(
                      color: BantTheme.text,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 46,
                          backgroundColor: const Color(0xFFE8F4FF),
                          backgroundImage: avatarUrl == null
                              ? null
                              : NetworkImage(avatarUrl!),
                          child: avatarUrl == null
                              ? const Icon(
                                  Icons.person_rounded,
                                  size: 42,
                                  color: BantTheme.blue,
                                )
                              : null,
                        ),
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: IconButton.filled(
                            onPressed: saving
                                ? null
                                : () async {
                                    try {
                                      final uploaded =
                                          await avatarService.pickAndUpload();
                                      if (uploaded == null) return;
                                      setSheetState(() => avatarUrl = uploaded);
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
                    decoration:
                        const InputDecoration(hintText: 'Display name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: username,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.none,
                    maxLength: 24,
                    decoration: const InputDecoration(hintText: 'Username'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: bio,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 160,
                    decoration: const InputDecoration(hintText: 'Bio'),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: const TextStyle(
                        color: BantTheme.danger,
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
                        setSheetState(() => saving = false);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    name.dispose();
    username.dispose();
    bio.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshProfile,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: BantTheme.surface,
              border: Border.all(color: BantTheme.border),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 46,
                  backgroundColor: const Color(0xFFE8F4FF),
                  backgroundImage: profile.avatarUrl == null
                      ? null
                      : NetworkImage(profile.avatarUrl!),
                  child: profile.avatarUrl == null
                      ? const Icon(
                          Icons.person_rounded,
                          size: 42,
                          color: BantTheme.blue,
                        )
                      : null,
                ),
                const SizedBox(height: 14),
                Text(
                  profile.displayName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: BantTheme.text,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${profile.username}',
                  style: const TextStyle(
                    color: BantTheme.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (profile.bio.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    profile.bio,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: BantTheme.secondary,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                BantButton(
                  label: 'Edit profile',
                  secondary: true,
                  onPressed: _editProfile,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            body: 'Friend requests, room invitations and activity appear in People.',
          ),
          _SettingsTile(
            icon: Icons.shield_outlined,
            title: 'Safety',
            body: 'Use the Safety button on People to report or block an account.',
          ),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'About BANT',
            body: 'A safe place to just talk.',
          ),
          const SizedBox(height: 18),
          BantButton(
            label: 'Sign out',
            secondary: true,
            onPressed: widget.auth.signOut,
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BantTheme.surface,
        border: Border.all(color: BantTheme.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: BantTheme.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: BantTheme.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
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
        ],
      ),
    );
  }
}
