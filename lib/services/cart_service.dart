import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cart_model.dart';
import 'auth_service.dart';

class CartService {
  final _supabase = Supabase.instance.client;
  final _authService = AuthService();

  String? getCurrentUserId() => _authService.currentUserId;
  
  String? getCurrentBuyerId() => _authService.currentBuyerId;

  Future<List<CartItem>> getCartItems(String userId) async {
    try {
      final response = await _supabase
          .from('cart')
          .select('''
            cart_id,
            buyer_id,
            product_id,
            variant_id,
            quantity,
            added_at,
            products(product_id, product_name, price, seller_id, sellers(shop_name, shop_logo)),
            product_variants(color, size, image_url)
          ''')
          .eq('buyer_id', userId)
          .order('added_at', ascending: false); // Newest items first

      final cartItems = <CartItem>[];
      
      for (var item in response as List) {
        String? primaryImage;
        final variantId = item['variant_id'];
        
        try {
          if (variantId != null) {
            // Try to get variant-specific image from product_images table
            final variantImageResponse = await _supabase
                .from('product_images')
                .select('image_url')
                .eq('product_id', item['product_id'])
                .eq('variant_id', variantId)
                .order('display_order', ascending: true)
                .limit(1)
                .maybeSingle();
            
            primaryImage = variantImageResponse?['image_url'];
            
            // Fallback to variant's image_url field if no image in product_images
            if (primaryImage == null && item['product_variants'] != null) {
              final variantData = item['product_variants'];
              if (variantData is Map && variantData['image_url'] != null) {
                primaryImage = variantData['image_url'];
              }
            }
          }
          
          // If still no image, get general product image (where variant_id is NULL)
          if (primaryImage == null) {
            final imageResponse = await _supabase
                .from('product_images')
                .select('image_url')
                .eq('product_id', item['product_id'])
                .isFilter('variant_id', null)
                .eq('is_primary', true)
                .maybeSingle();
            
            primaryImage = imageResponse?['image_url'];
          }
        } catch (e) {
          print('Error fetching image for product ${item['product_id']}: $e');
        }
        
        // Add primary image to item data
        item['primary_image'] = primaryImage;
        cartItems.add(CartItem.fromJson(item));
      }

      return cartItems;
    } catch (e) {
      throw Exception('Failed to load cart: $e');
    }
  }

  Future<void> addToCart({
    required String userId,
    required int productId,
    required String sellerId,
    int quantity = 1,
    int? variantId,
  }) async {
    try {
      // Get available stock first
      int availableStock = 0;
      if (variantId != null) {
        final variant = await _supabase
            .from('product_variants')
            .select('stock_quantity')
            .eq('variant_id', variantId)
            .single();
        availableStock = variant['stock_quantity'] ?? 0;
      } else {
        final product = await _supabase
            .from('products')
            .select('stock_quantity')
            .eq('product_id', productId)
            .single();
        availableStock = product['stock_quantity'] ?? 0;
      }
      
      // Check if item with same product and variant already exists
      final existingQuery = _supabase
          .from('cart')
          .select('cart_id, quantity')
          .eq('buyer_id', userId)
          .eq('product_id', productId);
      
      // Add variant filter - handle both null and non-null cases
      final existingResponse = variantId != null
          ? await existingQuery.eq('variant_id', variantId).maybeSingle()
          : await existingQuery.isFilter('variant_id', null).maybeSingle();
      
      if (existingResponse != null) {
        // Item exists in cart
        final existingQuantity = existingResponse['quantity'] as int;
        
        // Check if this is the last stock
        if (availableStock == 1 && existingQuantity >= 1) {
          throw Exception('This item is already in your cart and it is the last stock');
        }
        
        final newQuantity = existingQuantity + quantity;
        
        // Validate total quantity doesn't exceed stock
        if (newQuantity > availableStock) {
          throw Exception('Only $availableStock item${availableStock != 1 ? 's' : ''} available. You already have $existingQuantity in cart');
        }
        
        // Update quantity
        final existingCartId = existingResponse['cart_id'];
        await _supabase
            .from('cart')
            .update({'quantity': newQuantity})
            .eq('cart_id', existingCartId);
        
        print('Updated cart item $existingCartId: quantity $existingQuantity -> $newQuantity');
      } else {
        // Item doesn't exist - validate quantity
        if (quantity > availableStock) {
          throw Exception('Only $availableStock item${availableStock != 1 ? 's' : ''} available in stock');
        }
        
        // Insert new
        await _supabase.from('cart').insert({
          'buyer_id': userId,
          'product_id': productId,
          'variant_id': variantId,
          'quantity': quantity,
        });
        
        print('Added new cart item: product $productId, variant $variantId, quantity $quantity');
      }
    } catch (e) {
      throw Exception('${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  Future<void> updateQuantity(int cartId, int quantity) async {
    try {
      // First, get the cart item to check product and variant
      final cartItem = await _supabase
          .from('cart')
          .select('product_id, variant_id')
          .eq('cart_id', cartId)
          .single();
      
      final productId = cartItem['product_id'];
      final variantId = cartItem['variant_id'];
      
      // Get available stock
      int availableStock = 0;
      if (variantId != null) {
        // Check variant stock
        final variant = await _supabase
            .from('product_variants')
            .select('stock_quantity')
            .eq('variant_id', variantId)
            .single();
        availableStock = variant['stock_quantity'] ?? 0;
      } else {
        // Check product stock
        final product = await _supabase
            .from('products')
            .select('stock_quantity')
            .eq('product_id', productId)
            .single();
        availableStock = product['stock_quantity'] ?? 0;
      }
      
      // Validate quantity
      if (quantity > availableStock) {
        throw Exception('Only $availableStock item${availableStock != 1 ? 's' : ''} available in stock');
      }
      
      await _supabase
          .from('cart')
          .update({'quantity': quantity})
          .eq('cart_id', cartId);
    } catch (e) {
      throw Exception('${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  Future<void> removeFromCart(int cartId) async {
    try {
      await _supabase.from('cart').delete().eq('cart_id', cartId);
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
