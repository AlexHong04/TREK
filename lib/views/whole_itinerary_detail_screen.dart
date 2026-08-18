import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/entities/activity.dart';
import '../view_models/presentation_logic/whole_itinerary_detail_view_model.dart';
import '../main.dart';

class WholeItineraryDetailScreen extends StatefulWidget {
  const WholeItineraryDetailScreen({super.key});

  static Widget builder(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    return ChangeNotifierProvider<WholeItineraryDetailViewModel>(
      create: (context) {
        final vm = WholeItineraryDetailViewModel();
        vm.initialize(
          destination: args?['destination'] as String? ?? 'Unknown',
          dates: args?['dates'] as String? ?? '',
          budget: args?['budget'] as String? ?? '0',
          preference: args?['preference'] as String?,
          emergencyFund: args?['emergencyFund'] as String?,
        );
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
  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<WholeItineraryDetailViewModel>();
    return Scaffold(
      backgroundColor: appTheme.gray_50_03,
      appBar: _buildAppBar(context),
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
                    _buildTimeline(context, viewModel),
                    SizedBox(height: 10.0),
                  ],
                ),
              ),
            ),
          ),
          _buildBottomSection(context, viewModel),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: appTheme.white_A700,
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: appTheme.teal_A700),
        onPressed: () => Navigator.maybePop(context),
      ),
      toolbarHeight: 60,
      titleSpacing: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: appTheme.blue_gray_50),
      ),
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                'Vibrant Odyssey',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                  fontSize: 18,
                  color: appTheme.teal_A700,
                ).copyWith(height: 1.2),
              ),
            ),
          ],
        ),
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
                viewModel.datesText.isNotEmpty ? viewModel.datesText : 'Dates',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                  color: AppColors.gray800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Overview',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Inter',
                  color: AppColors.gray900,
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
                  color: const Color(0xFFCCFBF1), // Teal 50
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${viewModel.uiState.activities.length} Stops Planned',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Inter',
                    color: Color(0xFF0F766E), // Teal 700
                  ),
                ),
              ),
              Text(
                'RM${viewModel.budgetText}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Inter',
                  color: Color(0xFF14BBA6), // Teal A700
                ),
              ),
            ],
          ),
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
            viewModel.destinationTitle.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              fontFamily: 'Inter',
              color: AppColors.teal800,
            ),
          ),
        ),
        const SizedBox(height: 6.0),
        const Padding(
          padding: EdgeInsets.only(left: 8.0),
          child: Text(
            'Whole Itinerary',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              fontFamily: 'Inter',
              color: AppColors.gray900,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline(
    BuildContext context,
    WholeItineraryDetailViewModel viewModel,
  ) {
    if (viewModel.uiState.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: appTheme.teal_A700),
      );
    }

    final activities = viewModel.uiState.activities;
    return Column(
      children: List.generate(activities.length, (index) {
        final activity = activities[index];
        final isLast = index == activities.length - 1;
        return _buildTimelineItem(
          context: context,
          activity: activity,
          isLast: isLast,
          onRemove: () => viewModel.removeActivity(activity.activitiesId),
        );
      }),
    );
  }

  Widget _buildTimelineItem({
    required BuildContext context,
    required Activity activity,
    required bool isLast,
    required VoidCallback onRemove,
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
                    DateFormat('hh:mm a').format(activity.date),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                      color: AppColors.gray800,
                    ).copyWith(height: 1.2),
                  ),
                  GestureDetector(
                    onTap: onRemove,
                    child: Icon(
                      Icons
                          .cancel_outlined, // or close/cancel depending on the look, but cancel is similar to a red 'x' pill or bordered x
                      color: AppColors.errorRed,
                      size: 20,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.0),
              _buildActivityCard(activity),
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
        if (!isLast)
          Container(width: 2.0, height: 380.0, color: const Color(0xFFCBD5E1)),
      ],
    );
  }

  Widget _buildBottomSection(
    BuildContext context,
    WholeItineraryDetailViewModel viewModel,
  ) {
    return Container(
      color: appTheme.gray_50_03,
      padding: EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: appTheme.teal_A700,
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
            onTap: () async {
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
                      'Itinerary saved to database successfully! ✨',
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
            },
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
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
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

  Widget _buildActivityCard(Activity activity) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.blueGray50, width: 1),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.black900_0c,
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
              activity.destination ?? '',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
                color: AppColors.gray900,
              ).copyWith(height: 25 / 20),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 20, right: 20),
            child: Text(
              activity.description ?? '',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                fontFamily: 'Inter',
                color: AppColors.gray800,
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
              children: [
                if (activity.duration != null && activity.duration!.isNotEmpty)
                  _buildChip(
                    label: activity.duration!,
                    backgroundColor: const Color(0xFF64FFDA), // Neon cyan/green
                    textColor: AppColors.teal700,
                  ),
                _buildChip(
                  label: 'RM${activity.allocatedBudget.toStringAsFixed(0)}',
                  backgroundColor: AppColors.amber200,
                  textColor: AppColors.lime900,
                ),
                if (activity.isOverspend == true &&
                    activity.overspendAmount != null)
                  _buildChip(
                    label: 'RM${activity.overspendAmount!.toStringAsFixed(0)}',
                    backgroundColor: const Color(0xFFFFCDD2), // Light Red
                    textColor: const Color(0xFFD32F2F), // Dark Red
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
