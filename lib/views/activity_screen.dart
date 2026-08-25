import 'dart:async';
import 'dart:io';

import '../theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/entities/activity.dart';
import '../models/entities/expense_item.dart';
import '../view_models/presentation_logic/activity_view_model.dart';
import '../view_models/ui_state/activity_ui_state.dart';
import '../widgets/custom_app_bar.dart';
import '../utils/date_time_formatter.dart';

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
  final String _destination = 'Trip Itinerary';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments;
      String? extractedTripId;

      if (args is Map<String, dynamic>) {
        if (args['trip'] != null) {
          final innerTrip = args['trip'];
          if (innerTrip is Map) {
            extractedTripId =
                (innerTrip['tripId'] ??
                        innerTrip['trip_id'] ??
                        innerTrip['dayTripId'])
                    ?.toString();
          } else {
            extractedTripId =
                (innerTrip as dynamic).tripId ??
                (innerTrip as dynamic).dayTripId;
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
        } catch (_) {
          extractedTripId = null;
        }
      }

      // Schedule after the current build frame completes to prevent the '!_dirty' assertion error
      if (extractedTripId != null && extractedTripId.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.read<ActivityViewModel>().loadTripItinerary(
              extractedTripId!,
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
      appBar: const CustomAppBar(title: 'Activities'),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(top: 24.0, left: 24.0, right: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLocationHeader(_destination),
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

  Widget _buildLocationHeader(String destination) {
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
          'Day 1: Cultural\nImmersion',
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

    if (uiState.activities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32.0),
          child: Text(
            'No activities scheduled for this trip',
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

    final activities = uiState.activities;
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
    // return Column(
    //   children: List.generate(activities.length, (index) {
    //     final activity = activities[index];
    //     final isLast = index == activities.length - 1;
    //     return _buildTimelineItem(activity: activity, isLast: isLast);
    //   }),
    // );
    //
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
                      // viewModel.setCurrentActivityId(activity.activitiesId);
                      // showBudgetRecoveryDialog(
                      //   context: context,
                      //   shortageAmount: uiState.overspentBudget.toString(),
                      //   remainingBudget: uiState.remainingBudget.toString(),
                      //   warningText:
                      //       'Insufficient top-up amount will trigger alternative recommendation directly.',
                      //   onEndTrip: () {
                      //     viewModel.endTrip();
                      //   },
                      //   onTopUpBudget: (amount) async {
                      //     final success = await viewModel.topUpBudget(amount);
                      //
                      //     if (!context.mounted) return false;
                      //
                      //     if (!success) {
                      //       ScaffoldMessenger.of(context).showSnackBar(
                      //         SnackBar(
                      //           content: Text(viewModel.uiState.errorMessage),
                      //         ),
                      //       );
                      //       return false;
                      //     }
                      //
                      //     ScaffoldMessenger.of(context).showSnackBar(
                      //       const SnackBar(
                      //         content: Text('Top-up successful!'),
                      //       ),
                      //     );
                      //
                      //     return true;
                      //   },
                      // );
                      // showBudgetExceededDialog(
                      //   context: context,
                      //   allocatedBudget:
                      //       'RM ${activity.allocatedBudget.toStringAsFixed(2)}',
                      //   remainingBudget: uiState.remainingBudget.toString(),
                      //   exceededAmount: uiState.overspentBudget.toString(),
                      //   warningText1:
                      //       'You have overspent ${uiState.overspentBudget.toString()} so far on this trip.',
                      //   warningText2:
                      //       'The budget allocated for remaining restaurants have been modified.',
                      //   onContinue: () {
                      //     // Handle continue action here
                      //     Navigator.pop(context);
                      //   },
                      // );
                      // showBudgetExceeded20Dialog(
                      //   context: context,
                      //   allocatedBudget: 'RM25.00',
                      //   remainingBudget: 'RM2325.00',
                      //   exceededAmount: 'RM100.00',
                      //   warningText1:
                      //       'You have overspent RM 100.00 so far on this trip.',
                      //   estimatedDays: '3',
                      //   warningText3: 'Plan will be modified automatically.',
                      //   onContinue: () {
                      //     // Handle action
                      //   },
                      // );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    // return Row(
    //   crossAxisAlignment: CrossAxisAlignment.start,
    //   children: [
    //     _buildTimelineIndicatorColumn(isLast: isLast),
    //     const SizedBox(width: 20.0),
    //     Expanded(
    //       child: Column(
    //         crossAxisAlignment: CrossAxisAlignment.start,
    //         children: [
    //           Text(
    //             DateFormat('hh:mm a').format(activity.date),
    //             style: TextStyle(
    //               fontSize: 14,
    //               fontWeight: FontWeight.w600,
    //               fontFamily: 'Inter',
    //               color: appTheme.gray_800,
    //             ).copyWith(height: 1.2),
    //           ),
    //           const SizedBox(height: 12.0),
    //           _buildActivityCard(activity),
    //           if (!isLast) const SizedBox(height: 32.0),
    //         ],
    //       ),
    //     ),
    //   ],
    // );
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
            Container(
              width: 2.0,
              height: 420.0, // adjusted height based on content
              color: appTheme.gray_200, // Slate 300 equivalent
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
                // child: activity.activityImgUrl.isNotEmpty
                //     ? Image.asset(
                //         activity.activityImgUrl,
                //         height: 180,
                //         width: double.infinity,
                //         fit: BoxFit.cover,
                //       )
                //     : Container(height: 180, color: appTheme.gray_200),
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
              // Padding(
              //   padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              //   child: SizedBox(
              //     width: double.infinity,
              //     child: OutlinedButton.icon(
              //       onPressed: () {
              //         context
              //             .read<ActivityViewModel>()
              //             .selectActivityForExpense(activity);
              //
              //         showModalBottomSheet<void>(
              //           context: context,
              //           isScrollControlled: true,
              //           isDismissible: true,
              //           enableDrag: true,
              //           barrierColor: Colors.black.withOpacity(0.20),
              //           backgroundColor: Colors.transparent,
              //           builder: (_) => ChangeNotifierProvider.value(
              //             value: context.read<ActivityViewModel>(),
              //             child: _ExpenseBottomSheet(activity: activity),
              //           ),
              //         );
              //       },
              //       icon: const Icon(Icons.add_card_outlined),
              //       label: const Text('Record Expense'),
              //     ),
              //   ),
              // ),
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

    // 1. Check if it's a web/Supabase URL
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

    // 2. Fallback to local asset
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

class _ExpenseBottomSheet extends StatefulWidget {
  final Activity activity;

  const _ExpenseBottomSheet({required this.activity});

  @override
  State<_ExpenseBottomSheet> createState() => _ExpenseBottomSheetState();
}

class _ExpenseBottomSheetState extends State<_ExpenseBottomSheet> {
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _merchantController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _unitPriceController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  int? _editingItemIndex;
  bool _isEditingItem = false;
  bool _showItemForm = true;
  String? _topMessage;
  Timer? _topMessageTimer;

  @override
  void dispose() {
    _topMessageTimer?.cancel();
    _itemNameController.dispose();
    _descriptionController.dispose();
    _merchantController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    final timeText = activity.startTime?.isNotEmpty == true
        ? activity.startTime!
        : DateFormat.jm().format(activity.date);
    final uiState = context.watch<ActivityViewModel>().uiState;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.10,
      maxChildSize: 0.96,
      snap: true,
      snapSizes: const [0.50, 0.92],
      shouldCloseOnMinExtent: true,
      builder: (context, scrollController) => Stack(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Material(
              color: Colors.white,
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 64,
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Add Expense',
                        style: TextStyle(
                          color: Color(0xFF1F2937),
                          fontFamily: 'Inter',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _ExpenseActivitySummary(
                        activity: activity,
                        timeText: timeText,
                      ),
                      const SizedBox(height: 10),
                      _ExpenseCategoryCard(category: activity.activityCategory),
                      const SizedBox(height: 10),
                      _buildExpenseItemsSection(uiState),
                      const SizedBox(height: 10),
                      _buildTotalAmountSection(uiState),
                      const SizedBox(height: 10),
                      _buildPaymentMethodSection(uiState),
                      const SizedBox(height: 10),
                      _buildReceiptSection(uiState),
                      if (uiState.errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildMessage(uiState.errorMessage, true),
                      ],
                      if (uiState.successMessage.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildMessage(uiState.successMessage, false),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton.icon(
                          onPressed: uiState.isSavingExpense
                              ? null
                              : _showConfirmExpenseDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF14BBA6),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: uiState.isSavingExpense
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            uiState.isSavingExpense
                                ? 'Saving Expense...'
                                : 'Confirm Expense',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_topMessage != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _TopMessageAlert(
                message: _topMessage!,
                onClose: _dismissTopMessage,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExpenseItemsSection(ActivityUiState uiState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF3F4F6)),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EXPENSE ITEMS',
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < uiState.draftExpenseItems.length; index++)
            _buildSavedItemCard(uiState.draftExpenseItems[index], index),
          if (_showItemForm) _buildItemForm(),
          const SizedBox(height: 14),
          InkWell(
            onTap: _startNewItem,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFFE5E7EB),
                  width: 2,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: Color(0xFF9CA3AF), size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Add Another Item',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedItemCard(ExpenseItem item, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF14BBA6),
          child: Icon(Icons.receipt_long_outlined, color: Colors.white),
        ),
        title: Text(
          item.itemName,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${item.quantity} × RM${item.unitPrice.toStringAsFixed(2)} = RM${item.subtotal.toStringAsFixed(2)}',
        ),
        trailing: Wrap(
          children: [
            IconButton(
              onPressed: () => _editItem(item, index),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              onPressed: () => _confirmDeleteItem(index),
              icon: const Icon(Icons.delete_outline, color: Color(0xFFE05252)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemForm() {
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    final unitPrice = _parsePrice(_unitPriceController.text) ?? 0;
    final subtotal = quantity * unitPrice;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0x08F9FAFB),
              border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF14BBA6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ITEM ENTRY',
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .5,
                        ),
                      ),
                      TextField(
                        controller: _itemNameController,
                        readOnly: !_isEditingItem,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Item Entry',
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _isEditingItem = true),
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: Color(0xFFB3B3B3),
                  ),
                ),
                IconButton(
                  onPressed: _editingItemIndex == null
                      ? null
                      : () => _confirmDeleteItem(
                          _editingItemIndex!,
                          clearEditor: true,
                        ),
                  icon: const Icon(Icons.close, color: Color(0xFFB3B3B3)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField('Item Description', _descriptionController, ''),
                const SizedBox(height: 14),
                _buildTextField(
                  'Merchant Name (Optional)',
                  _merchantController,
                  '',
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _buildDatePicker()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTimePicker()),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        'Quantity',
                        _quantityController,
                        '',
                        TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        'Unit Price',
                        _unitPriceController,
                        '',
                        const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Subtotal',
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'AMOUNT',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontFamily: 'Inter',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            'RM${subtotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: _discardItem,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF9CA3AF),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        minimumSize: const Size(100, 44),
                      ),
                      child: const Text('Discard'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isEditingItem ? _saveItem : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14BBA6),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(98, 44),
                      ),
                      child: Text(
                        _editingItemIndex == null ? 'Save Item' : 'Update Item',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String? hint, [
    TextInputType? keyboardType,
  ]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: _fieldLabelStyle),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          readOnly: !_isEditingItem,
          keyboardType: keyboardType,
          inputFormatters: _inputFormattersFor(controller),
          onChanged: (_) => setState(() {}),
          decoration: _fieldDecoration(hint),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DATE', style: _fieldLabelStyle),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          height: 43,
          child: OutlinedButton.icon(
            onPressed: _isEditingItem ? _pickDate : null,
            style: _dateTimeButtonStyle,
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TIME', style: _fieldLabelStyle),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          height: 43,
          child: OutlinedButton.icon(
            onPressed: _isEditingItem ? _pickTime : null,
            style: _dateTimeButtonStyle,
            icon: const Icon(Icons.access_time_outlined, size: 18),
            label: Text(_selectedTime.format(context)),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalAmountSection(ActivityUiState uiState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOTAL AMOUNT',
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'RM${uiState.draftTotalAmount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontFamily: 'Inter',
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSection(ActivityUiState uiState) {
    const methods = ['Debit/Credit Card', 'Cash', 'E-wallet', 'Bank Transfer'];
    return _ExpenseSectionCard(
      title: 'PAYMENT METHOD',
      child: DropdownButtonFormField<String>(
        value: uiState.paymentMethod.isEmpty ? null : uiState.paymentMethod,
        decoration: _fieldDecoration(
          'Optional',
        ).copyWith(prefixIcon: const Icon(Icons.credit_card_outlined)),
        items: methods
            .map(
              (method) => DropdownMenuItem(value: method, child: Text(method)),
            )
            .toList(),
        onChanged: (method) =>
            context.read<ActivityViewModel>().setPaymentMethod(method ?? ''),
      ),
    );
  }

  Widget _buildReceiptSection(ActivityUiState uiState) {
    final hasReceipt = uiState.receiptLocalPath.isNotEmpty;
    return _ExpenseSectionCard(
      title: 'UPLOAD RECEIPT',
      child: hasReceipt
          ? Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(uiState.receiptLocalPath),
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(
                      width: 56,
                      height: 56,
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Receipt selected')),
                IconButton(
                  onPressed: context.read<ActivityViewModel>().removeReceipt,
                  icon: const Icon(Icons.close, color: Color(0xFFE05252)),
                ),
              ],
            )
          : OutlinedButton.icon(
              onPressed: uiState.isPickingReceipt ? null : _chooseReceipt,
              icon: uiState.isPickingReceipt
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_outlined),
              label: Text(
                uiState.isPickingReceipt
                    ? 'Opening...'
                    : 'Scan or upload receipt',
              ),
            ),
    );
  }

  Widget _buildMessage(String message, bool isError) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFE4E6) : const Color(0xFFCCFBF1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message),
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date != null && mounted) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (time != null && mounted) setState(() => _selectedTime = time);
  }

  void _saveItem() {
    final name = _itemNameController.text.trim();
    final quantity = int.tryParse(_quantityController.text.trim());
    final price = _parsePrice(_unitPriceController.text);
    if (name.isEmpty) {
      _showValidationMessage('Item name cannot be empty.');
      return;
    }
    if (quantity == null || quantity <= 0) {
      _showValidationMessage('Item quantity must be greater than zero.');
      return;
    }
    if (price == null || price < 0) {
      _showValidationMessage('Enter a valid unit price of zero or more.');
      return;
    }
    final dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    final item = ExpenseItem(
      itemName: name,
      itemDescription: _nullIfEmpty(_descriptionController.text),
      merchantName: _nullIfEmpty(_merchantController.text),
      expenseDateTime: dateTime,
      quantity: quantity,
      unitPrice: price,
      subtotal: quantity * price,
    );
    final viewModel = context.read<ActivityViewModel>();
    final currentIndex = _editingItemIndex;
    if (currentIndex == null) {
      final newItemIndex = viewModel.uiState.draftExpenseItems.length;
      viewModel.addExpenseItem(item);
      setState(() {
        _editingItemIndex = newItemIndex;
        _isEditingItem = false;
        _showItemForm = false;
      });
    } else {
      viewModel.updateExpenseItem(currentIndex, item);
      setState(() {
        _isEditingItem = false;
        _showItemForm = false;
      });
    }
  }

  String? _nullIfEmpty(String value) =>
      value.trim().isEmpty ? null : value.trim();

  double? _parsePrice(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  List<TextInputFormatter>? _inputFormattersFor(
    TextEditingController controller,
  ) {
    if (controller == _quantityController) {
      return [FilteringTextInputFormatter.digitsOnly];
    }
    if (controller == _unitPriceController) {
      return [FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}'))];
    }
    return null;
  }

  void _showValidationMessage(String message) {
    _topMessageTimer?.cancel();
    setState(() => _topMessage = message);
    _topMessageTimer = Timer(const Duration(seconds: 5), _dismissTopMessage);
  }

  void _dismissTopMessage() {
    _topMessageTimer?.cancel();
    if (mounted) setState(() => _topMessage = null);
  }

  void _editItem(ExpenseItem item, int index) {
    setState(() {
      _editingItemIndex = index;
      _isEditingItem = true;
      _showItemForm = true;
      _itemNameController.text = item.itemName;
      _descriptionController.text = item.itemDescription ?? '';
      _merchantController.text = item.merchantName ?? '';
      _quantityController.text = item.quantity.toString();
      _unitPriceController.text = item.unitPrice.toStringAsFixed(2);
      _selectedDate = item.expenseDateTime;
      _selectedTime = TimeOfDay.fromDateTime(item.expenseDateTime);
    });
  }

  void _discardItem() {
    setState(() {
      _editingItemIndex = null;
      _isEditingItem = false;
      _showItemForm = false;
      _itemNameController.clear();
      _descriptionController.clear();
      _merchantController.clear();
      _quantityController.clear();
      _unitPriceController.clear();
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
    });
  }

  void _startNewItem() {
    if (_showItemForm && _hasUnfinishedItem()) {
      _showValidationMessage(
        'Save or discard the current item before adding another item.',
      );
      return;
    }
    _discardItem();
    setState(() {
      _isEditingItem = true;
      _showItemForm = true;
    });
  }

  bool _hasUnfinishedItem() {
    return _itemNameController.text.trim().isNotEmpty ||
        _descriptionController.text.trim().isNotEmpty ||
        _merchantController.text.trim().isNotEmpty ||
        _quantityController.text.trim().isNotEmpty ||
        _unitPriceController.text.trim().isNotEmpty;
  }

  Future<void> _chooseReceipt() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take photo'),
              onTap: () async {
                Navigator.pop(sheetContext);
                await context.read<ActivityViewModel>().takeReceiptPhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () async {
                Navigator.pop(sheetContext);
                await context
                    .read<ActivityViewModel>()
                    .chooseReceiptFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmExpense() async {
    final viewModel = context.read<ActivityViewModel>();
    await viewModel.confirmExpense();
    if (!mounted) return;

    if (viewModel.uiState.errorMessage.isNotEmpty) {
      _showValidationMessage(viewModel.uiState.errorMessage);
      return;
    }

    if (viewModel.uiState.successMessage.isEmpty) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(viewModel.uiState.successMessage)));
    Navigator.pop(context);
  }

  Future<void> _showConfirmExpenseDialog() async {
    final totalAmount = context
        .read<ActivityViewModel>()
        .uiState
        .draftTotalAmount;
    final isConfirmed = await _showConfirmationDialog(
      title: 'Confirm Expense',
      message:
          'Are you sure you want to record this expense of RM${totalAmount.toStringAsFixed(2)}?',
      confirmLabel: 'Confirm',
    );

    if (isConfirmed && mounted) {
      await _confirmExpense();
    }
  }

  Future<void> _confirmDeleteItem(int index, {bool clearEditor = false}) async {
    final isConfirmed = await _showConfirmationDialog(
      title: 'Delete Expense Item',
      message: 'Are you sure you want to delete this expense item?',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (!isConfirmed || !mounted) return;

    context.read<ActivityViewModel>().removeExpenseItem(index);
    if (clearEditor) _discardItem();
  }

  Future<bool> _showConfirmationDialog({
    required String title,
    required String message,
    required String confirmLabel,
    bool isDestructive = false,
  }) async {
    final isConfirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive
                  ? const Color(0xFFE05252)
                  : const Color(0xFF14BBA6),
              foregroundColor: Colors.white,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    return isConfirmed ?? false;
  }

  static const _fieldLabelStyle = TextStyle(
    color: Color(0xFF9CA3AF),
    fontFamily: 'Inter',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  static final _dateTimeButtonStyle = OutlinedButton.styleFrom(
    alignment: Alignment.centerLeft,
    foregroundColor: const Color(0xFF191C1E),
    backgroundColor: const Color(0xFFF9FAFB),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    side: const BorderSide(color: Color(0xFFF3F4F6)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );

  InputDecoration _fieldDecoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFBFC4CC)),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFF3F4F6)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFF3F4F6)),
      ),
    );
  }
}

class _TopMessageAlert extends StatelessWidget {
  final String message;
  final VoidCallback onClose;

  const _TopMessageAlert({required this.message, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 250),
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, -36 * (1 - value)),
        child: Opacity(opacity: value, child: child),
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE4E6),
            border: Border.all(color: const Color(0xFFE05252)),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x24000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFE05252)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF7F1D1D),
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, color: Color(0xFF7F1D1D)),
                tooltip: 'Close message',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpenseSectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ExpenseSectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF3F4F6)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 15,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ExpenseActivitySummary extends StatelessWidget {
  final Activity activity;
  final String timeText;

  const _ExpenseActivitySummary({
    required this.activity,
    required this.timeText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFF3F4F6)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _ExpenseActivityImage(imageUrl: activity.activityImgUrl),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.destination,
                  style: const TextStyle(
                    color: Color(0xFF191C1E),
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                _detail(Icons.access_time_outlined, timeText),
                const SizedBox(height: 6),
                _detail(
                  Icons.account_balance_wallet_outlined,
                  'RM${activity.allocatedBudget.toStringAsFixed(2)}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detail(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF9CA3AF),
            fontFamily: 'Inter',
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _ExpenseActivityImage extends StatelessWidget {
  final String imageUrl;

  const _ExpenseActivityImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    const placeholder = ColoredBox(
      color: Color(0xFFF3F4F6),
      child: SizedBox(width: 120, height: 90),
    );

    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return Image.network(
        imageUrl,
        width: 120,
        height: 90,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      );
    }

    if (imageUrl.isNotEmpty) {
      return Image.asset(
        imageUrl,
        width: 120,
        height: 90,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      );
    }

    return placeholder;
  }
}

class _ExpenseCategoryCard extends StatelessWidget {
  final String category;

  const _ExpenseCategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF3F4F6)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CATEGORY',
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.category_outlined, color: Color(0xFF1F2937)),
                const SizedBox(width: 12),
                Text(
                  category,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
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
              // Header Title
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: appTheme.warningPopupHeader,
                ),
              ),
              const SizedBox(height: 16),

              // Summary Section
              summaryCard,
              const SizedBox(height: 16),

              // Warning Message
              _buildWarningRow(warningText),
              const SizedBox(height: 16),

              // Optional Content Widget (Item details card or Top-Up input)
              if (contentCard != null) ...[
                contentCard!,
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 8),

              // Action Buttons
              actions,
            ],
          ),
        ),
      ),
    );
  }

  // Shared Warning Row Builder
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

  // Shared Tag Chip Builder
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

// Budget Exceeded Within 20% Popup
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
            // Center(
            //   child: Container(
            //     decoration: BoxDecoration(
            //       color: appTheme.white_A700,
            //       borderRadius: BorderRadius.circular(12),
            //       border: Border.all(color: appTheme.blue_gray_50),
            //       boxShadow: [
            //         BoxShadow(
            //           color: appTheme.black.withAlpha(10),
            //           offset: const Offset(0, 2),
            //           blurRadius: 10,
            //         ),
            //       ],
            //     ),
            //     child: Column(
            //       crossAxisAlignment: CrossAxisAlignment.start,
            //       children: [
            //         ClipRRect(
            //           borderRadius: const BorderRadius.vertical(
            //             top: Radius.circular(12),
            //           ),
            //           child: Image.network(
            //             imageUrl,
            //             height: 160,
            //             width: double.infinity,
            //             fit: BoxFit.cover,
            //             errorBuilder: (_, __, ___) => Container(
            //               height: 160,
            //               color: Colors.grey.shade300,
            //               child: const Icon(Icons.restaurant, size: 48),
            //             ),
            //           ),
            //         ),
            //         Padding(
            //           padding: const EdgeInsets.all(12.0),
            //           child: Column(
            //             crossAxisAlignment: CrossAxisAlignment.start,
            //             children: [
            //               Text(
            //                 itemTitle,
            //                 style: TextStyle(
            //                   fontSize: 18,
            //                   fontWeight: FontWeight.bold,
            //                   color: appTheme.black,
            //                 ),
            //               ),
            //               const SizedBox(height: 10),
            //               BaseBudgetDialog.buildTagChip(
            //                 label: originalBudgetChipText,
            //                 bgColor: appTheme.lime_900,
            //                 textColor: appTheme.amber_200,
            //               ),
            //               const SizedBox(height: 6),
            //               BaseBudgetDialog.buildTagChip(
            //                 label: modifiedBudgetChipText,
            //                 bgColor: appTheme.expenseOverspendBg,
            //                 textColor: appTheme.expenseOverspendText,
            //               ),
            //             ],
            //           ),
            //         ),
            //       ],
            //     ),
            //   ),
            // ),
            // const SizedBox(height: 16),
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

// Budget Exceeded Above 20% Popup
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
            // Second Warning Message with bold days text
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
            // Third Warning Message
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

// Budget Recovery Popup
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

// showBudgetRecoveryDialog(
//   context: context,
//   shortageAmount: 'RM30.00',
//   remainingBudget: 'RM20.00',
//   warningText:
//   'Insufficient top-up amount will trigger alternative recommendation directly.',
// onEndTrip: () {
// viewModel.endTrip();
// },
// onTopUpBudget: (amount) {
// viewModel.topUpBudget(double.tryParse(amount) ?? 0.0);
// },
// );
// showBudgetExceededDialog(
//   context: context,
//   allocatedBudget: 'RM ${activity.allocatedBudget.toStringAsFixed(2)}',
//   remainingBudget: 'RM2405.00',
//   exceededAmount: 'RM20.00',
//   warningText1: 'You have overspent RM 20.00 so far on this trip.',
//   imageUrl: activity.activityImgUrl ?? '',
//   itemTitle: activity.destination ?? 'Activity Details',
//   originalBudgetChipText: 'Original allocated budget: RM ${activity.allocatedBudget.toStringAsFixed(2)}',
//   modifiedBudgetChipText: 'Modified allocated budget: RM15.00',
//   warningText2: 'The budget allocated for remaining restaurants have been modified.',
//   onContinue: () {
//     // Handle continue action here
//   },
// );
// showBudgetExceeded20Dialog(
// context: context,
// allocatedBudget: 'RM25.00',
// remainingBudget: 'RM2325.00',
// exceededAmount: 'RM100.00',
// warningText1: 'You have overspent RM 100.00 so far on this trip.',
// estimatedDays: '3',
// warningText3: 'Plan will be modified automatically.',
// onContinue: () {
// // Handle action
// },
