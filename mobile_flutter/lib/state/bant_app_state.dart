import 'package:flutter/foundation.dart';

import '../core/mobile_api.dart';
import '../models/room.dart';

class BantAppState extends ChangeNotifier {
  final MobileApi api;

  BantAppState(this.api);

  bool loading = false;
  String? error;
  List<BantRoom> rooms = const [];
  List<Map<String, dynamic>> notifications = const [];

  int get unreadNotifications =>
      notifications.where((item) => item['read_at'] == null).length;

  Future<void> load() async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        api.feed(),
        api.notifications(),
      ]);

      rooms = (results[0] as List<Map<String, dynamic>>)
          .map(BantRoom.fromJson)
          .toList();
      notifications =
          List<Map<String, dynamic>>.from(results[1] as List);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshRooms() async {
    try {
      final rows = await api.feed();
      rooms = rows.map(BantRoom.fromJson).toList();
      error = null;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  List<BantRoom> publicRooms({
    String category = 'Feed',
    String query = '',
    String filter = 'Live',
  }) {
    final normalized = query.trim().toLowerCase();

    final visible = rooms.where((room) {
      if (room.privacy == 'private') return false;
      if (category != 'Feed' && room.category != category) return false;
      if (normalized.isEmpty) return true;

      return ('${room.title} ${room.description}')
          .toLowerCase()
          .contains(normalized);
    }).toList();

    if (filter == 'Popular') {
      visible.sort(
        (a, b) => b.participantCount.compareTo(a.participantCount),
      );
    } else if (filter == 'New') {
      visible.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      visible.removeWhere((room) => !room.isLive);
    }

    return visible;
  }
}
