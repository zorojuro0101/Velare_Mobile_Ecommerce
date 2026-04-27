import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/favorite_model.dart';
import 'auth_service.dart';

class FavoriteService {
  final _supabase = Supabase.instance.client;
  final _authService = AuthService();

  String? getCurrentUserId() => _authService.currentUserId;
  String? getCurrentBuyerId() => _authService.currentBuyerId;

  Future<List<FavoriteItem>> getFavorites(String userId) async {
    try {
      final response = await _supabase
          .from('favorites')
          .select('''
            *,
            products!favorites_product_id_fkey(
              product_name, 
              price,
              product_images(image_url, is_primary, display_order)
            )
          ''')
          .eq('buyer_id', userId)
          .order('added_at', ascending: false);

      return (response as List).map((item) => FavoriteItem.fromJson(item)).toList();
    } catch (e) {
      throw Exception('Failed to load favorites: $e');
    }
  }

  Future<void> addToFavorites(String userId, int productId) async {
    try {
      // Check if already exists first
      final exists = await isFavorite(userId, productId);
      if (exists) {
        return; // Already in favorites, do nothing
      }
      
      await _supabase.from('favorites').insert({
        'buyer_id': userId,
        'product_id': productId,
        'added_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to add to favorites: $e');
    }
  }

  Future<void> removeFromFavorites(int favoriteId) async {
    try {
      await _supabase.from('favorites').delete().eq('favorite_id', favoriteId);
    } catch (e) {
      throw Exception('Failed to remove from favorites: $e');
    }
  }

  Future<bool> isFavorite(String userId, int productId) async {
    try {
      final response = await _supabase
          .from('favorites')
          .select('favorite_id')
          .eq('buyer_id', userId)
          .eq('product_id', productId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  Future<int?> getFavoriteId(String userId, int productId) async {
    try {
      final response = await _supabase
          .from('favorites')
          .select('favorite_id')
          .eq('buyer_id', userId)
          .eq('product_id', productId)
          .maybeSingle();

      return response?['favorite_id'];
    } catch (e) {
      return null;
    }
  }

  Future<int> getFavoriteCount(String userId) async {
    try {
      final response = await _supabase
          .from('favorites')
          .select('favorite_id')
          .eq('buyer_id', userId);

      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }
}
