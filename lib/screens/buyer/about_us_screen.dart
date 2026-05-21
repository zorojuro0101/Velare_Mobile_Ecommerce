import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'package:visibility_detector/visibility_detector.dart';

import '../../utils/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
class AboutUsScreen extends StatefulWidget {
  const AboutUsScreen({super.key});

  @override
  State<AboutUsScreen> createState() => _AboutUsScreenState();
}

class _AboutUsScreenState extends State<AboutUsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Video controllers
  VideoPlayerController? _heroVideoController;
  VideoPlayerController? _promiseVideoController;

  // Image carousel indices for fade transitions
  int _section1ImageIndex = 0;
  int _section4ImageIndex = 0;
  int _section5ImageIndex = 0;
  int _section6ImageIndex = 0;

  // Timers for image transitions
  Timer? _section1Timer;
  Timer? _section4Timer;
  Timer? _section5Timer;
  Timer? _section6Timer;

  // Section 2 animation triggers
  bool _section2Visible = false;
  
  // Section 1 images
  final List<String> _section1Images = [
    'assets/images/about_us/cae471df4fa9995898498a7a69a0fe6b.jpg',
    'assets/images/about_us/dilaw.png',
    'assets/images/about_us/sayaw.png',
    'assets/images/about_us/Untitled design (1).png',
    'assets/images/about_us/VO090118_coverstory02 copy2.webp',
  ];
  
  // Section 4 images
  final List<String> _section4Images = [
    'assets/images/about_us/section4/pexels-photo-8483558.webp',
    'assets/images/about_us/section4/Website-FEATURED-IMAGE-1200-×-628px-56.webp',
    'assets/images/about_us/section4/Women-Climate-Change_7a6f315d-6c08-431f-a4e4-31476ff9c786_1000x.webp',
  ];
  
  // Section 5 images
  final List<String> _section5Images = [
    'assets/images/about_us/section5/EDITED-Blog-RESDA-Uganda-Sewing-Center-Sept-Visit-USANA-Foundation-scaled.jpg',
    'assets/images/about_us/section5/habi-filipino-weaving-techniques-865050.webp',
    'assets/images/about_us/section5/isatou-ceesay.png',
    'assets/images/about_us/section5/WomenPlantingTrees.jpg',
  ];
  
  // Section 6 images
  final List<String> _section6Images = [
    'assets/images/about_us/section6/card-from-seed-to-store-roadmap.jpg',
    'assets/images/about_us/section6/china.jpg',
    'assets/images/about_us/section6/shutterstock_778298764-1_auto.png',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
    
    // Start image fade timers
    _startImageTimers();
    
    // Initialize videos after a delay to avoid blocking UI
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _initializeVideos();
      }
    });
  }
  
  void _startImageTimers() {
    // Section 1 - 4 second intervals
    _section1Timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _section1ImageIndex = (_section1ImageIndex + 1) % _section1Images.length;
        });
      }
    });
    
    // Section 4 - 5 second intervals
    _section4Timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _section4ImageIndex = (_section4ImageIndex + 1) % _section4Images.length;
        });
      }
    });
    
    // Section 5 - 5 second intervals
    _section5Timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _section5ImageIndex = (_section5ImageIndex + 1) % _section5Images.length;
        });
      }
    });
    
    // Section 6 - 5 second intervals
    _section6Timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _section6ImageIndex = (_section6ImageIndex + 1) % _section6Images.length;
        });
      }
    });
  }
  
  Future<void> _initializeVideos() async {
    try {
      // Hero video - try to load it with timeout
      _heroVideoController = VideoPlayerController.asset('assets/videos/pm_11872_1214_1214538-06xy8yl893-ori.webm')
        ..setLooping(true)
        ..setVolume(0);
      
      _heroVideoController!.initialize().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          print('⏱️ Hero video timeout');
          return Future.value();
        },
      ).then((_) {
        if (mounted) {
          setState(() {});
          _heroVideoController?.play();
        }
      }).catchError((error) {
        print('Error loading hero video: $error');
      });
      
      // Promise video - Fixed filename (removed spaces)
      print('🎥 Loading promise video (70MB file, may take time)...');
      _promiseVideoController = VideoPlayerController.asset(
        'assets/videos/partners/last-video.mp4',
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      )
        ..setLooping(true)
        ..setVolume(0);
      
      // Longer timeout for large file (15 seconds)
      _promiseVideoController!.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('⏱️ Promise video timeout after 15s - file is 70MB');
          return Future.value();
        },
      ).then((_) {
        if (mounted && _promiseVideoController!.value.isInitialized) {
          print('✅ Promise video initialized successfully (70MB)');
          setState(() {});
          _promiseVideoController?.play().then((_) {
            print('▶️ Promise video playing');
          });
        } else {
          print('⚠️ Promise video not initialized after timeout');
        }
      }).catchError((error) {
        print('❌ Error loading promise video: $error');
      });
    } catch (e) {
      print('Error initializing videos: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _heroVideoController?.dispose();
    _promiseVideoController?.dispose();
    _section1Timer?.cancel();
    _section4Timer?.cancel();
    _section5Timer?.cancel();
    _section6Timer?.cancel();
    super.dispose();
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch URL')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground(context),
      appBar: AppBar(
        title: Text(
          'About Us',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            fontSize: 22.sp,
          ),
        ),
        backgroundColor: AppColors.surface(context),
        foregroundColor: AppColors.onSurface(context),
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroSection(),
              _buildSection1(),
              _buildSection2(),
              _buildSection3(),
              _buildSection4(),
              _buildSection5(),
              _buildSection6(),
              _buildSection7(),
              _buildSection8(),
              _buildSection9(),
              SizedBox(height: 40.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      height: 300.h,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF2C2236),
      ),
      child: Stack(
        children: [
          // Background video or image
          Positioned.fill(
            child: _heroVideoController != null && _heroVideoController!.value.isInitialized
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _heroVideoController!.value.size.width,
                      height: _heroVideoController!.value.size.height,
                      child: VideoPlayer(_heroVideoController!),
                    ),
                  )
                : Image.asset(
                    'assets/images/about_us/cae471df4fa9995898498a7a69a0fe6b.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFF2C2236)),
                  ),
          ),
          // Dark overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
          ),
          // Text content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'About Us',
                  style: GoogleFonts.cinzel(
                    fontSize: 36.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.alwaysWhite,
                    letterSpacing: 3.sp,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  'Where Elegance Meets Purpose',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 20.sp,
                    color: Colors.white.withValues(alpha: 0.95),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection1() {
    return Container(
      padding: EdgeInsets.all(24.w),
      margin: EdgeInsets.only(bottom: 250.h),
      child: Column(
        children: [
          // Image with fade transition (fixed height and width with proper aspect ratio)
          Container(
            height: 300.h,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.r),
              color: AppColors.surfaceVariant2(context),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 1000),
                child: Image.asset(
                  _section1Images[_section1ImageIndex],
                  key: ValueKey<int>(_section1ImageIndex),
                  fit: BoxFit.cover, // Cover ensures consistent size, crops if needed
                  width: double.infinity,
                  height: 300.h,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppColors.border(context),
                    child: const Icon(Icons.error),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 32.h),
          // Velare Logo with visibility-based fade-in animation
          VisibilityDetector(
            key: const Key('velare_logo'),
            onVisibilityChanged: (info) {},
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 500),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 30 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Image.asset(
                'assets/images/velarelogo.png',
                height: 80.h,
                errorBuilder: (context, error, stackTrace) => SizedBox(height: 80.h),
              ),
            ),
          ),
          SizedBox(height: 24.h),
          _buildAnimatedText(
            'Velare is more than a label — it\'s a movement redefining what luxury stands for.',
            delay: 200,
          ),
          SizedBox(height: 16.h),
          _buildAnimatedText(
            'We believe that true elegance is not only worn — it\'s lived.',
            delay: 400,
          ),
          SizedBox(height: 16.h),
          _buildAnimatedText(
            'Crafted with intention, guided by conscience, and inspired by beauty that empowers women and sustains the world we share.',
            delay: 600,
          ),
        ],
      ),
    );
  }

  Widget _buildSection2() {
    return VisibilityDetector(
      key: const Key('section2_trigger'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.3 && !_section2Visible) {
          setState(() {
            _section2Visible = true;
          });
        }
      },
      child: Container(
        padding: EdgeInsets.all(32.w),
        margin: EdgeInsets.only(bottom: 6.h),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAnimatedText(
              'Our Story:',
              delay: 0,
              style: GoogleFonts.playfairDisplay(
                fontSize: 56.sp,
                fontWeight: FontWeight.bold,
                letterSpacing: -1.5.sp,
                height: 1.1,
              ),
              alignment: Alignment.centerLeft,
            ),
            SizedBox(height: 24.h),
            Wrap(
              children: [
                _buildAnimatedText(
                  'Born from ',
                  delay: 0,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 32.sp,
                    color: const Color(0xFFBF9F4A),
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                  alignment: Alignment.centerLeft,
                ),
                _buildAnimatedText(
                  'Elegance',
                  delay: _section2Visible ? 5000 : 999999,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 32.sp,
                    color: const Color(0xFFBF9F4A),
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                  alignment: Alignment.centerLeft,
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Wrap(
              children: [
                _buildAnimatedText(
                  'Guided by ',
                  delay: 0,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 32.sp,
                    color: const Color(0xFFBF9F4A),
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                  alignment: Alignment.centerLeft,
                ),
                _buildAnimatedText(
                  'Conscience',
                  delay: _section2Visible ? 10000 : 999999,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 32.sp,
                    color: const Color(0xFFBF9F4A),
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                  alignment: Alignment.centerLeft,
                ),
              ],
            ),
            SizedBox(height: 40.h),
            _buildAnimatedText(
              'Founded on the belief that fashion should embody both artistry and responsibility, Velare was created to celebrate women — their strength, creativity, and grace.',
              delay: 0,
              style: GoogleFonts.goudyBookletter1911(
                fontSize: 18.sp,
                height: 1.6,
                color: AppColors.textBodyStrong(context),
              ),
              alignment: Alignment.centerLeft,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection3() {
    return Container(
      padding: EdgeInsets.all(24.w),
      margin: EdgeInsets.only(bottom: 40.h),
      child: Column(
        children: [
          SizedBox(height: 80.h), // Increased gap at the top
          _buildAnimatedText(
            'We embrace sustainability not as a trend, but as a principle. From our in-house production led by women artisans to our use of biodegradable materials, every collection reflects our commitment to beauty that uplifts, respects, and endures.',
            delay: 0,
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 15.sp,
              height: 1.6,
              color: AppColors.textBodyStrong(context),
            ),
          ),
          SizedBox(height: 20.h),
          _buildAnimatedText(
            'Our journey is shaped by the United Nations Sustainable Development Goals, particularly:',
            delay: 200,
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 14.sp,
              height: 1.6,
              color: AppColors.textBody(context),
            ),
          ),
          SizedBox(height: 24.h),
          _buildSDGGrid(),
        ],
      ),
    );
  }

  Widget _buildSDGGrid() {
    final sdgs = [
      'assets/images/sdg/SDG5.png',
      'assets/images/sdg/SDG8.png',
      'assets/images/sdg/SDG12.png',
      'assets/images/sdg/SDG13.png',
      'assets/images/sdg/SDG15.png',
      'assets/images/sdg/SDG17.png',
    ];

    return VisibilityDetector(
      key: const Key('sdg_grid'),
      onVisibilityChanged: (info) {},
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 500),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 30 * (1 - value)),
              child: child,
            ),
          );
        },
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: sdgs.length,
          itemBuilder: (context, index) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(8.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: Image.asset(
                  sdgs[index],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppColors.surfaceVariant2(context),
                    child: const Icon(Icons.eco, color: Color(0xFFBF9F4A)),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSection4() {
    return Container(
      padding: EdgeInsets.all(24.w),
      margin: EdgeInsets.only(bottom: 40.h),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Image with fade transition (no shadow)
          Container(
            height: 250.h,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 1000),
                child: Image.asset(
                  _section4Images[_section4ImageIndex],
                  key: ValueKey<int>(_section4ImageIndex),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppColors.border(context),
                    child: const Icon(Icons.error),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 24.h),
          _buildAnimatedText(
            'Empowering Women and Communities',
            delay: 0,
            style: GoogleFonts.playfairDisplay(
              fontSize: 26.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 20.h),
          _buildAnimatedText(
            'Behind every creation lies a story of empowerment. Through our in-house production, Velare provides meaningful opportunities for women artisans — nurturing craftsmanship, leadership, and independence.',
            delay: 200,
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 15.sp,
              height: 1.6,
              color: AppColors.textBodyStrong(context),
            ),
          ),
          SizedBox(height: 16.h),
          _buildAnimatedText(
            'We take pride in the diversity of our community — from designers and tailors to local suppliers — each one contributing to a tapestry of culture, creativity, and collaboration. Every piece carries their touch, their story, their artistry.',
            delay: 400,
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 15.sp,
              height: 1.6,
              color: AppColors.textBodyStrong(context),
            ),
          ),
          SizedBox(height: 24.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSDGImageBadge('assets/images/sdg/SDG5.png'),
              SizedBox(width: 16.w),
              _buildSDGImageBadge('assets/images/sdg/SDG8.png'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection5() {
    return Container(
      padding: EdgeInsets.all(24.w),
      margin: EdgeInsets.only(bottom: 250.h),
      child: Column(
        children: [
          // Image with text overlay - reduced height to match smallest video
          Container(
            height: 200.h,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: Stack(
                children: [
                  // Changing background image
                  Positioned.fill(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 1000),
                      child: Image.asset(
                        _section5Images[_section5ImageIndex],
                        key: ValueKey<int>(_section5ImageIndex),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: AppColors.border(context),
                          child: const Icon(Icons.error),
                        ),
                      ),
                    ),
                  ),
                  // Dark overlay
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.5),
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Text content
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.all(20.w),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildAnimatedText(
                            'Sustainability in Every Stitch',
                            delay: 0,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 28.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.alwaysWhite,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          _buildAnimatedText(
                            'At Velare, we design with the Earth in mind.',
                            delay: 200,
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 18.sp,
                              fontStyle: FontStyle.italic,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection6() {
    return Container(
      padding: EdgeInsets.all(24.w),
      margin: EdgeInsets.only(bottom: 250.h),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildAnimatedText(
            'Tradition Meets Innovation',
            delay: 0,
            style: GoogleFonts.playfairDisplay(
              fontSize: 26.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 20.h),
          _buildAnimatedText(
            'We honor craftsmanship passed down through generations while embracing innovation that advances sustainability.',
            delay: 200,
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 15.sp,
              height: 1.6,
              color: AppColors.textBodyStrong(context),
            ),
          ),
          SizedBox(height: 16.h),
          _buildAnimatedText(
            'Guided by SDG 9: Industry, Innovation, and Infrastructure, we invest in modern methods and technologies that preserve both quality and planet.',
            delay: 400,
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 15.sp,
              height: 1.6,
              color: AppColors.textBodyStrong(context),
            ),
          ),
          SizedBox(height: 16.h),
          _buildAnimatedText(
            'The result — timeless pieces that embody modern luxury, without compromise.',
            delay: 600,
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 15.sp,
              height: 1.6,
              color: AppColors.textBodyStrong(context),
            ),
          ),
          SizedBox(height: 24.h),
          // Image with fade transition (no shadow)
          Container(
            height: 250.h,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 1000),
                child: Image.asset(
                  _section6Images[_section6ImageIndex],
                  key: ValueKey<int>(_section6ImageIndex),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppColors.border(context),
                    child: const Icon(Icons.error),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 24.h),
          _buildSDGImageBadge('assets/images/sdg/SDG9.png'),
        ],
      ),
    );
  }

  Widget _buildSection7() {
    return Container(
      padding: EdgeInsets.all(24.w),
      margin: EdgeInsets.only(bottom: 250.h),
      child: Column(
        children: [
          _buildAnimatedText(
            'Collaborating for Change',
            delay: 0,
            style: GoogleFonts.playfairDisplay(
              fontSize: 26.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12.h),
          _buildAnimatedText(
            'Meaningful impact is never achieved alone.',
            delay: 200,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 18.sp,
              fontStyle: FontStyle.italic,
              color: AppColors.textBody(context),
            ),
          ),
          SizedBox(height: 20.h),
          _buildAnimatedText(
            'Through partnerships with local cooperatives, eco-design advocates, and community organizations, we advance SDG 17: Partnerships for the Goals — building a network that uplifts artisans and encourages responsible fashion practices. Together, we are redefining what luxury can mean: inclusive, conscious, and transformative.',
            delay: 400,
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 15.sp,
              height: 1.6,
              color: AppColors.textBodyStrong(context),
            ),
          ),
          SizedBox(height: 24.h),
          _buildSDGImageBadge('assets/images/sdg/SDG17.png'),
        ],
      ),
    );
  }

  Widget _buildSection8() {
    return Container(
      padding: EdgeInsets.all(24.w),
      margin: EdgeInsets.only(bottom: 250.h),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildAnimatedText(
            'Our Partners',
            delay: 0,
            style: GoogleFonts.playfairDisplay(
              fontSize: 26.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 24.h),
          // Top row - 2 videos side by side
          Row(
            children: [
              Expanded(
                child: _buildPartnerVideoCard(
                  'Rags to Riches',
                  'https://r2rshop.com/',
                  'assets/videos/partners/rags-to-riches.mp4',
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildPartnerVideoCard(
                  'Habi',
                  'https://www.habiphilippinetextilecouncil.com/',
                  'assets/videos/partners/habi.mp4',
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          // Bottom - 1 wide video
          _buildPartnerVideoCard(
            'Spark',
            'https://sparkphilippines.org/',
            'assets/videos/partners/Spark.mp4',
          ),
        ],
      ),
    );
  }
  
  Widget _buildPartnerVideoCard(String name, String url, String videoPath) {
    return InkWell(
      onTap: () => _launchUrl(url),
      child: Container(
        height: 160.h, // Reduced height to match smallest video
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.r),
          child: Stack(
            children: [
              // Video background
              Positioned.fill(
                child: _VideoBackground(videoPath: videoPath),
              ),
              // Dark overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.3),
                        Colors.black.withValues(alpha: 0.6),
                      ],
                    ),
                  ),
                ),
              ),
              // Text overlay
              Positioned.fill(
                child: Center(
                  child: Text(
                    name,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.alwaysWhite,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection9() {
    return Column(
      children: [
        // Video section with overlaid text
        Container(
          height: 400.h,
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF2C2236),
          ),
          child: Stack(
            children: [
              // Background video (if initialized)
              if (_promiseVideoController != null && 
                  _promiseVideoController!.value.isInitialized)
                Positioned.fill(
                  child: SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _promiseVideoController!.value.size.width,
                        height: _promiseVideoController!.value.size.height,
                        child: VideoPlayer(_promiseVideoController!),
                      ),
                    ),
                  ),
                )
              else
                // Fallback: Show loading or gradient background
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF2C2236),
                          const Color(0xFF2C2236).withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                    child: _promiseVideoController != null && 
                           !_promiseVideoController!.value.isInitialized
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white54,
                              strokeWidth: 2,
                            ),
                          )
                        : null,
                  ),
                ),
              // Dark overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.5),
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
              ),
              // Content - Only first part of text
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(24.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Our Promise',
                        style: GoogleFonts.cinzel(
                          fontSize: 32.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.alwaysWhite,
                          letterSpacing: 1.5.sp,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        'Velare stands for beauty that empowers, fashion that respects, and luxury that sustains.',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 18.sp,
                          color: Colors.white.withValues(alpha: 0.95),
                          fontStyle: FontStyle.italic,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Text below the video
        Container(
          padding: EdgeInsets.all(24.w),
          color: AppColors.surface(context),
          child: Text(
            'We promise to continue our journey toward an elegant future — one that celebrates women, diversity, and the planet that inspires us. Because in every thread we weave, and in every life we touch, we believe fashion should always serve a greater purpose.',
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 15.sp,
              color: AppColors.textBodyStrong(context),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildSDGImageBadge(String imagePath) {
    return VisibilityDetector(
      key: Key('sdg_badge_$imagePath'),
      onVisibilityChanged: (info) {},
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 500),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 30 * (1 - value)),
              child: child,
            ),
          );
        },
        child: Container(
          width: 80.w,
          height: 80.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: Image.asset(
              imagePath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xFFBF9F4A),
                child: Icon(Icons.eco, color: AppColors.alwaysWhite, size: 40.r),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Animated text widget with fade-in and slide-up effect triggered by visibility
  Widget _buildAnimatedText(
    String text, {
    required int delay,
    TextStyle? style,
    Alignment alignment = Alignment.center,
  }) {
    return VisibilityDetector(
      key: Key('animated_text_${text.hashCode}_$delay'),
      onVisibilityChanged: (info) {
        // Trigger animation when at least 20% of the widget is visible
        if (info.visibleFraction > 0.2) {
          // Animation will trigger automatically
        }
      },
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 500), // Faster animation (was 800ms)
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 30 * (1 - value)), // Slightly more movement for visibility
              child: child,
            ),
          );
        },
        child: Text(
          text,
          style: style ?? GoogleFonts.goudyBookletter1911(
            fontSize: 15.sp,
            height: 1.6,
            color: AppColors.textBodyStrong(context),
          ),
          textAlign: alignment == Alignment.center ? TextAlign.center : TextAlign.left,
        ),
      ),
    );
  }

}

// Video background widget for partner cards
class _VideoBackground extends StatefulWidget {
  final String videoPath;

  const _VideoBackground({required this.videoPath});

  @override
  State<_VideoBackground> createState() => _VideoBackgroundState();
}

class _VideoBackgroundState extends State<_VideoBackground> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    
    // Set a longer timeout for video loading (10 seconds to handle larger files)
    _timeoutTimer = Timer(const Duration(seconds: 10), () {
      if (!_initialized && mounted) {
        print('⏱️ Video loading timeout after 10s: ${widget.videoPath}');
        setState(() => _hasError = true);
      }
    });
  }
  
  Future<void> _initializeVideo() async {
    try {
      print('🎥 Loading partner video: ${widget.videoPath}');
      
      // Create controller with low quality options
      _controller = VideoPlayerController.asset(
        widget.videoPath,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );
      
      // Set properties for lower quality playback
      await _controller!.setLooping(true);
      await _controller!.setVolume(0);
      
      // Initialize with longer timeout (8 seconds)
      await _controller!.initialize().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          print('⏱️ Initialize timeout (8s) for: ${widget.videoPath}');
          throw TimeoutException('Video initialization timeout');
        },
      );
      
      if (mounted) {
        print('✅ Video initialized: ${widget.videoPath}');
        _timeoutTimer?.cancel();
        setState(() => _initialized = true);
        
        // Start playing
        await _controller!.play();
        print('▶️ Video playing: ${widget.videoPath}');
      }
    } on TimeoutException catch (e) {
      print('❌ TIMEOUT loading video ${widget.videoPath}: $e');
      if (mounted) {
        setState(() => _hasError = true);
      }
    } catch (e) {
      print('❌ ERROR loading partner video ${widget.videoPath}: $e');
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      // Show a dark background with icon instead of error
      return Container(
        color: const Color(0xFF2C2236),
        child: Center(
          child: Icon(
            Icons.play_circle_outline,
            color: Colors.white.withValues(alpha: 0.3),
            size: 60.r,
          ),
        ),
      );
    }
    
    if (!_initialized || _controller == null || !_controller!.value.isInitialized) {
      return Container(
        color: const Color(0xFF2C2236),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
          ),
        ),
      );
    }

    // Use AspectRatio for better video display with lower quality
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.size.width,
          height: _controller!.value.size.height,
          child: VideoPlayer(_controller!),
        ),
      ),
    );
  }
}

