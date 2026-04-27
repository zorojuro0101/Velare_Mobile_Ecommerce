class ServerConfig {
  // Web server URL for accessing uploaded files
  // ⚠️ IMPORTANT: If testing on a physical device or emulator, you MUST use your computer's IP address
  //
  // Change this to your actual server URL:
  //
  // ❌ DON'T USE for mobile devices: 'http://127.0.0.1:5000' (only works on same device)
  // ✅ USE for mobile devices: 'http://192.168.1.100:5000' (replace with your computer's IP)
  //
  // How to find your computer's IP:
  // - Windows: Run 'ipconfig' in Command Prompt, look for IPv4 Address
  // - Mac/Linux: Run 'ifconfig' or 'ip addr', look for inet address
  // - Production: 'https://yourdomain.com'
  static const String webServerUrl = 'http://127.0.0.1:5000';

  // Helper method to get full URL for uploaded files
  static String getFileUrl(String path) {
    // If it's already a full URL, return as is
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    // Remove leading slash if present
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;

    return '$webServerUrl/$cleanPath';
  }
}
