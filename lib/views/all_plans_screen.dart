// lib/views/all_plans_screen.dart

import 'package:Trek/main.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/entities/whole_trip.dart';
import '../theme/app_theme.dart';
import '../view_models/presentation_logic/whole_itinerary_detail_view_model.dart';
import '../view_models/ui_state/whole_itinerary_ui_state.dart';

class AllPlansScreen extends StatefulWidget {
  const AllPlansScreen({super.key});

  static Widget builder(BuildContext context) {
    return ChangeNotifierProvider<WholeItineraryDetailViewModel>(
      create: (_) => WholeItineraryDetailViewModel(),
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
      appBar: AppBar(
        backgroundColor: appTheme.white_A700,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: appTheme.teal_800),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'All Plan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            fontFamily: 'Inter',
            color: appTheme.teal_800,
          ),
        ),
      ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FILTER BY TRIP STATUS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              fontFamily: 'Inter',
              color: appTheme.gray_800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10.0),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(color: appTheme.gray_200),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: uiState.selectedStatusFilter,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down),
                items: const [
                  DropdownMenuItem(value: 'All Plans', child: Text('All Plans')),
                  DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'Ongoing', child: Text('Ongoing')),
                  DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    viewModel.setStatusFilter(value);
                  }
                },
              ),
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
      separatorBuilder: (_, __) => const SizedBox(height: 16.0),
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
              AppRoutes.wholeItineraryDetailScreen,
              arguments: {'tripID': trip.tripId, 'trip': trip, 'isReadOnly': false},
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
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isOngoing
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
                              isOngoing
                                  ? Icons.play_circle_outline
                                  : Icons.check_circle_outline,
                              size: 14,
                              color: isOngoing
                                  ? appTheme.lime_900
                                  : isCompleted
                                  ? appTheme.gray_800
                                  : appTheme.lime_900,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              status.isNotEmpty
                                  ? status[0].toUpperCase() + status.substring(1)
                                  : 'Pending',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Inter',
                                color: isOngoing
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
                        Text(
                          'RM${trip.totalBudget.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                            color: appTheme.gray_900,
                          ),
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
        errorBuilder: (_, __, ___) => _buildFallbackBanner(destination),
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
}