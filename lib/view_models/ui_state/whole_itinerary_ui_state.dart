import '../../models/entities/activity.dart';
import '../../models/entities/whole_trip.dart';
export '../../models/entities/activity.dart';
export '../../models/entities/whole_trip.dart';
import 'travel_information_ui_state.dart';
export 'travel_information_ui_state.dart' show TransitPoint, HotelStay;
import '../../models/entities/future_suggestion.dart';

class WholeItineraryUiState {
  final bool isLoading;
  final bool isRegeneratingPlan;
  final String? regeneratingSlotId;
  final List<Activity> activities;
  final List<Activity> stashedActivities;
  final String? errorMessage;
  final String destinationTitle;
  final String datesText;
  final String budgetText;
  final double totalAllocatedBudget;
  final int wishlistItemsCoveredCount;
  final double estimatedExtraBudgetNeeded;
  final bool showWishlistWarning;
  final List<WholeTrip> allTrips;
  final String selectedStatusFilter; // 'All Plans', 'Pending', 'Completed'
  final String? preference;
  final List<String>? wishlist;
  final List<String>? constraints;
  final List<FutureSuggestion>? futureSuggestions;
  final List<TransitPoint> arrivals;
  final List<TransitPoint> departures;
  final List<HotelStay> hotels;

  String? get arrivalLocation =>
      arrivals.isNotEmpty ? arrivals.first.location : null;
  String? get arrivalTime => arrivals.isNotEmpty ? arrivals.first.time : null;
  String? get departureLocation =>
      departures.isNotEmpty ? departures.first.location : null;
  String? get departureTime =>
      departures.isNotEmpty ? departures.first.time : null;
  String? get hotelLocation => hotels.isNotEmpty ? hotels.first.location : null;
  String? get hotelCheckInTime =>
      hotels.isNotEmpty ? hotels.first.checkInTime : null;
  String? get hotelCheckOutTime =>
      hotels.isNotEmpty ? hotels.first.checkOutTime : null;

  const WholeItineraryUiState({
    this.isLoading = false,
    this.isRegeneratingPlan = false,
    this.regeneratingSlotId,
    this.activities = const [],
    this.stashedActivities = const [],
    this.errorMessage,
    this.destinationTitle = '',
    this.datesText = '',
    this.budgetText = '',
    this.totalAllocatedBudget = 0.0,
    this.wishlistItemsCoveredCount = 0,
    this.estimatedExtraBudgetNeeded = 0.0,
    this.showWishlistWarning = false,
    this.allTrips = const [],
    this.selectedStatusFilter = 'All Plans',
    this.preference,
    this.wishlist,
    this.constraints,
    this.futureSuggestions,
    this.arrivals = const [],
    this.departures = const [],
    this.hotels = const [],
    String? hotelLocation,
    String? hotelCheckInTime,
    String? hotelCheckOutTime,
  });

  List<WholeTrip> get filteredTrips {
    if (selectedStatusFilter == 'All Plans') {
      return allTrips;
    }
    return allTrips.where((trip) {
      final tripStatus = trip.computedStatus;
      return tripStatus.toLowerCase() == selectedStatusFilter.toLowerCase();
    }).toList();
  }

  WholeItineraryUiState copyWith({
    bool? isLoading,
    bool? isRegeneratingPlan,
    String? regeneratingSlotId,
    bool clearRegeneratingSlot = false,
    List<Activity>? activities,
    List<Activity>? stashedActivities,
    String? errorMessage,
    String? destinationTitle,
    String? datesText,
    String? budgetText,
    double? totalAllocatedBudget,
    int? wishlistItemsCoveredCount,
    double? estimatedExtraBudgetNeeded,
    bool? showWishlistWarning,
    List<WholeTrip>? allTrips,
    String? selectedStatusFilter,
    String? preference,
    List<String>? wishlist,
    List<String>? constraints,
    List<FutureSuggestion>? futureSuggestions,
    List<TransitPoint>? arrivals,
    List<TransitPoint>? departures,
    List<HotelStay>? hotels,
    String? arrivalLocation,
    String? arrivalTime,
    String? departureLocation,
    String? departureTime,
    String? hotelLocation,
    String? hotelCheckInTime,
    String? hotelCheckOutTime,
  }) {
    List<TransitPoint>? resolvedArrivals = arrivals;
    if (resolvedArrivals == null &&
        (arrivalLocation != null || arrivalTime != null)) {
      final currentFirst = this.arrivals.isNotEmpty
          ? this.arrivals.first
          : const TransitPoint(id: 'arr_0');
      final updatedFirst = currentFirst.copyWith(
        location: arrivalLocation ?? currentFirst.location,
        time: arrivalTime ?? currentFirst.time,
      );
      resolvedArrivals = [
        updatedFirst,
        if (this.arrivals.length > 1) ...this.arrivals.sublist(1),
      ];
    }

    List<TransitPoint>? resolvedDepartures = departures;
    if (resolvedDepartures == null &&
        (departureLocation != null || departureTime != null)) {
      final currentFirst = this.departures.isNotEmpty
          ? this.departures.first
          : const TransitPoint(id: 'dep_0');
      final updatedFirst = currentFirst.copyWith(
        location: departureLocation ?? currentFirst.location,
        time: departureTime ?? currentFirst.time,
      );
      resolvedDepartures = [
        updatedFirst,
        if (this.departures.length > 1) ...this.departures.sublist(1),
      ];
    }

    List<HotelStay>? resolvedHotels = hotels;
    if (resolvedHotels == null &&
        (hotelLocation != null ||
            hotelCheckInTime != null ||
            hotelCheckOutTime != null)) {
      final currentFirst = this.hotels.isNotEmpty
          ? this.hotels.first
          : const HotelStay(id: 'hotel_0');
      final updatedFirst = currentFirst.copyWith(
        location: hotelLocation ?? currentFirst.location,
        checkInTime: hotelCheckInTime ?? currentFirst.checkInTime,
        checkOutTime: hotelCheckOutTime ?? currentFirst.checkOutTime,
      );
      resolvedHotels = [
        updatedFirst,
        if (this.hotels.length > 1) ...this.hotels.sublist(1),
      ];
    }

    return WholeItineraryUiState(
      isLoading: isLoading ?? this.isLoading,
      isRegeneratingPlan: isRegeneratingPlan ?? this.isRegeneratingPlan,
      regeneratingSlotId: clearRegeneratingSlot
          ? null
          : (regeneratingSlotId ?? this.regeneratingSlotId),
      activities: activities ?? this.activities,
      stashedActivities: stashedActivities ?? this.stashedActivities,
      errorMessage: errorMessage ?? this.errorMessage,
      destinationTitle: destinationTitle ?? this.destinationTitle,
      datesText: datesText ?? this.datesText,
      budgetText: budgetText ?? this.budgetText,
      totalAllocatedBudget: totalAllocatedBudget ?? this.totalAllocatedBudget,
      wishlistItemsCoveredCount:
          wishlistItemsCoveredCount ?? this.wishlistItemsCoveredCount,
      estimatedExtraBudgetNeeded:
          estimatedExtraBudgetNeeded ?? this.estimatedExtraBudgetNeeded,
      showWishlistWarning: showWishlistWarning ?? this.showWishlistWarning,
      allTrips: allTrips ?? this.allTrips,
      selectedStatusFilter: selectedStatusFilter ?? this.selectedStatusFilter,
      preference: preference ?? this.preference,
      wishlist: wishlist ?? this.wishlist,
      constraints: constraints ?? this.constraints,
      futureSuggestions: futureSuggestions ?? this.futureSuggestions,
      arrivals: resolvedArrivals ?? this.arrivals,
      departures: resolvedDepartures ?? this.departures,
      hotels: resolvedHotels ?? this.hotels,
    );
  }
}
