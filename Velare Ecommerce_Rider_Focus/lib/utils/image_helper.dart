import 'package:supabase_flutter/supabase_flutter.dart';

class ImageHelper {
  static String getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return '';
    }

    // If already a full URL (Supabase or external), return as is
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      print('ImageHelper - Full URL detected: $imagePath');
      return imagePath;
    }

    final supabase = Supabase.instance.client;

    // Remove leading slash if present
    String path = imagePath;
    if (path.startsWith('/')) {
      path = path.substring(1);
    }

    // Remove 'static/' prefix for Supabase Storage
    // Files in Supabase are stored as: uploads/profiles/filename.jpg
    // NOT: static/uploads/profiles/filename.jpg
    if (path.startsWith('static/')) {
      path = path.substring(7); // Remove 'static/'
    }

    // Construct the public URL using 'Images' bucket
    final url = supabase.storage.from('Images').getPublicUrl(path);
    print('ImageHelper - Constructed URL from path: $imagePath -> $url');
    return url;
  }

  /// Get avatar URL with smart detection
  /// Returns empty string if avatar should show initial instead
  static String getAvatarUrl(String? avatarPath) {
    if (avatarPath == null ||
        avatarPath.isEmpty ||
        avatarPath.contains('default-avatar')) {
      return ''; // Will show initial
    }

    // Use the main getImageUrl method which handles both Supabase and local paths
    return getImageUrl(avatarPath);
  }
}
