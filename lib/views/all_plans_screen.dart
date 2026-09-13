import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/services/i_auth_service.dart';
import '../models/services/i_profile_service.dart'; // added this
import '../theme/app_theme.dart';
import '../view_models/presentation_logic/whole_itinerary_detail_view_model.dart';
import '../view_models/ui_state/whole_itinerary_ui_state.dart';
import '../widgets/app_date_picker.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/dual_currency_amount.dart';

class AllPlansScreen extends StatefulWidget {
  const AllPlansScreen({super.key});

  static Widget builder(BuildContext context) {
    final authService = context.read<IAuthService>();
    final profileService = context.read<IProfileService>(); // added this

    return ChangeNotifierProvider<WholeItineraryDetailViewModel>(
      create: (_) => WholeItineraryDetailViewModel(
        authService: authService,
        profileService: profileService,
      ), // changed this
      child: const AllPlansScreen(),
    );
  }

  @override
  State<AllPlansScreen> createState() => _AllPlansScreenState();
}

class _AllPlansScreenState extends State<AllPlansScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WholeItineraryDetailViewModel>().loadAllTrips();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<WholeItineraryDetailViewModel>();
    final uiState = viewModel.uiState;

    return Scaffold(
      backgroundColor: appTheme.gray_50_03,
      appBar: const CustomAppBar(title: 'All Plans'),
      body: uiState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilterDropdownCard(uiState, viewModel),
                  const SizedBox(height: 16.0),
                  _buildTripList(uiState),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterDropdownCard(
    WholeItineraryUiState uiState,
    WholeItineraryDetailViewModel viewModel,
  ) {
    const statusFilters = [
      'All Plans',
      'Pending',
      'Ongoing',
      'Completed',
      'Terminated',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: appTheme.white_A700,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: appTheme.black_900_0c,
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status filter
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STATUS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Inter',
                    color: appTheme.gray_800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10.0),
                PopupMenuButton<String>(
                  tooltip: 'Filter plans by status',
                  initialValue: uiState.selectedStatusFilter,
                  onSelected: viewModel.setStatusFilter,
                  color: appTheme.white_A700,
                  surfaceTintColor: appTheme.white_A700,
                  shadowColor: appTheme.gray_900.withValues(alpha: 0.16),
                  elevation: 8,
                  position: PopupMenuPosition.under,
                  offset: const Offset(0, 6),
                  constraints: const BoxConstraints(
                    minWidth: 150,
                    maxWidth: 180,
                  ),
                  menuPadding: const EdgeInsets.symmetric(vertical: 6),
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: appTheme.gray_200),
                  ),
                  itemBuilder: (context) => statusFilters
                      .map(
                        (status) => PopupMenuItem<String>(
                          value: status,
                          height: 44,
                          padding: EdgeInsets.zero,
                          child: Container(
                            width: double.infinity,
                            height: 44,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            color: status == uiState.selectedStatusFilter
                                ? appTheme.gray_200
                                : appTheme.white_A700,
                            child: Text(
                              status,
                              style: TextStyle(
                                color: appTheme.gray_900,
                                fontSize: 12,
                                fontWeight:
                                    status == uiState.selectedStatusFilter
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: appTheme.white_A700,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: appTheme.gray_200),
                      boxShadow: [
                        BoxShadow(
                          color: appTheme.black_900_0c,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            uiState.selectedStatusFilter,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: appTheme.gray_900,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: appTheme.teal_A700,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12.0),
          // Date filter
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DATE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Inter',
                    color: appTheme.gray_800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10.0),
                GestureDetector(
                  onTap: () async {
                    final picked = await showAppDatePicker(
                      context: context,
                      initialDate: uiState.selectedDateFilter ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      viewModel.setDateFilter(picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14.0,
                      vertical: 12.0,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10.0),
                      border: Border.all(color: appTheme.gray_200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                          color: appTheme.teal_A700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            uiState.selectedDateFilter != null
                                ? DateFormat(
                                    'dd/MM/yy',
                                  ).format(uiState.selectedDateFilter!)
                                : 'All',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Inter',
                              color: uiState.selectedDateFilter != null
                                  ? appTheme.gray_900
                                  : appTheme.blue_gray_300,
                            ),
                          ),
                        ),
                        if (uiState.selectedDateFilter != null)
                          GestureDetector(
                            onTap: () {
                              viewModel.setDateFilter(null);
                            },
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: appTheme.gray_800,
                            ),
                          ),
                      ],
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

  Widget _buildTripList(WholeItineraryUiState uiState) {
    final trips = uiState.filteredTrips;

    if (trips.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 48, color: appTheme.blue_gray_300),
              const SizedBox(height: 12),
              Text(
                'No itineraries found.',
                style: TextStyle(
                  fontSize: 14,
                  color: appTheme.blue_gray_300,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: trips.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16.0),
      itemBuilder: (context, index) {
        return _buildPlanCard(context, trips[index]);
      },
    );
  }

  Widget _buildPlanCard(BuildContext context, WholeTrip trip) {
    final startDateStr = DateFormat('MMM dd').format(trip.startDate);
    final endDateStr = DateFormat('MMM dd, yyyy').format(trip.endDate);

    final status = trip.computedStatus.toLowerCase();
    final bool isOngoing = status == 'ongoing';
    final bool isCompleted = status == 'completed';
    final bool isPending = status == 'pending';
    final bool isTerminated = status == 'terminated';

    final String? activeImageUrl =
        (trip.imgUrl != null && trip.imgUrl!.trim().isNotEmpty)
        ? trip.imgUrl!.trim()
        : null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: appTheme.white_A700,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: appTheme.black_900_0c,
            offset: const Offset(0, 4),
            blurRadius: 16,
          ),
        ],
      ),
      child: Material(
        color: appTheme.white_A700,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            Navigator.of(context).pushNamed(
              '/activityScreen',
              arguments: {'trip': trip, 'forceViewOnly': true},
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: Stack(
                  children: [
                    _buildTripBanner(
                      activeImageUrl,
                      destination: trip.destination,
                    ),
                    if (isPending)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Material(
                          color: appTheme.transparentCustom,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _confirmDelete(context, trip),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: appTheme.blueGray900,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: appTheme.redButton,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isTerminated
                              ? appTheme.wholeAlertBudgetBg
                              : isOngoing
                              ? appTheme.amber_200
                              : isCompleted
                              ? appTheme.gray_200
                              : appTheme.amber_200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isTerminated
                                  ? Icons.cancel_outlined
                                  : isOngoing
                                  ? Icons.play_circle_outline
                                  : Icons.check_circle_outline,
                              size: 14,
                              color: isTerminated
                                  ? appTheme.errorRed
                                  : isOngoing
                                  ? appTheme.lime_900
                                  : isCompleted
                                  ? appTheme.gray_800
                                  : appTheme.lime_900,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              status.isNotEmpty
                                  ? status[0].toUpperCase() +
                                        status.substring(1)
                                  : 'Pending',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Inter',
                                color: isTerminated
                                    ? appTheme.errorRed
                                    : isOngoing
                                    ? appTheme.lime_900
                                    : isCompleted
                                    ? appTheme.gray_800
                                    : appTheme.lime_900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.destination,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                        color: appTheme.gray_900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: appTheme.gray_100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 14,
                                color: appTheme.teal_A700,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$startDateStr - $endDateStr',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Inter',
                                  color: appTheme.gray_800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DualCurrencyAmount(
                          amount: trip.totalBudget.toDouble(),
                          baseCurrency: 'MYR',
                          baseLabel: 'MYR',
                          primaryStyle: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                            color: appTheme.gray_900,
                          ),
                          secondaryStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Inter',
                            color: appTheme.blue_gray_700,
                          ),
                          crossAxisAlignment: CrossAxisAlignment.end,
                          textAlign: TextAlign.end,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripBanner(String? imageUrl, {required String destination}) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildFallbackBanner(destination),
      );
    }
    return _buildFallbackBanner(destination);
  }

  Widget _buildFallbackBanner(String destination) {
    return Container(
      height: 180,
      width: double.infinity,
      color: appTheme.gray_200,
      child: Center(
        child: Icon(Icons.landscape, size: 48, color: appTheme.blue_gray_300),
      ),
    );
  }

  // weisong
  // delete the trip only when it is still pending status in view all plan screen from profile
  Future<void> _confirmDelete(BuildContext context, WholeTrip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Plan'),
        content: Text(
          'Are you sure you want to delete your trip to ${trip.destination}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: appTheme.redButton),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<WholeItineraryDetailViewModel>().deletePendingTrip(
        trip.tripId,
      );
    }
  }
}
