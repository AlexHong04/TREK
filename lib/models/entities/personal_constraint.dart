class PersonalConstraint {
  final String constraintId;
  final String category;
  final String constraintName;

  const PersonalConstraint({
    required this.constraintId,
    required this.category,
    required this.constraintName,
  });

  // get from supabase
  factory PersonalConstraint.fromMap(Map<String, dynamic> map) {
    return PersonalConstraint(
      constraintId: map['constraint_id'] as String,
      category: map['category'] as String,
      constraintName: map['constraint_name'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PersonalConstraint && other.constraintId == constraintId;

  @override
  int get hashCode => constraintId.hashCode;
}