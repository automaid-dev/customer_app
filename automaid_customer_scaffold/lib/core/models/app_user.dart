/// The three roles this backend recognises (matches User::CUSTOMER / RIDER / MERCHANT
/// constants and the Spatie roles seeded on the backend).
enum UserRole { customer, rider, merchant, unknown }

UserRole userRoleFromString(String value) {
  switch (value) {
    case 'customer':
      return UserRole.customer;
    case 'rider':
      return UserRole.rider;
    case 'merchant':
      return UserRole.merchant;
    default:
      return UserRole.unknown;
  }
}

/// Mirrors the subset of app/Models/User.php fields the mobile app needs.
/// Extend this as more profile fields are wired up screen by screen.
class AppUser {
  final int id;
  final String name;
  final String email;
  final String? countryCodeMobile;
  final String? mobileNo;
  final String status; // active | inactive | pending | onboarding | rejected
  final bool isActive;
  final String? avatarUrl;
  final List<UserRole> roles;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.status,
    required this.isActive,
    this.countryCodeMobile,
    this.mobileNo,
    this.avatarUrl,
    this.roles = const [],
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final rolesJson = json['roles'] as List<dynamic>? ?? [];
    return AppUser(
      id: json['id'] as int,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      isActive: json['is_active'] == true || json['is_active'] == 1,
      countryCodeMobile: json['country_code_mobile']?.toString(),
      mobileNo: json['mobile_no']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      roles: rolesJson
          .map((r) => userRoleFromString((r as Map<String, dynamic>)['name']?.toString() ?? ''))
          .where((r) => r != UserRole.unknown)
          .toList(),
    );
  }

  bool get isRegistrationComplete => isActive && status != 'pending';
  bool get isRejected => status == 'rejected';

  /// True once OTP is verified but before admin approves the
  /// Rider/Merchant entity — matches the backend setting User::ONBOARDING
  /// right after verifyRegisterRider/Merchant succeeds. The app shows a
  /// "pending approval" screen instead of the normal dashboard for this.
  bool get isPendingApproval => status == 'onboarding';

  /// A user could technically hold multiple roles; the app picks one active
  /// role at a time (persisted via TokenStorage.saveActiveRole) and routes
  /// into that role's module. Falls back to the first role present.
  UserRole get primaryRole => roles.isNotEmpty ? roles.first : UserRole.unknown;
}
