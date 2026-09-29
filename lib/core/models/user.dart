/// Auth user profile DTO.
library;

class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    this.nickname,
    this.avatar,
    this.role,
    this.enabled,
  });

  final int id;
  final String username;
  final String? nickname;
  final String? avatar;
  final String? role;
  final bool? enabled;

  bool get isAdmin => role?.toUpperCase() == 'ADMIN';
  String get roleText => isAdmin ? '管理员' : '普通用户';
  String get title =>
      (nickname != null && nickname!.isNotEmpty) ? nickname! : username;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: (json['id'] as num?)?.toInt() ?? 0,
    username: json['username'] as String? ?? '',
    nickname: json['nickname'] as String?,
    avatar: json['avatar'] as String?,
    role: json['role'] as String?,
    enabled: json['enabled'] as bool?,
  );
}
