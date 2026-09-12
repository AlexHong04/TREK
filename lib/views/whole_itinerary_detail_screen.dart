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
import '../widgets/dual_currency_amount.dart';
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
        final vm = WholeItineraryDetailViewModel(authService: authService);
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
  bool _isUncoveredWishlistExpanded = false;

  Future<void> _checkWishlistWarning(
    WholeItineraryDetailViewModel viewModel,
  ) async {
    final wishlist = viewModel.uiState.wishlist;

    final hasWishlist = wishlist != null && wishlist.isNotEmpty;

    final hasUncoveredWishlist =
        hasWishlist &&
        viewModel.uiState.wishlistItemsCoveredCount < wishlist.length;

    final hasExtraBudgetNeeded =
        viewModel.uiState.estimatedExtraBudgetNeeded > 0;

    final isOverBudget = viewModel.spentBudget > viewModel.totalBudget;

    // nothing to warn
    if (!hasUncoveredWishlist && !hasExtraBudgetNeeded && !isOverBudget) {
      return;
    }

    await _showWishlistWarningDialog(viewModel);
  }

  void _showActivityRemovedSnackBar(
    BuildContext context,
    String activityName, {
    required bool isReadOnly,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: isReadOnly ? 20.0 : 135.0,
          left: 16.0,
          right: 16.0,
        ),
        elevation: 6,
        backgroundColor: appTheme.blueGray900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: appTheme.white_A700.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        duration: const Duration(seconds: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        content: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: appTheme.errorRed.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                color: appTheme.errorRed,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activity removed',
                    style: TextStyle(
                      color: appTheme.white_A700,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                    ),
                  ),
                  if (activityName.isNotEmpty &&
                      activityName != 'Activity') ...[
                    const SizedBox(height: 2),
                    Text(
                      activityName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: appTheme.white_A700.withValues(alpha: 0.65),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWishlistItemRemovedSnackBar(
    BuildContext context,
    String item, {
    required bool isReadOnly,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: isReadOnly ? 20.0 : 135.0,
          left: 16.0,
          right: 16.0,
        ),
        elevation: 6,
        backgroundColor: appTheme.blueGray900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: appTheme.white_A700.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        duration: const Duration(seconds: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        content: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: appTheme.errorRed.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.playlist_remove_rounded,
                color: appTheme.errorRed,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wishlist item removed',
                    style: TextStyle(
                      color: appTheme.white_A700,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: appTheme.white_A700.withValues(alpha: 0.65),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

  Future<bool> _handleTopUp({
    required WholeItineraryDetailViewModel viewModel,
    required double amount,
    required double minTopUp,
  }) async {
    final convertedAmt = await viewModel.convertAmountToCurrency(
      amount: amount,
    );

    final symbol = viewModel.preferredCurrency;

    if (!mounted) return false;

    // Close the first dialog.
    Navigator.of(context).pop();

    // Wait until the first dialog is removed.
    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) return false;

    bool confirmed = false;

    await showTopUpConfirmation(
      context: context,
      topUpAmount: amount,
      symbol: symbol,
      convertedAmt: convertedAmt ?? amount,
      onCancel: () {
        confirmed = false;
      },
      onConfirm: () {
        confirmed = true;
      },
    );

    // User cancelled the confirmation.
    if (!confirmed) {
      if (!mounted) return false;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        _showWishlistWarningDialog(viewModel);
      });

      return false;
    }

    // User confirmed.
    final isSufficient = await viewModel.topUpBudget(amount);

    if (!mounted) return false;

    // Top-up was not enough to cover the remaining shortage.
    if (!isSufficient) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        showInsufficientTopUpTotalBudgetDialog(
          context: context,
          onContinue: () {
            viewModel.generateItinerary(suppressWarning: true);
          },
        );
      });
    }

    showThreeSecondMessage(
      context,
      'Budget top up successfully',
      isError: false,
    );

    return true;
  }

  Future<void> _showWishlistWarningDialog(
    WholeItineraryDetailViewModel viewModel,
  ) async {
    if (_wishlistWarningShowing) return;

    _wishlistWarningShowing = true;

    try {
      double minTopUp = viewModel.uiState.estimatedExtraBudgetNeeded * 0.50;

      if (minTopUp <= 0.0) {
        minTopUp = 20.0;
      }

      final wishlist = viewModel.uiState.wishlist;

      final hasWishlist = wishlist != null && wishlist.isNotEmpty;

      final hasUncoveredWishlist =
          hasWishlist &&
          viewModel.uiState.wishlistItemsCoveredCount < wishlist.length;

      final hasBudgetShortfall =
          viewModel.uiState.estimatedExtraBudgetNeeded > 0;

      if (hasUncoveredWishlist || hasBudgetShortfall) {
        await showInitialBudgetInsufficientDialog(
          context: context,
          shortageAmount: viewModel.uiState.estimatedExtraBudgetNeeded,
          minTopUp: minTopUp,
          wishlistCovered: hasWishlist
              ? viewModel.uiState.wishlistItemsCoveredCount
              : null,
          warningText:
              'Insufficient top-up amount will trigger '
              'alternative recommendation directly.',
          onCancel: () {},
          onTopUpBudget: (double amount) {
            return _handleTopUp(
              viewModel: viewModel,
              amount: amount,
              minTopUp: minTopUp,
            );
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

    return Scaffold(
      backgroundColor: appTheme.gray_50_03,
      appBar: const CustomAppBar(title: 'Itinerary Plan'),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 24.0,
                  left: 16.0,
                  right: 16.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOverviewCard(viewModel, isReadOnly: isReadOnly),
                    const SizedBox(height: 24.0),
                    _buildLocationHeader(viewModel, isReadOnly: isReadOnly),
                    const SizedBox(height: 16.0),
                    _buildTimeline(context, viewModel, isReadOnly: isReadOnly),
                    const SizedBox(height: 10.0),
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

  Widget _buildOverviewCard(
    WholeItineraryDetailViewModel viewModel, {
    required bool isReadOnly,
  }) {
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
              DualCurrencyAmount(
                amount: double.tryParse(viewModel.uiState.budgetText) ?? 0.0,
                baseCurrency: 'MYR',
                baseLabel: 'MYR',
                primaryStyle: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Inter',
                  color: appTheme.teal_A700, // Teal A700
                ),
                secondaryStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                  color: appTheme.blue_gray_700,
                ),
                crossAxisAlignment: CrossAxisAlignment.end,
                textAlign: TextAlign.end,
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
              DualCurrencyAmount(
                amount: viewModel.uiState.totalAllocatedBudget,
                baseCurrency: 'MYR',
                baseLabel: 'MYR',
                primaryStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Inter',
                  color: appTheme.teal_800,
                ),
                secondaryStyle: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                  color: appTheme.blue_gray_700,
                ),
                crossAxisAlignment: CrossAxisAlignment.end,
                textAlign: TextAlign.end,
              ),
            ],
          ),
          if ((viewModel.uiState.wishlist == null ||
                  viewModel.uiState.wishlist!.isEmpty) &&
              (viewModel.spentBudget > viewModel.totalBudget ||
                  viewModel.uiState.estimatedExtraBudgetNeeded > 0)) ...[
            const SizedBox(height: 8.0),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: appTheme.redButton.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: appTheme.errorRed.withValues(alpha: 0.25),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: appTheme.errorRed,
                  ),
                  const SizedBox(width: 6.0),
                  Expanded(
                    child: Text(
                      'Your budget is not sufficient for the trip.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                        color: appTheme.errorRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
            if (viewModel.uncoveredWishlistItems.isNotEmpty) ...[
              const SizedBox(height: 6.0),
              InkWell(
                onTap: () {
                  setState(() {
                    _isUncoveredWishlistExpanded =
                        !_isUncoveredWishlistExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(6.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Wishlist Uncovered',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter',
                              color: appTheme.blue_gray_700,
                            ),
                          ),
                          const SizedBox(width: 4.0),
                          AnimatedRotation(
                            turns: _isUncoveredWishlistExpanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: appTheme.blue_gray_700,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: appTheme.gray_100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${viewModel.uncoveredWishlistItems.length} Items',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Inter',
                            color: appTheme.errorRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: appTheme.gray_50_03,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: appTheme.blue_gray_50,
                      width: 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 14,
                            color: appTheme.blue_gray_300,
                          ),
                          const SizedBox(width: 6.0),
                          Expanded(
                            child: Text(
                              viewModel.uiState.wishlistItemsCoveredCount == 0
                                  ? 'Your budget is not sufficient to cover any wishlist items.'
                                  : 'Your budget is not sufficient to cover all wishlist items.',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Inter',
                                color: appTheme.blue_gray_700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      Wrap(
                        spacing: 6.0,
                        runSpacing: 6.0,
                        children: viewModel.uncoveredWishlistItems.map((item) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10.0,
                              vertical: 5.0,
                            ),
                            decoration: BoxDecoration(
                              color: appTheme.white_A700,
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(
                                color: appTheme.gray_200,
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.remove_circle_outline_rounded,
                                  size: 13,
                                  color: appTheme.errorRed,
                                ),
                                const SizedBox(width: 5.0),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 240,
                                  ),
                                  child: Text(
                                    item,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Inter',
                                      color: appTheme.gray_800,
                                    ),
                                  ),
                                ),
                                if (!isReadOnly) ...[
                                  const SizedBox(width: 6.0),
                                  InkWell(
                                    onTap: () {
                                      viewModel.deleteWishlistItem(item);
                                      _showWishlistItemRemovedSnackBar(
                                        context,
                                        item,
                                        isReadOnly: isReadOnly,
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2.0),
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 14,
                                        color: appTheme.blue_gray_300,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                crossFadeState: _isUncoveredWishlistExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
              ),
            ],
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
                DualCurrencyAmount(
                  amount: viewModel.uiState.estimatedExtraBudgetNeeded,
                  baseCurrency: 'MYR',
                  baseLabel: 'MYR',
                  primaryStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Inter',
                    color: appTheme.errorRed,
                  ),
                  secondaryStyle: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                    color: appTheme.blue_gray_700,
                  ),
                  crossAxisAlignment: CrossAxisAlignment.end,
                  textAlign: TextAlign.end,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationHeader(
    WholeItineraryDetailViewModel viewModel, {
    required bool isReadOnly,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Text(
        viewModel.uiState.destinationTitle.toUpperCase(),
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          fontFamily: 'Inter',
          color: appTheme.teal_800,
        ),
      ),
    );
  }

  Widget _buildRegenerateInfoMessage(WholeItineraryDetailViewModel viewModel) {
    final emptyCount = viewModel.uiState.activities
        .where(
          (a) =>
              a.status == 'empty' ||
              (a.destination.trim().isEmpty && a.description.trim().isEmpty),
        )
        .length;

    if (viewModel.uiState.isRegeneratingPlan) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: appTheme.teal_50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: appTheme.teal_A700.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: appTheme.teal_A700,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'AI is crafting new activities based on your remaining plan...',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                  color: appTheme.teal_800,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: appTheme.teal_50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: appTheme.teal_A700.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: appTheme.white_A700,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: appTheme.teal_A700,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Plan Incomplete ($emptyCount empty slot${emptyCount > 1 ? 's' : ''})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                    color: appTheme.teal_800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Auto-fill using your remaining itinerary as context',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Inter',
                    color: appTheme.blue_gray_700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
          onRemove: () async {
            final activityName =
                (activity.destination as String?)?.isNotEmpty == true
                ? activity.destination as String
                : 'Activity';
            final confirmed = await showConfirmRemoveActivityDialog(
              context: context,
              activityName: activityName,
            );
            if (confirmed) {
              viewModel.removeActivity(activity.activitiesId);
              if (context.mounted) {
                _showActivityRemovedSnackBar(
                  context,
                  activityName,
                  isReadOnly: isReadOnly,
                );
              }
            }
          },
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
    final bool isActivityNonEmpty =
        activity.status != 'empty' && activity.destination.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTimelineIndicatorColumn(isLast: isLast),
        const SizedBox(width: 24.0),
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
                  if (!isReadOnly && isActivityNonEmpty)
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
              const SizedBox(height: 12.0),
              _buildActivityCard(context, viewModel, activity),
              if (!isLast) const SizedBox(height: 24.0),
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
    final bool hasEmptySlots = viewModel.hasEmptyActivitySlots;
    final bool isRegenerating = viewModel.uiState.isRegeneratingPlan;
    final bool needsTopUp = viewModel.needsTopUp;

    return Container(
      color: appTheme.gray_50_03,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasEmptySlots) ...[
            _buildRegenerateInfoMessage(viewModel),
            const SizedBox(height: 10),
          ],
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                // Left: Top-up Button (Only appears when budget is insufficient or wishlist uncovered)
                if (needsTopUp) ...[
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: appTheme.white_A700,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: appTheme.teal_A700,
                          width: 1.5,
                        ),
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
                          onTap: () async {
                            await _checkWishlistWarning(viewModel);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_card_rounded,
                                  size: 20,
                                  color: appTheme.teal_A700,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Top-up',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Inter',
                                    color: appTheme.teal_A700,
                                  ).copyWith(height: 22 / 18),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // Right: Regenerate Plan Button (if empty slots exist) OR Confirm Button (if all filled)
                Expanded(
                  child: hasEmptySlots
                      ? Container(
                          decoration: BoxDecoration(
                            color: isRegenerating
                                ? appTheme.gray_400
                                : appTheme.teal_A700,
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
                              onTap: isRegenerating
                                  ? null
                                  : () =>
                                        viewModel.regeneratePlanFromRemaining(),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (isRegenerating) ...[
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: appTheme.white_A700,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Regenerating...',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: 'Inter',
                                          color: appTheme.white_A700,
                                        ).copyWith(height: 22 / 16),
                                      ),
                                    ] else ...[
                                      Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 20,
                                        color: appTheme.white_A700,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Regenerate Plan',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: 'Inter',
                                          color: appTheme.white_A700,
                                        ).copyWith(height: 22 / 16),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: viewModel.canConfirmItinerary
                                ? appTheme.teal_A700
                                : appTheme.gray_400,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: viewModel.canConfirmItinerary
                                ? [
                                    BoxShadow(
                                      color: appTheme.teal_50,
                                      offset: const Offset(0, 4),
                                      blurRadius: 6,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Material(
                            color: appTheme.transparentCustom,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              onTap: viewModel.canConfirmItinerary
                                  ? () async {
                                      // Wishlist does NOT block confirm; only check if actually overspent
                                      if (viewModel.spentBudget >
                                          viewModel.totalBudget) {
                                        await _showWishlistWarningDialog(
                                          viewModel,
                                        );
                                        return;
                                      }

                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (BuildContext context) {
                                          return const Center(
                                            child: CircularProgressIndicator(),
                                          );
                                        },
                                      );

                                      final errorMsg = await viewModel
                                          .confirmItinerary();

                                      if (context.mounted) {
                                        Navigator.of(context).pop();
                                      }

                                      if (errorMsg == null && context.mounted) {
                                        showThreeSecondMessage(
                                          context,
                                          'Itinerary saved to database successfully!',
                                          isError: false,
                                        );
                                        Navigator.pushNamedAndRemoveUntil(
                                          context,
                                          AppRoutes.homeScreen,
                                          (route) => false,
                                        );
                                      } else if (errorMsg != null &&
                                          context.mounted) {
                                        showDialog(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text('Save Failed'),
                                            content: Text(errorMsg),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text('OK'),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    }
                                  : null,
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
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
                ),
              ],
            ),
          ),
        ],
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
      final isSlotRegenerating =
          viewModel.uiState.regeneratingSlotId == activity.activitiesId ||
          viewModel.uiState.isRegeneratingPlan;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24.0),
        height: 330,
        decoration: BoxDecoration(
          color: appTheme.gray_100,
          border: Border.all(color: appTheme.blue_gray_50, width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSlotRegenerating) ...[
                CircularProgressIndicator(color: appTheme.teal_A700),
                const SizedBox(height: 12),
                Text(
                  'Generating activity...',
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
                      destination: activity.destination.isNotEmpty
                          ? activity.destination
                          : viewModel.uiState.destinationTitle,
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
                  backgroundColor: appTheme.amber_200,
                  textColor: appTheme.lime_900,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      DualCurrencyAmount(
                        amount: (activity.allocatedBudget as num).toDouble(),
                        baseCurrency: 'MYR',
                        baseLabel: 'MYR',
                        crossAxisAlignment: CrossAxisAlignment.start,
                        textAlign: TextAlign.start,
                        primaryStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Inter',
                          color: appTheme.lime_900,
                          height: 1.2,
                        ),
                        secondaryStyle: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                          color: appTheme.lime_900.withValues(alpha: 0.75),
                          height: 1.2,
                        ),
                      ),
                      if (activity.activityCategory.toLowerCase() ==
                          'restaurant') ...[
                        const SizedBox(width: 3),
                        Text(
                          '/ pax',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Inter',
                            color: appTheme.lime_900,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (activity.isOverspend == true &&
                    activity.overspendAmount != null)
                  _buildChip(
                    backgroundColor: appTheme.wholeAlertBudgetBg,
                    textColor: appTheme.wholeAlertBudgetText,
                    child: DualCurrencyAmount(
                      amount: (activity.overspendAmount as num).toDouble(),
                      baseCurrency: 'MYR',
                      baseLabel: 'MYR',
                      crossAxisAlignment: CrossAxisAlignment.start,
                      textAlign: TextAlign.start,
                      primaryStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Inter',
                        color: appTheme.wholeAlertBudgetText,
                        height: 1.2,
                      ),
                      secondaryStyle: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                        color: appTheme.wholeAlertBudgetText.withValues(
                          alpha: 0.75,
                        ),
                        height: 1.2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    String? label,
    Widget? child,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child:
          child ??
          Text(
            label ?? '',
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
