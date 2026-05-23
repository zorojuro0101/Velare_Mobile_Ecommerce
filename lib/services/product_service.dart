import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';
import '../utils/color_matcher.dart';

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
          .eq('is_active', true)
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
          .eq('is_active', true)
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
            .eq('is_active', true)
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
          .eq('is_active', true)
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
          .eq('is_active', true)
          .ilike('product_name', '%$query%')
          .order('created_at', ascending: false);
      
      return (response as List).map((item) => Product.fromJson(item)).toList();
    } catch (e) {
      print('ProductService - Error searching products: $e');
      throw Exception('Error searching products: $e');
    }
  }

  /// Smart search na nag-co-combine ng:
  /// - Free-text matching sa `product_name`, `description`, at variant `color` name
  /// - Color similarity matching via `hex_code` ng product_variants
  ///
  /// Ginagamit ito ng voice search para suportahan ang creative seller-defined
  /// color names (e.g. "Eggplant", "Lipstick") via fuzzy hex matching.
  ///
  /// Logic:
  /// 1. Run a text-keyword query if [keywords] is provided.
  /// 2. If [canonicalColor] is provided, fetch variants whose hex_code is
  ///    visually within Lab-distance threshold of that color's anchors,
  ///    then collect their product_ids.
  /// 3. Combine results:
  ///    - Both filters → intersection (products na text-match AT may matching color variant)
  ///    - Color only → products with matching variant
  ///    - Text only → text matches
  ///    - Neither → empty list
  Future<List<Product>> searchProductsAdvanced({
    String? keywords,
    String? canonicalColor,
  }) async {
    try {
      final hasText = keywords != null && keywords.trim().isNotEmpty;
      final hasColor = canonicalColor != null && canonicalColor.trim().isNotEmpty;

      if (!hasText && !hasColor) return [];

      // Step 1: Text-keyword candidates (search across name, description, materials, AND variant color names)
      Set<int>? textMatchIds;
      List<Product> textMatches = [];
      if (hasText) {
        final q = keywords.trim();
        final response = await _supabase
            .from('products')
            .select('''
              *,
              product_images(image_url),
              product_variants(color, hex_code)
            ''')
            .eq('is_active', true)
            .or('product_name.ilike.%$q%,description.ilike.%$q%,materials.ilike.%$q%,category.ilike.%$q%')
            .order('created_at', ascending: false);

        textMatches = (response as List).map((item) => Product.fromJson(item)).toList();
        textMatchIds = textMatches.map((p) => p.id).toSet();
      }

      // Step 2: Color-similarity candidates via hex_code matching
      Set<int>? colorMatchIds;
      if (hasColor) {
        // Fetch ALL variants (we need hex codes to compute Lab distance client-side).
        // Variants table is small relative to products; for very large catalogs we
        // could later add a `canonical_color` column to avoid this scan.
        final variantsResp = await _supabase
            .from('product_variants')
            .select('product_id, hex_code, color');

        final ids = <int>{};
        for (final row in (variantsResp as List)) {
          final pid = row['product_id'] as int?;
          if (pid == null) continue;
          final hex = row['hex_code'] as String?;
          final colorName = row['color'] as String?;

          // Match if hex is visually close, OR if the seller's color name
          // resolves to the same canonical bucket (covers cases where hex is
          // missing).
          final hexMatch = ColorMatcher.hexMatchesColor(hex, canonicalColor);
          final nameMatch = !hexMatch &&
              ColorMatcher.canonicalColorFromName(colorName) == canonicalColor.toLowerCase();
          if (hexMatch || nameMatch) {
            ids.add(pid);
          }
        }
        colorMatchIds = ids;
      }

      // Step 3: Combine
      List<Product> results;
      if (hasText && hasColor) {
        // Intersection
        final intersect = textMatchIds!.intersection(colorMatchIds!);
        results = textMatches.where((p) => intersect.contains(p.id)).toList();
        // If intersection is empty, fall back to text matches so the user
        // still sees something rather than a blank screen.
        if (results.isEmpty && textMatches.isNotEmpty) {
          results = textMatches;
        }
      } else if (hasText) {
        results = textMatches;
      } else {
        // Color only: fetch the products by their IDs
        if (colorMatchIds == null || colorMatchIds.isEmpty) return [];
        final response = await _supabase
            .from('products')
            .select('''
              *,
              product_images(image_url)
            ''')
            .eq('is_active', true)
            .inFilter('product_id', colorMatchIds.toList())
            .order('created_at', ascending: false);
        results = (response as List).map((item) => Product.fromJson(item)).toList();
      }

      print('ProductService - Advanced search keywords="$keywords" color="$canonicalColor" -> ${results.length} results');
      return results;
    } catch (e) {
      print('ProductService - Error in advanced search: $e');
      // Fallback to plain text search to avoid breaking the UX.
      if (keywords != null && keywords.trim().isNotEmpty) {
        return searchProducts(keywords);
      }
      return [];
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
          .eq('is_active', true)
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
          .eq('is_active', true)
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
          .eq('is_active', true)
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
          .eq('is_active', true)
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
