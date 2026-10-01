import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/auth_service.dart';
import 'core/config.dart';
import 'core/mobile_api.dart';
import 'models/profile.dart';
import 'models/room.dart';
import 'screens/create_room_screen.dart';
import 'screens/home_screen.dart';
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

  runApp(const BantMobileApp());
}

class BantMobileApp extends StatelessWidget {
  const BantMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BANT',
      debugShowCheckedModeBanner: false,
      theme: BantTheme.light(),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthService auth;
  late final MobileApi api;
  late final Stream<AuthState> authChanges;
  BantProfile? profile;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    auth = AuthService(Supabase.instance.client);
    api = MobileApi(Supabase.instance.client);
    authChanges = auth.changes;
    authChanges.listen((_) => bootstrap());
    bootstrap();
  }

  Future<void> bootstrap() async {
    if (!mounted) return;

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
      final next = BantProfile.fromJson(
        Map<String, dynamic>.from(data['profile']),
      );
      if (!mounted) return;
      setState(() {
        profile = next;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
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
      return SignInScreen(auth: auth);
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
      );
    }

    return HomeShell(auth: auth, api: api, profile: current);
  }
}

class SignInScreen extends StatefulWidget {
  final AuthService auth;
  const SignInScreen({super.key, required this.auth});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                const _BrandMark(),
                const SizedBox(height: 36),
                const Text(
                  'Welcome to BANT',
                  style: TextStyle(
                    color: BantTheme.text,
                    fontSize: 34,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Find your people. Join live conversations. Start your own room.',
                  style: TextStyle(
                    color: BantTheme.secondary,
                    fontSize: 16,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 28),
                BantButton(
                  label: 'Continue with Google',
                  loading: loading,
                  onPressed: signIn,
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
                const SizedBox(height: 16),
                const Text(
                  'Google sign-in is currently the way to access BANT.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: BantTheme.secondary,
                    fontSize: 12,
                  ),
                ),
              ],
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

  const OnboardingFlow({
    super.key,
    required this.api,
    required this.profile,
    required this.onComplete,
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
    if (step <= 1) {
      return ProfileOnboardingScreen(
        api: widget.api,
        profile: profile,
        onSaved: updateProfile,
      );
    }
    if (step == 2) {
      return InterestsOnboardingScreen(
        api: widget.api,
        onBack: () => setState(() => step = 1),
        onSaved: updateProfile,
      );
    }
    return CompleteOnboardingScreen(
      profile: profile,
      api: widget.api,
      onBack: () => setState(() => step = 2),
      onComplete: widget.onComplete,
    );
  }
}

class ProfileOnboardingScreen extends StatefulWidget {
  final MobileApi api;
  final BantProfile profile;
  final ValueChanged<BantProfile> onSaved;

  const ProfileOnboardingScreen({
    super.key,
    required this.api,
    required this.profile,
    required this.onSaved,
  });

  @override
  State<ProfileOnboardingScreen> createState() => _ProfileOnboardingScreenState();
}

class _ProfileOnboardingScreenState extends State<ProfileOnboardingScreen> {
  late final TextEditingController name;
  late final TextEditingController username;
  late final TextEditingController bio;
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.profile.displayName);
    username = TextEditingController(text: widget.profile.username);
    bio = TextEditingController(text: widget.profile.bio);
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
    return _OnboardingScaffold(
      stepLabel: 'STEP 1 OF 2',
      title: 'SET UP YOUR PROFILE',
      subtitle: 'Tell people a little about who you are.',
      footer: BantButton(
        label: 'Continue',
        loading: loading,
        onPressed: save,
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 42,
            backgroundColor: Color(0xFFE8F4FF),
            child: Icon(Icons.person, size: 40, color: BantTheme.blue),
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
                style: const TextStyle(
                  color: BantTheme.danger,
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

  const InterestsOnboardingScreen({
    super.key,
    required this.api,
    required this.onBack,
    required this.onSaved,
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
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final interest in interests)
                      ChoiceChip(
                        selectedColor: BantTheme.blue,
                        labelStyle: TextStyle(
                          color: selected.contains(interest['slug']) ? Colors.white : BantTheme.text,
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
                    color: selected.length >= 3 ? BantTheme.mint : BantTheme.secondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
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
    );
  }
}

class CompleteOnboardingScreen extends StatefulWidget {
  final BantProfile profile;
  final MobileApi api;
  final VoidCallback onBack;
  final Future<void> Function() onComplete;

  const CompleteOnboardingScreen({
    super.key,
    required this.profile,
    required this.api,
    required this.onBack,
    required this.onComplete,
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
          const Icon(Icons.check_circle, color: BantTheme.mint, size: 52),
          const SizedBox(height: 12),
          const Text(
            "You're ready.",
            style: TextStyle(
              color: BantTheme.text,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '@${widget.profile.username}',
            style: const TextStyle(
              color: BantTheme.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
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
                        style: const TextStyle(
                          color: BantTheme.blue,
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: const TextStyle(
                          color: BantTheme.text,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: BantTheme.secondary,
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

class HomeShell extends StatefulWidget {
  final AuthService auth;
  final MobileApi api;
  final BantProfile profile;

  const HomeShell({
    super.key,
    required this.auth,
    required this.api,
    required this.profile,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  late final BantAppState appState;

  @override
  void initState() {
    super.initState();
    appState = BantAppState(widget.api);
    appState.load();
  }

  @override
  void dispose() {
    appState.dispose();
    super.dispose();
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
    final pages = [
      BantHomeScreen(
        state: appState,
        profile: widget.profile,
        onOpenRoom: openRoom,
        onStartRoom: startRoom,
        onNotifications: () => setState(() => index = 2),
      ),
      BantRoomsScreen(
        state: appState,
        onOpenRoom: openRoom,
        onStartRoom: startRoom,
      ),
      PeopleScreen(api: widget.api),
      ProfileScreen(auth: widget.auth, profile: widget.profile),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: index,
          children: pages,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 72,
        backgroundColor: BantTheme.surface,
        indicatorColor: const Color(0xFFE8F4FF),
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: BantTheme.blue),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum_rounded, color: BantTheme.blue),
            label: 'Rooms',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded, color: BantTheme.blue),
            label: 'People',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: BantTheme.blue),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class PeopleScreen extends StatelessWidget {
  final MobileApi api;
  const PeopleScreen({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: api.people(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _BrandMark(),
            const SizedBox(height: 22),
            const Text(
              'People',
              style: TextStyle(
                color: BantTheme.text,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            for (final person in snapshot.data!)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(person['display_name']?.toString() ?? 'BANT user'),
                subtitle: Text('@${person['username'] ?? ''}'),
                trailing: TextButton(
                  onPressed: () => api.sendFriendRequest(person['id'].toString()),
                  child: const Text('Add friend'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class ProfileScreen extends StatelessWidget {
  final AuthService auth;
  final BantProfile profile;

  const ProfileScreen({
    super.key,
    required this.auth,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _BrandMark(),
        const SizedBox(height: 24),
        const CircleAvatar(
          radius: 42,
          child: Icon(Icons.person, size: 38),
        ),
        const SizedBox(height: 14),
        Text(
          profile.displayName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          '@${profile.username}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: BantTheme.secondary),
        ),
        const SizedBox(height: 24),
        BantButton(
          label: 'Sign out',
          secondary: true,
          onPressed: auth.signOut,
        ),
      ],
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F4FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            'B',
            style: TextStyle(
              color: BantTheme.blue,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F4FF),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'BANT',
            style: TextStyle(
              color: BantTheme.blue,
              fontWeight: FontWeight.w900,
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
                    style: const TextStyle(color: BantTheme.danger),
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
