import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/auth_service.dart';
import 'core/config.dart';
import 'core/mobile_api.dart';
import 'core/voice_service.dart';
import 'models/room.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!BantConfig.valid) {
    runApp(const MaterialApp(home: _MissingConfigScreen()));
    return;
  }
  await Supabase.initialize(
    url: BantConfig.supabaseUrl,
    anonKey: BantConfig.supabaseAnonKey,
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
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0E96F6),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
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

  @override
  void initState() {
    super.initState();
    auth = AuthService(Supabase.instance.client);
    auth.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return auth.session == null
        ? SignInScreen(auth: auth)
        : HomeShell(auth: auth);
  }
}

class SignInScreen extends StatelessWidget {
  final AuthService auth;
  const SignInScreen({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Welcome to BANT',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text('Find your people. Join the conversation.'),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: auth.signInWithGoogle,
                    child: const Text('Continue with Google'),
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

class HomeShell extends StatefulWidget {
  final AuthService auth;
  const HomeShell({super.key, required this.auth});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  late final MobileApi api;

  @override
  void initState() {
    super.initState();
    api = MobileApi(Supabase.instance.client);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      FeedScreen(api: api, title: 'For You'),
      FeedScreen(api: api, title: 'Live Rooms'),
      PeopleScreen(api: api),
      ProfileScreen(auth: widget.auth),
    ];

    return Scaffold(
      body: SafeArea(child: pages[index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dynamic_feed), label: 'Feed'),
          NavigationDestination(icon: Icon(Icons.graphic_eq), label: 'Rooms'),
          NavigationDestination(icon: Icon(Icons.people), label: 'People'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      floatingActionButton: index < 2
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await api.createRoom(
                  title: 'New BANT room',
                  description: 'A fresh BANT room.',
                  category: 'General',
                  privacy: 'public',
                );
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RoomScreen(
                      api: api,
                      room: BantRoom.fromJson(created),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Create room'),
            )
          : null,
    );
  }
}

class FeedScreen extends StatefulWidget {
  final MobileApi api;
  final String title;
  const FeedScreen({super.key, required this.api, required this.title});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = widget.api.feed();
  }

  Future<void> refresh() async {
    setState(() => future = widget.api.feed());
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: refresh,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rooms = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                widget.title,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              for (final raw in rooms)
                Card(
                  child: ListTile(
                    title: Text(raw['title']?.toString() ?? 'BANT room'),
                    subtitle: Text(
                      '${raw['category'] ?? 'General'} · ${raw['participant_count'] ?? 0}/${raw['max_participants'] ?? 20}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RoomScreen(
                            api: widget.api,
                            room: BantRoom.fromJson(raw),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
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
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'People',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            for (final person in snapshot.data!)
              ListTile(
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
  const ProfileScreen({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    final user = auth.session?.user;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Profile',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        Text(user?.email ?? 'BANT user'),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: auth.signOut,
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}

class RoomScreen extends StatefulWidget {
  final MobileApi api;
  final BantRoom room;
  const RoomScreen({super.key, required this.api, required this.room});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late final VoiceService voice;
  final message = TextEditingController();
  bool connected = false;
  bool muted = false;
  bool busy = true;
  List<Map<String, dynamic>> messages = const [];

  @override
  void initState() {
    super.initState();
    voice = VoiceService(Supabase.instance.client);
    join();
  }

  Future<void> join() async {
    try {
      await widget.api.joinRoom(widget.room.id);
      await voice.connect(widget.room.id);
      messages = await widget.api.messages(widget.room.id);
      if (mounted) {
        setState(() {
          connected = voice.connected;
          busy = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  Future<void> leave() async {
    await voice.disconnect();
    await widget.api.leaveRoom(widget.room.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    message.dispose();
    voice.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room.title),
        leading: IconButton(
          onPressed: leave,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Column(
        children: [
          ListTile(
            leading: Icon(
              muted ? Icons.mic_off : Icons.mic,
              color: connected ? Colors.green : Colors.grey,
            ),
            title: Text(
              busy
                  ? 'Connecting...'
                  : connected
                      ? 'Voice connected'
                      : 'Voice not connected',
            ),
            subtitle: Text(widget.room.description),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final item in messages)
                  ListTile(
                    title: Text(
                      item['sender_name']?.toString() ?? 'BANT user',
                    ),
                    subtitle: Text(item['body']?.toString() ?? ''),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () async {
                      muted = !muted;
                      await voice.setMuted(muted);
                      if (mounted) setState(() {});
                    },
                    icon: Icon(muted ? Icons.mic_off : Icons.mic),
                  ),
                  Expanded(
                    child: TextField(
                      controller: message,
                      decoration: const InputDecoration(
                        hintText: 'Message the room',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      final body = message.text.trim();
                      if (body.isEmpty) return;
                      await widget.api.sendMessage(widget.room.id, body);
                      message.clear();
                      messages = await widget.api.messages(widget.room.id);
                      if (mounted) setState(() {});
                    },
                    icon: const Icon(Icons.send),
                  ),
                  IconButton(
                    onPressed: () async {
                      final invite =
                          await widget.api.createInvite(widget.room.id);
                      final token =
                          invite['invite_token']?.toString() ?? '';
                      final link =
                          'https://bant-demo.vercel.app/r/$token';
                      await Share.share(
                        '${widget.room.title}\nJoin the conversation on BANT: $link',
                      );
                    },
                    icon: const Icon(Icons.share),
                  ),
                ],
              ),
            ),
          ),
        ],
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
            'BANT mobile needs SUPABASE_URL and SUPABASE_ANON_KEY dart defines.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
