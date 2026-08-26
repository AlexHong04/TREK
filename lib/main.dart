import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';
import 'models/configurations/supabase_config.dart';
import 'models/configurations/gemini_api_config.dart';
import 'models/local_data_source/location_source.dart';

import 'models/repository/auth_repository.dart';
import 'models/repository/i_user_repository.dart';
import 'models/repository/user_repository.dart';

import 'models/services/auth_service.dart';
import 'models/services/i_auth_service.dart';

import 'views/login_screen.dart';
import 'views/registration_screen.dart';
import 'views/email_submission_screen.dart';
import 'views/whole_itinerary_detail_screen.dart';
import 'views/home_screen.dart';
import 'views/travel_information_input_screen.dart';
import 'views/activity_screen.dart';
import 'views/financial_dashboard_screen.dart';
import 'views/trip_summary_screen.dart';

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
  // static const String initialRoute = loginScreen;
  static const String initialRoute = homeScreen;
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

  // Initialize Supabase config
  await SupabaseConfig.initialize();

  // Initialize Gemini config
  GeminiApiConfig.initialize();

  final IUserRepository userRepository = UserRepository(SupabaseConfig.client);

  final authRepository = AuthRepository(
    SupabaseConfig.client,
    authCallbackUrl: SupabaseConfig.authCallbackUrl,
    passwordResetCallbackUrl: SupabaseConfig.passwordResetCallbackUrl,
  );

  final IAuthService authService = AuthService(authRepository, userRepository);

  runApp(
    ChangeNotifierProvider<IAuthService>.value(
      value: authService,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trek',
      debugShowCheckedModeBanner: false,
      theme: theme,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.0)),
          child: child!,
        );
      },
      navigatorKey: NavigatorService.navigatorKey,
      initialRoute: AppRoutes.initialRoute,

      routes: {
        AppRoutes.loginScreen: (context) => LoginScreen.builder(
          context,
          onLoginSuccess: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.homeScreen,
              (route) => false,
            );
          },
          onRegister: () {
            Navigator.pushNamed(
              context,
              AppRoutes.registrationScreen,
            );
          },
          onForgotPassword: () {
            Navigator.pushNamed(
              context,
              AppRoutes.forgotPasswordScreen,
            );
          },
        ),

        AppRoutes.registrationScreen: (context) =>
            RegistrationScreen.builder(context),

        AppRoutes.forgotPasswordScreen: (context) =>
            EmailSubmissionScreen.builder(context),

        AppRoutes.homeScreen: (context) => HomeScreen.builder(context),

        AppRoutes.travelInformationInputScreen: (context) =>
            TravelInformationInputScreen.builder(context),

        AppRoutes.wholeItineraryDetailScreen: (context) =>
            WholeItineraryDetailScreen.builder(context),

        AppRoutes.activityScreen: (context) => ActivityScreen.builder(context),
        AppRoutes.financialDashboardScreen: (context) =>
            const FinancialDashboardScreen(),
        AppRoutes.tripSummaryScreen: (context) => const TripSummaryScreen(),
      },
    );
  }
}
