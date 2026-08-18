class WholeTrip {
  final String? tripId;
  final String? userId; // Nullable for demo if no auth
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final double totalBudget;
  final double? emergencyFund;
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
    this.emergencyFund,
    this.remainingBalance,
    this.isCriticalBudget,
    required this.status,
    required this.travelPreference,
    this.createdAt,
    this.imgUrl,
  });

  factory WholeTrip.fromJson(Map<String, dynamic> json) {
    return WholeTrip(
      tripId: json['trip_id'],
      userId: json['user_id'],
      destination: json['destination'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      totalBudget: (json['total_budget'] as num).toDouble(),
      emergencyFund: (json['emergency_fund'] as num?)?.toDouble(),
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
      if (emergencyFund != null) 'emergency_fund': emergencyFund,
      if (remainingBalance != null) 'remaining_balance': remainingBalance,
      if (isCriticalBudget != null) 'is_critical_budget': isCriticalBudget,
      'status': status,
      'travel_preference': travelPreference,
      if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
      if (imgUrl != null) 'img_url': imgUrl,
    };
  }
}
