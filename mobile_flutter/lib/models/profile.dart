class BantProfile {
  final String id;
  final String displayName;
  final String username;
  final String bio;
  final String? avatarUrl;
  final bool onboardingCompleted;
  final int onboardingStep;

  const BantProfile({
    required this.id,
    required this.displayName,
    required this.username,
    required this.bio,
    required this.avatarUrl,
    required this.onboardingCompleted,
    required this.onboardingStep,
  });

  factory BantProfile.fromJson(Map<String, dynamic> json) => BantProfile(
        id: json['id']?.toString() ?? '',
        displayName: json['display_name']?.toString() ?? 'BANT User',
        username: json['username']?.toString() ?? 'bant',
        bio: json['bio']?.toString() ?? '',
        avatarUrl: json['avatar_url']?.toString(),
        onboardingCompleted: json['onboarding_completed'] == true,
        onboardingStep: (json['onboarding_step'] as num?)?.toInt() ?? 1,
      );
}
