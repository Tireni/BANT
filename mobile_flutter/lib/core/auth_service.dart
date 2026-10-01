import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient supabase;
  AuthService(this.supabase);

  Session? get session => supabase.auth.currentSession;
  Stream<AuthState> get changes => supabase.auth.onAuthStateChange;

  Future<void> signInWithGoogle() async {
    await supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'bant://auth-callback',
    );
  }

  Future<void> signOut() => supabase.auth.signOut();
}
