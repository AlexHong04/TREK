import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/entities/activity.dart';
import '../view_models/presentation_logic/day_itinerary_detail_view_model.dart';
import '../main.dart';

class DayItineraryDetailScreen extends StatefulWidget {
  const DayItineraryDetailScreen({super.key});

  static Widget builder(BuildContext context) {
    return ChangeNotifierProvider<DayItineraryDetailViewModel>(
      create: (context) => DayItineraryDetailViewModel()..initialize(),
      child: DayItineraryDetailScreen(),
    );
  }

  @override
  State<DayItineraryDetailScreen> createState() =>
      _DayItineraryDetailScreenState();
}

class _DayItineraryDetailScreenState extends State<DayItineraryDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DayItineraryDetailViewModel>();
    return Scaffold(
      backgroundColor: appTheme.gray_50_03,
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(top: 36.0, left: 16.0, right: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLocationHeader(),
                    SizedBox(height: 44.0),
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

  Widget _buildLocationHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 8.0),
          child: Text(
            'KYOTO, JAPAN',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFamily: 'Inter',
              color: AppColors.teal800,
            ).copyWith(letterSpacing: 1, height: 17 / 14),
          ),
        ),
        SizedBox(height: 8.0),
        Padding(
          padding: EdgeInsets.only(left: 8.0),
          child: Text(
            'Day 1: Cultural\nImmersion',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              fontFamily: 'Inter',
              color: AppColors.gray900,
            ).copyWith(height: 37 / 30),
          ),
        ),
        SizedBox(height: 18.0),
        Padding(
          padding: EdgeInsets.only(left: 8.0),
          child: Text(
            "Discover the spiritual heart and culinary\nexcellence of Japan's ancient capital.",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              fontFamily: 'Inter',
              color: AppColors.gray800,
            ).copyWith(height: 26 / 16),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline(
    BuildContext context,
    DayItineraryDetailViewModel viewModel,
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
                    DateFormat('dd MMMM yyyy').format(activity.date),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Inter',
                      color: AppColors.gray800,
                    ).copyWith(height: 20 / 16),
                  ),
                  GestureDetector(
                    onTap: onRemove,
                    child: Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Icon(
                        Icons.close,
                        size: 14.0,
                        color: appTheme.blue_gray_700,
                      ),
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
          padding: EdgeInsets.all(4.0),
          decoration: BoxDecoration(
            color: appTheme.white_A700,
            border: Border.all(color: appTheme.teal_800, width: 4),
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Container(
            width: 6.0,
            height: 6.0,
            decoration: BoxDecoration(
              color: appTheme.teal_800,
              borderRadius: BorderRadius.circular(3.0),
            ),
          ),
        ),
        if (!isLast)
          Container(width: 2.0, height: 420.0, color: appTheme.blue_gray_50),
      ],
    );
  }

  Widget _buildBottomSection(
    BuildContext context,
    DayItineraryDetailViewModel viewModel,
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
            onTap: () => viewModel.onConfirmPressed(context),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 24,
                    color: appTheme.white_A700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Confirm',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Afacad',
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
            child:
                activity.activityImgUrl != null &&
                    activity.activityImgUrl!.isNotEmpty
                ? Image.asset(
                    activity.activityImgUrl!,
                    height: 192,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
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
                    backgroundColor: AppColors.tealA200,
                    textColor: AppColors.teal700,
                  ),
                _buildChip(
                  label: 'RM ${activity.allocatedBudget.toStringAsFixed(2)}',
                  backgroundColor: AppColors.amber200,
                  textColor: AppColors.lime900,
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
