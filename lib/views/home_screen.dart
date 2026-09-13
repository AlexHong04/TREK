import 'dart:io';

import 'package:Trek/view_models/presentation_logic/activity_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../view_models/presentation_logic/home_view_model.dart';
import '../widgets/dual_currency_amount.dart';
import 'financial_dashboard_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static Widget builder(BuildContext context) {
    return const HomeViewModelScope(child: HomeScreen());
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _verificationBannerDismissed = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appTheme.gray_50_02,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            const SizedBox(height: 18),
            _buildPageIndicator(),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildHomePage(context),
                  FinancialDashboardScreen.builder(
                    context,
                    showNavigationHeader: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomePage(BuildContext context) {
    final state = context.watch<HomeViewModel>().uiState;
    return Column(
      children: [
        if (state.isOffline)
          const _HomeStatusBanner(
            icon: Icons.cloud_off_outlined,
            text: 'You’re offline. Showing saved information.',
            isWarning: true,
          ),
        if (!state.isEmailVerified && !_verificationBannerDismissed)
          _HomeStatusBanner(
            icon: Icons.mark_email_unread_outlined,
            text: _verificationBannerText(state.verificationDaysRemaining),
            onClose: () => setState(() => _verificationBannerDismissed = true),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context
                .read<HomeViewModel>()
                .fetchLatestTripWithCurrentUserId(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20.0),
                    _buildGreeting(context),
                    const SizedBox(height: 32.0),
                    _buildPlanCard(context),
                    const SizedBox(height: 24.0),
                  ],
                ),
              ),
            ),
          ),
        ),
        _buildBottomButtons(context),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final profilePictureUrl = context.select<HomeViewModel, String?>(
      (viewModel) => viewModel.uiState.profilePictureUrl,
    );
    final profileName = context.select<HomeViewModel, String?>(
      (viewModel) => viewModel.uiState.userName,
    );
    final cachedProfilePicturePath = context.select<HomeViewModel, String?>(
      (viewModel) => viewModel.uiState.cachedProfilePicturePath,
    );
    final cachedProfilePath = cachedProfilePicturePath ?? '';
    final trimmedName = profileName?.trim() ?? '';
    final initial = trimmedName.isEmpty ? 'T' : trimmedName[0].toUpperCase();

    Widget initialAvatar() {
      return Center(
        child: Text(
          initial,
          style: TextStyle(
            color: appTheme.teal_800,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: appTheme.teal_A700, width: 2),
                ),
                child: ClipOval(
                  child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Trek',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ).copyWith(color: appTheme.teal_A700, fontSize: 16),
              ),
            ],
          ),
          Semantics(
            button: true,
            label: 'Open profile',
            child: Material(
              color: appTheme.teal_50,
              shape: CircleBorder(
                side: BorderSide(color: appTheme.gray_100, width: 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _openProfile(context),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child:
                      cachedProfilePath.isNotEmpty &&
                          File(cachedProfilePath).existsSync()
                      ? Image.file(
                          File(cachedProfilePath),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => initialAvatar(),
                        )
                      : profilePictureUrl?.isNotEmpty == true
                      ? Image.network(
                          profilePictureUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, loadingProgress) =>
                              loadingProgress == null ? child : initialAvatar(),
                          errorBuilder: (_, _, _) => initialAvatar(),
                        )
                      : initialAvatar(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _verificationBannerText(int daysRemaining) {
    if (daysRemaining <= 0) return 'Verify your account email to continue.';
    final unit = daysRemaining == 1 ? 'day' : 'days';
    return 'Verify your account email within $daysRemaining $unit.';
  }

  Future<void> _openProfile(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => ProfileScreen.builder(routeContext),
      ),
    );
    if (context.mounted) {
      await context.read<HomeViewModel>().refreshProfile();
    }
  }

  Widget _buildPageIndicator() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => _goToPage(0),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentPage == 0
                    ? appTheme.teal_A700
                    : appTheme.gray_200,
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _goToPage(1),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentPage == 1
                    ? appTheme.teal_A700
                    : appTheme.gray_200,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildGreeting(BuildContext context) {
    final viewModel = context.watch<HomeViewModel>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hi, ${viewModel.uiState.displayName}',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            fontFamily: 'Inter',
            color: appTheme.gray_900,
          ).copyWith(fontSize: 28, height: 1.2),
        ),
        const SizedBox(height: 6),
        Text(
          "Here's your plan for today",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            fontFamily: 'Inter',
            color: appTheme.gray_800,
          ).copyWith(color: appTheme.blue_gray_300, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildPlanCard(BuildContext context) {
    final viewModel = context.watch<HomeViewModel>();
    final state = viewModel.uiState;

    if (state.isLoading) {
      debugPrint('[_buildPlanCard] State is loading...');
      return Container(
        width: double.infinity,
        height: 260,
        decoration: BoxDecoration(
          color: appTheme.gray_100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!state.hasPlan || state.latestTrip == null) {
      debugPrint('[_buildPlanCard] No active plan found in state.');
      return Container(
        width: double.infinity,
        height: 260,
        decoration: BoxDecoration(
          color: appTheme.gray_100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 48, color: appTheme.blue_gray_300),
              const SizedBox(height: 12),
              Text(
                'No plans yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Inter',
                  color: appTheme.gray_800,
                ).copyWith(color: appTheme.blue_gray_300),
              ),
            ],
          ),
        ),
      );
    }

    final trip = state.latestTrip!;
    final startDateStr = DateFormat('MMM dd').format(trip.startDate);
    final endDateStr = DateFormat('MMM dd, yyyy').format(trip.endDate);

    final status = trip.computedStatus.toLowerCase();
    final bool isOngoing = status == 'ongoing';
    final bool isCompleted = status == 'completed';
    final bool isTerminated = status == 'terminated';

    // Prioritize resolved banner from state, falling back to trip.imgUrl
    final String? activeImageUrl =
        (state.bannerImgUrl?.trim().isNotEmpty == true)
        ? state.bannerImgUrl!.trim()
        : (trip.imgUrl?.trim().isNotEmpty == true ? trip.imgUrl!.trim() : null);

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
          onTap: () async {
            await Navigator.of(context).pushNamed(
              '/activityScreen',
              arguments: {'trip': trip, 'isReadOnly': state.isOffline},
            );
            // Refresh trip status when returning (e.g. trip was ended).
            if (context.mounted) {
              context.read<HomeViewModel>().fetchLatestTripWithCurrentUserId();
            }
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
                          color: isTerminated
                              ? appTheme.wholeAlertBudgetBg
                              : isOngoing
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
                              isTerminated
                                  ? Icons.cancel_outlined
                                  : isOngoing
                                  ? Icons.play_circle_outline
                                  : Icons.check_circle_outline,
                              size: 14,
                              color: isTerminated
                                  ? appTheme.errorRed
                                  : isOngoing
                                  ? appTheme.lime_900
                                  : isCompleted
                                  ? appTheme.gray_800
                                  : appTheme.lime_900,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              status.isNotEmpty
                                  ? status[0].toUpperCase() +
                                        status.substring(1)
                                  : 'Pending',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Inter',
                                color: isTerminated
                                    ? appTheme.errorRed
                                    : isOngoing
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
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
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: DualCurrencyAmount(
                            amount: trip.totalBudget,
                            baseCurrency: 'MYR',
                            baseLabel: 'MYR',
                            textAlign: TextAlign.end,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            primaryStyle: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
                      ],
                    ),
                    const SizedBox(height: 12),
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
                        mainAxisSize: MainAxisSize.min,
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
                            ).copyWith(color: appTheme.gray_800),
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

  Widget _buildBottomButtons(BuildContext context) {
    final viewModel = context.watch<HomeViewModel>();
    final trip = viewModel.uiState.latestTrip;

    final bool hasPlan = viewModel.uiState.hasPlan && trip != null;
    final String status = trip?.computedStatus.toLowerCase() ?? 'pending';
    final bool isStartEnabled = hasPlan && status == 'ongoing';

    return Padding(
      padding: const EdgeInsets.only(
        left: 24.0,
        right: 24.0,
        bottom: 28.0,
        top: 12.0,
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                color: isStartEnabled ? appTheme.teal_A700 : appTheme.gray_200,
                borderRadius: BorderRadius.circular(14),
                boxShadow: isStartEnabled
                    ? [
                        BoxShadow(
                          color: appTheme.teal_50,
                          offset: const Offset(0, 4),
                          blurRadius: 8,
                        ),
                      ]
                    : [],
              ),
              child: Material(
                color: appTheme.transparentCustom,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: isStartEnabled
                      ? () async {
                          final now = DateTime.now();
                          final deviceDate = DateTime(
                            now.year,
                            now.month,
                            now.day,
                          );
                          await Navigator.of(context).pushNamed(
                            '/activityScreen',
                            arguments: {
                              'trip': trip,
                              'isReadOnly': false,
                              'filterDate': deviceDate,
                            },
                          );
                          if (context.mounted) {
                            viewModel.fetchLatestTripWithCurrentUserId();
                          }
                        }
                      : null,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'Start Plan',
                        style:
                            const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Inter',
                            ).copyWith(
                              color: isStartEnabled
                                  ? appTheme.white_A700
                                  : appTheme.blue_gray_300,
                              height: 22 / 18,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                color: appTheme.teal_A700,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: appTheme.teal_50,
                    offset: const Offset(0, 4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Material(
                color: appTheme.transparentCustom,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () async {
                    viewModel.prepareNewPlan();
                    await Navigator.of(
                      context,
                    ).pushNamed('/travelInformationInputScreen');
                    if (context.mounted) {
                      final activityViewModel = context
                          .read<ActivityViewModel>();
                      await viewModel.fetchLatestTripWithCurrentUserId();
                      await activityViewModel.initialize();
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'Plan New',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                        ).copyWith(color: appTheme.white_A700, height: 22 / 18),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripBanner(String? imgUrl, {String destination = ''}) {
    const double height = 140.0;

    if (imgUrl == null || imgUrl.trim().isEmpty) {
      return _buildFallBackImagePlaceholder(height);
    }

    final cleanUrl = imgUrl.trim();

    if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
      return Image.network(
        cleanUrl,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: height,
            width: double.infinity,
            color: appTheme.gray_200,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2.0),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildFallBackImagePlaceholder(height);
        },
      );
    }

    if (cleanUrl.startsWith('assets/')) {
      return Image.asset(
        cleanUrl,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildFallBackImagePlaceholder(height);
        },
      );
    }

    return _buildFallBackImagePlaceholder(height);
  }

  Widget _buildFallBackImagePlaceholder(double height) {
    return Container(
      height: height,
      width: double.infinity,
      color: appTheme.gray_200,
      child: Icon(Icons.terrain, size: 48, color: appTheme.blue_gray_300),
    );
  }
}

class _HomeStatusBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isWarning;
  final VoidCallback? onClose;

  const _HomeStatusBanner({
    required this.icon,
    required this.text,
    this.isWarning = false,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final background = isWarning
        ? appTheme.wholeAlertBudgetBg
        : appTheme.teal_50;
    final foreground = isWarning
        ? appTheme.wholeAlertBudgetText
        : appTheme.teal_800;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onClose != null) ...[
            const SizedBox(width: 4),
            IconButton(
              onPressed: onClose,
              tooltip: 'Dismiss verification reminder',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
              icon: Icon(Icons.close_rounded, size: 18, color: foreground),
            ),
          ],
        ],
      ),
    );
  }
}
