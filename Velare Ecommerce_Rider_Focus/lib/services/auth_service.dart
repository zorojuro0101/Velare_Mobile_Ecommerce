import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _supabase = Supabase.instance.client;
  String? _currentUserId;
  String? _currentUserEmail;
  String? _currentUserType;
  String? _currentBuyerId; // Add buyer_id storage

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

  Future<Map<String, dynamic>> signUp(String email, String password, String userType) async {
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
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      _currentUserId = response['user_id'].toString();
      _currentUserEmail = response['email'];
      _currentUserType = response['user_type'];

      return {'success': true, 'user_type': userType};
    } catch (e) {
      print('Sign up error: $e');
      return {'success': false, 'message': 'Sign up failed: $e'};
    }
  }

  Future<bool> isLoggedIn() async {
    return _currentUserId != null;
  }

  Future<String?> getUserType() async {
    return _currentUserType;
  }

  Future<void> logout() async {
    _currentUserId = null;
    _currentUserEmail = null;
    _currentUserType = null;
  }

  String? get currentUserId => _currentUserId;
  
  String? get currentUserEmail => _currentUserEmail;
  
  String? get currentUserType => _currentUserType;
  
  String? get currentBuyerId => _currentBuyerId; // Add getter for buyer_id
}
