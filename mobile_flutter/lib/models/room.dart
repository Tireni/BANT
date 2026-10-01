class BantRoom {
  final String id;
  final String title;
  final String description;
  final String category;
  final String privacy;
  final int participantCount;
  final int speakerCount;
  final int maxParticipants;
  final bool noiseControlEnabled;
  final bool isLive;
  final DateTime createdAt;

  const BantRoom({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.privacy,
    required this.participantCount,
    required this.speakerCount,
    required this.maxParticipants,
    required this.noiseControlEnabled,
    required this.isLive,
    required this.createdAt,
  });

  factory BantRoom.fromJson(Map<String, dynamic> json) => BantRoom(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? 'BANT room',
        description: json['description']?.toString() ?? '',
        category: json['category']?.toString() ?? 'General',
        privacy: json['privacy']?.toString() ?? 'public',
        participantCount: (json['participant_count'] as num?)?.toInt() ?? 0,
        speakerCount: (json['speaker_count'] as num?)?.toInt() ?? 0,
        maxParticipants: (json['max_participants'] as num?)?.toInt() ?? 20,
        noiseControlEnabled: json['noise_control_enabled'] == true,
        isLive: (json['status'] ?? 'live') == 'live',
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}
