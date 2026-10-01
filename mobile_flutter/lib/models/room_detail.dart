class BantParticipant {
  final String id;
  final String displayName;
  final String username;
  final String? avatarUrl;
  final String role;
  final bool muted;
  final DateTime? joinedAt;

  const BantParticipant({
    required this.id,
    required this.displayName,
    required this.username,
    required this.avatarUrl,
    required this.role,
    required this.muted,
    required this.joinedAt,
  });

  factory BantParticipant.fromMembership(Map<String, dynamic> json) {
    final rawProfile = json['profiles'];
    final profile = rawProfile is List
        ? (rawProfile.isNotEmpty
            ? Map<String, dynamic>.from(rawProfile.first as Map)
            : <String, dynamic>{})
        : rawProfile is Map
            ? Map<String, dynamic>.from(rawProfile)
            : <String, dynamic>{};

    return BantParticipant(
      id: (json['user_id'] ?? profile['id'] ?? '').toString(),
      displayName:
          (profile['display_name'] ?? profile['username'] ?? 'BANT user')
              .toString(),
      username: (profile['username'] ?? '').toString(),
      avatarUrl: profile['avatar_url']?.toString(),
      role: (json['role'] ?? 'listener').toString(),
      muted: json['is_muted'] == true,
      joinedAt: DateTime.tryParse(json['joined_at']?.toString() ?? ''),
    );
  }
}

class BantRoomDetail {
  final String id;
  final String title;
  final String description;
  final String category;
  final String privacy;
  final String status;
  final String ownerId;
  final int maxParticipants;
  final bool noiseControlEnabled;
  final List<BantParticipant> participants;

  const BantRoomDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.privacy,
    required this.status,
    required this.ownerId,
    required this.maxParticipants,
    required this.noiseControlEnabled,
    required this.participants,
  });

  factory BantRoomDetail.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['room_members'];
    final members = rawMembers is List
        ? rawMembers
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .where((row) => row['left_at'] == null)
            .map(BantParticipant.fromMembership)
            .toList()
        : <BantParticipant>[];

    members.sort((a, b) {
      const priority = {'owner': 0, 'host': 0, 'speaker': 1, 'listener': 2};
      final roleCompare =
          (priority[a.role] ?? 9).compareTo(priority[b.role] ?? 9);
      if (roleCompare != 0) return roleCompare;
      return a.displayName.compareTo(b.displayName);
    });

    return BantRoomDetail(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'BANT room',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      privacy: json['privacy']?.toString() ?? 'public',
      status: json['status']?.toString() ?? 'live',
      ownerId: (json['owner_id'] ?? json['host_id'] ?? '').toString(),
      maxParticipants: (json['max_participants'] as num?)?.toInt() ?? 20,
      noiseControlEnabled: json['noise_control_enabled'] == true,
      participants: members,
    );
  }

  int get participantCount => participants.length;

  int get speakerCount => participants
      .where((item) =>
          item.role == 'owner' ||
          item.role == 'host' ||
          item.role == 'speaker')
      .length;

  BantParticipant? participantFor(String userId) {
    for (final participant in participants) {
      if (participant.id == userId) return participant;
    }
    return null;
  }
}
