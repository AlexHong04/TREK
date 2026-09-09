import 'package:Trek/models/entities/whole_trip.dart';
import '../view_models/ui_state/travel_information_ui_state.dart';

import '../theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../view_models/presentation_logic/whole_itinerary_detail_view_model.dart';
import '../models/services/i_auth_service.dart';
import '../main.dart';
import '../widgets/custom_app_bar.dart';
import 'budget_popup.dart';

class WholeItineraryDetailScreen extends StatefulWidget {
  const WholeItineraryDetailScreen({super.key});

  static Widget builder(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;

    // For all plan screen
    final isReadOnly = args?['isReadOnly'] as bool? ?? false;
    final tripId = (args?['tripId'] ?? args?['tripID']) as String?;
    final trip = args?['trip'] as WholeTrip?;

    // Retrieve constraints from current user
    final authService = context.read<IAuthService>();
    final constraints =
        authService.currentUser?.personalConstraints
            .map((c) => '${c.category}: ${c.constraintName}')
            .toList() ??
        [];

    final rawArrivals = args?['arrivals'] as List?;
    final arrivals = rawArrivals
        ?.map((e) => TransitPoint.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final rawDepartures = args?['departures'] as List?;
    final departures = rawDepartures
        ?.map((e) => TransitPoint.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final rawHotels = args?['hotels'] as List?;
    final hotels = rawHotels
        ?.map((e) => HotelStay.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return ChangeNotifierProvider<WholeItineraryDetailViewModel>(
      create: (context) {
        final vm = WholeItineraryDetailViewModel();
        final resolvedTripId = tripId ?? trip?.tripId ?? '';

        if (isReadOnly && (tripId != null || trip != null)) {
          vm.loadSavedTrip(tripId: resolvedTripId, trip: trip);
        } else {
          vm.initialize(
            destination: args?['destination'] as String? ?? 'Unknown',
            dates: args?['dates'] as String? ?? '',
            budget: args?['budget'] as String? ?? '0',
            preference: args?['preference'] as String?,
            wishlist: (args?['wishlist'] as List?)
                ?.map((e) => e.toString())
                .toList(),
            constraints: constraints,
            arrivals: arrivals,
            departures: departures,
            hotels: hotels,
            arrivalLocation: args?['arrivalLocation'] as String?,
            arrivalTime: args?['arrivalTime'] as String?,
            departureLocation: args?['departureLocation'] as String?,
            departureTime: args?['departureTime'] as String?,
            hotelLocation: args?['hotelLocation'] as String?,
            hotelCheckInTime: args?['hotelCheckInTime'] as String?,
            hotelCheckOutTime: args?['hotelCheckOutTime'] as String?,
          );
        }

        return vm;
      },
      child: const WholeItineraryDetailScreen(),
    );
  }

  @override
  State<WholeItineraryDetailScreen> createState() =>
      _WholeItineraryDetailScreenState();
}

class _WholeItineraryDetailScreenState
    extends State<WholeItineraryDetailScreen> {
  bool _wishlistWarningShowing = false;

  void _checkWishlistWarning(WholeItineraryDetailViewModel viewModel) {
    if (!viewModel.uiState.showWishlistWarning || _wishlistWarningShowing) {
      return;
    }

    _wishlistWarningShowing = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      viewModel.dismissWishlistWarning();
      _showWishlistWarningDialog(viewModel);
    });
  }

  String _formatDisplayTime(dynamic activity) {
    final startTime = activity.startTime as String?;
    if (startTime != null && startTime.trim().isNotEmpty) {
      try {
        final parsed = DateFormat('HH:mm').parse(startTime.trim());
        return DateFormat('hh:mm a').format(parsed);
      } catch (_) {
        return startTime;
      }
    }
    return DateFormat('hh:mm a').format(activity.date);
  }

  Future<void> _showWishlistWarningDialog(
    WholeItineraryDetailViewModel viewModel,
  ) async {
    try {
      double minTopUp = viewModel.uiState.estimatedExtraBudgetNeeded * 0.50;
      if (minTopUp <= 0.0) {
        minTopUp = 20.0;
      }
      debugPrint("wishlist: ${viewModel.uiState.wishlist}");
      debugPrint(
        "estimated extra budget needed: ${viewModel.uiState.estimatedExtraBudgetNeeded}",
      );
      debugPrint(
        "wishlist covered count: ${viewModel.uiState.wishlistItemsCoveredCount}",
      );
      if ((viewModel.uiState.wishlist == null ||
              viewModel.uiState.wishlist!.isEmpty) &&
          viewModel.uiState.estimatedExtraBudgetNeeded > 0) {
        await showEmptyWishlistInsufficientTotalBudgetDialog(
          context: context,
          shortageAmount: viewModel.uiState.estimatedExtraBudgetNeeded
              .toStringAsFixed(2),
          minTopUp: minTopUp,
          onCancel: () async {
            await showCancelTripWithoutWishlistDialog(
              context: context,
              onContinue: () {
                Navigator.of(context).pop();
              },
            );
          },

          onTopUpBudget: (double amount) async {
            final isSufficient = await viewModel.topUpBudget(amount);

            if (!isSufficient) {
              // Wait until the first dialog is completely removed.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;

                showInsufficientTopUpTotalBudgetWithoutWishlistDialog(
                  context: context,
                  onContinue: () {
                    // Trigger re-recommendation with the latest total budget
                    viewModel.generateItinerary(suppressWarning: true);
                  },
                );
              });
            }

            return true;
          },
        );
      } else if (viewModel.uiState.wishlist != null &&
          viewModel.uiState.wishlist!.isNotEmpty &&
          viewModel.uiState.wishlistItemsCoveredCount == 0) {
        await showInitialTotalBudgetTotallyInsufficientDialog(
          context: context,
          shortageAmount: viewModel.uiState.estimatedExtraBudgetNeeded
              .toStringAsFixed(2),
          minTopUp: minTopUp,
          wishlistCovered: viewModel.uiState.wishlistItemsCoveredCount,
          onCancel: () async {
            await showCancelTripDialog(
              context: context,
              onContinue: () {
                Navigator.of(context).pop();
              },
            );
          },
          onTopUpBudget: (double amount) async {
            final isSufficient = await viewModel.topUpBudget(amount);

            if (!isSufficient) {
              // Wait until the first dialog is completely removed.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;

                showInsufficientTopUpTotalBudgetDialog(
                  context: context,
                  onContinue: () {
                    // Trigger re-recommendation with the latest total budget
                    viewModel.generateItinerary(suppressWarning: true);
                  },
                );
              });
            }

            return true;
          },
        );
      } else if (viewModel.uiState.wishlist != null &&
          viewModel.uiState.wishlist!.isNotEmpty &&
          (viewModel.uiState.wishlistItemsCoveredCount <
                  viewModel.uiState.wishlist!.length ||
              viewModel.uiState.estimatedExtraBudgetNeeded > 0)) {
        await showInitialTotalBudgetInsufficientDialog(
          context: context,
          shortageAmount: viewModel.uiState.estimatedExtraBudgetNeeded
              .toStringAsFixed(2),
          minTopUp: minTopUp,
          wishlistCovered: viewModel.uiState.wishlistItemsCoveredCount,
          onCancel: () async {
            await showCancelTopUpDialog(
              context: context,
              onContinue: () {
                Navigator.of(context).pop();
              },
            );
          },

          onTopUpBudget: (double amount) async {
            final isSufficient = await viewModel.topUpBudget(amount);

            if (!isSufficient) {
              // Wait until the first dialog is completely removed.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;

                showInsufficientTopUpTotalBudgetDialog(
                  context: context,
                  onContinue: () {
                    // Trigger re-recommendation with the latest total budget
                    viewModel.generateItinerary(suppressWarning: true);
                  },
                );
              });
            }

            return true;
          },
        );
      }
    } finally {
      if (mounted) {
        _wishlistWarningShowing = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<WholeItineraryDetailViewModel>();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final isReadOnly = args?['isReadOnly'] as bool? ?? false;

    // hide the confirm button when it only read the generated itinerary plan
    if (!isReadOnly) {
      _checkWishlistWarning(viewModel);
    }

    return Scaffold(
      backgroundColor: appTheme.gray_50_03,
      appBar: const CustomAppBar(title: 'Itinerary Plan'),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(top: 24.0, left: 16.0, right: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOverviewCard(viewModel),
                    SizedBox(height: 24.0),
                    _buildLocationHeader(viewModel),
                    SizedBox(height: 16.0),
                    _buildTimeline(context, viewModel, isReadOnly: isReadOnly),
                    SizedBox(height: 10.0),
                  ],
                ),
              ),
            ),
          ),
          if (!isReadOnly) _buildBottomSection(context, viewModel),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(WholeItineraryDetailViewModel viewModel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: appTheme.white_A700,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: appTheme.black_900_0c,
            offset: const Offset(0, 2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'JOURNEY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Inter',
                  color: appTheme.teal_A700,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                viewModel.uiState.datesText.isNotEmpty
                    ? viewModel.uiState.datesText
                    : 'Dates',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                  color: appTheme.gray_800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Overview',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Inter',
                  color: appTheme.gray_900,
                  height: 1.1,
                ),
              ),
              Text(
                'BUDGET',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Inter',
                  color: appTheme.teal_A700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: appTheme.teal_50, // Teal 50
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${viewModel.plannedStopsCount} Stops Planned',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Inter',
                    color: appTheme.teal_700, // Teal 700
                  ),
                ),
              ),
              Text(
                'RM${viewModel.uiState.budgetText}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Inter',
                  color: appTheme.teal_A700, // Teal A700
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          Divider(color: appTheme.gray_100, height: 1.0),
          const SizedBox(height: 12.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AI Allocated Budget',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                  color: appTheme.blue_gray_700,
                ),
              ),
              Text(
                'RM${viewModel.uiState.totalAllocatedBudget.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Inter',
                  color: appTheme.teal_800,
                ),
              ),
            ],
          ),
          if (viewModel.uiState.wishlist != null &&
              viewModel.uiState.wishlist!.isNotEmpty) ...[
            const SizedBox(height: 6.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Wishlist Covered',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                    color: appTheme.blue_gray_700,
                  ),
                ),
                Text(
                  '${viewModel.uiState.wishlistItemsCoveredCount} / ${viewModel.uiState.wishlist!.length} Items',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Inter',
                    color: appTheme.teal_800,
                  ),
                ),
              ],
            ),
          ],
          if (viewModel.uiState.estimatedExtraBudgetNeeded > 0.0) ...[
            const SizedBox(height: 6.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Extra Budget Needed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                    color: appTheme.errorRed,
                  ),
                ),
                Text(
                  'RM${viewModel.uiState.estimatedExtraBudgetNeeded.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Inter',
                    color: appTheme.errorRed,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationHeader(WholeItineraryDetailViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(
            viewModel.uiState.destinationTitle.toUpperCase(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              fontFamily: 'Inter',
              color: appTheme.teal_800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline(
    BuildContext context,
    WholeItineraryDetailViewModel viewModel, {
    required bool isReadOnly,
  }) {
    if (viewModel.uiState.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: appTheme.teal_A700),
      );
    }

    // 1. Create a sorted copy of the activities
    final activities = List<dynamic>.from(viewModel.uiState.activities);
    activities.sort((a, b) {
      // Primary sort: Date
      final DateTime aDate = a.date is DateTime
          ? a.date
          : DateTime.parse(a.date.toString());
      final DateTime bDate = b.date is DateTime
          ? b.date
          : DateTime.parse(b.date.toString());

      final dateCompare = DateTime(
        aDate.year,
        aDate.month,
        aDate.day,
      ).compareTo(DateTime(bDate.year, bDate.month, bDate.day));
      if (dateCompare != 0) return dateCompare;

      // Secondary sort: startTime (HH:mm)
      final String aTime = (a.startTime as String?)?.trim() ?? '00:00';
      final String bTime = (b.startTime as String?)?.trim() ?? '00:00';
      return aTime.compareTo(bTime);
    });

    List<Widget> children = [];
    int currentDayCount = 1;
    DateTime? lastDate;

    for (int i = 0; i < activities.length; i++) {
      final activity = activities[i];
      final DateTime actDate = activity.date is DateTime
          ? activity.date
          : DateTime.parse(activity.date.toString());

      if (lastDate == null ||
          lastDate.year != actDate.year ||
          lastDate.month != actDate.month ||
          lastDate.day != actDate.day) {
        if (lastDate != null) currentDayCount++;

        children.add(
          Padding(
            padding: const EdgeInsets.only(left: 8.0, top: 24.0, bottom: 16.0),
            child: Text(
              'Day $currentDayCount',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                fontFamily: 'Inter',
                color: appTheme.gray_900,
                height: 1.1,
              ),
            ),
          ),
        );
        lastDate = actDate;
      }

      final bool isLast =
          i == activities.length - 1 ||
          (i + 1 < activities.length &&
              (activities[i + 1].date.day != actDate.day ||
                  activities[i + 1].date.month != actDate.month ||
                  activities[i + 1].date.year != actDate.year));

      children.add(
        _buildTimelineItem(
          context: context,
          viewModel: viewModel,
          activity: activity,
          isLast: isLast,
          isReadOnly: isReadOnly,
          onRemove: () => viewModel.removeActivity(activity.activitiesId),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildTimelineItem({
    required BuildContext context,
    required WholeItineraryDetailViewModel viewModel,
    required dynamic activity,
    required bool isLast,
    required VoidCallback onRemove,
    required bool isReadOnly,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTimelineIndicatorColumn(isLast: isLast),
        SizedBox(width: 24.0),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDisplayTime(activity),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                      color: appTheme.gray_800,
                    ).copyWith(height: 1.2),
                  ),
                  if (!isReadOnly)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onRemove,
                      child: Icon(
                        Icons.delete_outline,
                        color: appTheme.errorRed,
                        size: 24,
                      ),
                    ),
                ],
              ),
              SizedBox(height: 12.0),
              _buildActivityCard(context, viewModel, activity),
              if (!isLast) SizedBox(height: 24.0),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineIndicatorColumn({required bool isLast}) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2.0),
          padding: const EdgeInsets.all(4.0),
          decoration: BoxDecoration(
            color: appTheme.white_A700,
            border: Border.all(color: appTheme.teal_800, width: 3),
            shape: BoxShape.circle,
          ),
          child: Container(
            width: 8.0,
            height: 8.0,
            decoration: BoxDecoration(
              color: appTheme.teal_800,
              shape: BoxShape.circle,
            ),
          ),
        ),
        Container(width: 2.0, height: 350.0, color: appTheme.blue_gray_300),
      ],
    );
  }

  Widget _buildBottomSection(
    BuildContext context,
    WholeItineraryDetailViewModel viewModel,
  ) {
    // Confirm is only allowed once EVERY time slot is filled (no deleted /
    // empty activities) and the plan is not still being generated.
    final bool canConfirm = viewModel.canConfirmItinerary;

    return Container(
      color: appTheme.gray_50_03,
      padding: EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        // Disabled state uses a clearly grey button (not tappable) when an
        // activity was deleted or an empty slot is still present.
        decoration: BoxDecoration(
          color: canConfirm ? appTheme.teal_A700 : appTheme.gray_400,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: appTheme.teal_50,
              offset: const Offset(0, 4),
              blurRadius: 6,
            ),
          ],
        ),
        child: Material(
          color: appTheme.transparentCustom,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: canConfirm
                ? () async {
                    if (viewModel.uiState.estimatedExtraBudgetNeeded > 0) {
                      await _showWishlistWarningDialog(viewModel);
                      return;
                    }

                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext context) {
                        return const Center(child: CircularProgressIndicator());
                      },
                    );

                    final errorMsg = await viewModel.confirmItinerary();

                    if (context.mounted) {
                      Navigator.of(context).pop(); // dismiss loading
                    }

                    if (errorMsg == null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Itinerary saved to database successfully!',
                          ),
                        ),
                      );
                      // Return to home page, clearing all previous routes
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.homeScreen,
                        (route) => false,
                      );
                    } else if (errorMsg != null && context.mounted) {
                      // Show extreme specific error message so we can solve Supabase DB issue!
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Save Failed'),
                          content: Text(errorMsg),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('OK'),
                            ),
                          ],
                        ),
                      );
                    }
                  }
                : null,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 20,
                    color: appTheme.white_A700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Confirm',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                      color: appTheme.white_A700,
                    ).copyWith(height: 22 / 18),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityCard(
    BuildContext context,
    WholeItineraryDetailViewModel viewModel,
    dynamic activity,
  ) {
    // Check if the activity has been cleared (empty slot state)
    if (activity.status == 'empty' ||
        (activity.destination.isEmpty && activity.description.isEmpty)) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24.0),
        height: 330,
        decoration: BoxDecoration(
          color: appTheme.gray_100,
          border: Border.all(color: appTheme.blue_gray_50, width: 1),
          borderRadius: BorderRadius.circular(12),
          // Optional dashed border effect simulation via background or style
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // While this specific slot is being regenerated, show an inline
              // spinner ONLY here instead of blocking the whole screen.
              if (viewModel.uiState.regeneratingSlotId ==
                  activity.activitiesId) ...[
                CircularProgressIndicator(color: appTheme.teal_A700),
                const SizedBox(height: 12),
                Text(
                  'Generating alternative activity...',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                    color: appTheme.blue_gray_300,
                  ),
                ),
              ] else ...[
                IconButton(
                  icon: Icon(
                    Icons.add_circle_outline,
                    size: 32,
                    color: appTheme.blue_gray_300,
                  ),
                  onPressed: () async {
                    await viewModel.generateAlternativeActivity(
                      slotActivityId: activity.activitiesId,
                      destination: activity.destination,
                    );
                    final error = viewModel.uiState.errorMessage;
                    if (error != null && error.isNotEmpty && context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(error)));
                    }
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Empty Activity Slot',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                    color: appTheme.blue_gray_300,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: appTheme.white_A700,
        border: Border.all(color: appTheme.blue_gray_50, width: 1),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: appTheme.black_900_0c,
            offset: Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
            ),
            child: activity.activityImgUrl.isNotEmpty
                ? (activity.activityImgUrl.startsWith('http')
                      ? Image.network(
                          activity.activityImgUrl,
                          height: 192,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Image.asset(
                          activity.activityImgUrl,
                          height: 192,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ))
                : const SizedBox.shrink(),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
            child: Text(
              activity.destination,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
                color: appTheme.gray_900,
              ).copyWith(height: 25 / 20),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 20, right: 20),
            child: Text(
              activity.description,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                fontFamily: 'Inter',
                color: appTheme.gray_800,
              ).copyWith(height: 22 / 14),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              top: 12,
              left: 20,
              right: 20,
              bottom: 20,
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (activity.activityCategory.isNotEmpty)
                  _buildChip(
                    label: activity.activityCategory,
                    backgroundColor: appTheme.blue_gray_50,
                    textColor: appTheme.blue_gray_700,
                  ),
                if (activity.duration != null && activity.duration!.isNotEmpty)
                  _buildChip(
                    label: activity.duration!,
                    backgroundColor: appTheme.teal_A200,
                    textColor: appTheme.teal_700,
                  ),
                _buildChip(
                  label:
                      'RM${activity.allocatedBudget.toStringAsFixed(0)}${activity.activityCategory.toLowerCase() == 'restaurant' ? ' / pax' : ''}',
                  backgroundColor: appTheme.amber_200,
                  textColor: appTheme.lime_900,
                ),
                if (activity.isOverspend == true &&
                    activity.overspendAmount != null)
                  _buildChip(
                    label: 'RM${activity.overspendAmount!.toStringAsFixed(0)}',
                    backgroundColor: appTheme.wholeAlertBudgetBg,
                    textColor: appTheme.wholeAlertBudgetText,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
          color: textColor,
        ).copyWith(height: 15 / 12),
      ),
    );
  }
}
