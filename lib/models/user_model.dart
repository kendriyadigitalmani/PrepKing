// lib/models/user_model.dart

class UserModel {
  final int id;
  final String email;
  final String name;
  final String? mobile;
  final String? profilePicture;
  final int coins;
  final int streak;

  // Progress fields – populated dynamically via userWithProgressProvider
  final Map<String, double> courseProgress; // courseId → progress (0.0 to 1.0)
  final Set<String> completedContentIds;

  // User settings
  final bool notificationsEnabled;
  final String theme; // 'light' or 'dark'

  // Language and Exam preferences
  final int? languageId;
  final List<int> examIds;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.mobile,
    this.profilePicture,
    this.coins = 0,
    this.streak = 0,
    Map<String, double>? courseProgress,
    Set<String>? completedContentIds,
    this.notificationsEnabled = true,
    this.theme = 'light',
    this.languageId,
    List<int>? examIds,
  })  : courseProgress = courseProgress ?? {},
        completedContentIds = Set<String>.from(completedContentIds ?? {}),
        examIds = List<int>.unmodifiable(examIds ?? []);

  /// Factory constructor – handles multiple API response formats safely
  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Normalize input: handle {success: true, data: {...}}, direct map, or list
    Map<String, dynamic> data = {};

    if (json.containsKey('data') && json['data'] is Map<String, dynamic>) {
      data = json['data'];
    } else if (json.containsKey('id')) {
      // Direct response (e.g., after login or create)
      data = Map<String, dynamic>.from(json);
    } else if (json is List && json.isNotEmpty) {
      data = Map<String, dynamic>.from(json[0]);
    } else {
      throw Exception('Invalid user JSON: no valid data found');
    }

    if (data['id'] == null) {
      throw Exception('User JSON missing required "id" field');
    }

    // Safely parse basic fields
    final int id = int.parse(data['id'].toString());
    final String email = data['email']?.toString().trim() ?? '';
    final String name = data['name']?.toString().trim() ?? 'User';

    // Optional fields
    final String? mobile = data['mobile']?.toString().trim();
    final String? profilePicture = data['profile_picture']?.toString().trim();

    // Coins & streak
    final int coins = int.tryParse(data['coins']?.toString() ?? '0') ?? 0;
    final int streak = int.tryParse(data['streak']?.toString() ?? '0') ?? 0;

    // Notifications (support multiple possible field names)
    final bool notificationsEnabled = [
      data['isNotificationEnabled'],
      data['notifications_enabled'],
      data['notification_enabled'],
    ].any((v) => v == true || v == 1 || v?.toString().toLowerCase() == 'true');

    // Theme
    final String theme = (data['theme']?.toString().toLowerCase() == 'dark') ? 'dark' : 'light';

    // Language ID
    final int? languageId = data['language_id'] is int
        ? data['language_id']
        : int.tryParse(data['language_id']?.toString() ?? '');

    // Exam IDs – support list or comma-separated string
    final List<int> examIds = [];
    final examRaw = data['exam_ids'];
    if (examRaw != null) {
      if (examRaw is List) {
        examIds.addAll(
          examRaw.map((e) => int.tryParse(e.toString()) ?? 0).where((id) => id > 0),
        );
      } else if (examRaw is String && examRaw.trim().isNotEmpty) {
        examIds.addAll(
          examRaw
              .split(',')
              .map((s) => int.tryParse(s.trim()) ?? 0)
              .where((id) => id > 0),
        );
      }
    }

    // Note: courseProgress and completedContentIds are NOT parsed here
    // because they are injected separately via userWithProgressProvider.copyWith()
    return UserModel(
      id: id,
      email: email,
      name: name,
      mobile: mobile,
      profilePicture: profilePicture,
      coins: coins,
      streak: streak,
      notificationsEnabled: notificationsEnabled,
      theme: theme,
      languageId: languageId,
      examIds: examIds,
    );
  }

  /// CopyWith – essential for merging progress data
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
    int? languageId,
    List<int>? examIds,
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
      languageId: languageId ?? this.languageId,
      examIds: examIds ?? this.examIds,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is UserModel &&
              runtimeType == other.runtimeType &&
              id == other.id &&
              email == other.email &&
              name == other.name;

  @override
  int get hashCode => Object.hash(id, email, name);
}