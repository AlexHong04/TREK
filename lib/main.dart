import 'package:Trek/views/edit_profile_screen.dart';
import 'package:Trek/views/password_reset_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';
import 'models/configurations/supabase_config.dart';
import 'models/configurations/gemini_api_config.dart';

import 'models/repository/auth_repository.dart';
import 'models/repository/user_repository.dart';
import 'models/repository/i_itinerary_repository.dart';
import 'models/repository/itinerary_repository.dart';
import 'models/repository/expense_repository.dart';

import 'models/services/auth_service.dart';
import 'models/services/i_auth_service.dart';
import 'models/services/i_itinerary_service.dart';
import 'models/services/itinerary_service.dart';
import 'models/services/budget_service.dart';
import 'models/services/expense_tracking_service.dart';
import 'models/services/profile_service.dart';

import 'views/login_screen.dart';
import 'views/registration_screen.dart';
import 'views/email_submission_screen.dart';
import 'views/whole_itinerary_detail_screen.dart';
import 'views/home_screen.dart';
import 'views/travel_information_input_screen.dart';
import 'views/activity_screen.dart';
import 'views/financial_dashboard_screen.dart';
import 'views/all_plans_screen.dart';

class AppRoutes {
  static const String loginScreen = '/login';
  static const String registrationScreen = '/register';
  static const String forgotPasswordScreen = '/forgotPassword';
  static const String resetPasswordScreen = '/resetPassword';
  static const String editProfileScreen = '/editProfile';
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

  // Initialize Supabase config
  await SupabaseConfig.initialize();

  // Initialize Gemini config
  GeminiApiConfig.initialize();

  final authRepository = AuthRepository(
    SupabaseConfig.client,
    authCallbackUrl: SupabaseConfig.authCallbackUrl,
    passwordResetCallbackUrl: SupabaseConfig.passwordResetCallbackUrl,
  );

  final userRepository = UserRepository(SupabaseConfig.client, authRepository);

  final profileService = ProfileService(userRepository);

  final authService = AuthService(userRepository, profileService);

  await authService.restoreSession();
  final IItineraryRepository itineraryRepository = ItineraryRepository();
  final IExpenseRepository expenseRepository = ExpenseRepository();
  final IItineraryService itineraryService = ItineraryService();
  final IBudgetService budgetService = BudgetService(authService: authService);
  final IExpenseTrackingService expenseTrackingService = ExpenseTrackingService(
    authService: authService,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<IItineraryRepository>.value(value: itineraryRepository),
        Provider<IExpenseRepository>.value(value: expenseRepository),
        Provider<IItineraryService>.value(value: itineraryService),
        Provider<IBudgetService>.value(value: budgetService),
        Provider<IExpenseTrackingService>.value(value: expenseTrackingService),
        ChangeNotifierProvider<IAuthService>.value(value: authService),
      ],
      child: MyApp(authService: authService),
    ),
  );
}

class MyApp extends StatefulWidget {
  final IAuthService authService;

  const MyApp({super.key, required this.authService});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool _wasLoggedIn;
  late bool _wasPasswordRecovery;

  @override
  void initState() {
    super.initState();
    _wasLoggedIn = widget.authService.isLoggedIn;
    _wasPasswordRecovery = widget.authService.isPasswordRecovery;
    widget.authService.addListener(_handleAuthChange);
  }

  @override
  void dispose() {
    widget.authService.removeListener(_handleAuthChange);
    super.dispose();
  }

  void _handleAuthChange() {
    final isLoggedIn = widget.authService.isLoggedIn;
    final isRecovery = widget.authService.isPasswordRecovery;
    final shouldOpenRecovery = isRecovery && !_wasPasswordRecovery;
    final shouldOpenHome = !isRecovery && isLoggedIn && !_wasLoggedIn;
    final shouldOpenLogin = !isRecovery && !isLoggedIn && _wasLoggedIn;

    _wasLoggedIn = isLoggedIn;
    _wasPasswordRecovery = isRecovery;

    if (!shouldOpenRecovery && !shouldOpenHome && !shouldOpenLogin) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = NavigatorService.navigatorKey.currentState;
      if (navigator == null) return;
      final route = shouldOpenRecovery
          ? AppRoutes.resetPasswordScreen
          : shouldOpenHome
          ? AppRoutes.homeScreen
          : AppRoutes.loginScreen;
      navigator.pushNamedAndRemoveUntil(route, (_) => false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final initialRoute = widget.authService.isPasswordRecovery
        ? AppRoutes.resetPasswordScreen
        : widget.authService.isLoggedIn
        ? AppRoutes.homeScreen
        : AppRoutes.loginScreen;

    return MaterialApp(
      title: 'TREK',
      debugShowCheckedModeBanner: false,
      theme: theme,
      navigatorKey: NavigatorService.navigatorKey,
      scaffoldMessengerKey: globalMessengerKey,
      initialRoute: initialRoute,
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
        AppRoutes.editProfileScreen: (context) =>
            EditProfileScreen.builder(context),

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
