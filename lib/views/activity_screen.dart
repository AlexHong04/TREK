import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../utils/date_time_formatter.dart';
import '../view_models/presentation_logic/activity_view_model.dart';
import '../view_models/ui_state/activity_ui_state.dart';
import '../widgets/custom_app_bar.dart';
import 'budget_popup.dart';
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

  void _handleUiStateChange() {
    if (!mounted) return;

    final viewModel = context.read<ActivityViewModel>();
    final state = viewModel.uiState;

    if (state.popupAction.isEmpty) {
      return;
    }

    switch (state.popupAction) {
      case 'successful':
        _showUnderThresholdDialog(state);
        break;

      case 'fail':
        _showFailedDialog(state);
        break;

      case 'recommendation':
        _showExceedsThresholdDialog(state);
        break;

      case 'critical':
        _showBudgetRecoveryDialog(
          state,
          onEndTrip: viewModel.endTrip,
          onTopUpBudget: (amount) => viewModel.topUpBudget(amount),
        );
        break;
    }

    viewModel.clearPopupAction();
  }

  void _showUnderThresholdDialog(ActivityUiState state) {
    showBudgetExceededDialog(
      context: context,
      allocatedBudget:
      'RM ${state.selectedActivity?.allocatedBudget.toStringAsFixed(2)}',
      remainingBudget: state.remainingBudget.toString(),
      exceededAmount: state.overspentBudget.toString(),
      warningText1:
      'You have overspent ${state.overspentBudget} so far on this trip.',
      warningText2:
      'The budget allocated for remaining restaurants have been modified.',
      onContinue: () {
        Navigator.pop(context);
      },
    );
  }

  void _showFailedDialog(ActivityUiState state) {
    // show your failed dialog
  }

  void _showExceedsThresholdDialog(ActivityUiState state) {
    showBudgetExceeded20Dialog(
      context: context,
      allocatedBudget:
      'RM ${state.selectedActivity?.allocatedBudget.toStringAsFixed(2)}',
      remainingBudget: state.remainingBudget.toStringAsFixed(2),
      exceededAmount: state.shortageAmount.toStringAsFixed(2),
      warningText1:
      'You have overspent ${state.overspentBudget} so far on this trip.',
      estimatedDays: state.sufficientDays.toString(),
      warningText3: 'Plan will be modified automatically.',
      onContinue: () {
        // Handle action
      },
    );
  }

  void _showBudgetRecoveryDialog(
      ActivityUiState uiState, {
        required VoidCallback onEndTrip,
        required Future<bool> Function(double amount) onTopUpBudget,
      }) {
    showBudgetRecoveryDialog(
      context: context,
      shortageAmount: uiState.shortageAmount.toString(),
      remainingBudget: uiState.remainingBudget.toString(),
      warningText:
      'Insufficient top-up amount will trigger alternative recommendation directly.',
      onEndTrip: onEndTrip,
      onTopUpBudget: (amount) async {
        final success = await onTopUpBudget(amount);

        if (!context.mounted) return false;

        if (!success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to top up budget.')),
          );
        }

        return success;
      },
    );
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
          ClipRRect(
            borderRadius: BorderRadius.circular(4.0),
            child: LinearProgressIndicator(
              value: uiState.usedPercentageValue,
              minHeight: 8.0,
              backgroundColor: appTheme.gray_200,
              valueColor: AlwaysStoppedAnimation<Color>(appTheme.teal_A700),
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
                    onTap: () async {
                      viewModel.selectActivityForExpense(activity);

                      await showExpenseBottomSheet(
                        context: context,
                        activity: activity,
                        viewModel: viewModel,
                      );

                      _handleUiStateChange();
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
            Expanded(child: Container(width: 2.0, color: appTheme.gray_200)),
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
