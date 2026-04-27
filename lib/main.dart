import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'config/supabase_config.dart';
import 'services/auth_service.dart';
import 'screens/buyer/browse_products_screen.dart';
import 'screens/buyer/buyer_home.dart';
import 'screens/rider/rider_home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );
  
  // Initialize auth service and load saved session
  await AuthService().initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Velaree',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        // Set default text theme with Goudy Bookletter 1911
        textTheme: GoogleFonts.goudyBookletter1911TextTheme(),
        // Set app bar theme with Playfair Display for titles
        appBarTheme: AppBarTheme(
          titleTextStyle: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      home: const AppInitializer(),
      debugShowCheckedModeBanner: false,
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
    return const BrowseProductsScreen(isGuestMode: true);
  }
}
