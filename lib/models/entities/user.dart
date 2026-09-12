import 'personal_constraint.dart';

enum TrekAccountStatus {
  active,
  deletionPending,
  deletionEmailConfirmed,
}

class User {
  final String userId;
  final String authId;
  final String fullName;
  final String email;
  final String currency;
  final String? profilePicture;
  final String? cachedProfilePicturePath;
  final int failedLoginAttempts;
  final DateTime? lockedUntil;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? emailVerifiedAt;
  final DateTime verificationDeadlineAt;
  final TrekAccountStatus accountStatus;
  final DateTime? deletionConfirmedAt;
  final bool hasPasswordSignIn;
  final List<PersonalConstraint> personalConstraints;

  const User({
    required this.userId,
    required this.authId,
    required this.fullName,
    required this.email,
    required this.currency,
    this.profilePicture,
    this.cachedProfilePicturePath,
    this.failedLoginAttempts = 0,
    this.lockedUntil,
    required this.createdAt,
    required this.updatedAt,
    this.emailVerifiedAt,
    required this.verificationDeadlineAt,
    this.accountStatus = TrekAccountStatus.active,
    this.deletionConfirmedAt,
    this.hasPasswordSignIn = false,
    this.personalConstraints = const [],
  });

  bool get isLocked =>
      lockedUntil != null && lockedUntil!.isAfter(DateTime.now());

  bool get isEmailVerified => emailVerifiedAt != null;

  bool get isDeletionPending =>
      accountStatus == TrekAccountStatus.deletionPending;

  bool get isDeletionConfirmed =>
      accountStatus == TrekAccountStatus.deletionEmailConfirmed;

  bool requiresVerificationAt(DateTime now) =>
      !isEmailVerified && !verificationDeadlineAt.isAfter(now.toUtc());

  int verificationDaysRemainingAt(DateTime now) {
    if (isEmailVerified) return 0;
    final remaining = verificationDeadlineAt.difference(now.toUtc());
    if (remaining.isNegative || remaining == Duration.zero) return 0;
    return (remaining.inSeconds / Duration.secondsPerDay).ceil();
  }

  factory User.fromMap(
      Map<String, dynamic> map, {
        List<PersonalConstraint> constraints = const [],
        String? cachedProfilePicturePath,
      }) {
    final createdAt = _date(map['created_at']) ?? DateTime.now().toUtc();
    return User(
      userId: map['user_id']?.toString() ?? '',
      authId: map['auth_id']?.toString() ?? '',
      fullName: map['full_name']?.toString().trim() ?? '',
      email: map['email']?.toString() ?? '',
      currency: (_nonEmpty(map['currency']) ?? 'MYR').toUpperCase(),
      profilePicture: _nonEmpty(map['profile_picture']),
      cachedProfilePicturePath: cachedProfilePicturePath ??
          _nonEmpty(map['cached_profile_picture_path']),
      failedLoginAttempts:
      (map['failed_login_attempts'] as num?)?.toInt() ?? 0,
      lockedUntil: _date(map['locked_until']),
      createdAt: createdAt,
      updatedAt: _date(map['updated_at']) ?? createdAt,
      emailVerifiedAt: _date(map['email_verified_at']),
      verificationDeadlineAt: _date(map['verification_deadline_at']) ??
          createdAt.add(const Duration(days: 7)),
      accountStatus: _accountStatus(map['account_status']),
      deletionConfirmedAt: _date(map['deletion_confirmed_at']),
      hasPasswordSignIn: map['has_password_sign_in'] == true,
      personalConstraints: constraints,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'user_id': userId,
      'auth_id': authId,
      // Keep the stored value truthful. "Trekker" is a presentation fallback,
      // not a name supplied by the tourist.
      'full_name': fullName.trim(),
      'email': email.trim(),
      'currency': currency.trim().toUpperCase(),
      'profile_picture': profilePicture,
    };
  }

  Map<String, dynamic> toCacheMap() {
    return {
      'user_id': userId,
      'auth_id': authId,
      'full_name': fullName,
      'email': email,
      'currency': currency,
      'profile_picture': profilePicture,
      'cached_profile_picture_path': cachedProfilePicturePath,
      'failed_login_attempts': failedLoginAttempts,
      'locked_until': lockedUntil?.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'email_verified_at': emailVerifiedAt?.toUtc().toIso8601String(),
      'verification_deadline_at':
      verificationDeadlineAt.toUtc().toIso8601String(),
      'account_status': accountStatus.name,
      'deletion_confirmed_at':
      deletionConfirmedAt?.toUtc().toIso8601String(),
      'has_password_sign_in': hasPasswordSignIn,
      'personal_constraints': personalConstraints
          .map(
            (item) => {
          'constraint_id': item.constraintId,
          'category': item.category,
          'constraint_name': item.constraintName,
        },
      )
          .toList(growable: false),
    };
  }

  factory User.fromCacheMap(Map<String, dynamic> map) {
    final rawConstraints = map['personal_constraints'];
    final constraints = rawConstraints is List
        ? rawConstraints
        .whereType<Map>()
        .map(
          (item) => PersonalConstraint.fromMap(
        Map<String, dynamic>.from(item),
      ),
    )
        .toList(growable: false)
        : const <PersonalConstraint>[];
    return User.fromMap(map, constraints: constraints);
  }

  User copyWith({
    String? fullName,
    String? email,
    String? currency,
    String? profilePicture,
    String? cachedProfilePicturePath,
    int? failedLoginAttempts,
    DateTime? lockedUntil,
    bool clearLockedUntil = false,
    DateTime? emailVerifiedAt,
    bool clearEmailVerifiedAt = false,
    DateTime? verificationDeadlineAt,
    TrekAccountStatus? accountStatus,
    DateTime? deletionConfirmedAt,
    bool clearDeletionConfirmedAt = false,
    bool? hasPasswordSignIn,
    List<PersonalConstraint>? personalConstraints,
    bool clearProfilePicture = false,
    bool clearCachedProfilePicture = false,
  }) {
    return User(
      userId: userId,
      authId: authId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      currency: currency ?? this.currency,
      profilePicture:
      clearProfilePicture ? null : (profilePicture ?? this.profilePicture),
      cachedProfilePicturePath: clearCachedProfilePicture
          ? null
          : (cachedProfilePicturePath ?? this.cachedProfilePicturePath),
      failedLoginAttempts: failedLoginAttempts ?? this.failedLoginAttempts,
      lockedUntil: clearLockedUntil ? null : (lockedUntil ?? this.lockedUntil),
      createdAt: createdAt,
      updatedAt: updatedAt,
      emailVerifiedAt: clearEmailVerifiedAt
          ? null
          : (emailVerifiedAt ?? this.emailVerifiedAt),
      verificationDeadlineAt:
      verificationDeadlineAt ?? this.verificationDeadlineAt,
      accountStatus: accountStatus ?? this.accountStatus,
      deletionConfirmedAt: clearDeletionConfirmedAt
          ? null
          : (deletionConfirmedAt ?? this.deletionConfirmedAt),
      hasPasswordSignIn: hasPasswordSignIn ?? this.hasPasswordSignIn,
      personalConstraints: personalConstraints ?? this.personalConstraints,
    );
  }

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toUtc();
  }

  static String? _nonEmpty(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static TrekAccountStatus _accountStatus(Object? value) {
    switch (value?.toString()) {
      case 'deletion_pending':
      case 'deletionPending':
        return TrekAccountStatus.deletionPending;
      case 'deletion_email_confirmed':
      case 'deletionEmailConfirmed':
        return TrekAccountStatus.deletionEmailConfirmed;
      default:
        return TrekAccountStatus.active;
    }
  }
}
