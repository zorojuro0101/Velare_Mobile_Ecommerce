import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
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
      print('Attempting login with email: $email');
      
      // Query the users table directly with timeout
      final response = await _supabase
          .from('users')
          .select('*')
          .eq('email', email)
          .maybeSingle()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Connection timeout. Please check your internet connection.');
            },
          );

      print('User found: ${response != null}');

      if (response == null) {
        return {'success': false, 'message': 'User not found'};
      }

      // Check password (assuming it's stored as plain text or hashed)
      // If hashed, you'll need to verify the hash
      final storedPassword = response['password'];
      
      if (storedPassword != password) {
        // Try hashed comparison if plain text doesn't match
        final hashedPassword = sha256.convert(utf8.encode(password)).toString();
        if (storedPassword != hashedPassword) {
          return {'success': false, 'message': 'Invalid password'};
        }
      }

      // Check account status
      final status = response['status'];
      if (status != 'active') {
        if (status == 'pending') {
          return {'success': false, 'message': 'Your account is pending approval. Please wait for admin approval.'};
        } else if (status == 'inactive') {
          return {'success': false, 'message': 'Your account has been deactivated. Please contact support.'};
        } else {
          return {'success': false, 'message': 'Your account is not active. Please contact support.'};
        }
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
  }) async {
    try {
      // Check if user already exists
      final existing = await _supabase
          .from('users')
          .select('user_id')
          .eq('email', email)
          .maybeSingle();

      if (existing != null) {
        return {'success': false, 'message': 'Email already registered'};
      }

      // Insert new user into users table
      final response = await _supabase.from('users').insert({
        'email': email,
        'password': password, // Store as-is (or hash it if needed)
        'user_type': userType,
        'status': 'pending', // Set status as pending for admin approval
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      _currentUserId = response['user_id'].toString();
      _currentUserEmail = response['email'];
      _currentUserType = response['user_type'];

      // Create buyer or rider record
      String? userRefId;
      if (userType == 'buyer' && firstName != null && lastName != null) {
        final buyerResponse = await _supabase.from('buyers').insert({
          'user_id': _currentUserId,
          'first_name': firstName,
          'last_name': lastName,
        }).select().single();
        userRefId = buyerResponse['buyer_id'].toString();
        _currentBuyerId = userRefId;
      } else if (userType == 'rider' && firstName != null && lastName != null) {
        final riderResponse = await _supabase.from('riders').insert({
          'user_id': _currentUserId,
          'first_name': firstName,
          'last_name': lastName,
        }).select().single();
        userRefId = riderResponse['rider_id'].toString();
      }

      // Save address if provided
      if (addressData != null && userRefId != null) {
        await _saveAddress(userType, userRefId, firstName, lastName, addressData);
      }

      return {'success': true, 'user_type': userType};
    } catch (e) {
      print('Sign up error: $e');
      return {'success': false, 'message': 'Sign up failed: $e'};
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

  Future<bool> isLoggedIn() async {
    return _currentUserId != null;
  }

  Future<String?> getUserType() async {
    return _currentUserType;
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
}
