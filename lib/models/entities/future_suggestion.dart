class FutureSuggestion {
  final String? suggestionId;
  final double suggestedAmount;
  final String activityCategory;
  final DateTime? createdAt;
  final String tripId;

  const FutureSuggestion({
    this.suggestionId,
    required this.suggestedAmount,
    required this.activityCategory,
    this.createdAt,
    required this.tripId,
  });

  factory FutureSuggestion.fromJson(Map<String, dynamic> json) {
    return FutureSuggestion(
      suggestionId: json['suggestion_id'] as String?,
      suggestedAmount: (json['suggested_amount'] as num).toDouble(),
      activityCategory: json['activity_category'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      tripId: json['trip_id'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (suggestionId != null) 'suggestion_id': suggestionId,
      'suggested_amount': suggestedAmount,
      'activity_category': activityCategory,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'trip_id': tripId,
    };
  }

  FutureSuggestion copyWith({
    String? suggestionId,
    double? suggestedAmount,
    String? activityCategory,
    DateTime? createdAt,
    String? tripId,
  }) {
    return FutureSuggestion(
      suggestionId: suggestionId ?? this.suggestionId,
      suggestedAmount: suggestedAmount ?? this.suggestedAmount,
      activityCategory: activityCategory ?? this.activityCategory,
      createdAt: createdAt ?? this.createdAt,
      tripId: tripId ?? this.tripId,
    );
  }
}
