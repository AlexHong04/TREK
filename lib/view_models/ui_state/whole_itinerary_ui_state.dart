import '../../models/entities/activity.dart';
import '../../models/entities/whole_trip.dart';
export '../../models/entities/activity.dart';
export '../../models/entities/whole_trip.dart';
import '../../models/entities/future_suggestion.dart';

class WholeItineraryUiState {
  final bool isLoading;
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
  final String? arrivalLocation;
  final String? arrivalTime;
  final String? departureLocation;
  final String? departureTime;
  final String? hotelLocation;
  final String? hotelCheckInTime;
  final String? hotelCheckOutTime;

  const WholeItineraryUiState({
    this.isLoading = false,
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
    this.arrivalLocation,
    this.arrivalTime,
    this.departureLocation,
    this.departureTime,
    this.hotelLocation,
    this.hotelCheckInTime,
    this.hotelCheckOutTime,
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
    String? arrivalLocation,
    String? arrivalTime,
    String? departureLocation,
    String? departureTime,
    String? hotelLocation,
    String? hotelCheckInTime,
    String? hotelCheckOutTime,
  }) {
    return WholeItineraryUiState(
      isLoading: isLoading ?? this.isLoading,
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
      arrivalLocation: arrivalLocation ?? this.arrivalLocation,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      departureLocation: departureLocation ?? this.departureLocation,
      departureTime: departureTime ?? this.departureTime,
      hotelLocation: hotelLocation ?? this.hotelLocation,
      hotelCheckInTime: hotelCheckInTime ?? this.hotelCheckInTime,
      hotelCheckOutTime: hotelCheckOutTime ?? this.hotelCheckOutTime,
    );
  }
}
