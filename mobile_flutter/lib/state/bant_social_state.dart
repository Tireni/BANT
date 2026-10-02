import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/mobile_api.dart';

enum BantFriendshipState {
  none,
  pendingSent,
  pendingReceived,
  friends,
}

class BantSocialPerson {
  final String id;
  final String displayName;
  final String username;
  final String bio;
  final String? avatarUrl;

  const BantSocialPerson({
    required this.id,
    required this.displayName,
    required this.username,
    required this.bio,
    required this.avatarUrl,
  });

  factory BantSocialPerson.fromJson(Map<String, dynamic> json) {
    return BantSocialPerson(
      id: json['id']?.toString() ?? '',
      displayName:
          (json['display_name'] ?? json['username'] ?? 'BANT user').toString(),
      username: json['username']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString(),
    );
  }
}

class BantFriendRequest {
  final String id;
  final String senderId;
  final String receiverId;

  const BantFriendRequest({
    required this.id,
    required this.senderId,
    required this.receiverId,
  });

  factory BantFriendRequest.fromJson(Map<String, dynamic> json) {
    return BantFriendRequest(
      id: json['id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      receiverId: json['receiver_id']?.toString() ?? '',
    );
  }
}

class BantSocialState extends ChangeNotifier {
  final MobileApi api;
  final SupabaseClient supabase;
  final String currentUserId;

  BantSocialState({
    required this.api,
    required this.supabase,
    required this.currentUserId,
  });

  List<BantSocialPerson> people = const [];
  List<BantSocialPerson> blockedPeople = const [];
  Set<String> friendIds = <String>{};
  List<BantFriendRequest> incoming = const [];
  List<BantFriendRequest> outgoing = const [];
  bool loading = true;
  String? error;

  RealtimeChannel? _requestsChannel;
  RealtimeChannel? _friendshipsChannel;
  bool _started = false;
  bool _disposed = false;

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    await load();
    if (_disposed) return;

    _requestsChannel = supabase
        .channel('mobile-social-requests:$currentUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friend_requests',
          callback: (_) => load(),
        )
        .subscribe();

    _friendshipsChannel = supabase
        .channel('mobile-social-friendships:$currentUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friendships',
          callback: (_) => load(),
        )
        .subscribe();
  }

  Future<void> load() async {
    if (_disposed) return;

    loading = true;
    error = null;
    notifyListeners();

    try {
      final data = await api.peopleState();

      final rawPeople =
          List<Map<String, dynamic>>.from(data['people'] ?? const []);
      final rawFriendIds = List<dynamic>.from(data['friend_ids'] ?? const []);
      final rawBlocked = List<Map<String, dynamic>>.from(
        data['blocked_people'] ?? const [],
      );
      final rawIncoming = List<Map<String, dynamic>>.from(
        data['incoming_requests'] ?? const [],
      );
      final rawOutgoing = List<Map<String, dynamic>>.from(
        data['outgoing_requests'] ?? const [],
      );

      people = rawPeople.map(BantSocialPerson.fromJson).toList();
      blockedPeople = rawBlocked.map(BantSocialPerson.fromJson).toList();
      friendIds = rawFriendIds.map((value) => value.toString()).toSet();
      incoming = rawIncoming.map(BantFriendRequest.fromJson).toList();
      outgoing = rawOutgoing.map(BantFriendRequest.fromJson).toList();
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  BantFriendshipState stateFor(String userId) {
    if (friendIds.contains(userId)) return BantFriendshipState.friends;
    if (incoming.any((request) => request.senderId == userId)) {
      return BantFriendshipState.pendingReceived;
    }
    if (outgoing.any((request) => request.receiverId == userId)) {
      return BantFriendshipState.pendingSent;
    }
    return BantFriendshipState.none;
  }

  BantFriendRequest? incomingFrom(String userId) {
    for (final request in incoming) {
      if (request.senderId == userId) return request;
    }
    return null;
  }

  BantFriendRequest? outgoingTo(String userId) {
    for (final request in outgoing) {
      if (request.receiverId == userId) return request;
    }
    return null;
  }

  Future<void> primaryAction(String userId) async {
    final state = stateFor(userId);
    error = null;
    notifyListeners();

    try {
      switch (state) {
        case BantFriendshipState.none:
          await api.sendFriendRequest(userId);
          break;
        case BantFriendshipState.pendingSent:
          final request = outgoingTo(userId);
          if (request == null) throw Exception('Friend request not found');
          await api.cancelFriendRequest(request.id);
          break;
        case BantFriendshipState.pendingReceived:
          final request = incomingFrom(userId);
          if (request == null) throw Exception('Friend request not found');
          await api.acceptFriendRequest(request.id);
          break;
        case BantFriendshipState.friends:
          return;
      }
      await load();
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
      await load();
    }
  }

  Future<void> declineIncoming(String userId) async {
    final request = incomingFrom(userId);
    if (request == null) return;

    try {
      await api.declineFriendRequest(request.id);
      await load();
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
      await load();
    }
  }

  Future<bool> blockUser(String userId) async {
    try {
      await api.blockUser(userId);
      await load();
      return true;
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> unblockUser(String userId) async {
    try {
      await api.unblockUser(userId);
      await load();
      return true;
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  String actionLabel(String userId) {
    switch (stateFor(userId)) {
      case BantFriendshipState.friends:
        return 'Friends';
      case BantFriendshipState.pendingReceived:
        return 'Accept';
      case BantFriendshipState.pendingSent:
        return 'Request sent';
      case BantFriendshipState.none:
        return 'Add friend';
    }
  }

  @override
  void dispose() {
    _disposed = true;
    if (_requestsChannel != null) {
      supabase.removeChannel(_requestsChannel!);
    }
    if (_friendshipsChannel != null) {
      supabase.removeChannel(_friendshipsChannel!);
    }
    super.dispose();
  }
}
