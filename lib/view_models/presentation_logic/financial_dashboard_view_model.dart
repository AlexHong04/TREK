import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/services/financial_dashboard_service.dart';
import '../../models/services/i_auth_service.dart';
import '../../theme/app_theme.dart';
import '../ui_state/financial_dashboard_ui_state.dart';
export '../ui_state/financial_dashboard_ui_state.dart';

class FinancialDashboardViewModel extends ChangeNotifier {
  final IFinancialDashboardService _service;
  final IAuthService? _authService;

  FinancialDashboardUiState _uiState = FinancialDashboardUiState(
    selectedDate: DateTime.now(),
    displayedCalendarMonth: DateTime(DateTime.now().year, DateTime.now().month),
  );

  FinancialDashboardViewModel({
    IFinancialDashboardService? service,
    IAuthService? authService,
  }) : _service = service ?? FinancialDashboardService(),
       _authService = authService {
    _authService?.addListener(_handleAuthUserChanged);
    _syncAuthUser(notify: false);
  }

  FinancialDashboardUiState get uiState => _uiState;

  void _handleAuthUserChanged() => _syncAuthUser();

  void _syncAuthUser({bool notify = true}) {
    final user = _authService?.currentUser;
    final pictureUrl = user?.profilePicture?.trim();
    _uiState = _uiState.copyWith(
      profileName: user?.fullName ?? '',
      profilePictureUrl: pictureUrl,
      clearProfilePictureUrl: pictureUrl == null || pictureUrl.isEmpty,
    );
    if (notify) notifyListeners();
  }

  Future<void> refreshProfile() async {
    await _authService?.refreshCurrentUser();
  }

  Future<void> loadCurrentDay() => loadDate(DateTime.now());

  @override
  void dispose() {
    _authService?.removeListener(_handleAuthUserChanged);
    super.dispose();
  }

  Future<void> loadDate(DateTime date) async {
    _uiState = _uiState.copyWith(
      isLoading: true,
      selectedDate: date,
      displayedCalendarMonth: DateTime(date.year, date.month),
      clearError: true,
    );
    notifyListeners();

    try {
      final summary = await _service.getCurrentDaySummary(date);
      if (summary == null) {
        _uiState = _uiState.copyWith(
          isLoading: false,
          hasCurrentTrip: false,
          tripId: '',
          userId: '',
          destination: '',
          topUpBudget: 0,
          categories: FinancialDashboardUiState.defaultCategories,
        );
      } else {
        _uiState = _uiState.copyWith(
          isLoading: false,
          hasCurrentTrip: true,
          tripId: summary.trip.tripId ?? '',
          userId: summary.trip.userId ?? '',
          destination: summary.trip.destination,
          topUpBudget: summary.dayTrip.topUpBudget ?? 0,
          categories: summary.categories
              .map(
                (category) => DashboardCategoryUiState(
                  name: category.category,
                  budget: category.allocatedBudget,
                  expense: category.expense,
                  expenseDetails: category.expenseDetails
                      .map(
                        (detail) => DashboardExpenseDetailUiState(
                          activityName: detail.activityName,
                          activityImageUrl: detail.activityImageUrl,
                          timeText: _formatTime(detail.activityStartTime, date),
                          amount: detail.amount,
                          paymentMethod:
                              detail.paymentMethod?.trim().isNotEmpty == true
                              ? detail.paymentMethod!.trim()
                              : 'Payment method unavailable',
                        ),
                      )
                      .toList(),
                ),
              )
              .toList(),
        );
      }
    } on TimeoutException {
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: 'Connection timed out. Please try again.',
      );
    } catch (_) {
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load expenses. Please try again.',
      );
    }
    notifyListeners();
  }

  Future<void> loadAvailableDates() async {
    _uiState = _uiState.copyWith(
      isLoadingAvailableDates: true,
      displayedCalendarMonth: DateTime(
        _uiState.selectedDate.year,
        _uiState.selectedDate.month,
      ),
      clearAvailableDatesError: true,
    );
    notifyListeners();

    try {
      final dates = await _service.getAvailableDates();
      _uiState = _uiState.copyWith(
        isLoadingAvailableDates: false,
        availableDates: dates,
      );
    } on TimeoutException {
      _uiState = _uiState.copyWith(
        isLoadingAvailableDates: false,
        availableDatesErrorMessage: 'Connection timed out. Please try again.',
      );
    } catch (_) {
      _uiState = _uiState.copyWith(
        isLoadingAvailableDates: false,
        availableDatesErrorMessage:
            'Unable to load available dates. Please try again.',
      );
    }
    notifyListeners();
  }

  void showPreviousCalendarMonth() {
    _uiState = _uiState.copyWith(
      displayedCalendarMonth: DateTime(
        _uiState.displayedCalendarMonth.year,
        _uiState.displayedCalendarMonth.month - 1,
      ),
    );
    notifyListeners();
  }

  void showNextCalendarMonth() {
    _uiState = _uiState.copyWith(
      displayedCalendarMonth: DateTime(
        _uiState.displayedCalendarMonth.year,
        _uiState.displayedCalendarMonth.month + 1,
      ),
    );
    notifyListeners();
  }

  Future<void> loadCompletedTrips() async {
    _uiState = _uiState.copyWith(
      isLoadingCompletedTrips: true,
      clearCompletedTripsError: true,
    );
    notifyListeners();

    try {
      final trips = await _service.getCompletedTrips();
      _uiState = _uiState.copyWith(
        isLoadingCompletedTrips: false,
        completedTrips: trips
            .map(
              (trip) => DashboardTripUiState(
                tripId: trip.tripId ?? '',
                destination: trip.destination,
                imageUrl: trip.imgUrl ?? '',
                startDate: trip.startDate,
                endDate: trip.endDate,
                totalBudget: trip.totalBudget,
                travelPreference: trip.travelPreference,
              ),
            )
            .toList(),
      );
    } on TimeoutException {
      _uiState = _uiState.copyWith(
        isLoadingCompletedTrips: false,
        completedTripsErrorMessage: 'Connection timed out. Please try again.',
      );
    } catch (_) {
      _uiState = _uiState.copyWith(
        isLoadingCompletedTrips: false,
        completedTripsErrorMessage:
            'Unable to load completed trips. Please try again.',
      );
    }
    notifyListeners();
  }

  String _formatTime(String? value, DateTime date) {
    final time = value?.trim() ?? '';
    if (time.isEmpty) return 'Scheduled';
    if (time.toUpperCase().contains('AM') ||
        time.toUpperCase().contains('PM')) {
      return time;
    }

    try {
      final parts = time.split(':');
      final parsed = DateTime(
        date.year,
        date.month,
        date.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      return DateFormat('hh:mm a').format(parsed);
    } catch (_) {
      return time;
    }
  }
}

class DashboardDonutChartPainter extends CustomPainter {
  final List<DashboardCategoryUiState> categories;

  const DashboardDonutChartPainter(this.categories);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const radius = 58.0;
    const strokeWidth = 24.0;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final total = categories.fold<double>(0, (sum, item) => sum + item.expense);
    if (total <= 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2,
        false,
        Paint()
          ..color = appTheme.gray_400
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
      return;
    }
    var startAngle = -math.pi / 2;

    for (final category in categories) {
      if (category.expense <= 0) continue;
      final sweep = math.pi * 2 * category.expense / total;
      canvas.drawArc(
        rect,
        startAngle,
        sweep,
        false,
        Paint()
          ..color = dashboardCategoryColor(category.name)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );

      final middleAngle = startAngle + sweep / 2;
      final labelPosition =
          center + Offset(math.cos(middleAngle), math.sin(middleAngle)) * 100;
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'RM ${category.expense.toStringAsFixed(0)}',
          style: TextStyle(color: appTheme.gray_900, fontSize: 14),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      final desiredOffset =
          labelPosition - Offset(textPainter.width / 2, textPainter.height / 2);
      textPainter.paint(
        canvas,
        Offset(
          desiredOffset.dx
              .clamp(4, size.width - textPainter.width - 4)
              .toDouble(),
          desiredOffset.dy
              .clamp(4, size.height - textPainter.height - 4)
              .toDouble(),
        ),
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant DashboardDonutChartPainter oldDelegate) {
    return oldDelegate.categories != categories;
  }
}

Color dashboardCategoryColor(String categoryName) {
  return switch (categoryName) {
    'Restaurant' => appTheme.teal_50,
    'Transport' => appTheme.teal_800,
    _ => appTheme.teal_A700,
  };
}
