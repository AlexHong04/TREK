import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/entities/activity.dart';
import '../../view_models/presentation_logic/day_itinerary_detail_view_model.dart';

import '../theme/app_theme.dart';
// image_constant and size_utils removed per user request
import '../widgets/activity_card_widget.dart';
import '../widgets/custom_app_bar.dart';

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
      appBar: CustomAppBar(
        title: 'Vibrant Odyssey',
        // leadingImagePath removed - asset doesn't exist
        onLeadingTap: () => Navigator.of(context).pop(),
        titleColor: appTheme.teal_A700,
        titleFontSize: 18,
        backgroundColor: appTheme.white_A700,
        bottomBorderColor: appTheme.blue_gray_50,
        paddingHorizontal: 16,
        paddingVertical: 16,
        leadingIconSize: 40,
      ),
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
          onRemove: () => viewModel.removeActivity(activity.id ?? ''),
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
                    activity.time ?? '',
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
              ActivityCardWidget(activity: activity),
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
}
