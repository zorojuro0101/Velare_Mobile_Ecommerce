import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/gemini_service.dart';
import '../services/voice_search_service.dart';
import '../utils/app_colors.dart';

/// Bottom-sheet modal for voice search.
///
/// Lifecycle:
/// 1. Open → request mic + initialize → start listening automatically.
/// 2. Show live partial transcript habang nag-record.
/// 3. User stops or auto-stops after silence → send transcript to Gemini for
///    keyword extraction → return structured query (keywords + color) sa caller.
/// 4. If Gemini fails or query is empty, fallback to a raw-text extraction.
///
/// Returns a [VoiceSearchExtraction] via `Navigator.pop`, or `null` if cancelled.
class VoiceSearchModal extends StatefulWidget {
  const VoiceSearchModal({super.key});

  /// Helper para i-show yung modal at i-await yung resulting extraction.
  static Future<VoiceSearchExtraction?> show(BuildContext context) {
    return showModalBottomSheet<VoiceSearchExtraction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (_) => const VoiceSearchModal(),
    );
  }

  @override
  State<VoiceSearchModal> createState() => _VoiceSearchModalState();
}

enum _Phase {
  initializing,
  listening,
  processing,
  error,
}

class _VoiceSearchModalState extends State<VoiceSearchModal>
    with SingleTickerProviderStateMixin {
  final VoiceSearchService _voice = VoiceSearchService();

  late final AnimationController _pulse;

  _Phase _phase = _Phase.initializing;
  String _partial = '';
  String _errorMessage = '';
  double _level = 0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _start();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _voice.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final ok = await _voice.initialize();
    if (!mounted) return;

    if (!ok) {
      setState(() {
        _phase = _Phase.error;
        _errorMessage =
            'Mic access is needed for voice search. Please enable microphone permission in settings.';
      });
      return;
    }

    setState(() {
      _phase = _Phase.listening;
      _partial = '';
    });

    final result = await _voice.listenOnce(
      onPartial: (text) {
        if (!mounted) return;
        setState(() => _partial = text);
      },
      onSoundLevel: (level) {
        if (!mounted) return;
        // speech_to_text reports levels roughly in [-2, 10]; clamp to a 0..1
        // range for the pulse intensity.
        final normalized = ((level + 2) / 12).clamp(0.0, 1.0);
        setState(() => _level = normalized);
      },
    );

    if (!mounted) return;

    if (result.errorCode == 'not_available') {
      setState(() {
        _phase = _Phase.error;
        _errorMessage =
            'Voice recognition is not available on this device.';
      });
      return;
    }

    if (!result.hasText) {
      // Cancelled or no speech detected
      Navigator.of(context).pop(null);
      return;
    }

    setState(() {
      _phase = _Phase.processing;
    });

    // Use Gemini to clean up the transcript into structured keywords + color
    final extracted = await GeminiService.extractSearchKeywords(result.transcript);
    if (!mounted) return;

    if (extracted != null && extracted.isNotEmpty) {
      Navigator.of(context).pop(extracted);
      return;
    }

    // Fallback: treat the raw transcript as keywords (no color extraction).
    Navigator.of(context).pop(VoiceSearchExtraction(
      keywords: result.transcript.trim(),
      color: null,
    ));
  }

  Future<void> _stopAndSubmit() async {
    if (_phase != _Phase.listening) return;
    await _voice.stop();
    // listenOnce() will resolve via the watchdog, then _start() finishes.
  }

  Future<void> _retry() async {
    setState(() {
      _phase = _Phase.initializing;
      _errorMessage = '';
      _partial = '';
    });
    await _start();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      padding: EdgeInsets.fromLTRB(
        24.w,
        12.h,
        24.w,
        24.h + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.border(context),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 24.h),
            _buildTitle(),
            SizedBox(height: 32.h),
            _buildMicVisual(),
            SizedBox(height: 32.h),
            _buildTranscriptArea(),
            SizedBox(height: 32.h),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    String title;
    switch (_phase) {
      case _Phase.initializing:
        title = 'Getting ready...';
        break;
      case _Phase.listening:
        title = 'Listening...';
        break;
      case _Phase.processing:
        title = 'Processing...';
        break;
      case _Phase.error:
        title = 'Voice search unavailable';
        break;
    }
    return Text(
      title,
      style: GoogleFonts.playfairDisplay(
        fontSize: 22.sp,
        fontWeight: FontWeight.bold,
        color: AppColors.onSurface(context),
      ),
    );
  }

  Widget _buildMicVisual() {
    final goldColor = const Color(0xFFD4AF37);
    final isListening = _phase == _Phase.listening;
    final isProcessing = _phase == _Phase.processing;

    return SizedBox(
      width: 140.w,
      height: 140.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isListening) ...[
            // Outer pulse driven by mic level
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 140.w * (0.7 + 0.3 * _level),
              height: 140.w * (0.7 + 0.3 * _level),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: goldColor.withValues(alpha: 0.15),
              ),
            ),
            // Inner pulse via animation controller
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Container(
                width: 140.w * (0.55 + 0.15 * _pulse.value),
                height: 140.w * (0.55 + 0.15 * _pulse.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: goldColor.withValues(alpha: 0.25),
                ),
              ),
            ),
          ],
          // Center mic / spinner
          Container(
            width: 90.w,
            height: 90.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _phase == _Phase.error
                  ? Colors.red.shade400
                  : goldColor,
            ),
            child: Center(
              child: isProcessing
                  ? SizedBox(
                      width: 32.w,
                      height: 32.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Icon(
                      _phase == _Phase.error ? Icons.mic_off : Icons.mic,
                      color: Colors.white,
                      size: 40.r,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptArea() {
    if (_phase == _Phase.error) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        child: Text(
          _errorMessage,
          textAlign: TextAlign.center,
          style: GoogleFonts.goudyBookletter1911(
            fontSize: 14.sp,
            color: AppColors.textBody(context),
            height: 1.5,
          ),
        ),
      );
    }

    String displayText;
    Color textColor;
    if (_partial.isNotEmpty) {
      displayText = '"$_partial"';
      textColor = AppColors.onSurface(context);
    } else if (_phase == _Phase.listening) {
      displayText =
          'Try saying "Find me a black dress" or "Sapatos na puti"';
      textColor = AppColors.textMuted(context);
    } else if (_phase == _Phase.processing) {
      displayText = 'Understanding what you said...';
      textColor = AppColors.textMuted(context);
    } else {
      displayText = '';
      textColor = AppColors.textMuted(context);
    }

    return Container(
      constraints: BoxConstraints(minHeight: 60.h),
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      child: Text(
        displayText,
        textAlign: TextAlign.center,
        style: GoogleFonts.goudyBookletter1911(
          fontSize: 16.sp,
          color: textColor,
          height: 1.4,
          fontStyle: _partial.isEmpty ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_phase == _Phase.error) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(null),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14.h),
                side: BorderSide(color: AppColors.border(context)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface(context),
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: ElevatedButton(
              onPressed: _retry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.onSurface(context),
                foregroundColor: AppColors.surface(context),
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: Text(
                'Try again',
                style: GoogleFonts.goudyBookletter1911(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_phase == _Phase.listening) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _stopAndSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.onSurface(context),
            foregroundColor: AppColors.surface(context),
            padding: EdgeInsets.symmetric(vertical: 14.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
          child: Text(
            'Done',
            style: GoogleFonts.goudyBookletter1911(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    // initializing or processing — show only cancel
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: () {
          _voice.cancel();
          Navigator.of(context).pop(null);
        },
        child: Text(
          'Cancel',
          style: GoogleFonts.goudyBookletter1911(
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted(context),
          ),
        ),
      ),
    );
  }
}
