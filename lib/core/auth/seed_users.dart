import 'user_role.dart';

class SeedUser {
  const SeedUser({
    required this.email,
    required this.password,
    required this.fullName,
    required this.role,
  });

  final String email;
  final String password;
  final String fullName;
  final UserRole role;
}

abstract final class SeedUsers {
  static const List<SeedUser> all = <SeedUser>[
    SeedUser(
      email: 'admin@growfit.erp',
      password: 'Admin@1234',
      fullName: 'محمد إبراهيم',
      role: UserRole.admin,
    ),
    SeedUser(
      email: 'manager@growfit.erp',
      password: 'Manager@1234',
      fullName: 'أحمد علي',
      role: UserRole.manager,
    ),
    SeedUser(
      email: 'accountant@growfit.erp',
      password: 'Account@1234',
      fullName: 'سارة محمود',
      role: UserRole.accountant,
    ),
    SeedUser(
      email: 'store@growfit.erp',
      password: 'Store@1234',
      fullName: 'خالد حسن',
      role: UserRole.storekeeper,
    ),

    SeedUser(
      email: 'sales@growfit.erp',
      password: 'Sales@1234',
      fullName: 'ياسر سمير',
      role: UserRole.sales,
    ),
  ];

  static SeedUser? byEmail(String email) {
    final String normalized = email.trim().toLowerCase();
    for (final SeedUser user in all) {
      if (user.email == normalized) {
        return user;
      }
    }
    return null;
  }
}
