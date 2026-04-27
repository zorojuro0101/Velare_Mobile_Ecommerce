import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cart_model.dart';
import 'auth_service.dart';

class CartService {
  final _supabase = Supabase.instance.client;
  final _authService = AuthService();

  String? getCurrentUserId() => _authService.currentUserId;

  Future<List<CartItem>> getCartItems(String userId) async {
    try {
      final response = await _supabase
          .from('cart')
          .select('''
            *,
            products!cart_product_id_fkey(product_name, price, primary_image),
            profiles!cart_seller_id_fkey(id)
          ''')
          .eq('buyer_id', userId);

      return (response as List).map((item) => CartItem.fromJson(item)).toList();
    } catch (e) {
      throw Exception('Failed to load cart: $e');
    }
  }

  Future<void> addToCart({
    required String userId,
    required int productId,
    required String sellerId,
    int quantity = 1,
    String? color,
    String? size,
  }) async {
    try {
      await _supabase.from('cart').insert({
        'buyer_id': userId,
        'product_id': productId,
        'seller_id': sellerId,
        'quantity': quantity,
        'color': color,
        'size': size,
      });
    } catch (e) {
      throw Exception('Failed to add to cart: $e');
    }
  }

  Future<void> updateQuantity(int cartId, int quantity) async {
    try {
      await _supabase
          .from('cart')
          .update({'quantity': quantity})
          .eq('id', cartId);
    } catch (e) {
      throw Exception('Failed to update quantity: $e');
    }
  }

  Future<void> removeFromCart(int cartId) async {
    try {
      await _supabase.from('cart').delete().eq('id', cartId);
    } catch (e) {
      throw Exception('Failed to remove from cart: $e');
    }
  }

  Future<int> getCartCount(String userId) async {
    try {
      final response = await _supabase
          .from('cart')
          .select('quantity')
          .eq('buyer_id', userId);

      int total = 0;
      for (var item in response as List) {
        total += (item['quantity'] ?? 0) as int;
      }
      return total;
    } catch (e) {
      return 0;
    }
  }
}
