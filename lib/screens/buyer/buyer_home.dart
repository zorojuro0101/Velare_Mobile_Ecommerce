import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'browse_products_screen.dart';
import 'favorites_screen.dart';
import 'order_history_screen.dart';
import 'profile_screen.dart';

import '../../utils/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
class BuyerHome extends StatefulWidget {
  const BuyerHome({super.key});

  @override
  State<BuyerHome> createState() => _BuyerHomeState();
}

class _BuyerHomeState extends State<BuyerHome> {
  int _currentIndex = 0;
  VoidCallback? _resetToAllProducts;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      BrowseProductsScreen(
        onResetCallback: (callback) => _resetToAllProducts = callback,
      ),
      const FavoritesScreen(),
      const OrderHistoryScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        // If not on home tab, go back to home tab
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
          return;
        }
        
        // If on home tab, show quit confirmation dialog
        final shouldQuit = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5.r),
            ),
            title: Text(
              'Quit App',
              style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'Are you sure you want to quit?',
              style: GoogleFonts.goudyBookletter1911(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.goudyBookletter1911(
                    color: AppColors.textBody(context),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  'Quit',
                  style: GoogleFonts.goudyBookletter1911(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
        
        if (shouldQuit == true) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: _screens[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          // Always reset to "All Products" when Home is tapped
          if (index == 0) {
            _resetToAllProducts?.call();
          }
          setState(() => _currentIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFD4AF37),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: GoogleFonts.goudyBookletter1911(fontSize: 11.sp, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.goudyBookletter1911(fontSize: 11.sp),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_outline),
            activeIcon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      ),
    );
  }
}
