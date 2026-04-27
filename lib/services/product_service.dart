import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';

class ProductService {
  final _supabase = Supabase.instance.client;
  
  Future<List<Product>> getFeaturedProducts() async {
    try {
      final response = await _supabase
          .from('products')
          .select('''
            *,
            product_images(image_url)
          ''')
          .eq('is_featured', true)
          .order('created_at', ascending: false);
      
      return (response as List).map((item) => Product.fromJson(item)).toList();
    } catch (e) {
      print('ProductService - Error loading featured products: $e');
      throw Exception('Error loading products: $e');
    }
  }

  Future<List<Product>> getAllProducts() async {
    try {
      // Try to join with product_images table
      final response = await _supabase
          .from('products')
          .select('''
            *,
            product_images(image_url)
          ''')
          .order('created_at', ascending: false);
      
      print('ProductService - Raw response with images: $response');
      final products = (response as List).map((item) {
        print('ProductService - Product item with images: $item');
        return Product.fromJson(item);
      }).toList();
      print('ProductService - Total products loaded: ${products.length}');
      return products;
    } catch (e) {
      print('ProductService - Error with join, trying without: $e');
      // If join fails, try without it
      try {
        final response = await _supabase
            .from('products')
            .select('*')
            .order('created_at', ascending: false);
        
        print('ProductService - Raw response without join: $response');
        return (response as List).map((item) => Product.fromJson(item)).toList();
      } catch (e2) {
        print('ProductService - Error loading products: $e2');
        throw Exception('Error loading products: $e2');
      }
    }
  }

  Future<List<Product>> getProductsByCategory(String category) async {
    try {
      if (category == 'All') {
        return await getAllProducts();
      }
      
      // Search for exact category match (case-insensitive)
      final response = await _supabase
          .from('products')
          .select('''
            *,
            product_images(image_url)
          ''')
          .ilike('category', '%$category%')
          .order('created_at', ascending: false);
      
      print('ProductService - Category: $category, Found ${(response as List).length} products');
      return (response as List).map((item) => Product.fromJson(item)).toList();
    } catch (e) {
      print('ProductService - Error loading products by category: $e');
      throw Exception('Error loading products: $e');
    }
  }

  Future<List<Product>> searchProducts(String query) async {
    try {
      final response = await _supabase
          .from('products')
          .select('''
            *,
            product_images(image_url)
          ''')
          .ilike('product_name', '%$query%')
          .order('created_at', ascending: false);
      
      return (response as List).map((item) => Product.fromJson(item)).toList();
    } catch (e) {
      print('ProductService - Error searching products: $e');
      throw Exception('Error searching products: $e');
    }
  }

  Future<Product> getProductById(int productId) async {
    try {
      print('ProductService - Fetching product by ID: $productId');
      final response = await _supabase
          .from('products')
          .select('''
            *,
            product_images(image_url, variant_id, is_primary, display_order),
            product_variants(variant_id, color, size, stock_quantity, image_url),
            sellers(shop_name, shop_logo)
          ''')
          .eq('product_id', productId)
          .single();
      
      print('ProductService - Product detail response: $response');
      
      // Flatten sellers data
      if (response['sellers'] != null) {
        final sellerData = response['sellers'];
        response['shop_name'] = sellerData['shop_name'];
        response['shop_logo'] = sellerData['shop_logo'];
      }
      
      return Product.fromJson(response);
    } catch (e) {
      print('ProductService - Error loading product: $e');
      throw Exception('Error loading product: $e');
    }
  }

  Future<List<String>> getVariantImages(int productId, int variantId) async {
    try {
      final response = await _supabase
          .from('product_images')
          .select('image_url')
          .eq('product_id', productId)
          .eq('variant_id', variantId)
          .order('display_order', ascending: true);
      
      return (response as List).map((item) => item['image_url'] as String).toList();
    } catch (e) {
      print('ProductService - Error loading variant images: $e');
      return [];
    }
  }

  Future<Product?> getHeroProduct() async {
    try {
      final response = await _supabase
          .from('products')
          .select('''
            *,
            product_images(image_url)
          ''')
          .not('badge_type', 'is', null)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      
      return response != null ? Product.fromJson(response) : null;
    } catch (e) {
      print('ProductService - Error loading hero product: $e');
      return null;
    }
  }

  Future<Product?> getBestSellerProduct() async {
    try {
      final response = await _supabase
          .from('products')
          .select('''
            *,
            product_images(image_url)
          ''')
          .order('total_sold', ascending: false)
          .limit(1)
          .maybeSingle();
      
      return response != null ? Product.fromJson(response) : null;
    } catch (e) {
      print('ProductService - Error loading best seller product: $e');
      return null;
    }
  }

  // Get best seller by category
  Future<Product?> getBestSellerProductByCategory(String category) async {
    try {
      final products = await getProductsByCategory(category);
      if (products.isEmpty) return null;
      
      // For now, return the first product (will need total_sold field in database)
      return products.first;
    } catch (e) {
      print('ProductService - Error loading best seller by category: $e');
      return null;
    }
  }

  // Get top rated product (overall)
  Future<Product?> getTopRatedProduct() async {
    try {
      final response = await _supabase
          .from('products')
          .select('''
            *,
            product_images(image_url)
          ''')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      
      return response != null ? Product.fromJson(response) : null;
    } catch (e) {
      print('ProductService - Error loading top rated product: $e');
      return null;
    }
  }

  // Get top rated by category
  Future<Product?> getTopRatedProductByCategory(String category) async {
    try {
      final products = await getProductsByCategory(category);
      if (products.isEmpty) return null;
      
      // For now, return the first product (will need average_rating field in database)
      return products.first;
    } catch (e) {
      print('ProductService - Error loading top rated by category: $e');
      return null;
    }
  }

  // Get newest product (overall)
  Future<Product?> getNewestProduct() async {
    try {
      final response = await _supabase
          .from('products')
          .select('''
            *,
            product_images(image_url)
          ''')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      
      return response != null ? Product.fromJson(response) : null;
    } catch (e) {
      print('ProductService - Error loading newest product: $e');
      return null;
    }
  }

  // Get newest by category
  Future<Product?> getNewestProductByCategory(String category) async {
    try {
      final products = await getProductsByCategory(category);
      if (products.isEmpty) return null;
      
      // Already sorted by created_at descending in getProductsByCategory
      return products.first;
    } catch (e) {
      print('ProductService - Error loading newest by category: $e');
      return null;
    }
  }
}
