import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'browse_products_screen.dart';
import '../auth/login_screen.dart';
import '../../utils/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class GuestHome extends StatefulWidget {
  const GuestHome({super.key});

  @override
  State<GuestHome> createState() => _GuestHomeState();
}

class _GuestHomeState extends State<GuestHome> {
  int _currentIndex = 0;
  VoidCallback? _resetToAllProducts;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return;
        }

        final shouldQuit = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5.r),
            ),
            title: Text(
              'Quit App',
              style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
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
        body: _buildBody(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            if (index == 0) {
              _resetToAllProducts?.call();
            }
            setState(() => _currentIndex = index);
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFFD4AF37),
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: GoogleFonts.goudyBookletter1911(
              fontSize: 11.sp, fontWeight: FontWeight.w600),
          unselectedLabelStyle:
              GoogleFonts.goudyBookletter1911(fontSize: 11.sp),
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

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return BrowseProductsScreen(
          isGuestMode: true,
          onResetCallback: (callback) => _resetToAllProducts = callback,
        );
      case 1:
        return _GuestLockedScreen(
          icon: Icons.favorite_border,
          title: 'Your Favorites Await',
          subtitle: 'Sign in to save and view the pieces you love.',
          actionLabel: 'Sign In',
        );
      case 2:
        return _GuestLockedScreen(
          icon: Icons.receipt_long_outlined,
          title: 'Track Your Orders',
          subtitle: 'Sign in to view your order history and updates.',
          actionLabel: 'Sign In',
        );
      case 3:
        return _GuestLockedScreen(
          icon: Icons.person_outline,
          title: 'Your Profile',
          subtitle: 'Sign in to manage your account, addresses, and more.',
          actionLabel: 'Sign In',
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _GuestLockedScreen extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;

  const _GuestLockedScreen({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground(context),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 40.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 80.r,
                  color: AppColors.textFaint(context),
                ),
                SizedBox(height: 24.h),
                Text(
                  title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12.h),
                Text(
                  subtitle,
                  style: GoogleFonts.goudyBookletter1911(
                    fontSize: 14.sp,
                    color: AppColors.textMuted(context),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 36.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LoginScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.onSurface(context),
                      foregroundColor: AppColors.surface(context),
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      actionLabel,
                      style: GoogleFonts.goudyBookletter1911(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const LoginScreen()),
                    );
                  },
                  child: Text(
                    'Create an account',
                    style: GoogleFonts.goudyBookletter1911(
                      fontSize: 13.sp,
                      color: AppColors.textMuted(context),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
