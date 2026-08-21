import 'personal_constraint.dart';

class User {
  final String userId;
  final String fullName;
  final String email;
  final String currency;
  final String? profilePicture;
  final int failedLoginAttempts;
  final DateTime? lockedUntil;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isEmailVerified;
  final List<PersonalConstraint> personalConstraints;

  const User({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.currency,
    this.profilePicture,
    this.failedLoginAttempts = 0,
    this.lockedUntil,
    required this.createdAt,
    required this.updatedAt,
    this.isEmailVerified = false,
    this.personalConstraints = const [],
  });

  bool get isLocked => lockedUntil != null && lockedUntil!.isAfter(DateTime.now());

  // get from supabase
  factory User.fromMap(
      Map<String, dynamic> map, {
        bool isEmailVerified = false,
        List<PersonalConstraint> constraints = const [],
      }) {
    return User(
      userId: map['user_id'] as String,
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
      isEmailVerified: isEmailVerified,
      personalConstraints: constraints,
    );
  }

  // send to supabase
  Map<String, dynamic> toInsertMap() {
    return {
      'user_id': userId,
      'full_name': fullName,
      'email': email,
      'currency': currency,
      'profile_picture': profilePicture,
    };
  }

  User copyWith({
    String? fullName,
    String? currency,
    String? profilePicture,
    int? failedLoginAttempts,
    DateTime? lockedUntil,
    bool clearLockedUntil = false,
    bool? isEmailVerified,
    List<PersonalConstraint>? personalConstraints,
  }) {
    return User(
      userId: userId,
      fullName: fullName ?? this.fullName,
      email: email,
      currency: currency ?? this.currency,
      profilePicture: profilePicture ?? this.profilePicture,
      failedLoginAttempts: failedLoginAttempts ?? this.failedLoginAttempts,
      lockedUntil: clearLockedUntil ? null : (lockedUntil ?? this.lockedUntil),
      createdAt: createdAt,
      updatedAt: updatedAt,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      personalConstraints: personalConstraints ?? this.personalConstraints,
    );
  }
}