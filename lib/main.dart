import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'config/supabase_config.dart';
import 'services/auth_service.dart';
import 'services/theme_service.dart';
import 'screens/buyer/buyer_home.dart';
import 'screens/buyer/guest_home.dart';
import 'screens/rider/rider_home.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );
  
  // Initialize auth service and load saved session
  await AuthService().initialize();

  // Initialize theme service and load saved dark-mode preference
  await ThemeService().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();

    // Light theme - existing look
    final lightTheme = ThemeData(
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.white,
      textTheme: GoogleFonts.goudyBookletter1911TextTheme(),
      appBarTheme: AppBarTheme(
        titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
    );

    // Dark theme - mirror of light with inverted neutrals
    final darkTheme = ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF121212),
      textTheme: GoogleFonts.goudyBookletter1911TextTheme(
        ThemeData(brightness: Brightness.dark).textTheme,
      ),
      appBarTheme: AppBarTheme(
        titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardColor: const Color(0xFF1E1E1E),
      dividerColor: const Color(0xFF2A2A2A),
    );

    return ScreenUtilInit(
      // Base design size — gamitin ang sukat ng UI mockup mo (default: iPhone 13/14)
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return AnimatedBuilder(
          animation: themeService,
          builder: (context, _) {
            return MaterialApp(
              title: 'Velaree',
              theme: lightTheme,
              darkTheme: darkTheme,
              themeMode: themeService.themeMode,
              home: const SplashScreen(
                nextScreen: AppInitializer(),
              ),
              debugShowCheckedModeBanner: false,
            );
          },
        );
      },
    );
  }
}

class AppInitializer extends StatelessWidget {
  const AppInitializer({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final isLoggedIn = authService.currentUserId != null;
    final userType = authService.currentUserType;

    // Route based on user type
    if (isLoggedIn) {
      if (userType == 'buyer') {
        return const BuyerHome();
      } else if (userType == 'rider') {
        return const RiderHome();
      }
    }

    // Otherwise, show guest mode
    return const GuestHome();
  }
}
