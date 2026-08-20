import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/entities/activity.dart';
import '../view_models/presentation_logic/activity_view_model.dart';
import '../view_models/ui_state/activity_ui_state.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  static Widget builder(BuildContext context) {
    return ChangeNotifierProvider<ActivityViewModel>(
      create: (context) => ActivityViewModel()..initialize(),
      child: const ActivityScreen(),
    );
  }

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ActivityViewModel>();
    final uiState = viewModel.uiState;

    return Scaffold(
      backgroundColor: appTheme.gray_50_03,
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(top: 24.0, left: 24.0, right: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLocationHeader(),
              const SizedBox(height: 24.0),
              _buildBudgetCard(uiState),
              const SizedBox(height: 32.0),
              _buildTimeline(uiState),
              const SizedBox(height: 40.0),
            ],
          ),
        ),
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

  Widget _buildLocationHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'KYOTO, JAPAN',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            fontFamily: 'Inter',
            color: AppColors.teal800,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8.0),
        const Text(
          'Day 1: Cultural\nImmersion',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            fontFamily: 'Inter',
            color: AppColors.gray900,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetCard(ActivityUiState uiState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: appTheme.white_A700,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: appTheme.black_900_0c,
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Budget',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Inter',
                  color: AppColors.gray900,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: appTheme.teal_50, // replaced emerald-100
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Text(
                  uiState.usedPercentageString,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Inter',
                    color: appTheme.teal_700, // replaced emerald-600
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'USAGE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Inter',
                  color: AppColors.gray800,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'RM ${uiState.spentBudget.toStringAsFixed(2)} / RM ${uiState.totalBudget.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Inter',
                  color: AppColors.gray900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Container(
            height: 8.0,
            width: double.infinity,
            decoration: BoxDecoration(
              color: appTheme.gray_200, // gray-200
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: (uiState.usedPercentageValue * 100).toInt().clamp(
                    0,
                    100,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: appTheme.teal_A700, // replaced emerald-500
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                  ),
                ),
                Expanded(
                  flex:
                      100 -
                      (uiState.usedPercentageValue * 100).toInt().clamp(0, 100),
                  child: const SizedBox(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24.0),
          Row(
            children: [
              Expanded(
                child: _buildSubBudgetCard(
                  title: 'SPENT',
                  amount: 'RM ${uiState.spentBudget.toStringAsFixed(2)}',
                  amountColor: AppColors.gray900,
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: _buildSubBudgetCard(
                  title: 'REMAINING',
                  amount: 'RM ${uiState.remainingBudget.toStringAsFixed(2)}',
                  amountColor: appTheme.teal_A700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          Row(
            children: [
              Expanded(
                child: _buildSubBudgetCard(
                  title: 'OVERSPENT',
                  amount: 'RM ${uiState.overspentBudget.toStringAsFixed(2)}',
                  amountColor: AppColors.gray900,
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: _buildSubBudgetCard(
                  title: 'SUFFICIENT FOR',
                  amount: '${uiState.sufficientDays} DAYS',
                  amountColor: appTheme.teal_A700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubBudgetCard({
    required String title,
    required String amount,
    required Color amountColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: appTheme.white_A700,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: appTheme.gray_100, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              fontFamily: 'Inter',
              color: AppColors.gray800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6.0),
          Text(
            amount,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              fontFamily: 'Inter',
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(ActivityUiState uiState) {
    if (uiState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final activities = uiState.activities;
    return Column(
      children: List.generate(activities.length, (index) {
        final activity = activities[index];
        final isLast = index == activities.length - 1;
        return _buildTimelineItem(activity: activity, isLast: isLast);
      }),
    );
  }

  Widget _buildTimelineItem({
    required Activity activity,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTimelineIndicatorColumn(isLast: isLast),
        const SizedBox(width: 20.0),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 12.0),
              _buildActivityCard(activity),
              if (!isLast) const SizedBox(height: 32.0),
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
          Container(
            width: 2.0,
            height: 420.0, // adjusted height based on content
            color: appTheme.gray_200, // Slate 300 equivalent
          ),
      ],
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
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: activity.activityImgUrl.isNotEmpty
                ? Image.asset(
                    activity.activityImgUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Container(height: 180, color: appTheme.gray_200),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
            child: Text(
              activity.destination,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFamily: 'Inter',
                color: AppColors.gray900,
              ).copyWith(height: 1.2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12, left: 20, right: 20),
            child: Text(
              activity.description,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                fontFamily: 'Inter',
                color: AppColors.gray800,
              ).copyWith(height: 1.5),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              top: 16,
              left: 20,
              right: 20,
              bottom: 20,
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (activity.duration != null && activity.duration!.isNotEmpty)
                  _buildChip(
                    label: activity.duration!,
                    backgroundColor: appTheme.teal_A200,
                    textColor: appTheme.teal_800,
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
                    backgroundColor: appTheme.blue_gray_50,
                    textColor: AppColors.blueGray900,
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
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          fontFamily: 'Inter',
          color: textColor,
        ).copyWith(height: 1.2),
      ),
    );
  }
}
