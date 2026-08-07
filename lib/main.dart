import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/configurations/supabase_config.dart';
import 'models/configurations/gemini_api_config.dart';

import 'views/screen/day_itinerary_detail_screen.dart';
import 'views/screen/home_screen.dart';
import 'views/screen/travel_information_input_screen.dart';
import 'views/theme/app_theme.dart';

class AppRoutes {

  static const String homeScreen = '/homeScreen';
  static const String travelInformationInputScreen ='/travelInformationInputScreen';
  static const String dayItineraryDetailScreen = '/dayItineraryDetailScreen';
  static const String initialRoute = homeScreen;
}

class NavigatorService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
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
        AppRoutes.travelInformationInputScreen: (context) => TravelInformationInputScreen.builder(context),
        AppRoutes.dayItineraryDetailScreen: (context) => DayItineraryDetailScreen.builder(context),
      },
    );
  }
}
