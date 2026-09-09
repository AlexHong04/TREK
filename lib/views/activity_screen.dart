import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../utils/date_time_formatter.dart';
import '../main.dart';
import '../models/services/i_auth_service.dart';
import '../view_models/presentation_logic/activity_view_model.dart';
import '../view_models/ui_state/activity_ui_state.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/dual_currency_amount.dart';
import 'budget_popup.dart';
import 'expense_bottom_sheet.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  static Widget builder(BuildContext context) {
    return ChangeNotifierProvider<ActivityViewModel>(
      create: (context) => ActivityViewModel(
        authService: context.read<IAuthService>(),
      ),
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
      final args = ModalRoute
          .of(context)
          ?.settings
          .arguments;
      String? extractedTripId;

      if (args is Map<String, dynamic>) {
        if (args['filterDate'] is DateTime) {
          _filterDate = args['filterDate'] as DateTime;
        } else {
          final now = DateTime.now();
          _filterDate = DateTime(now.year, now.month, now.day);
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
      } else {
        final now = DateTime.now();
        _filterDate = DateTime(now.year, now.month, now.day);
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
    final action = state.popupAction;

    if (action.isEmpty) return;

    viewModel.clearPopupAction();

    switch (action) {
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
          onTopUpBudget: (amount) =>
              viewModel.topUpBudget(amount),
        );
        break;
    }
  }

  /// The overspent amount for the single activity the user just recorded an
  /// expense for (spent - allocated when over budget), NOT the whole trip.
  double _activityExceededAmount(ActivityUiState state) {
    Activity? activity = state.selectedActivity;
    if (activity == null) {
      for (final candidate in state.activities) {
        if (candidate.activitiesId == state.currentActivityId) {
          activity = candidate;
          break;
        }
      }
    }
    if (activity == null) return state.exceededAmount;

    final spent = state.activitySpentMap[activity.activitiesId] ?? 0.0;
    final exceeded = spent - activity.allocatedBudget;
    return exceeded > 0 ? exceeded : state.exceededAmount;
  }

  void _showUnderThresholdDialog(ActivityUiState state) {
    showBudgetExceededDialog(
      context: context,
      allocatedBudget:
      '${state.displayCurrency} ${state.selectedActivity?.allocatedBudget.toStringAsFixed(2)}',
      remainingBudget: '${state.displayCurrency} ${state.remainingBudget.toStringAsFixed(2)}',
      exceededAmount: '${state.displayCurrency} ${state.exceededAmount.toStringAsFixed(2)}',
      warningText1:
      'You have overspent ${state.displayCurrency} ${state.overspentBudget.toStringAsFixed(2)} so far for entire trip.',
      warningText2:
      'The budget allocated for remaining restaurants have been modified.',
    );
  }

  void _showFailedDialog(ActivityUiState state) {
    showBudgetReallocationFailureDialog(
      context: context,
      onContinue: () async {
        // 1. Dismiss the dialog
        Navigator.of(context, rootNavigator: true).pop();

        // 2. Trigger the budget recovery plan generation
        final viewModel = context.read<ActivityViewModel>();
        final success = await viewModel.generateBudgetRecoveryPlan(
          dayTripId: state.selectedActivity?.dayTripId,
          availableBudget: state.totalBudget - state.spentBudget,
        );

        // 3. Optional: Provide UI feedback if recovery fails
        if (!success && mounted) {
          final error = viewModel.uiState.errorMessage;
          if (error.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error),
              ),
            );
          }
        }
      },
    );
  }

  void _showExceedsThresholdDialog(ActivityUiState state) {
    showBudgetExceededThresholdDialog(
      context: context,
      allocatedBudget:
      '${state.displayCurrency} ${state.selectedActivity?.allocatedBudget.toStringAsFixed(2)}',
      remainingBudget: '${state.displayCurrency} ${state.remainingBudget.toStringAsFixed(2)}',
      exceededAmount: '${state.displayCurrency} ${state.exceededAmount.toStringAsFixed(2)}',
      warningText1:
      'You have overspent ${state.displayCurrency} ${state.overspentBudget.toStringAsFixed(2)} so far on this trip.',
      estimatedDays: state.sufficientDays.toString(),
      warningText3: 'Plan will be modified automatically.',
      onContinue: () async {
        // 1. Show a labelled, non-dismissible loading dialog while the plan is
        // being re-optimized (instead of the bare screen-wide spinner).
        BuildContext? loadingDialogContext;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) {
            loadingDialogContext = dialogCtx;
            return PopScope(
              canPop: false,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    color: appTheme.white_A700,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: appTheme.teal_A700),
                      const SizedBox(height: 16),
                      Text(
                        'Re-optimizing your itinerary...',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                          color: appTheme.gray_900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );

        // 2. Trigger the budget recovery plan generation. Always dismiss the
        // loading dialog afterwards, even if generation throws.
        final viewModel = context.read<ActivityViewModel>();
        bool success;
        try {
          success = await viewModel.generateBudgetRecoveryPlan(
            dayTripId: state.selectedActivity?.dayTripId,
            availableBudget: state.totalBudget - state.spentBudget,
          );
        } catch (e) {
          debugPrint('Recovery plan error: $e');
          success = false;
        } finally {
          if (loadingDialogContext != null &&
              loadingDialogContext!.mounted) {
            Navigator.of(loadingDialogContext!, rootNavigator: true).pop();
          }
        }

        if (!mounted) return;

        if (success) {
          showThreeSecondMessage(
            context,
            'Your plan has been optimized to fit your remaining budget.',
          );
          // 4. Take the tourist straight to the updated plan so they can see
          // the re-optimized (future) activities instead of a static screen.
          Navigator.of(context).pushNamed(
            AppRoutes.wholeItineraryDetailScreen,
            arguments: <String, dynamic>{
              'isReadOnly': true,
              'tripId': viewModel.uiState.tripId,
            },
          );
        } else {
          final error = viewModel.uiState.errorMessage;
          showThreeSecondMessage(
            context,
            error.isNotEmpty
                ? error
                : 'Failed to optimize the plan. Please try again.',
            isError: true,
          );
        }
      },
    );
  }

  void _showBudgetRecoveryDialog(ActivityUiState uiState, {
    required VoidCallback onEndTrip,
    required Future<bool> Function(double amount) onTopUpBudget,
  }) {
    final minTopUp = uiState.shortageAmount * 0.50;
    showBudgetRecoveryDialog(
      context: context,
      shortageAmount: '${uiState.displayCurrency} ${uiState.shortageAmount.toStringAsFixed(2)}',
      minTopUp: '${uiState.displayCurrency} ${minTopUp.toStringAsFixed(2)}',
      remainingBudget: '${uiState.displayCurrency} ${uiState.remainingBudget.toStringAsFixed(2)}',
      warningText:
      'Top-up amount should at least ${uiState.displayCurrency} ${minTopUp.toStringAsFixed(2)}, insufficient top-up amount will trigger alternative recommendation directly.',
      onEndTrip: onEndTrip,
      onTopUpBudget: (amount) async {
        final success = await onTopUpBudget(amount);

        if (!context.mounted) return false;

        if (!success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to top up budget.'),
            ),
          );

          return false;
        }

        // Get the latest state AFTER topUpBudget()
        final viewModel = context.read<ActivityViewModel>();
        final latestState = viewModel.uiState;

        // Top-up succeeded, but shortage still remains.
        if (latestState.shortageAmount > 0) {

          // Wait until the first dialog is completely removed.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;

            _showInsufficientTopUpDialog(latestState, topUpAmount: amount);
          });
        }

        return true;
      },
    );
  }

  void _showInsufficientTopUpDialog(ActivityUiState state, {required double topUpAmount}) {
    showInsufficientTopUpBudgetRecoveryDialog(
      context: context,
      onContinue: () async {
        // 1. Close confirmation dialog
        Navigator.of(context).pop();

        // 2. Show loading dialog and capture its reference
        BuildContext? loadingDialogContext;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) {
            loadingDialogContext = dialogCtx;
            return PopScope(
              canPop: false,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
                  decoration: BoxDecoration(
                    color: appTheme.white_A700,
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: appTheme.teal_A700),
                      const SizedBox(height: 16.0),
                      Text(
                        'Re-optimizing your itinerary...',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                          color: appTheme.gray_900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );

        final viewModel = context.read<ActivityViewModel>();
        bool success = false;

        try {
          success = await viewModel.generateBudgetRecoveryPlan(
            dayTripId: state.selectedActivity?.dayTripId,
            availableBudget: state.totalBudget - state.spentBudget,
            topUpAmount: topUpAmount,
          );
          debugPrint("[Activity Insufficient Budget] Remaining budget after entering top up budget: ${state.remainingBudget}");
        } catch (e) {
          debugPrint('Recovery plan error: $e');
        } finally {
          // 3. Pop using the dialog's specific context if it was mounted
          if (loadingDialogContext != null && loadingDialogContext!.mounted) {
            Navigator.of(loadingDialogContext!).pop();
          } else if (mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }
        }

        if (!mounted) return;

        if (!success) {
          final error = viewModel.uiState.errorMessage;
          showThreeSecondMessage(
            context,
            error.isNotEmpty ? error : 'Failed to re-optimize itinerary.',
            isError: true,
          );
        } else {
          showThreeSecondMessage(
            context,
            'Itinerary successfully updated to fit your budget!',
          );
        }
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

  // yellow when 50% and red when 90% (of total budget)
  Color _getSpentRemainingColor(double spent, double total) {
    if (total <= 0) return appTheme.gray_900;
    final double ratio = spent / total;

    if (ratio >= 0.90) {
      return appTheme.errorRed; // Red at 90%+
    } else if (ratio >= 0.50) {
      return Colors.amber.shade800; // Yellow/Amber at 50%+
    }
    return appTheme.gray_900; // Default color below 50%
  }

  Widget _buildBudgetCard(ActivityUiState uiState) {
    final progressColor = _getBudgetProgressColor(
      uiState.spentBudget,
      uiState.totalBudget,
    );

    final badgeBgColor = progressColor.withValues(alpha: 0.12);
    final Color alertColor = _getSpentRemainingColor(
      uiState.spentBudget,
      uiState.totalBudget,
    );

    final Color spentColor = alertColor;
    final Color remainingColor = (alertColor == appTheme.gray_900)
        ? appTheme.teal_A700
        : alertColor;

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
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Text(
                  uiState.usedPercentageString,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Inter',
                    color: progressColor,
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
              Row(
                children: [
                  DualCurrencyAmount(
                    amount: uiState.spentBudget,
                    baseCurrency: 'MYR',
                    baseLabel: 'RM',
                    primaryStyle: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Inter',
                      color: appTheme.gray_900,
                    ),
                    secondaryStyle: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                      color: appTheme.blue_gray_700,
                    ),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    textAlign: TextAlign.start,
                  ),
                  Text(
                    ' / ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Inter',
                      color: appTheme.gray_900,
                    ),
                  ),
                  DualCurrencyAmount(
                    amount: uiState.totalBudget,
                    baseCurrency: 'MYR',
                    baseLabel: 'RM',
                    primaryStyle: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Inter',
                      color: appTheme.gray_900,
                    ),
                    secondaryStyle: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                      color: appTheme.blue_gray_700,
                    ),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    textAlign: TextAlign.start,
                  ),
                ],
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
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 24.0),
          Row(
            children: [
              Expanded(
                child: _buildSubBudgetCard(
                  title: 'SPENT',
                  amountWidget: DualCurrencyAmount(
                    amount: uiState.spentBudget,
                    baseCurrency: 'MYR',
                    baseLabel: 'RM',
                    crossAxisAlignment: CrossAxisAlignment.start,
                    textAlign: TextAlign.start,
                    primaryStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Inter',
                      color: spentColor,
                    ),
                    secondaryStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Inter',
                      color: appTheme.blue_gray_700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: _buildSubBudgetCard(
                  title: 'REMAINING',
                  amountWidget: DualCurrencyAmount(
                    amount: uiState.remainingBudget,
                    baseCurrency: 'MYR',
                    baseLabel: 'RM',
                    crossAxisAlignment: CrossAxisAlignment.start,
                    textAlign: TextAlign.start,
                    primaryStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Inter',
                      color: remainingColor,
                    ),
                    secondaryStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Inter',
                      color: appTheme.blue_gray_700,
                    ),
                  ),
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
                  amountWidget: DualCurrencyAmount(
                    amount: uiState.overspentBudget,
                    baseCurrency: 'MYR',
                    baseLabel: 'RM',
                    crossAxisAlignment: CrossAxisAlignment.start,
                    textAlign: TextAlign.start,
                    primaryStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Inter',
                      color: appTheme.gray_900,
                    ),
                    secondaryStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Inter',
                      color: appTheme.blue_gray_700,
                    ),
                  ),
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
    String? amount,
    Color? amountColor,
    Widget? amountWidget,
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
          amountWidget ??
              Text(
                amount!,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Inter',
                  color: amountColor!,
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

  Widget _buildActivityCard(Activity activity,
      ActivityUiState uiState, {
        VoidCallback? onTap,
      }) {
    final spent = uiState.activitySpentMap[activity.activitiesId] ?? 0.0;

    // Red as soon as spending EXCEEDS the allocated budget. This also covers
    // zero-budget activities (allocatedBudget == 0), where any spending at all
    // is already an overspend.
    final bool isOverBudget = spent > activity.allocatedBudget;

    // Warn (red) slightly earlier for budgeted activities: 80% or more used.
    final bool reachedAlertThreshold = activity.allocatedBudget > 0 &&
        spent >= activity.allocatedBudget * 0.80;

    final bool isAlert = isOverBudget || reachedAlertThreshold;

    final Color chipBgColor = isAlert
        ? appTheme.wholeAlertBudgetStroke
        : appTheme.teal_50;

    final Color chipTextColor = isAlert
        ? appTheme.expenseOverspendText
        : appTheme.teal_700;

    debugPrint('----------------------------------------');
    debugPrint('[ActivityScreen] Destination: ${activity.destination}');
    debugPrint('[ActivityScreen] Allocated Budget: RM${activity.allocatedBudget}');
    debugPrint('[ActivityScreen] Spent Budget: RM$spent');
    debugPrint('[ActivityScreen] Overspend Amount: RM${activity.overspendAmount}');
    debugPrint('[ActivityScreen] Is Overspend: ${activity.isOverspend}');
    debugPrint('----------------------------------------');
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
                      backgroundColor: appTheme.amber_200,
                      textColor: appTheme.lime_900,
                      child: DualCurrencyAmount(
                        amount: activity.allocatedBudget,
                        baseCurrency: 'MYR',
                        baseLabel: 'RM',
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
                          color: appTheme.lime_900.withValues(alpha: 0.7),
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (spent > 0)
                      _buildChip(
                        backgroundColor: chipBgColor,
                        textColor: chipTextColor,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Spent: ',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Inter',
                                color: chipTextColor,
                                height: 1.2,
                              ),
                            ),
                            DualCurrencyAmount(
                              amount: spent,
                              baseCurrency: 'MYR',
                              baseLabel: 'RM',
                              crossAxisAlignment: CrossAxisAlignment.start,
                              textAlign: TextAlign.start,
                              primaryStyle: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Inter',
                                color: chipTextColor,
                                height: 1.2,
                              ),
                              secondaryStyle: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Inter',
                                color: chipTextColor.withValues(alpha: 0.7),
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
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
    String? label,
    required Color backgroundColor,
    required Color textColor,
    Widget? child,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child ??
          Text(
            label!,
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
      return CachedNetworkImage(
        imageUrl: url,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          height: height,
          color: appTheme.gray_100,
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (context, error, stackTrace) {
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

  Color _getBudgetProgressColor(double spentBudget, double totalBudget) {
    if (totalBudget <= 0) return appTheme.teal_A700;

    final double ratio = spentBudget / totalBudget;

    if (ratio >= 0.90) {
      return appTheme.errorRed;
    } else if (ratio >= 0.50) {
      return Colors.amber.shade800;
    } else {
      return appTheme.teal_A700;
    }
  }
}