import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/mobile_api.dart';

class RoomModerationController extends ChangeNotifier {
  final MobileApi api;
  final SupabaseClient supabase;
  final String roomId;
  final String currentUserId;

  RoomModerationController({
    required this.api,
    required this.supabase,
    required this.roomId,
    required this.currentUserId,
  });

  bool selectionMode = false;
  bool busy = false;
  String? error;
  String? warningMessage;
  final Set<String> selectedUserIds = <String>{};

  RealtimeChannel? _warningChannel;
  Timer? _warningTimer;

  void start() {
    _warningChannel = supabase
        .channel('mobile-room-warnings:$roomId:$currentUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'room_warnings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            final target = row['target_user_id']?.toString();
            if (target != null &&
                target.isNotEmpty &&
                target != currentUserId) {
              return;
            }

            _warningTimer?.cancel();
            warningMessage =
                row['message']?.toString() ?? 'Easy on the noise';
            notifyListeners();

            _warningTimer = Timer(const Duration(milliseconds: 3200), () {
              warningMessage = null;
              notifyListeners();
            });
          },
        )
        .subscribe();
  }

  void toggleSelectionMode() {
    selectionMode = !selectionMode;
    selectedUserIds.clear();
    error = null;
    notifyListeners();
  }

  void toggleUser(String userId, {required String ownerId}) {
    if (!selectionMode || userId == ownerId) return;
    if (!selectedUserIds.add(userId)) {
      selectedUserIds.remove(userId);
    }
    notifyListeners();
  }

  Future<bool> moderate(
    String action, {
    bool all = false,
  }) async {
    if (busy) return false;

    final targets = selectedUserIds.toList();
    if (!all && targets.isEmpty) {
      error = 'Select at least one participant first.';
      notifyListeners();
      return false;
    }

    busy = true;
    error = null;
    notifyListeners();

    try {
      if (all) {
        await api.moderateRoomAll(roomId, action);
      } else {
        await api.moderateRoom(roomId, action, targets);
      }
      selectedUserIds.clear();
      selectionMode = false;
      return true;
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> warn({
    bool all = false,
  }) async {
    if (busy) return false;

    final targets = selectedUserIds.toList();
    if (!all && targets.isEmpty) {
      error = 'Select at least one participant first.';
      notifyListeners();
      return false;
    }

    busy = true;
    error = null;
    notifyListeners();

    try {
      await api.sendNoiseWarning(
        roomId,
        userIds: all ? null : targets,
      );
      selectedUserIds.clear();
      selectionMode = false;
      return true;
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _warningTimer?.cancel();
    final channel = _warningChannel;
    _warningChannel = null;
    if (channel != null) {
      supabase.removeChannel(channel);
    }
    super.dispose();
  }
}
