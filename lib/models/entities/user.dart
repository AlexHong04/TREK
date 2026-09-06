import 'personal_constraint.dart';

class User {
  final String userId;
  // this authId handles password, JWT tokens and login sessions.
  // acts as a Foreign key that bridges between auth.users with the user table
  // no longer using share preference to store the login session while this authId store the logged in userId
  // the app read this authId to know what userId is logged in and never render the information by other userId
  final String authId;
  final String fullName;
  final String email;
  final String currency;
  final String? profilePicture;
  final int failedLoginAttempts;
  final DateTime? lockedUntil;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? emailVerifiedAt;
  final List<PersonalConstraint> personalConstraints;

  const User({
    required this.userId,
    required this.authId,
    required this.fullName,
    required this.email,
    required this.currency,
    this.profilePicture,
    this.failedLoginAttempts = 0,
    this.lockedUntil,
    required this.createdAt,
    required this.updatedAt,
    this.emailVerifiedAt,
    this.personalConstraints = const [],
  });

  bool get isLocked => lockedUntil != null && lockedUntil!.isAfter(DateTime.now());

  bool get isEmailVerified => emailVerifiedAt != null;

  // get from supabase
  factory User.fromMap(
      Map<String, dynamic> map, {
        List<PersonalConstraint> constraints = const [],
      }) {
    return User(
      userId: map['user_id'] as String,
      authId: map['auth_id'] as String,
      fullName: map['full_name'] as String? ?? '',
      email: map['email'] as String,
      currency: map['currency'] as String? ?? 'MYR',
      profilePicture: map['profile_picture'] as String?,
      failedLoginAttempts: map['failed_login_attempts'] as int? ?? 0,
      lockedUntil: map['locked_until'] != null
          ? DateTime.parse(map['locked_until'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      emailVerifiedAt: map['email_verified_at'] == null
          ? null
          : DateTime.parse(map['email_verified_at'] as String),
      personalConstraints: constraints,
    );
  }

  // send to supabase
  Map<String, dynamic> toInsertMap() {
    return {
      'user_id': userId,
      'auth_id': authId,
      'full_name': fullName,
      'email': email,
      'currency': currency,
      'profile_picture': profilePicture,
      'email_verified_at': emailVerifiedAt?.toUtc().toIso8601String(), // standard utc format
    };
  }

  User copyWith({
    String? fullName,
    String? currency,
    String? profilePicture,
    int? failedLoginAttempts,
    DateTime? lockedUntil,
    bool clearLockedUntil = false,
    DateTime? emailVerifiedAt,
    bool clearEmailVerifiedAt = false,
    List<PersonalConstraint>? personalConstraints,
  }) {
    return User(
      userId: userId,
      authId: authId,
      fullName: fullName ?? this.fullName,
      email: email,
      currency: currency ?? this.currency,
      profilePicture: profilePicture ?? this.profilePicture,
      failedLoginAttempts: failedLoginAttempts ?? this.failedLoginAttempts,
      lockedUntil: clearLockedUntil ? null : (lockedUntil ?? this.lockedUntil),
      createdAt: createdAt,
      updatedAt: updatedAt,
      emailVerifiedAt: clearEmailVerifiedAt
          ? null
          : (emailVerifiedAt ?? this.emailVerifiedAt),
      personalConstraints: personalConstraints ?? this.personalConstraints,
    );
  }
}