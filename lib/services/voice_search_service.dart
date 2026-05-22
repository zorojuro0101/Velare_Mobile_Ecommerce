import 'dart:async';
import 'dart:developer' as developer;

import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Result na ibinabalik ng [VoiceSearchService] kapag pinindot natin yung
/// stop / o auto-stop yung session.
class VoiceSearchResult {
  /// Yung raw transcript na narinig ng device (English / Tagalog / Taglish).
  final String transcript;

  /// True kung user-cancelled (no-op), false kung okay yung session.
  final bool cancelled;

  /// Optional na error code na galing sa platform.
  final String? errorCode;

  /// Pasok yung confidence score from 0.0 to 1.0.
  final double confidence;

  const VoiceSearchResult({
    required this.transcript,
    this.cancelled = false,
    this.errorCode,
    this.confidence = 0,
  });

  bool get hasText => transcript.trim().isNotEmpty;
}

/// Lifecycle wrapper para sa `speech_to_text` package, plus mic permission
/// handling.
///
/// Usage:
/// ```dart
/// final svc = VoiceSearchService();
/// await svc.initialize();
/// final result = await svc.listenOnce(
///   onPartial: (text) => print('Heard: $text'),
/// );
/// ```
class VoiceSearchService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;

  /// True kung available yung device speech recognizer.
  bool get isAvailable => _initialized && _speech.isAvailable;

  /// True kung kasalukuyang nakikinig.
  bool get isListening => _speech.isListening;

  /// Lazy initialization. Safe to call multiple times.
  Future<bool> initialize() async {
    if (_initialized) return _speech.isAvailable;

    final permission = await _ensureMicPermission();
    if (!permission) {
      developer.log('Mic permission denied', name: 'VoiceSearch');
      return false;
    }

    try {
      _initialized = await _speech.initialize(
        onError: (SpeechRecognitionError e) {
          developer.log(
            'Speech error: ${e.errorMsg} (permanent=${e.permanent})',
            name: 'VoiceSearch',
          );
        },
        onStatus: (status) {
          developer.log('Speech status: $status', name: 'VoiceSearch');
        },
      );
    } catch (e) {
      developer.log('Speech init failed: $e', name: 'VoiceSearch');
      _initialized = false;
    }
    return _initialized;
  }

  Future<bool> _ensureMicPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) return false;
    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  /// Sublist ng lahat ng locales na supported ng device (e.g. en_US, fil_PH).
  Future<List<stt.LocaleName>> availableLocales() async {
    if (!_initialized) await initialize();
    return _speech.locales();
  }

  /// Pumili ng locale based sa user preference.
  /// - Kapag may "fil" o "tl" sa device locales, gamitin yun (Filipino)
  /// - Otherwise, fall back sa "en_US"
  Future<String> preferredLocaleId() async {
    final locales = await availableLocales();
    for (final l in locales) {
      final id = l.localeId.toLowerCase();
      if (id.startsWith('fil') || id.startsWith('tl')) {
        return l.localeId;
      }
    }
    // Fallback: any English
    for (final l in locales) {
      if (l.localeId.toLowerCase().startsWith('en')) {
        return l.localeId;
      }
    }
    return locales.isNotEmpty ? locales.first.localeId : 'en_US';
  }

  /// Mag-listen ng isang voice query, then return the final transcript.
  ///
  /// - [onPartial] tumatawag ng kada update (live transcript). Useful sa UI.
  /// - [onSoundLevel] tumatawag ng amplitude updates (0..10) para sa wave UI.
  /// - [pauseFor] auto-stop na duration kung tumigil mag-salita yung user.
  /// - [listenFor] hard maximum (default 12s).
  Future<VoiceSearchResult> listenOnce({
    void Function(String partial)? onPartial,
    void Function(double level)? onSoundLevel,
    Duration pauseFor = const Duration(seconds: 3),
    Duration listenFor = const Duration(seconds: 12),
    String? localeId,
  }) async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) {
        return const VoiceSearchResult(
          transcript: '',
          cancelled: true,
          errorCode: 'not_available',
        );
      }
    }

    final completer = Completer<VoiceSearchResult>();
    String latestTranscript = '';
    double latestConfidence = 0;
    String? lastErrorCode;

    final locale = localeId ?? await preferredLocaleId();

    void finishWith(VoiceSearchResult r) {
      if (!completer.isCompleted) completer.complete(r);
    }

    try {
      await _speech.listen(
        localeId: locale,
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.search,
          cancelOnError: false,
          partialResults: true,
        ),
        pauseFor: pauseFor,
        listenFor: listenFor,
        onSoundLevelChange: onSoundLevel == null ? null : (level) {
          onSoundLevel(level);
        },
        onResult: (SpeechRecognitionResult r) {
          latestTranscript = r.recognizedWords;
          latestConfidence = r.confidence;
          if (r.finalResult) {
            finishWith(VoiceSearchResult(
              transcript: latestTranscript,
              confidence: latestConfidence,
            ));
          } else {
            onPartial?.call(latestTranscript);
          }
        },
      );
    } catch (e) {
      developer.log('listen() threw: $e', name: 'VoiceSearch');
      lastErrorCode = 'listen_failed';
    }

    // Watchdog: if onResult never fires with finalResult (rare), settle when
    // the engine reports it stopped listening.
    final watchdog = Timer.periodic(const Duration(milliseconds: 250), (t) {
      if (completer.isCompleted) {
        t.cancel();
        return;
      }
      if (!_speech.isListening) {
        t.cancel();
        finishWith(VoiceSearchResult(
          transcript: latestTranscript,
          confidence: latestConfidence,
          errorCode: lastErrorCode,
          cancelled: latestTranscript.trim().isEmpty,
        ));
      }
    });

    final result = await completer.future;
    watchdog.cancel();
    return result;
  }

  /// Manually stop yung kasalukuyang session. Yung naka-pending na `listenOnce`
  /// completes via the watchdog with whatever transcript was captured so far.
  Future<void> stop() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  Future<void> cancel() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }
}
