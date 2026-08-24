class DayTrip {
  final String? dayTripId;
  final String tripId;
  final String? destination;
  final DateTime date;
  final bool? isOverspend;
  final double? overspendAmount;
  final String? overspendCategory;
  final DateTime? createdAt;

  DayTrip({
    this.dayTripId,
    required this.tripId,
    this.destination,
    required this.date,
    this.isOverspend,
    this.overspendAmount,
    this.overspendCategory,
    this.createdAt,
  });

  DayTrip copyWith({
    String? dayTripId,
    String? tripId,
    String? destination,
    DateTime? date,
    bool? isOverspend,
    double? overspendAmount,
    String? overspendCategory,
    DateTime? createdAt
}) {
    return DayTrip(
      dayTripId: dayTripId ?? this.dayTripId,
      tripId: tripId ?? this.tripId,
      destination: destination ?? this.destination,
      date: date ?? this.date,
      isOverspend: isOverspend ?? this.isOverspend,
      overspendAmount: overspendAmount ?? this.overspendAmount,
      overspendCategory: overspendCategory ?? this.overspendCategory,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory DayTrip.fromJson(Map<String, dynamic> json) {
    return DayTrip(
      dayTripId: json['day_trip_id'],
      tripId: json['trip_id'],
      destination: json['destination'],
      date: DateTime.parse(json['date']),
      isOverspend: json['is_overspend'],
      overspendAmount: (json['overspend_amount'] as num?)?.toDouble(),
      overspendCategory: json['overspend_category'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (dayTripId != null) 'day_trip_id': dayTripId,
      'trip_id': tripId,
      if (destination != null) 'destination': destination,
      'date': date.toIso8601String(),
      if (isOverspend != null) 'is_overspend': isOverspend,
      if (overspendAmount != null) 'overspend_amount': overspendAmount,
      if (overspendCategory != null) 'overspend_category': overspendCategory,
      if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
    };
  }
}
