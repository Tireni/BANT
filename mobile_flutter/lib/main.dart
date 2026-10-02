import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/auth_service.dart';
import 'core/avatar_service.dart';
import 'core/config.dart';
import 'core/invite_links.dart';
import 'core/mobile_api.dart';
import 'core/pending_invite_store.dart';
import 'core/push_notification_service.dart';
import 'core/theme_controller.dart';
import 'models/profile.dart';
import 'models/room.dart';
import 'screens/create_room_screen.dart';
import 'screens/home_screen.dart';
import 'screens/pending_invite_gate.dart';
import 'screens/people_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/room_screen.dart';
import 'screens/rooms_screen.dart';
import 'state/bant_app_state.dart';
import 'ui/bant_button.dart';
import 'ui/bant_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!BantConfig.valid) {
    runApp(const MaterialApp(home: _MissingConfigScreen()));
    return;
  }

  await Supabase.initialize(
    url: BantConfig.supabaseUrl,
    publishableKey: BantConfig.supabaseAnonKey,
  );

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(
      bantFirebaseMessagingBackgroundHandler,
    );
  } catch (_) {
    // Firebase is optional in local/dev builds until platform credentials
    // (google-services.json / GoogleService-Info.plist) are installed.
  }

  runApp(const BantMobileApp());
}

class BantMobileApp extends StatefulWidget {
  const BantMobileApp({super.key});

  @override
  State<BantMobileApp> createState() => _BantMobileAppState();
}

class _BantMobileAppState extends State<BantMobileApp> {
  late final BantThemeController themeController;
  late final BantPushService pushService;

  @override
  void initState() {
    super.initState();
    themeController = BantThemeController();
    pushService = BantPushService();
    themeController.addListener(_themeChanged);
    themeController.load();
    unawaited(pushService.initialize());
  }

  void _themeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    themeController.removeListener(_themeChanged);
    themeController.dispose();
    unawaited(pushService.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BANT',
      debugShowCheckedModeBanner: false,
      theme: BantTheme.light(),
      darkTheme: BantTheme.dark(),
      themeMode: themeController.mode,
      home: AuthGate(
        themeController: themeController,
        pushService: pushService,
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  final BantThemeController themeController;
  final BantPushService pushService;

  const AuthGate({
    super.key,
    required this.themeController,
    required this.pushService,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthService auth;
  late final MobileApi api;
  late final Stream<AuthState> authChanges;
  late final PendingInviteStore pendingInviteStore;
  late final AppLinks appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<AuthState>? _authSubscription;
  int _bootstrapGeneration = 0;
  BantProfile? profile;
  String? pendingInviteToken;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    auth = AuthService(Supabase.instance.client);
    api = MobileApi(Supabase.instance.client);
    pendingInviteStore = PendingInviteStore();
    appLinks = AppLinks();
    authChanges = auth.changes;
    _authSubscription = authChanges.listen((event) {
      if (event.event == AuthChangeEvent.signedOut) {
        unawaited(widget.pushService.resetAfterSignOut());
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) bootstrap();
      });
    });
    _startInviteLinks();
    bootstrap();
  }

  Future<void> _startInviteLinks() async {
    try {
      final stored = await pendingInviteStore.read();
      if (mounted && stored != null) {
        setState(() => pendingInviteToken = stored);
      }
    } catch (_) {}

    try {
      final initial = await appLinks.getInitialLink();
      if (initial != null) {
        await _captureInviteUri(initial);
      }
    } catch (_) {}

    _linkSubscription = appLinks.uriLinkStream.listen(
      (uri) {
        _captureInviteUri(uri);
      },
      onError: (_) {},
    );
  }

  Future<void> _captureInviteUri(Uri uri) async {
    final token = bantInviteTokenFromUri(uri);
    if (token == null || token.isEmpty) return;
    await pendingInviteStore.save(token);
    if (!mounted) return;
    setState(() => pendingInviteToken = token);
  }

  Future<void> _clearPendingInvite() async {
    await pendingInviteStore.clear();
    if (!mounted) return;
    setState(() => pendingInviteToken = null);
  }

  @override
  void dispose() {
    _bootstrapGeneration++;
    _linkSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> bootstrap() async {
    if (!mounted) return;
    final generation = ++_bootstrapGeneration;

    if (auth.session == null) {
      setState(() {
        profile = null;
        error = null;
        loading = false;
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final data = await api.bootstrap();
      if (!mounted || generation != _bootstrapGeneration) return;
      final next = BantProfile.fromJson(
        Map<String, dynamic>.from(data['profile']),
      );
      if (!mounted) return;
      setState(() {
        profile = next;
        loading = false;
      });
      unawaited(widget.pushService.registerCurrentDevice(api));
    } catch (e) {
      if (!mounted || generation != _bootstrapGeneration) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const _BrandedLoadingScreen(label: 'Opening BANT...');
    }

    if (auth.session == null) {
      return SignInScreen(
        auth: auth,
        pendingInviteToken: pendingInviteToken,
      );
    }

    if (error != null) {
      return _RetryScreen(
        message: error!,
        onRetry: bootstrap,
        onSignOut: auth.signOut,
      );
    }

    final current = profile;
    if (current == null) {
      return _RetryScreen(
        message: 'BANT could not load your profile.',
        onRetry: bootstrap,
        onSignOut: auth.signOut,
      );
    }

    if (!current.onboardingCompleted) {
      return OnboardingFlow(
        api: api,
        profile: current,
        onComplete: bootstrap,
        pendingInviteToken: pendingInviteToken,
      );
    }

    final inviteToken = pendingInviteToken;
    if (inviteToken != null && inviteToken.isNotEmpty) {
      return PendingInviteGate(
        api: api,
        token: inviteToken,
        onFinished: _clearPendingInvite,
      );
    }

    return HomeShell(
      auth: auth,
      api: api,
      profile: current,
      themeController: widget.themeController,
      pushService: widget.pushService,
    );
  }
}

class SignInScreen extends StatefulWidget {
  final AuthService auth;
  final String? pendingInviteToken;

  const SignInScreen({
    super.key,
    required this.auth,
    this.pendingInviteToken,
  });

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool providerStep = false;
  bool loading = false;
  String? error;

  Future<void> signIn() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await widget.auth.signInWithGoogle();
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = BantTheme.of(context);

    if (!providerStep) {
      return Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/brand/bant-mascot.png',
                            width: 104,
                            height: 104,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'BANT',
                            style: TextStyle(
                              color: colors.blue,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            'Discover live rooms.\nMeet people you vibe with.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.text,
                              fontSize: 32,
                              height: 38 / 32,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Talk, share interests, build friendships, and create your own room.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.secondary,
                              fontSize: 15,
                              height: 22 / 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (widget.pendingInviteToken != null) ...[
                            const SizedBox(height: 18),
                            const _PendingInviteBanner(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: [
                      BantButton(
                        label: 'Join BANT',
                        onPressed: () => setState(() => providerStep = true),
                      ),
                      const SizedBox(height: 12),
                      BantButton(
                        label: 'I already have an account',
                        secondary: true,
                        onPressed: () => setState(() => providerStep = true),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Built for real conversation.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed:
                          loading ? null : () => setState(() => providerStep = false),
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: colors.text,
                      ),
                    ),
                  ),
                  Text(
                    'Welcome to BANT',
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 30,
                      height: 36 / 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Find your people. Join the conversation.',
                    style: TextStyle(
                      color: colors.secondary,
                      fontSize: 15,
                      height: 22 / 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border.all(color: colors.border),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Continue with',
                          style: TextStyle(
                            color: colors.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        BantButton(
                          label: 'Continue with Google',
                          loading: loading,
                          onPressed: signIn,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Google sign-in is currently the only way to access BANT.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.secondary,
                            fontSize: 12,
                            height: 18 / 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.pendingInviteToken != null) ...[
                    const SizedBox(height: 14),
                    const _PendingInviteBanner(),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      error!,
                      style: TextStyle(
                        color: colors.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingFlow extends StatefulWidget {
  final MobileApi api;
  final BantProfile profile;
  final Future<void> Function() onComplete;
  final String? pendingInviteToken;

  const OnboardingFlow({
    super.key,
    required this.api,
    required this.profile,
    required this.onComplete,
    this.pendingInviteToken,
  });

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  late BantProfile profile;
  late int step;

  @override
  void initState() {
    super.initState();
    profile = widget.profile;
    step = profile.onboardingStep.clamp(1, 3);
  }

  void updateProfile(BantProfile next) {
    setState(() {
      profile = next;
      step = next.onboardingStep.clamp(1, 3);
    });
  }

  @override
  Widget build(BuildContext context) {
    final inviteNotice = widget.pendingInviteToken == null
        ? null
        : const _PendingInviteBanner();

    if (step <= 1) {
      return ProfileOnboardingScreen(
        api: widget.api,
        profile: profile,
        onSaved: updateProfile,
        banner: inviteNotice,
      );
    }
    if (step == 2) {
      return InterestsOnboardingScreen(
        api: widget.api,
        onBack: () => setState(() => step = 1),
        onSaved: updateProfile,
        banner: inviteNotice,
      );
    }
    return CompleteOnboardingScreen(
      profile: profile,
      api: widget.api,
      onBack: () => setState(() => step = 2),
      onComplete: widget.onComplete,
      banner: inviteNotice,
    );
  }
}

class ProfileOnboardingScreen extends StatefulWidget {
  final MobileApi api;
  final BantProfile profile;
  final ValueChanged<BantProfile> onSaved;
  final Widget? banner;

  const ProfileOnboardingScreen({
    super.key,
    required this.api,
    required this.profile,
    required this.onSaved,
    this.banner,
  });

  @override
  State<ProfileOnboardingScreen> createState() => _ProfileOnboardingScreenState();
}

class _ProfileOnboardingScreenState extends State<ProfileOnboardingScreen> {
  late final TextEditingController name;
  late final TextEditingController username;
  late final TextEditingController bio;
  late final AvatarService avatarService;
  String? avatarUrl;
  bool loading = false;
  bool uploading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.profile.displayName);
    username = TextEditingController(text: widget.profile.username);
    bio = TextEditingController(text: widget.profile.bio);
    avatarUrl = widget.profile.avatarUrl;
    avatarService = AvatarService(Supabase.instance.client);
  }

  @override
  void dispose() {
    name.dispose();
    username.dispose();
    bio.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty || username.text.trim().isEmpty) {
      setState(() => error = 'Name and username are required.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await widget.api.saveOnboardingProfile(
        displayName: name.text.trim(),
        username: username.text.trim().toLowerCase(),
        bio: bio.text.trim(),
        avatarUrl: avatarUrl,
      );
      widget.onSaved(BantProfile.fromJson(data));
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = BantTheme.of(context);
    return _OnboardingScaffold(
      stepLabel: 'STEP 1 OF 2',
      title: 'SET UP YOUR PROFILE',
      subtitle: 'Tell people a little about who you are.',
      footer: BantButton(
        label: 'Continue',
        loading: loading || uploading,
        onPressed: loading || uploading ? null : save,
      ),
      child: Column(
        children: [
          if (widget.banner != null) ...[
            widget.banner!,
            const SizedBox(height: 18),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(42),
                  onTap: uploading
                      ? null
                      : () async {
                          try {
                            setState(() {
                              uploading = true;
                              error = null;
                            });
                            final uploaded =
                                await avatarService.pickAndUpload();
                            if (!mounted || uploaded == null) return;
                            setState(() => avatarUrl = uploaded);
                          } catch (e) {
                            if (mounted) {
                              setState(() {
                                error = e
                                    .toString()
                                    .replaceFirst('Exception: ', '');
                              });
                            }
                          } finally {
                            if (mounted) {
                              setState(() => uploading = false);
                            }
                          }
                        },
                  child: CircleAvatar(
                    radius: 42,
                    backgroundColor: colors.soft,
                    backgroundImage:
                        avatarUrl == null ? null : NetworkImage(avatarUrl!),
                    child: avatarUrl == null
                        ? Icon(
                            Icons.camera_alt_outlined,
                            size: 28,
                            color: colors.blue,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Add a profile photo from your device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.secondary,
                    fontSize: 13,
                    height: 19 / 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                BantButton(
                  label: uploading ? 'Uploading...' : 'Choose photo',
                  secondary: true,
                  loading: uploading,
                  onPressed: uploading
                      ? null
                      : () async {
                          try {
                            setState(() {
                              uploading = true;
                              error = null;
                            });
                            final uploaded =
                                await avatarService.pickAndUpload();
                            if (!mounted || uploaded == null) return;
                            setState(() => avatarUrl = uploaded);
                          } catch (e) {
                            if (mounted) {
                              setState(() {
                                error = e
                                    .toString()
                                    .replaceFirst('Exception: ', '');
                              });
                            }
                          } finally {
                            if (mounted) {
                              setState(() => uploading = false);
                            }
                          }
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: name,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'Full name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: username,
            autocorrect: false,
            textCapitalization: TextCapitalization.none,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'Username'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: bio,
            maxLength: 160,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Short bio'),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                error!,
                style: TextStyle(
                  color: colors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class InterestsOnboardingScreen extends StatefulWidget {
  final MobileApi api;
  final VoidCallback onBack;
  final ValueChanged<BantProfile> onSaved;
  final Widget? banner;

  const InterestsOnboardingScreen({
    super.key,
    required this.api,
    required this.onBack,
    required this.onSaved,
    this.banner,
  });

  @override
  State<InterestsOnboardingScreen> createState() => _InterestsOnboardingScreenState();
}

class _InterestsOnboardingScreenState extends State<InterestsOnboardingScreen> {
  bool loading = true;
  bool saving = false;
  String? error;
  List<Map<String, dynamic>> interests = const [];
  Set<String> selected = {};

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await widget.api.interests();
      if (!mounted) return;
      setState(() {
        interests = List<Map<String, dynamic>>.from(data['interests'] ?? const []);
        selected = Set<String>.from(data['selected'] ?? const []);
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          loading = false;
        });
      }
    }
  }

  Future<void> save() async {
    if (selected.length < 3) {
      setState(() => error = 'Choose at least 3 interests.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final data = await widget.api.saveOnboardingInterests(selected.toList());
      widget.onSaved(BantProfile.fromJson(data));
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = BantTheme.of(context);
    return _OnboardingScaffold(
      stepLabel: 'STEP 2 OF 2',
      title: 'PICK YOUR INTERESTS',
      subtitle: 'Choose at least 3 so your feed feels like you.',
      footer: Row(
        children: [
          Expanded(
            child: BantButton(
              label: 'Back',
              secondary: true,
              onPressed: widget.onBack,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: BantButton(
              label: 'Continue',
              loading: saving,
              onPressed: save,
            ),
          ),
        ],
      ),
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.banner != null) ...[
                  widget.banner!,
                  const SizedBox(height: 18),
                ],
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final interest in interests)
                      ChoiceChip(
                        selectedColor: colors.blue,
                        labelStyle: TextStyle(
                          color: selected.contains(interest['slug'])
                              ? Colors.white
                              : colors.text,
                          fontWeight: FontWeight.w800,
                        ),
                        label: Text(interest['name']?.toString() ?? ''),
                        selected: selected.contains(interest['slug']),
                        onSelected: (_) {
                          final slug = interest['slug']?.toString();
                          if (slug == null) return;
                          setState(() {
                            if (!selected.add(slug)) {
                              selected.remove(slug);
                            }
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '${selected.length}/3 selected',
                  style: TextStyle(
                    color: selected.length >= 3
                        ? colors.mint
                        : colors.secondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: TextStyle(
                      color: colors.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class CompleteOnboardingScreen extends StatefulWidget {
  final BantProfile profile;
  final MobileApi api;
  final VoidCallback onBack;
  final Future<void> Function() onComplete;
  final Widget? banner;

  const CompleteOnboardingScreen({
    super.key,
    required this.profile,
    required this.api,
    required this.onBack,
    required this.onComplete,
    this.banner,
  });

  @override
  State<CompleteOnboardingScreen> createState() => _CompleteOnboardingScreenState();
}

class _CompleteOnboardingScreenState extends State<CompleteOnboardingScreen> {
  bool loading = false;
  String? error;

  Future<void> finish() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await widget.api.finishOnboarding();
      await widget.onComplete();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = BantTheme.of(context);
    return _OnboardingScaffold(
      stepLabel: 'COMPLETE',
      title: 'COMPLETE SETUP',
      subtitle: 'Review the basics, then enter BANT.',
      footer: Row(
        children: [
          Expanded(
            child: BantButton(
              label: 'Back',
              secondary: true,
              onPressed: widget.onBack,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: BantButton(
              label: 'Enter BANT',
              loading: loading,
              onPressed: finish,
            ),
          ),
        ],
      ),
      child: Column(
        children: [
          if (widget.banner != null) ...[
            widget.banner!,
            const SizedBox(height: 18),
          ],
          Icon(Icons.check_circle, color: colors.mint, size: 52),
          const SizedBox(height: 12),
          Text(
            "You're ready.",
            style: TextStyle(
              color: colors.text,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '@${widget.profile.username}',
            style: TextStyle(
              color: colors.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              style: TextStyle(
                color: colors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OnboardingScaffold extends StatelessWidget {
  final String stepLabel;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget footer;

  const _OnboardingScaffold({
    required this.stepLabel,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final colors = BantTheme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const _BrandMark(),
                      const SizedBox(height: 30),
                      Text(
                        stepLabel,
                        style: TextStyle(
                          color: colors.blue,
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: TextStyle(
                          color: colors.text,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: colors.secondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 26),
                      child,
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
                  child: footer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingInviteBanner extends StatelessWidget {
  const _PendingInviteBanner();

  @override
  Widget build(BuildContext context) {
    final colors = BantTheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.soft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.link_rounded, color: colors.blue),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your room invite is waiting. Finish setup and BANT will take you straight to the invited room.',
              style: TextStyle(
                color: colors.text,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  final AuthService auth;
  final MobileApi api;
  final BantProfile profile;
  final BantThemeController themeController;
  final BantPushService pushService;

  const HomeShell({
    super.key,
    required this.auth,
    required this.api,
    required this.profile,
    required this.themeController,
    required this.pushService,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  late final BantAppState appState;
  StreamSubscription<BantPushIntent>? _pushSubscription;
  int unreadNotifications = 0;
  int peopleNotificationNonce = 0;

  @override
  void initState() {
    super.initState();
    appState = BantAppState(widget.api);
    appState.load();
    _pushSubscription = widget.pushService.intents.listen(_handlePushIntent);
    _refreshUnreadNotifications();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = widget.pushService.takePendingIntent();
      if (pending != null) {
        _handlePushIntent(pending);
      }
    });
  }

  @override
  void dispose() {
    _pushSubscription?.cancel();
    appState.dispose();
    super.dispose();
  }

  Future<void> _refreshUnreadNotifications() async {
    try {
      final items = await widget.api.notifications();
      if (!mounted) return;
      setState(() {
        unreadNotifications =
            items.where((item) => item['read_at'] == null).length;
      });
    } catch (_) {}
  }

  Future<void> _handlePushIntent(BantPushIntent intent) async {
    if (!mounted) return;

    if (intent.type == BantPushIntentType.friendRequest) {
      setState(() {
        index = 2;
        peopleNotificationNonce++;
      });
      await _refreshUnreadNotifications();
      return;
    }

    final roomId = intent.roomId;
    if (roomId == null || roomId.isEmpty) return;

    try {
      final data = await widget.api.room(roomId);
      if (!mounted) return;
      openRoom(BantRoom.fromJson(data));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That BANT room is no longer available.'),
        ),
      );
    }
  }

  void openRoom(BantRoom room) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BantRoomScreen(
          api: widget.api,
          room: room,
          onRoomChanged: appState.refreshRooms,
        ),
      ),
    );
  }

  Future<void> startRoom() async {
    final created = await Navigator.of(context).push<BantRoom>(
      MaterialPageRoute(
        builder: (_) => CreateRoomScreen(
          api: widget.api,
          onCreatedRefresh: appState.refreshRooms,
        ),
      ),
    );

    if (created == null || !mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BantRoomScreen(
          api: widget.api,
          room: created,
          onRoomChanged: appState.refreshRooms,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = BantTheme.of(context);
    final pages = [
      BantHomeScreen(
        state: appState,
        profile: widget.profile,
        onOpenRoom: openRoom,
        onStartRoom: startRoom,
        onNotifications: () => setState(() {
          index = 2;
          peopleNotificationNonce++;
        }),
      ),
      BantRoomsScreen(
        state: appState,
        onOpenRoom: openRoom,
        onStartRoom: startRoom,
      ),
      BantPeopleScreen(
        key: ValueKey('people-$peopleNotificationNonce'),
        api: widget.api,
        initialTab:
            peopleNotificationNonce > 0 ? 'Notifications' : 'Discover',
        onUnreadChanged: (count) {
          if (count != unreadNotifications && mounted) {
            setState(() => unreadNotifications = count);
          }
        },
      ),
      BantProfileScreen(
        auth: widget.auth,
        api: widget.api,
        profile: widget.profile,
        themeController: widget.themeController,
        appState: appState,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: index,
          children: pages,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 68,
        backgroundColor: colors.surface,
        indicatorColor: colors.soft,
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum_rounded),
            label: 'Rooms',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unreadNotifications > 0,
              label: Text(
                unreadNotifications > 99
                    ? '99+'
                    : unreadNotifications.toString(),
              ),
              child: const Icon(Icons.people_outline_rounded),
            ),
            selectedIcon: Badge(
              isLabelVisible: unreadNotifications > 0,
              label: Text(
                unreadNotifications > 99
                    ? '99+'
                    : unreadNotifications.toString(),
              ),
              child: const Icon(Icons.people_rounded),
            ),
            label: 'People',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final colors = BantTheme.of(context);
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            'assets/brand/bant-mascot.png',
            width: 46,
            height: 46,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: colors.soft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'BANT',
            style: TextStyle(
              color: colors.blue,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _BrandedLoadingScreen extends StatelessWidget {
  final String label;
  const _BrandedLoadingScreen({required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _BrandMark(),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              const SizedBox(height: 14),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

class _RetryScreen extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  final Future<void> Function() onSignOut;

  const _RetryScreen({
    required this.message,
    required this.onRetry,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final colors = BantTheme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _BrandMark(),
                  const SizedBox(height: 24),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.danger),
                  ),
                  const SizedBox(height: 16),
                  BantButton(label: 'Try again', onPressed: onRetry),
                  const SizedBox(height: 10),
                  BantButton(
                    label: 'Sign out',
                    secondary: true,
                    onPressed: onSignOut,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MissingConfigScreen extends StatelessWidget {
  const _MissingConfigScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'BANT Android needs SUPABASE_URL and SUPABASE_ANON_KEY dart defines.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
