import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/entities/activity.dart';
import '../theme/app_theme.dart';
import '../utils/date_time_formatter.dart';
import '../view_models/presentation_logic/activity_view_model.dart';
import '../view_models/ui_state/activity_ui_state.dart';
import '../widgets/custom_app_bar.dart';
import 'expense_bottom_sheet.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  static Widget builder(BuildContext context) {
    return ChangeNotifierProvider<ActivityViewModel>(
      create: (context) => ActivityViewModel(),
      child: const ActivityScreen(),
    );
  }

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  bool _isInit = false;
  String _destination = 'Trip Itinerary';
  DateTime? _filterDate;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments;
      String? extractedTripId;

      if (args is Map<String, dynamic>) {
        if (args['filterDate'] is DateTime) {
          _filterDate = args['filterDate'] as DateTime;
        }

        if (args['trip'] != null) {
          final innerTrip = args['trip'];
          if (innerTrip is Map) {
            extractedTripId =
                (innerTrip['tripId'] ??
                    innerTrip['trip_id'] ??
                    innerTrip['dayTripId'])
                    ?.toString();
            if (innerTrip['destination'] != null) {
              _destination = innerTrip['destination'].toString();
            }
          } else {
            extractedTripId =
                (innerTrip as dynamic).tripId ??
                    (innerTrip as dynamic).dayTripId;
            try {
              if ((innerTrip as dynamic).destination != null) {
                _destination = (innerTrip as dynamic).destination.toString();
              }
            } catch (_) {}
          }
        } else {
          extractedTripId =
              (args['tripId'] ?? args['trip_id'] ?? args['dayTripId'])
                  ?.toString();
        }
      } else if (args != null) {
        try {
          extractedTripId =
              (args as dynamic).tripId ?? (args as dynamic).dayTripId;
          if ((args as dynamic).destination != null) {
            _destination = (args as dynamic).destination.toString();
          }
        } catch (_) {
          extractedTripId = null;
        }
      }

      if (extractedTripId != null && extractedTripId.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.read<ActivityViewModel>().loadTripItinerary(
              extractedTripId!,
              filterDate: _filterDate,
            );
          }
        });
      } else {
        debugPrint(
          'Warning: Could not resolve tripId from navigation arguments.',
        );
      }

      _isInit = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ActivityViewModel>();
    final uiState = viewModel.uiState;

    return Scaffold(
      backgroundColor: appTheme.gray_50_03,
      appBar: CustomAppBar(
        title: uiState.filterDate != null ? "Today's Schedule" : 'Activities',
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(top: 24.0, left: 24.0, right: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLocationHeader(_destination, uiState.filterDate),
              const SizedBox(height: 24.0),
              _buildBudgetCard(uiState),
              const SizedBox(height: 32.0),
              _buildTimeline(uiState, viewModel),
              const SizedBox(height: 40.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationHeader(String destination, DateTime? filterDate) {
    final String subTitle = filterDate != null
        ? DateFormat('EEEE, MMM dd').format(filterDate)
        : 'Full Itinerary';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          destination.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            fontFamily: 'Inter',
            color: appTheme.teal_800,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8.0),
        Text(
          subTitle,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            fontFamily: 'Inter',
            color: appTheme.gray_900,
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
              Text(
                'Total Budget',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Inter',
                  color: appTheme.gray_900,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: appTheme.teal_50,
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Text(
                  uiState.usedPercentageString,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Inter',
                    color: appTheme.teal_700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'USAGE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Inter',
                  color: appTheme.gray_800,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'RM ${uiState.spentBudget.toStringAsFixed(2)} / RM ${uiState.totalBudget.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Inter',
                  color: appTheme.gray_900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Container(
            height: 8.0,
            width: double.infinity,
            decoration: BoxDecoration(
              color: appTheme.gray_200,
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
                      color: appTheme.teal_A700,
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
                  amountColor: appTheme.gray_900,
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
                  amountColor: appTheme.gray_900,
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
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              fontFamily: 'Inter',
              color: appTheme.gray_800,
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

  Widget _buildTimeline(ActivityUiState uiState, ActivityViewModel viewModel) {
    if (uiState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final activities = uiState.displayActivities;

    if (activities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32.0),
          child: Text(
            uiState.filterDate != null
                ? 'No activities scheduled for today'
                : 'No activities scheduled for this trip',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: 'Inter',
              color: appTheme.blue_gray_300,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        final isLast = index == activities.length - 1;
        return _buildTimelineItem(
          activity: activity,
          isLast: isLast,
          uiState: uiState,
          viewModel: viewModel,
        );
      },
    );
  }

  Widget _buildTimelineItem({
    required Activity activity,
    required bool isLast,
    required ActivityUiState uiState,
    required ActivityViewModel viewModel,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimelineIndicatorColumn(isLast: isLast),
          const SizedBox(width: 16.0),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateTimeFormatter.formatDisplayTime(activity),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                      color: appTheme.gray_800,
                    ).copyWith(height: 1.2),
                  ),
                  const SizedBox(height: 12.0),
                  _buildActivityCard(
                    activity,
                    uiState,
                    onTap: () {
                      viewModel.selectActivityForExpense(activity);

                      showExpenseBottomSheet(
                        context: context,
                        activity: activity,
                        viewModel: viewModel,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineIndicatorColumn({required bool isLast}) {
    return SizedBox(
      width: 24.0,
      child: Column(
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
            Expanded(
              child: Container(
                width: 2.0,
                color: appTheme.gray_200,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(
      Activity activity,
      ActivityUiState uiState, {
        VoidCallback? onTap,
      }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: appTheme.white_A700,
            border: Border.all(color: appTheme.blue_gray_50, width: 1),
            borderRadius: BorderRadius.circular(12),
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
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: _buildAdaptiveImage(activity.activityImgUrl),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
                child: Text(
                  activity.destination,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Inter',
                    color: appTheme.gray_900,
                  ).copyWith(height: 1.2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12, left: 20, right: 20),
                child: Text(
                  activity.description,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Inter',
                    color: appTheme.gray_800,
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
                    if (activity.duration != null &&
                        activity.duration!.isNotEmpty)
                      _buildChip(
                        label: activity.duration!,
                        backgroundColor: appTheme.teal_A200,
                        textColor: appTheme.teal_800,
                      ),
                    _buildChip(
                      label: 'RM${activity.allocatedBudget.toStringAsFixed(0)}',
                      backgroundColor: appTheme.amber_200,
                      textColor: appTheme.lime_900,
                    ),
                    if (activity.isOverspend == true &&
                        activity.overspendAmount != null)
                      _buildChip(
                        label:
                        'RM${activity.overspendAmount!.toStringAsFixed(0)}',
                        backgroundColor: appTheme.blue_gray_50,
                        textColor: appTheme.blueGray900,
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

  Widget _buildAdaptiveImage(String url) {
    const double height = 180.0;

    if (url.isEmpty) {
      return _buildImagePlaceholder(height);
    }

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: height,
            color: appTheme.gray_100,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Image load error for URL $url: $error');
          return _buildImagePlaceholder(height);
        },
      );
    }

    return Image.asset(
      url,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return _buildImagePlaceholder(height);
      },
    );
  }

  Widget _buildImagePlaceholder(double height) {
    return Container(
      height: height,
      width: double.infinity,
      color: appTheme.gray_200,
      child: Icon(Icons.terrain, size: 40, color: appTheme.blue_gray_300),
    );
  }
}

class BaseBudgetDialog extends StatelessWidget {
  final String title;
  final Widget summaryCard;
  final String warningText;
  final Widget? contentCard;
  final Widget actions;

  const BaseBudgetDialog({
    super.key,
    required this.title,
    required this.summaryCard,
    required this.warningText,
    this.contentCard,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: appTheme.warningPopupHeader,
                ),
              ),
              const SizedBox(height: 16),
              summaryCard,
              const SizedBox(height: 16),
              _buildWarningRow(warningText),
              const SizedBox(height: 16),
              if (contentCard != null) ...[
                contentCard!,
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 8),
              actions,
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildWarningRow(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.warning_amber_rounded,
          color: appTheme.popupWarningMsg,
          size: 22,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: appTheme.popupWarningMsg,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  static Widget buildTagChip({
    required String label,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

Future<void> showBudgetExceededDialog({
  required BuildContext context,
  required String allocatedBudget,
  required String remainingBudget,
  required String exceededAmount,
  required String warningText1,
  required String warningText2,
  VoidCallback? onContinue,
}) {
  return showDialog(
    context: context,
    builder: (context) {
      return BaseBudgetDialog(
        title: 'Budget Exceeded',
        summaryCard: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: appTheme.popupCreamBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: appTheme.popupCreamStroke),
          ),
          child: Column(
            children: [
              _buildSummaryRow('Allocated Budget:', allocatedBudget),
              const SizedBox(height: 12),
              _buildSummaryRow('Remaining Budget:', remainingBudget),
              const SizedBox(height: 12),
              _buildSummaryRow(
                'Exceeded Amount',
                exceededAmount,
                valueColor: appTheme.warningPopupHeader,
              ),
            ],
          ),
        ),
        warningText: warningText1,
        contentCard: Column(
          children: [
            BaseBudgetDialog._buildWarningRow(warningText2),
          ],
        ),
        actions: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: appTheme.teal_A700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              'Continue',
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
                color: appTheme.white_A700,
              ),
            ),
          ),
        ),
      );
    },
  );
}

Future<void> showBudgetExceeded20Dialog({
  required BuildContext context,
  required String allocatedBudget,
  required String remainingBudget,
  required String exceededAmount,
  required String warningText1,
  required String estimatedDays,
  required String warningText3,
  VoidCallback? onContinue,
}) {
  return showDialog(
    context: context,
    builder: (context) {
      return BaseBudgetDialog(
        title: 'Budget Exceeded',
        summaryCard: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: appTheme.popupCreamBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: appTheme.popupCreamStroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Allocated Budget:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: appTheme.warningPopupHeader,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                allocatedBudget,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: appTheme.black,
                ),
              ),
              const SizedBox(height: 12),
              Divider(color: appTheme.popupCreamStroke, height: 1),
              const SizedBox(height: 12),
              _buildSummaryRow('Remaining Budget:', remainingBudget),
              const SizedBox(height: 12),
              _buildSummaryRow(
                'Exceeded Amount',
                exceededAmount,
                valueColor: appTheme.warningPopupHeader,
              ),
            ],
          ),
        ),
        warningText: warningText1,
        contentCard: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: appTheme.popupWarningMsg,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 14,
                        color: appTheme.popupWarningMsg,
                        height: 1.4,
                      ),
                      children: [
                        const TextSpan(
                          text:
                          'Based on your current spending rate, your remaining budget is estimated to last ',
                        ),
                        TextSpan(
                          text: '$estimatedDays more day(s)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(
                          text:
                          '. Please review your spending to avoid running out of budget.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            BaseBudgetDialog._buildWarningRow(warningText3),
          ],
        ),
        actions: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: appTheme.teal_700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              if (onContinue != null) {
                onContinue();
              }
            },
            child: Text(
              'Continue',
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
                color: appTheme.white_A700,
              ),
            ),
          ),
        ),
      );
    },
  );
}

Future<void> showBudgetRecoveryDialog({
  required BuildContext context,
  required String shortageAmount,
  required String remainingBudget,
  required String warningText,
  VoidCallback? onEndTrip,
  required Future<bool> Function(double amount) onTopUpBudget,
}) {
  final TextEditingController topUpController = TextEditingController();

  return showDialog(
    context: context,
    builder: (context) {
      return BaseBudgetDialog(
        title: 'Budget Recovery',
        summaryCard: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: appTheme.popupCreamBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: appTheme.popupCreamStroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Budget Shortage Amount:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: appTheme.popupBrownBudget,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                shortageAmount,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: appTheme.black,
                ),
              ),
              const SizedBox(height: 12),
              Divider(color: appTheme.popupCreamStroke, height: 1),
              const SizedBox(height: 12),
              _buildSummaryRow('Remaining Budget:', remainingBudget),
            ],
          ),
        ),
        warningText: warningText,
        contentCard: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: appTheme.black.withAlpha(8),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TOP-UP AMOUNT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: appTheme.blue_gray_300,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: topUpController,
                keyboardType: TextInputType.number,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: appTheme.black,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Colors.grey,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: appTheme.white_A700,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: appTheme.blue_gray_300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: appTheme.teal_A700,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appTheme.redButton,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (onEndTrip != null) {
                      onEndTrip();
                    }
                  },
                  child: Text(
                    'End Trip',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: appTheme.white_A700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appTheme.teal_A700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final amountText = topUpController.text.trim();
                    final amount = double.tryParse(amountText);

                    if (amount == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid top-up amount.'),
                        ),
                      );
                      return;
                    }

                    final success = await onTopUpBudget(amount);

                    if (success && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text(
                    'Top-up Budget',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: appTheme.white_A700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: appTheme.popupBrownBudget,
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: valueColor ?? appTheme.black,
        ),
      ),
    ],
  );
}