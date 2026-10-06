import 'user_role.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.isActive,
    required this.createdAt,
    this.lastLoginAt,
  });

  final int id;
  final String email;
  final String fullName;
  final UserRole role;
  final bool isActive;
  final String createdAt;
  final String? lastLoginAt;

  static AuthUser fromRow(Map<String, Object?> row) {
    return AuthUser(
      id: row['id'] as int,
      email: row['email'] as String,
      fullName: row['full_name'] as String,
      role: UserRole.parse(row['role'] as String?),
      isActive: ((row['is_active'] as int?) ?? 1) == 1,
      createdAt: row['created_at'] as String,
      lastLoginAt: row['last_login_at'] as String?,
    );
  }

  String get initials {
    final String trimmed = fullName.trim();
    if (trimmed.isEmpty) {
      return '?';
    }
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }
}
