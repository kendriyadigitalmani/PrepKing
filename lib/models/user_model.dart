// lib/models/user_model.dart
class UserModel {
  final int id;
  final String email;
  final String name;
  final String? mobile;
  final String? profilePicture;
  final int coins;
  final int streak;
  // Progress fields – now properly populated
  final Map<String, double> courseProgress; // courseId → progress (0.0 to 1.0)
  final Set<String> completedContentIds;
  // Settings fields (from backend)
  final bool notificationsEnabled;
  final String theme; // 'light' or 'dark'
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
    this.notificationsEnabled = true,
    this.theme = 'light',
  }) : courseProgress = courseProgress ?? {},
        completedContentIds = Set.from(completedContentIds ?? {});
  // Updated factory to support both plain user API and merged progress API
  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Handle different API variations: sometimes json['data'], sometimes direct map, sometimes list
    final data = json is List
        ? (json.isNotEmpty ? json[0] : {})
        : (json['data'] ?? json);
    // Extract progress if present (this is what your merged provider adds)
    Map<String, dynamic> progressMap = {};
    Set<String> completedIds = {};
    if (data['course_progress'] != null) {
      progressMap = Map<String, dynamic>.from(data['course_progress']);
    }
    if (data['completed_contents'] is List) {
      completedIds = (data['completed_contents'] as List).cast<String>().toSet();
    }
    // Convert progressMap { "5": "0.75" } → { "5": 0.75 }
    final Map<String, double> parsedProgress = {};
    progressMap.forEach((key, value) {
      final double? prog = double.tryParse(value.toString());
      if (prog != null) parsedProgress[key] = prog.clamp(0.0, 1.0);
    });
    // === FIX #1: Support both old and new API field names ===
    final bool notificationsEnabled =
        data['isNotificationEnabled'] == 1 ||
            data['isNotificationEnabled'] == true ||
            data['isNotificationEnabled']?.toString().toLowerCase() == 'true' ||
            data['notifications_enabled'] == 1 ||
            data['notifications_enabled'] == true ||
            data['notifications_enabled']?.toString().toLowerCase() == 'true';

    final String theme = (data['theme']?.toString().toLowerCase() ?? 'light') == 'dark'
        ? 'dark'
        : 'light';
    return UserModel(
      id: data['id'] ?? 0,
      email: data['email'] ?? 'user@example.com',
      name: data['name'] ?? 'PrepKing Warrior',
      mobile: data['mobile'],
      profilePicture: data['profile_picture'],
      coins: int.tryParse(data['coins']?.toString() ?? '0') ?? 0,
      streak: int.tryParse(data['streak']?.toString() ?? '7') ?? 7,
      courseProgress: parsedProgress,
      completedContentIds: completedIds,
      notificationsEnabled: notificationsEnabled,
      theme: theme,
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
    bool? notificationsEnabled,
    String? theme,
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
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      theme: theme ?? this.theme,
    );
  }
}