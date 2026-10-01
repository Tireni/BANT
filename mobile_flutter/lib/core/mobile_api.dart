import 'package:supabase_flutter/supabase_flutter.dart';

class MobileApi {
  final SupabaseClient _supabase;
  MobileApi(this._supabase);

  Future<dynamic> call(String action, [Map<String, dynamic>? payload]) async {
    final response = await _supabase.functions.invoke(
      'mobile-api',
      body: {'action': action, ...?payload},
    );
    if (response.status >= 400) {
      final data = response.data;
      final message = data is Map && data['error'] != null
          ? data['error'].toString()
          : 'BANT mobile request failed';
      throw Exception(message);
    }
    return response.data;
  }

  Future<Map<String, dynamic>> bootstrap() async {
    final data = await call('bootstrap');
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> profile() async {
    final data = await call('profile');
    return Map<String, dynamic>.from(data['profile']);
  }

  Future<Map<String, dynamic>> interests() async {
    final data = await call('interests');
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> saveOnboardingProfile({
    required String displayName,
    required String username,
    String bio = '',
    String? avatarUrl,
  }) async {
    final data = await call('onboarding_profile', {
      'display_name': displayName,
      'username': username,
      'bio': bio,
      'avatar_url': avatarUrl,
    });
    return Map<String, dynamic>.from(data['profile']);
  }

  Future<Map<String, dynamic>> saveOnboardingInterests(List<String> slugs) async {
    final data = await call('onboarding_interests', {'interests': slugs});
    return Map<String, dynamic>.from(data['profile']);
  }

  Future<Map<String, dynamic>> finishOnboarding() async {
    final data = await call('finish_onboarding');
    return Map<String, dynamic>.from(data['profile']);
  }

  Future<List<Map<String, dynamic>>> feed({String? category}) async {
    final data = await call('feed', {'category': category});
    return List<Map<String, dynamic>>.from(data?['rooms'] ?? const []);
  }

  Future<Map<String, dynamic>> room(String roomId) async {
    final data = await call('room', {'room_id': roomId});
    return Map<String, dynamic>.from(data['room']);
  }

  Future<Map<String, dynamic>> createRoom({
    required String title,
    required String description,
    required String category,
    required String privacy,
    int maxParticipants = 20,
    bool noiseControl = false,
  }) async {
    final data = await call('create_room', {
      'title': title,
      'description': description,
      'category': category,
      'privacy': privacy,
      'max_participants': maxParticipants,
      'noise_control_enabled': noiseControl,
    });
    return Map<String, dynamic>.from(data['room']);
  }

  Future<void> joinRoom(String roomId, {String role = 'speaker'}) async {
    await call('join_room', {'room_id': roomId, 'role': role});
  }

  Future<void> leaveRoom(String roomId) async {
    await call('leave_room', {'room_id': roomId});
  }

  Future<void> endRoom(String roomId) async {
    await call('end_room', {'room_id': roomId});
  }

  Future<Map<String, dynamic>> createInvite(String roomId) async {
    final data = await call('create_invite', {'room_id': roomId});
    return Map<String, dynamic>.from(data['invite']);
  }

  Future<List<Map<String, dynamic>>> people() async {
    final data = await call('people');
    return List<Map<String, dynamic>>.from(data?['people'] ?? const []);
  }

  Future<List<Map<String, dynamic>>> notifications() async {
    final data = await call('notifications');
    return List<Map<String, dynamic>>.from(data?['notifications'] ?? const []);
  }

  Future<List<Map<String, dynamic>>> messages(String roomId) async {
    final data = await call('messages', {'room_id': roomId});
    return List<Map<String, dynamic>>.from(data?['messages'] ?? const []);
  }

  Future<void> sendMessage(String roomId, String body) async {
    await call('send_message', {'room_id': roomId, 'body': body});
  }

  Future<void> sendFriendRequest(String userId) async {
    await call('send_friend_request', {'user_id': userId});
  }

  Future<void> acceptFriendRequest(String userId) async {
    await call('accept_friend_request', {'user_id': userId});
  }

  Future<void> declineFriendRequest(String userId) async {
    await call('decline_friend_request', {'user_id': userId});
  }

  Future<void> cancelFriendRequest(String userId) async {
    await call('cancel_friend_request', {'user_id': userId});
  }

  Future<void> blockUser(String userId) async {
    await call('block_user', {'user_id': userId});
  }

  Future<void> unblockUser(String userId) async {
    await call('unblock_user', {'user_id': userId});
  }

  Future<void> updateProfile({
    required String displayName,
    required String username,
    String bio = '',
  }) async {
    await call('update_profile', {
      'display_name': displayName,
      'username': username,
      'bio': bio,
    });
  }

  Future<void> moderateRoom(
    String roomId,
    String action,
    List<String> userIds,
  ) async {
    await call('moderate_room', {
      'room_id': roomId,
      'moderation_action': action,
      'user_ids': userIds,
    });
  }

  Future<void> moderateRoomAll(String roomId, String action) async {
    await call('moderate_room_all', {
      'room_id': roomId,
      'moderation_action': action,
    });
  }

  Future<void> sendNoiseWarning(
    String roomId, {
    List<String>? userIds,
  }) async {
    await call('send_warning', {
      'room_id': roomId,
      'user_ids': userIds,
    });
  }
}
