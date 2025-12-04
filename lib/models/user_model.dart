// lib/models/user_model.dart   ← FINAL WORKING VERSION (NO FREEZED)
class UserModel {
  final int id;
  final String email;
  final String name;
  final String? mobile;
  final String? profilePicture;
  final int coins;
  final int streak;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.mobile,
    this.profilePicture,
    this.coins = 0,
    this.streak = 7,
  });

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
}

// Dummy models — will be replaced with real ones later
class UserProgressModel {
  final String? courseTitle;
  final double? progressPercentage;

  UserProgressModel({this.courseTitle, this.progressPercentage});
}

class CourseQuizModel {
  final int? id;
  final String? title;

  CourseQuizModel({this.id, this.title});
}