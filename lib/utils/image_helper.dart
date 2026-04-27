import 'package:supabase_flutter/supabase_flutter.dart';

class ImageHelper {
  static String getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return '';
    }

    // If already a full URL, return as is
    if (imagePath.startsWith('http')) {
      print('ImageHelper - Full URL detected: $imagePath');
      return imagePath;
    }

    final supabase = Supabase.instance.client;
    
    // Remove leading slash if present
    String path = imagePath;
    if (path.startsWith('/')) {
      path = path.substring(1);
    }
    
    // The path should already be in format: static/uploads/products/filename.jpg
    // If it's just a filename, prepend the path
    if (!path.contains('/')) {
      path = 'static/uploads/products/$path';
    }
    
    // Construct the public URL using 'Images' bucket
    final url = supabase.storage.from('Images').getPublicUrl(path);
    print('ImageHelper - Constructed URL from path: $imagePath -> $url');
    return url;
  }
}
