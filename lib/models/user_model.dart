// lib/models/user_model.dart ← UPDATED BUT SAFE
class UserModel {
  final int id;
  final String email;
  final String name;
  final String? mobile;
  final String? profilePicture;
  final int coins;
  final int streak;

  // ← NEW: Progress tracking (computed at runtime)
  final Map<String, double> courseProgress;        // courseId → 0.0 to 1.0
  final Set<String> completedContentIds;           // content_id strings

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.mobile,
    this.profilePicture,
    this.coins = 0,
    this.streak = 7,
    Map<String, double>? courseProgress,
    Set<String>? completedContentIds,
  })  : courseProgress = courseProgress ?? {},
        completedContentIds = completedContentIds ?? {};

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final data = json is List ? (json.isNotEmpty ? json[0] : {}) : (json['data'] ?? json);
    return UserModel(
      id: data['id'] ?? 0,
      email: data['email'] ?? 'user@example.com',
      name: data['name'] ?? 'PrepKing Warrior',
      mobile: data['mobile'],
      profilePicture: data['profile_picture'],
      coins: int.tryParse(data['coins']?.toString() ?? '0') ?? 0,
      streak: int.tryParse(data['streak']?.toString() ?? '7') ?? 7,
    );
  }

  UserModel copyWith({
    int? id,
    String? email,
    String? name,
    String? mobile,
    String? profilePicture,
    int? coins,
    int? streak,
    Map<String, double>? courseProgress,
    Set<String>? completedContentIds,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      profilePicture: profilePicture ?? this.profilePicture,
      coins: coins ?? this.coins,
      streak: streak ?? this.streak,
      courseProgress: courseProgress ?? this.courseProgress,
      completedContentIds: completedContentIds ?? this.completedContentIds,
    );
  }
}