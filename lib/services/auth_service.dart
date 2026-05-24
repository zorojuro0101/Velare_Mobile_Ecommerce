import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'mail_service.dart';
import 'session_service.dart';

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _supabase = Supabase.instance.client;
  final _sessionService = SessionService();
  String? _currentUserId;
  String? _currentUserEmail;
  String? _currentUserType;
  String? _currentBuyerId;
  String? _currentSessionId;

  // Keys for shared preferences
  static const String _keyUserId = 'user_id';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserType = 'user_type';
  static const String _keyBuyerId = 'buyer_id';
  static const String _keySessionId = 'session_id';

  // Initialize and load saved session
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString(_keyUserId);
    _currentUserEmail = prefs.getString(_keyUserEmail);
    _currentUserType = prefs.getString(_keyUserType);
    _currentBuyerId = prefs.getString(_keyBuyerId);
    _currentSessionId = prefs.getString(_keySessionId);
    
    print('AuthService - Initialized with saved session:');
    print('  User ID: $_currentUserId');
    print('  Email: $_currentUserEmail');
    print('  User Type: $_currentUserType');
    print('  Buyer ID: $_currentBuyerId');
    print('  Session ID: $_currentSessionId');
  }

  // Save session to shared preferences
  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_currentUserId != null) {
      await prefs.setString(_keyUserId, _currentUserId!);
    }
    if (_currentUserEmail != null) {
      await prefs.setString(_keyUserEmail, _currentUserEmail!);
    }
    if (_currentUserType != null) {
      await prefs.setString(_keyUserType, _currentUserType!);
    }
    if (_currentBuyerId != null) {
      await prefs.setString(_keyBuyerId, _currentBuyerId!);
    }
    if (_currentSessionId != null) {
      await prefs.setString(_keySessionId, _currentSessionId!);
    }
    print('AuthService - Session saved to storage');
  }

  // Clear session from shared preferences
  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserType);
    await prefs.remove(_keyBuyerId);
    await prefs.remove(_keySessionId);
    print('AuthService - Session cleared from storage');
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      // Normalize email so casing/whitespace can't cause mismatches.
      final normalizedEmail = email.trim().toLowerCase();
      print('Attempting login with email: $normalizedEmail');

      // 1) First, look up the user record by email so we can give the user
      //    a meaningful message about their account status (e.g. pending
      //    admin approval) even if their password is wrong.
      final response = await _supabase
          .from('users')
          .select('user_id, email, user_type, status')
          .ilike('email', normalizedEmail)
          .maybeSingle()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception(
                  'Connection timeout. Please check your internet connection.');
            },
          );

      print('User found: ${response != null}');

      if (response == null) {
        return {'success': false, 'message': 'Invalid email or password.'};
      }

      // 2) Restrict the mobile app to buyer and rider accounts only.
      //    Seller and admin accounts are handled on the web version.
      final userType = response['user_type']?.toString() ?? '';
      if (userType != 'buyer' && userType != 'rider') {
        if (userType == 'seller') {
          return {
            'success': false,
            'message':
                'Seller accounts are not supported on the mobile app. Please log in to this account on the web version.',
          };
        }
        if (userType == 'admin') {
          return {
            'success': false,
            'message':
                'Admin accounts are not supported on the mobile app. Please log in to this account on the web version.',
          };
        }
        return {
          'success': false,
          'message':
              'This account type is not supported on the mobile app. Please log in on the web version.',
        };
      }

      // 3) Check account status BEFORE verifying password so a user whose
      //    account is still pending (or suspended/banned) gets a clear,
      //    helpful message instead of "invalid email or password".
      final status = response['status'];
      if (status != 'active') {
        if (status == 'pending') {
          return {
            'success': false,
            'message':
                'Your account is still waiting for admin approval. Please try again once it has been approved.',
          };
        } else if (status == 'suspended') {
          return {
            'success': false,
            'message':
                'Your account has been suspended. Please contact support.',
          };
        } else if (status == 'banned') {
          return {
            'success': false,
            'message':
                'Your account has been banned. Please contact support.',
          };
        } else if (status == 'rejected') {
          return {
            'success': false,
            'message':
                'Your account application was rejected. Please contact support for more information.',
          };
        } else if (status == 'inactive') {
          return {
            'success': false,
            'message':
                'Your account has been deactivated. Please contact support.',
          };
        } else {
          return {
            'success': false,
            'message':
                'Your account is not active. Please contact support.',
          };
        }
      }

      // 4) Now verify the password server-side via pgcrypto RPC. This matches
      //    the web's bcrypt-based check.
      final verified = await _supabase.rpc(
        'verify_user_password',
        params: {
          'p_email': normalizedEmail,
          'p_password': password,
        },
      );

      if (verified != true) {
        return {'success': false, 'message': 'Invalid email or password.'};
      }

      // Store user info in memory
      _currentUserId = response['user_id'].toString();
      _currentUserEmail = response['email'];
      _currentUserType = response['user_type'] ?? 'buyer';

      print('Login successful. User type: $_currentUserType');
      print('User ID stored: $_currentUserId');
      
      // If user is a buyer, get the buyer_id from buyers table
      String? buyerId;
      if (_currentUserType == 'buyer' && _currentUserId != null) {
        try {
          print('AuthService - Fetching buyer_id for user_id: $_currentUserId');
          final buyerData = await _supabase
              .from('buyers')
              .select('buyer_id')
              .eq('user_id', _currentUserId!)
              .maybeSingle();
          
          print('AuthService - Buyer data response: $buyerData');
          
          if (buyerData != null) {
            buyerId = buyerData['buyer_id'].toString();
            _currentBuyerId = buyerId; // Store buyer_id
            print('AuthService - Buyer ID found and stored: $buyerId');
            print('AuthService - _currentBuyerId is now: $_currentBuyerId');
          } else {
            print('AuthService - No buyer record found for user_id: $_currentUserId');
          }
        } catch (e) {
          print('AuthService - Error fetching buyer_id: $e');
        }
      }

      // Save session to persistent storage
      await _saveSession();

      // Create session in database and send notification if new device
      if (_currentUserId != null) {
        _currentSessionId = await _sessionService.createSession(_currentUserId!);
        if (_currentSessionId != null) {
          await _saveSession(); // Save session ID
        }
      }

      return {
        'success': true,
        'user_type': _currentUserType,
        'user_id': _currentUserId,
        'buyer_id': buyerId, // Add buyer_id to response
      };
    } on PostgrestException catch (e) {
      print('Postgrest error: ${e.message}, Code: ${e.code}');
      if (e.code == '42501') {
        return {'success': false, 'message': 'Database permission error. Please contact support.'};
      }
      return {'success': false, 'message': 'Database error: ${e.message}'};
    } catch (e) {
      print('Login error: $e');
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  Future<Map<String, dynamic>> signUp(
    String email,
    String password,
    String userType, {
    String? firstName,
    String? lastName,
    Map<String, String>? addressData,
    String? idType,
    File? idFile,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();

      // Check if user already exists (case-insensitive)
      final existing = await _supabase
          .from('users')
          .select('user_id')
          .ilike('email', normalizedEmail)
          .maybeSingle();

      if (existing != null) {
        return {'success': false, 'message': 'This email is already registered.'};
      }

      // Upload the ID image to Supabase Storage BEFORE creating the user, so
      // a storage failure doesn't leave us with a half-created account. The
      // bucket and path mirror the web's pattern (Images/static/uploads/...).
      String? idFileUrl;
      if (idFile != null && idType != null && idType.isNotEmpty) {
        try {
          idFileUrl = await _uploadIdFile(
            file: idFile,
            email: normalizedEmail,
            userType: userType,
            idType: idType,
          );
        } catch (e) {
          print('Sign up - ID upload error: $e');
          return {
            'success': false,
            'message': 'Failed to upload ID photo. Please try again.',
          };
        }
      }

      // Create user via RPC. The DB trigger on users.password takes the plain
      // text we pass and hashes it with bcrypt (pgcrypto), matching the web.
      // We do NOT pre-hash here, otherwise the trigger would hash the hash.
      dynamic newUserId;
      try {
        newUserId = await _supabase.rpc(
          'create_user_with_hashed_password',
          params: {
            'p_email': normalizedEmail,
            'p_password': password,
            'p_user_type': userType,
            'p_status': 'pending',
          },
        );
      } on PostgrestException catch (e) {
        print('Sign up RPC error: ${e.message}, code=${e.code}, '
            'details=${e.details}, hint=${e.hint}');
        return {
          'success': false,
          'message':
              'Sign up failed (database): ${e.message}',
        };
      }

      if (newUserId == null) {
        return {
          'success': false,
          'message':
              'Sign up failed. The email may already be in use.',
        };
      }

      _currentUserId = newUserId.toString();
      _currentUserEmail = normalizedEmail;
      _currentUserType = userType;

      // Create buyer or rider record
      String? userRefId;
      try {
        if (userType == 'buyer' && firstName != null && lastName != null) {
          final buyerResponse = await _supabase.from('buyers').insert({
            'user_id': _currentUserId,
            'first_name': firstName,
            'last_name': lastName,
            if (idType != null && idType.isNotEmpty) 'id_type': idType,
            'id_file_path': ?idFileUrl,
          }).select().single();
          userRefId = buyerResponse['buyer_id'].toString();
          _currentBuyerId = userRefId;
        } else if (userType == 'rider' && firstName != null && lastName != null) {
          final riderResponse = await _supabase.from('riders').insert({
            'user_id': _currentUserId,
            'first_name': firstName,
            'last_name': lastName,
            if (idType != null && idType.isNotEmpty) 'id_type': idType,
            'id_file_path': ?idFileUrl,
          }).select().single();
          userRefId = riderResponse['rider_id'].toString();
        }
      } on PostgrestException catch (e) {
        print('Profile-record insert error: ${e.message}, code=${e.code}, '
            'details=${e.details}, hint=${e.hint}');
        // Roll back the user row so we don't leave an orphan.
        try {
          await _supabase.from('users').delete().eq('user_id', _currentUserId!);
        } catch (_) {}
        return {
          'success': false,
          'message':
              'Sign up failed (profile): ${e.message}',
        };
      }

      // Save address if provided (best-effort; failure here doesn't block signup)
      if (addressData != null && userRefId != null) {
        await _saveAddress(userType, userRefId, firstName, lastName, addressData);
      }

      return {'success': true, 'user_type': userType};
    } on PostgrestException catch (e) {
      print('Sign up Postgrest error: ${e.message}, code=${e.code}, '
          'details=${e.details}, hint=${e.hint}');
      return {'success': false, 'message': 'Sign up failed: ${e.message}'};
    } catch (e) {
      print('Sign up error: $e');
      return {'success': false, 'message': 'Sign up failed: $e'};
    }
  }

  /// Uploads the user's ID image to the Supabase Storage `Images` bucket and
  /// returns the public URL. The path mirrors the web app's convention so the
  /// admin dashboard can show ID files from buyers, sellers, and riders the
  /// same way regardless of which client uploaded them.
  Future<String> _uploadIdFile({
    required File file,
    required String email,
    required String userType,
    required String idType,
  }) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('ID file is empty');
    }

    // Sanitize email so it's safe inside a storage path
    final safeEmail = email.replaceAll('@', '_').replaceAll('.', '_');
    final safeIdType = idType.replaceAll(' ', '_');

    // Pull extension and content type from the source path
    final originalPath = file.path;
    final dotIndex = originalPath.lastIndexOf('.');
    final ext = dotIndex >= 0 && dotIndex < originalPath.length - 1
        ? originalPath.substring(dotIndex + 1).toLowerCase()
        : 'jpg';
    final contentType = _contentTypeForExtension(ext);

    // 8-char unique token (matches the web's uuid4().hex[:8] pattern)
    final token = DateTime.now()
        .millisecondsSinceEpoch
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(0, 8);

    final folder = userType == 'rider'
        ? 'static/uploads/rider_ids'
        : 'static/uploads/buyer_ids';
    final filename =
        '${userType}_${safeEmail}_${safeIdType}_$token.$ext';
    final fullPath = '$folder/$filename';

    await _supabase.storage.from('Images').uploadBinary(
          fullPath,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );

    return _supabase.storage.from('Images').getPublicUrl(fullPath);
  }

  String _contentTypeForExtension(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _saveAddress(
    String userType,
    String userRefId,
    String? firstName,
    String? lastName,
    Map<String, String> addressData,
  ) async {
    try {
      // Get postal code from addressData (already fetched in modal)
      String? postalCode = addressData['postal_code'];
      
      // If not provided, try to fetch it
      if (postalCode == null || postalCode.isEmpty) {
        final city = addressData['city'];
        if (city != null) {
          postalCode = await _fetchPostalCode(
            addressData['region'],
            addressData['province'],
            city,
            addressData['barangay'],
          );
        }
      }

      // Build full address string
      final fullAddressParts = <String>[];
      if (addressData['barangay'] != null && addressData['barangay']!.isNotEmpty) {
        fullAddressParts.add(addressData['barangay']!);
      }
      if (addressData['city'] != null && addressData['city']!.isNotEmpty) {
        fullAddressParts.add(addressData['city']!);
      }
      if (addressData['province'] != null && addressData['province']!.isNotEmpty) {
        fullAddressParts.add(addressData['province']!);
      }
      if (addressData['region'] != null && addressData['region']!.isNotEmpty) {
        fullAddressParts.add(addressData['region']!);
      }
      final fullAddress = fullAddressParts.join(', ');

      // Create recipient name from first and last name
      final recipientName = '${firstName ?? ''} ${lastName ?? ''}'.trim();

      // Insert address into addresses table
      await _supabase.from('addresses').insert({
        'user_type': userType,
        'user_ref_id': userRefId,
        'recipient_name': recipientName.isNotEmpty ? recipientName : null,
        'full_address': fullAddress,
        'region': addressData['region'],
        'province': addressData['province'],
        'city': addressData['city'],
        'barangay': addressData['barangay'],
        'postal_code': postalCode,
        'is_default': true,
      });

      print('Address saved successfully with postal code: $postalCode');
    } catch (e) {
      print('Error saving address: $e');
      // Don't throw - address save failure shouldn't prevent registration
    }
  }

  Future<String?> _fetchPostalCode(
    String? region,
    String? province,
    String city,
    String? barangay,
  ) async {
    try {
      final response = await _supabase.functions.invoke(
        'fetch-postal-code',
        body: {
          'region': region,
          'province': province,
          'city': city,
          'barangay': barangay,
        },
      );

      if (response.data != null && response.data['postal_code'] != null) {
        return response.data['postal_code'] as String;
      }
    } catch (e) {
      print('Error fetching postal code from edge function: $e');
    }

    // Fallback: try direct HTTP call to postal code JSON
    try {
      final response = await http.get(
        Uri.parse('https://gist.githubusercontent.com/chrisbjr/784565232f10cba6530856dc7fda367a/raw/ph-zip-codes.json'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> postalData = jsonDecode(response.body);
        
        final cityTokens = _normalizeAndTokenize(city);
        final provinceTokens = province != null ? _normalizeAndTokenize(province) : <String>[];
        final barangayTokens = barangay != null ? _normalizeAndTokenize(barangay) : <String>[];
        
        String? foundPostalCode;
        int bestScore = 0;
        
        for (var entry in postalData) {
          final area = entry['area'] as String;
          final areaTokens = _normalizeAndTokenize(area);
          
          int score = 0;
          
          if (!cityTokens.every((token) => areaTokens.contains(token))) continue;
          
          score += 5;
          
          if (provinceTokens.isNotEmpty && provinceTokens.every((token) => areaTokens.contains(token))) {
            score += 3;
          }
          
          if (barangayTokens.isNotEmpty && barangayTokens.any((token) => areaTokens.contains(token))) {
            score += 2;
          }
          
          if (score > bestScore) {
            bestScore = score;
            foundPostalCode = entry['zip'] as String;
          }
        }
        
        return foundPostalCode;
      }
    } catch (e) {
      print('Error fetching postal code via HTTP: $e');
    }

    return null;
  }

  Set<String> _normalizeAndTokenize(String text) {
    final stopWords = {'OF', 'THE', 'CITY', 'MUNICIPALITY', 'PROVINCE', 'BARANGAY', 'DISTRICT'};
    
    return text
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty && !stopWords.contains(token))
        .toSet();
  }

  /// Parses a timestamp string from the database as UTC.
  ///
  /// PostgREST returns `TIMESTAMP WITHOUT TIME ZONE` columns as plain strings
  /// like `2026-05-24T11:15:00.000` (no `Z`, no offset). Dart's
  /// `DateTime.parse` would interpret that as **local time**, which gives the
  /// wrong instant when the device is not on UTC.
  ///
  /// We always write UTC into reset_token_expiry, so this helper appends a
  /// trailing `Z` if there's no timezone info, then parses.
  DateTime? _parseAsUtc(String value) {
    try {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;

      // If it already has a Z or +HH:MM / -HH:MM suffix, just parse.
      final hasTz = trimmed.endsWith('Z') ||
          RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(trimmed);

      final iso = hasTz ? trimmed : '${trimmed}Z';
      return DateTime.parse(iso).toUtc();
    } catch (_) {
      return null;
    }
  }

  Future<bool> isLoggedIn() async {
    return _currentUserId != null;
  }

  Future<String?> getUserType() async {
    return _currentUserType;
  }

  /// Returns true if the given email is already registered in the users table.
  /// Used by the register screen for real-time inline validation.
  Future<bool> checkEmailExists(String email) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      if (normalizedEmail.isEmpty) return false;

      // ilike treats `_` and `%` as wildcards. An email like
      // "juan_dela@gmail.com" would otherwise match "juanXdela@gmail.com".
      // Escape both so we get a literal, case-insensitive match.
      final escaped = normalizedEmail
          .replaceAll(r'\', r'\\')
          .replaceAll('%', r'\%')
          .replaceAll('_', r'\_');

      final result = await _supabase
          .from('users')
          .select('user_id')
          .ilike('email', escaped)
          .maybeSingle();
      return result != null;
    } catch (_) {
      return false; // On error, let the server-side check handle it on submit
    }
  }

  Future<void> logout() async {
    // End session in database
    if (_currentSessionId != null) {
      await _sessionService.endSession(_currentSessionId!);
    }
    
    _currentUserId = null;
    _currentUserEmail = null;
    _currentUserType = null;
    _currentBuyerId = null;
    _currentSessionId = null;
    
    // Clear session from persistent storage
    await _clearSession();
  }

  String? get currentUserId => _currentUserId;
  
  String? get currentUserEmail => _currentUserEmail;
  
  String? get currentUserType => _currentUserType;
  
  String? get currentBuyerId => _currentBuyerId; // Add getter for buyer_id
  
  String? get currentSessionId => _currentSessionId; // Add getter for session_id

  // ============================================================================
  // FORGOT / RESET PASSWORD
  // Mirrors the web flow: 6-digit code stored in users.reset_token
  // with users.reset_token_expiry (15 minutes).
  // ============================================================================

  /// Step 1: Request a password reset code.
  /// Generates a 6-digit code, stores it in the users table, and sends it
  /// via the Supabase edge function `send-reset-email`.
  ///
  /// Returns:
  ///   success    : true on accepted submission (no harsh error).
  ///   code_sent  : true ONLY when an actual code was generated AND email
  ///                delivery succeeded. The UI should only navigate to the
  ///                reset screen when this is true.
  ///   message    : user-facing message.
  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();

      if (normalizedEmail.isEmpty) {
        return {
          'success': false,
          'code_sent': false,
          'message': 'Please enter your email.',
        };
      }

      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(normalizedEmail)) {
        return {
          'success': false,
          'code_sent': false,
          'message': 'Please enter a valid email address.',
        };
      }

      // Look up the user (case-insensitive)
      final user = await _supabase
          .from('users')
          .select('user_id, email')
          .ilike('email', normalizedEmail)
          .maybeSingle();

      if (user == null) {
        // Tell the user clearly that the email is not registered.
        return {
          'success': false,
          'code_sent': false,
          'message': 'This email is not registered.',
        };
      }

      // Generate 6-digit numeric code
      final rand = Random.secure();
      final resetCode = List.generate(6, (_) => rand.nextInt(10)).join();

      // Expiry: 15 minutes from now (UTC ISO string)
      final expiry = DateTime.now().toUtc().add(const Duration(minutes: 15));

      // Store reset token + expiry
      await _supabase.from('users').update({
        'reset_token': resetCode,
        'reset_token_expiry': expiry.toIso8601String(),
      }).eq('user_id', user['user_id']);

      // Send email directly via SMTP (same Gmail App Password as the web app).
      bool emailSent = false;
      String? sendError;
      try {
        emailSent = await MailService.sendResetCode(normalizedEmail, resetCode);
        if (!emailSent) {
          sendError = 'SMTP send failed (see debug log for details)';
        }
      } catch (e) {
        sendError = e.toString();
        print('AuthService - MailService.sendResetCode error: $e');
      }

      if (!emailSent) {
        // Roll back the token if email failed
        await _supabase.from('users').update({
          'reset_token': null,
          'reset_token_expiry': null,
        }).eq('user_id', user['user_id']);

        return {
          'success': false,
          'code_sent': false,
          'message': sendError != null
              ? 'Failed to send email: $sendError'
              : 'Failed to send reset email. Please try again later.',
        };
      }

      return {
        'success': true,
        'code_sent': true,
        'message': 'A reset code has been sent to your email.',
      };
    } catch (e) {
      print('AuthService - requestPasswordReset error: $e');
      return {
        'success': false,
        'code_sent': false,
        'message': 'Something went wrong. Please try again.',
      };
    }
  }

  /// Step 2: Verify the code + set the new password.
  Future<Map<String, dynamic>> resetPasswordWithCode(
    String email,
    String code,
    String newPassword,
  ) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();

      if (normalizedEmail.isEmpty || code.trim().isEmpty || newPassword.isEmpty) {
        return {'success': false, 'message': 'Please fill in all fields.'};
      }

      // Validate password strength (matches register screen rules)
      if (newPassword.length < 6) {
        return {
          'success': false,
          'message': 'Password must be at least 6 characters.',
        };
      }
      if (!RegExp(r'[A-Z]').hasMatch(newPassword)) {
        return {
          'success': false,
          'message': 'Password must contain at least 1 uppercase letter.',
        };
      }
      if (!RegExp(r'[a-z]').hasMatch(newPassword)) {
        return {
          'success': false,
          'message': 'Password must contain at least 1 lowercase letter.',
        };
      }
      if (!RegExp(r'[0-9]').hasMatch(newPassword)) {
        return {
          'success': false,
          'message': 'Password must contain at least 1 number.',
        };
      }

      // Find user with reset token (case-insensitive)
      final user = await _supabase
          .from('users')
          .select('user_id, reset_token, reset_token_expiry')
          .ilike('email', normalizedEmail)
          .maybeSingle();

      if (user == null) {
        return {'success': false, 'message': 'This email is not registered.'};
      }

      final storedToken = user['reset_token'];
      final expiryStr = user['reset_token_expiry'];

      if (storedToken == null) {
        return {
          'success': false,
          'message': 'No reset code has been requested for this email.',
        };
      }

      if (storedToken.toString() != code.trim()) {
        return {'success': false, 'message': 'The reset code is incorrect.'};
      }

      // Check expiry.
      // The reset_token_expiry column is `TIMESTAMP WITHOUT TIME ZONE`, but
      // we always store UTC values. PostgREST returns the value WITHOUT a
      // timezone marker (e.g. "2026-05-24T11:15:00"), so DateTime.parse would
      // otherwise treat it as local time. Force-parse it as UTC.
      if (expiryStr != null) {
        final expiry = _parseAsUtc(expiryStr.toString());
        if (expiry == null) {
          return {
            'success': false,
            'message': 'Invalid reset code expiry. Please request a new one.',
          };
        }
        if (expiry.isBefore(DateTime.now().toUtc())) {
          return {
            'success': false,
            'message': 'The reset code has expired. Please request a new one.',
          };
        }
      }

      // Update password via RPC (hashes server-side with pgcrypto) + clear token
      await _supabase.rpc('reset_password_with_token', params: {
        'p_email': normalizedEmail,
        'p_new_password': newPassword,
      });

      return {
        'success': true,
        'message': 'Password has been reset. You can now log in.',
      };
    } catch (e) {
      print('AuthService - resetPasswordWithCode error: $e');
      return {
        'success': false,
        'message': 'Something went wrong. Please try again.',
      };
    }
  }
}
