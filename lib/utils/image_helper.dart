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

    // Determine which bucket to use based on path
    String bucket = 'Images'; // Use 'Images' bucket (capital I) for all

    // If it's just a filename, prepend the path for products
    if (!path.contains('/')) {
      path = 'static/uploads/products/$path';
    }

    // Construct the public URL
    final url = supabase.storage.from(bucket).getPublicUrl(path);
    print(
      'ImageHelper - Constructed URL from path: $imagePath -> $url (bucket: $bucket)',
    );
    return url;
  }
}
