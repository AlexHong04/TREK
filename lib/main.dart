import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/configurations/supabase_config.dart';
import 'models/configurations/gemini_api_config.dart';

import 'views/day_itinerary_detail_screen.dart';
import 'views/home_screen.dart';
import 'views/travel_information_input_screen.dart';

class AppRoutes {
  static const String homeScreen = '/homeScreen';
  static const String travelInformationInputScreen =
      '/travelInformationInputScreen';
  static const String dayItineraryDetailScreen = '/dayItineraryDetailScreen';
  static const String initialRoute = homeScreen;
}

class NavigatorService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
}

var globalMessengerKey = GlobalKey<ScaffoldMessengerState>();
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase config
  await SupabaseConfig.initialize();

  // Initialize Gemini config
  GeminiApiConfig.initialize();

  Future.wait([
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
  ]).then((value) {
    runApp(MyApp());
  });
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
        AppRoutes.homeScreen: (context) => HomeScreen.builder(context),
        AppRoutes.travelInformationInputScreen: (context) =>
            TravelInformationInputScreen.builder(context),
        AppRoutes.dayItineraryDetailScreen: (context) =>
            DayItineraryDetailScreen.builder(context),
      },
    );
  }
}

class AppColors {
  // Primary Colors
  static const Color tealA700 = Color(0xFF14BBA6);
  static const Color teal800 = Color(0xFF006B5E);
  static const Color teal800_01 = Color(0xFF006A63);
  static const Color teal700 = Color(0xFF007164);
  static const Color tealA200 = Color(0xFF6EF9E2);
  static const Color teal50 = Color(0xFFCCFBF1);

  // Gray Scale
  static const Color gray900 = Color(0xFF191C1E);
  static const Color gray800 = Color(0xFF3C4946);
  static const Color gray400 = Color(0xFFBBCAC5);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray50_01 = Color(0xFFF0FDFA);
  static const Color gray50_02 = Color(0xFFF8FAFC);
  static const Color gray50_03 = Color(0xFFF7F9FB);

  // Blue Gray
  static const Color blueGray900 = Color(0xFF1F2937);
  static const Color blueGray800 = Color(0xFF374151);
  static const Color blueGray700 = Color(0xFF4B5563);
  static const Color blueGray300 = Color(0xFF9CA3AF);
  static const Color blueGray50 = Color(0xFFECEEF0);

  // Accent Colors
  static const Color amber200 = Color(0xFFFDE68A);
  static const Color lime900 = Color(0xFF937600);
  static const Color errorRed = Color(0xFFEF4444);

  // Neutrals
  static const Color white = Color(0xFFFFFFFF);
  static const Color black900_0c = Color(0x0C000000);
  static const Color transparent = Colors.transparent;
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      visualDensity: VisualDensity.standard,

      colorScheme: const ColorScheme.light(
        primary: AppColors.tealA700,
        onPrimary: AppColors.white,
        surface: AppColors.white,
        onSurface: AppColors.blueGray900,
      ),
    );
  }
}

class AppThemeData {
  final Color transparentCustom = AppColors.transparent;

  final Color gray_50_02 = AppColors.gray50_02;
  final Color gray_50_03 = AppColors.gray50_03;

  final Color teal_A700 = AppColors.tealA700;
  final Color teal_800 = AppColors.teal800;
  final Color teal_50 = AppColors.teal50;
  final Color teal_A200 = AppColors.tealA200;
  final Color teal_700 = AppColors.teal700;

  final Color white_A700 = AppColors.white;

  final Color blue_gray_50 = AppColors.blueGray50;
  final Color blue_gray_300 = AppColors.blueGray300;
  final Color blue_gray_700 = AppColors.blueGray700;

  final Color gray_50 = AppColors.gray50;
  final Color gray_100 = AppColors.gray100;
  final Color gray_200 = AppColors.gray200;

  final Color colorFFEF44 = AppColors.errorRed;

  final Color black_900_0c = AppColors.black900_0c;

  final Color amber_200 = AppColors.amber200;
  final Color lime_900 = AppColors.lime900;

  final Color grey200 = AppColors.gray200;
  final Color grey100 = AppColors.gray100;
}

final appTheme = AppThemeData();

final theme = AppTheme.lightTheme;
