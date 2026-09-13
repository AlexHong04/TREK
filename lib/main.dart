import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';
import 'utils/network_error.dart';
import 'utils/input_validator.dart';

import 'models/configurations/supabase_config.dart';
import 'models/configurations/gemini_api_config.dart';

import 'models/repository/auth_repository.dart';
import 'models/repository/i_auth_repository.dart';
import 'models/repository/i_user_repository.dart';
import 'models/repository/user_repository.dart';
import 'models/repository/i_itinerary_repository.dart';
import 'models/repository/itinerary_repository.dart';
import 'models/repository/expense_repository.dart';

import 'models/services/auth_service.dart';
import 'models/services/i_auth_service.dart';
import 'models/services/i_profile_service.dart';
import 'models/services/profile_service.dart';
import 'models/services/i_itinerary_service.dart';
import 'models/services/itinerary_service.dart';
import 'models/services/budget_service.dart';
import 'models/services/expense_tracking_service.dart';

import 'views/login_screen.dart';
import 'views/registration_screen.dart';
import 'views/email_submission_screen.dart';
import 'views/edit_profile_screen.dart';
import 'views/password_reset_screen.dart';
import 'views/profile_screen.dart';
import 'views/delete_account_confirmation_screen.dart';
import 'views/edit_account_screen.dart';
import 'views/verification_gate_screen.dart';
import 'views/whole_itinerary_detail_screen.dart';
import 'views/home_screen.dart';
import 'views/user_guide_bottom_sheet.dart';
import 'views/travel_information_input_screen.dart';
import 'views/activity_screen.dart';
import 'views/financial_dashboard_screen.dart';
import 'views/all_plans_screen.dart';

class AppRoutes {
  static const String loginScreen = '/login';
  static const String registrationScreen = '/register';
  static const String forgotPasswordScreen = '/forgotPassword';
  static const String resetPasswordScreen = '/resetPassword';
  static const String verificationGateScreen = '/verificationRequired';
  static const String deletionConfirmationScreen = '/confirmDeletion';
  static const String editProfileScreen = '/editProfile';
  static const String editAccountScreen = '/editAccount';
  static const String profileScreen = '/profile';
  static const String homeScreen = '/homeScreen';
  static const String travelInformationInputScreen =
      '/travelInformationInputScreen';
  static const String wholeItineraryDetailScreen =
      '/wholeItineraryDetailScreen';
  static const String activityScreen = '/activityScreen';
  static const String financialDashboardScreen = '/financialDashboardScreen';
  static const String tripSummaryScreen = '/tripSummaryScreen';
  static const String allPlansScreen = '/allPlansScreen';
  static const String initialRoute = loginScreen;
}

class NavigatorService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
}

final GlobalKey<ScaffoldMessengerState> globalMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // sys nav bar solid white back + dark icons
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  InputValidator.initializePublicTextFilter();

  // Initialize Supabase config
  await SupabaseConfig.initialize();

  // Initialize Gemini config
  GeminiApiConfig.initialize();

  final IAuthRepository authRepository = AuthRepository(
    SupabaseConfig.client,
    authCallbackUrl: SupabaseConfig.authCallbackUrl,
    passwordResetCallbackUrl: SupabaseConfig.passwordResetCallbackUrl,
  );

  final IUserRepository userRepository = UserRepository(SupabaseConfig.client);
  final authService = AuthService(authRepository, userRepository);
  final profileService = ProfileService(userRepository, authService);

  try {
    await authService.restoreSession();
  } on NetworkUnavailableException {
    // With no saved profile there is nothing safe to show offline. The app
    // still starts at Login and retries when connectivity returns.
  }

  final IItineraryRepository itineraryRepository = ItineraryRepository();
  final IExpenseRepository expenseRepository = ExpenseRepository();
  final IItineraryService itineraryService = ItineraryService();
  final IBudgetService budgetService = BudgetService(profileService: profileService);
  final IExpenseTrackingService expenseTrackingService = ExpenseTrackingService(
    profileService: profileService,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<IItineraryRepository>.value(value: itineraryRepository),
        Provider<IExpenseRepository>.value(value: expenseRepository),
        Provider<IItineraryService>.value(value: itineraryService),
        Provider<IBudgetService>.value(value: budgetService),
        Provider<IExpenseTrackingService>.value(value: expenseTrackingService),
        ListenableProvider<IAuthService>.value(value: authService),
        ListenableProvider<IProfileService>.value(value: profileService),
      ],
      child: MyApp(authService: authService),
    ),
  );
}

class MyApp extends StatefulWidget {
  final IAuthService authService;

  const MyApp({
    super.key,
    required this.authService,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  AuthDestination? _lastRoutedDestination;
  bool _navigationScheduled = false;

  /// Shows the one-off user guide as soon as the Home route is on screen.
  /// Doing it here (rather than only inside the Home widget) means the guide
  /// cannot be missed because of Home's mount/reload timing.
  late final NavigatorObserver _userGuideObserver = _UserGuideRouteObserver();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastRoutedDestination = widget.authService.destination;
    widget.authService.addListener(_scheduleAuthNavigation);
  }

  @override
  void dispose() {
    widget.authService.removeListener(_scheduleAuthNavigation);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshAfterResume());
    }
  }

  Future<void> _refreshAfterResume() async {
    try {
      await widget.authService.onAppResumed();
    } on NetworkUnavailableException {
      // AuthService keeps and exposes the last safe cached profile.
    } catch (_) {
      // A resume refresh must never escape into Flutter's framework zone.
    }
  }

  void _scheduleAuthNavigation() {
    if (_navigationScheduled || !mounted) return;
    _navigationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigationScheduled = false;
      if (!mounted) return;

      final destination = widget.authService.destination;
      if (destination == _lastRoutedDestination) return;
      final navigator = NavigatorService.navigatorKey.currentState;
      if (navigator == null) {
        _scheduleAuthNavigation();
        return;
      }

      _lastRoutedDestination = destination;
      navigator.pushNamedAndRemoveUntil(
        _routeFor(destination),
            (_) => false,
      );
    });
  }

  String _routeFor(AuthDestination destination) {
    switch (destination) {
      case AuthDestination.passwordRecovery:
        return AppRoutes.resetPasswordScreen;
      case AuthDestination.verificationRequired:
        return AppRoutes.verificationGateScreen;
      case AuthDestination.deletionConfirmation:
        return AppRoutes.deletionConfirmationScreen;
      case AuthDestination.normalApp:
        return AppRoutes.homeScreen;
      case AuthDestination.signedOut:
        return AppRoutes.loginScreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TREK',
      debugShowCheckedModeBanner: false,
      theme: theme,
      navigatorKey: NavigatorService.navigatorKey,
      scaffoldMessengerKey: globalMessengerKey,
      navigatorObservers: [_userGuideObserver],
      initialRoute: _routeFor(widget.authService.destination),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.0)),
          child: child!,
        );
      },
      routes: {
        AppRoutes.loginScreen: (context) => LoginScreen.builder(context),
        AppRoutes.registrationScreen: (context) =>
            RegistrationScreen.builder(context),
        AppRoutes.forgotPasswordScreen: (context) =>
            EmailSubmissionScreen.builder(context),
        AppRoutes.resetPasswordScreen: (context) =>
            PasswordResetScreen.builder(context),
        AppRoutes.verificationGateScreen: (context) =>
            VerificationGateScreen.builder(context),
        AppRoutes.deletionConfirmationScreen: (context) =>
            DeleteAccountConfirmationScreen.builder(context),
        AppRoutes.editProfileScreen: (context) =>
            EditProfileScreen.builder(context),
        AppRoutes.editAccountScreen: (context) =>
            EditAccountScreen.builder(context),
        AppRoutes.profileScreen: (context) => ProfileScreen.builder(context),
        AppRoutes.homeScreen: (context) => HomeScreen.builder(context),

        AppRoutes.travelInformationInputScreen: (context) =>
            TravelInformationInputScreen.builder(context),

        AppRoutes.wholeItineraryDetailScreen: (context) =>
            WholeItineraryDetailScreen.builder(context),

        AppRoutes.activityScreen: (context) => ActivityScreen.builder(context),
        AppRoutes.financialDashboardScreen: (context) =>
            FinancialDashboardScreen.builder(context),
        AppRoutes.allPlansScreen: (context) => AllPlansScreen.builder(context),
      },
    );
  }
}

/// Watches route pushes so the one-off user guide can be shown the moment the
/// tourist lands on the Home screen.
class _UserGuideRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route.settings.name != AppRoutes.homeScreen) return;

    // Let the Home route finish its first frame before opening the sheet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = NavigatorService.navigatorKey.currentContext;
      if (context == null) return;
      unawaited(maybeShowUserGuide(context));
    });
  }
}
