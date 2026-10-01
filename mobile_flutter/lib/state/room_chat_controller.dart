import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/mobile_api.dart';

class RoomChatController extends ChangeNotifier {
  final MobileApi api;
  final SupabaseClient supabase;
  final String roomId;
  final String currentUserId;

  RoomChatController({
    required this.api,
    required this.supabase,
    required this.roomId,
    required this.currentUserId,
  });

  List<Map<String, dynamic>> messages = const [];
  bool loading = true;
  bool sending = false;
  String? error;
  RealtimeChannel? _channel;
  bool _started = false;
  bool _disposed = false;

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;

    await reload();
    if (_disposed) return;

    _channel = supabase
        .channel('mobile-room-messages:$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'room_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) {
            _handleInsert(payload.newRecord);
          },
        )
        .subscribe();
  }

  Future<void> reload() async {
    if (_disposed) return;
    loading = true;
    error = null;
    notifyListeners();

    try {
      messages = await api.messages(roomId);
      if (messages.length > 100) {
        messages = messages.sublist(messages.length - 100);
      }
    } catch (e) {
      error = _cleanError(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> send(String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      error = 'Type a message first.';
      notifyListeners();
      return false;
    }
    if (trimmed.length > 500) {
      error = 'Keep messages under 500 characters.';
      notifyListeners();
      return false;
    }
    if (sending) return false;

    sending = true;
    error = null;
    notifyListeners();

    try {
      await api.sendMessage(roomId, trimmed);
      return true;
    } catch (e) {
      error = _cleanError(e);
      return false;
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  Future<void> _handleInsert(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (_disposed || id == null || id.isEmpty) return;
    if (messages.any((item) => item['id']?.toString() == id)) return;

    var senderName = 'BANT user';
    final senderId = row['sender_id']?.toString() ?? '';

    if (senderId == currentUserId) {
      senderName = 'You';
    } else if (senderId.isNotEmpty) {
      try {
        final profile = await supabase
            .from('profiles')
            .select('display_name,username')
            .eq('id', senderId)
            .maybeSingle();
        if (profile != null) {
          senderName = (profile['display_name'] ??
                  profile['username'] ??
                  'BANT user')
              .toString();
        }
      } catch (_) {}
    }

    final next = <String, dynamic>{
      'id': id,
      'room_id': row['room_id']?.toString() ?? roomId,
      'sender_id': senderId,
      'sender_name': senderName,
      'body': row['body']?.toString() ?? '',
      'created_at': row['created_at']?.toString() ?? '',
    };

    final updated = [...messages, next];
    messages = updated.length > 100
        ? updated.sublist(updated.length - 100)
        : updated;
    if (_disposed) return;
    error = null;
    notifyListeners();
  }

  String _cleanError(Object e) =>
      e.toString().replaceFirst('Exception: ', '');

  @override
  void dispose() {
    _disposed = true;
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      supabase.removeChannel(channel);
    }
    super.dispose();
  }
}
