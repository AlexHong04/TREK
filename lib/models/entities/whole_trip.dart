class WholeTrip {
  final String? tripId;
  final String? userId;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final double totalBudget;
  final double? remainingBalance;
  final bool? isCriticalBudget;
  final String status;
  final String travelPreference;
  final DateTime? createdAt;
  final String? imgUrl;

  WholeTrip({
    this.tripId,
    this.userId,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.totalBudget,
    this.remainingBalance,
    this.isCriticalBudget,
    required this.status,
    required this.travelPreference,
    this.createdAt,
    this.imgUrl,
  });

  // dynamically change the status of itinerary
  String get computedStatus {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tripStart = DateTime(startDate.year, startDate.month, startDate.day);
    final tripEnd = DateTime(endDate.year, endDate.month, endDate.day);

    final s = status.toLowerCase();
    if(s == 'terminated') {
      return 'terminated';
    } else if(s == 'deleted') {
      // Soft-deleted plans keep their row for recovery, but they are not a real
      // trip state: returning 'deleted' keeps them out of every status-based
      // list (pending/ongoing/completed/terminated) instead of being mistaken
      // for a completed trip once their end date passes.
      return 'deleted';
    } else if(s == 'completed' || today.isAfter(tripEnd)) {
      return 'completed';
    } else if(today.isBefore(tripStart)) {
      return 'pending';
    } else {
      return 'ongoing';
    }
  }

  WholeTrip copyWith({
    String? tripId,
    String? userId,
    String? destination,
    DateTime? startDate,
    DateTime? endDate,
    double? totalBudget,
    double? remainingBalance,
    bool? isCriticalBudget,
    String? status,
    String? travelPreference,
    DateTime? createdAt,
    String? imgUrl,
  }) {
    return WholeTrip(
      tripId: tripId ?? this.tripId,
      userId: userId ?? this.userId,
      destination: destination ?? this.destination,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      totalBudget: totalBudget ?? this.totalBudget,
      remainingBalance: remainingBalance ?? this.remainingBalance,
      isCriticalBudget: isCriticalBudget ?? this.isCriticalBudget,
      status: status ?? this.status,
      travelPreference: travelPreference ?? this.travelPreference,
      createdAt: createdAt ?? this.createdAt,
      imgUrl: imgUrl ?? this.imgUrl,
    );
  }

  factory WholeTrip.fromJson(Map<String, dynamic> json) {
    return WholeTrip(
      tripId: json['trip_id'],
      userId: json['user_id'],
      destination: json['destination'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      totalBudget: (json['total_budget'] as num).toDouble(),
      remainingBalance: (json['remaining_balance'] as num?)?.toDouble(),
      isCriticalBudget: json['is_critical_budget'],
      status: json['status'],
      travelPreference: json['travel_preference'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      imgUrl: json['img_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (tripId != null) 'trip_id': tripId,
      if (userId != null) 'user_id': userId,
      'destination': destination,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'total_budget': totalBudget,
      if (remainingBalance != null) 'remaining_balance': remainingBalance,
      if (isCriticalBudget != null) 'is_critical_budget': isCriticalBudget,
      'status': status,
      'travel_preference': travelPreference,
      if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
      if (imgUrl != null) 'img_url': imgUrl,
    };
  }
}
