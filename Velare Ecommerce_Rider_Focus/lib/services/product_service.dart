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
      // Map UI categories to database category patterns
      String categoryPattern = '';
      switch (category) {
        case 'Dresses & Skirts':
          categoryPattern = '(dresses|Dresses|skirts|Skirts)';
          break;
        case 'Tops & Blouses':
          categoryPattern = '(tops|Tops|blouses|Blouses)';
          break;
        case 'Activewear & Yoga Pants':
          categoryPattern = '(activewear|Active Wear|yoga-pants|Yoga Pants)';
          break;
        case 'Lingerie & Sleepwear':
          categoryPattern = '(Lingerie|lingerie|sleepwear|Sleepwear)';
          break;
        case 'Jackets & Coats':
          categoryPattern = '(Jackets|jackets|Coats|coats)';
          break;
        case 'Shoes & Accessories':
          categoryPattern = '(shoes|Shoes|Accessories|accessories)';
          break;
        default:
          return await getAllProducts();
      }
      
      // Use OR conditions to match any of the category variations
      final response = await _supabase
          .from('products')
          .select('''
            *,
            product_images(image_url)
          ''')
          .or(categoryPattern.replaceAll('(', '').replaceAll(')', '').split('|')
              .map((cat) => 'category.ilike.$cat')
              .join(','))
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
            product_images(image_url),
            product_variants(color, size, stock_quantity)
          ''')
          .eq('product_id', productId)
          .single();
      
      print('ProductService - Product detail response: $response');
      return Product.fromJson(response);
    } catch (e) {
      print('ProductService - Error loading product: $e');
      throw Exception('Error loading product: $e');
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
}