import 'dart:io';
import 'package:flutter/foundation.dart';

/// Utility service for network-related operations, especially for development
class NetworkUtils {
  static final NetworkUtils _instance = NetworkUtils._internal();
  factory NetworkUtils() => _instance;
  NetworkUtils._internal();

  /// Cache for detected host IP to avoid repeated network calls
  String? _cachedHostIP;
  DateTime? _lastDetectionTime;
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  /// Detect the host machine's local network IP address
  /// This is useful for connecting mobile devices to development servers
  Future<String?> detectHostIP() async {
    try {
      // Return cached IP if still valid
      if (_cachedHostIP != null && 
          _lastDetectionTime != null && 
          DateTime.now().difference(_lastDetectionTime!) < _cacheValidDuration) {
        return _cachedHostIP;
      }

      String? detectedIP;

      if (Platform.isAndroid || Platform.isIOS) {
        // For mobile devices, we need to detect the network interface IP
        detectedIP = await _detectNetworkInterfaceIP();
      } else if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
        // For desktop platforms, detect the primary network interface
        detectedIP = await _detectNetworkInterfaceIP();
      }

      // Cache the result
      if (detectedIP != null) {
        _cachedHostIP = detectedIP;
        _lastDetectionTime = DateTime.now();
      }

      return detectedIP;
    } catch (e) {
      debugPrint('Failed to detect host IP: $e');
      return null;
    }
  }

  /// Get the appropriate backend URL for the current platform and environment
  Future<String> getRecommendedBackendUrl({int port = 8100}) async {
    // For release builds, always use production URL
    if (kReleaseMode) {
      return 'https://api.open-noisenet.org/api/v1';
    }

    // For debug/development builds, detect appropriate URL
    if (Platform.isAndroid) {
      // Check if running on emulator
      final isEmulator = await _isAndroidEmulator();
      if (isEmulator) {
        return 'http://10.0.2.2:$port/api/v1';
      }
    }

    // For physical devices or iOS simulator, try to detect host IP
    final hostIP = await detectHostIP();
    if (hostIP != null) {
      return 'http://$hostIP:$port/api/v1';
    }

    // Fallback to localhost (works for simulators/emulators in some cases)
    return 'http://localhost:$port/api/v1';
  }

  /// Detect network interface IP addresses
  Future<String?> _detectNetworkInterfaceIP() async {
    try {
      // Get all network interfaces
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      // Priority order for interface selection
      final preferredNames = ['wlan0', 'en0', 'eth0', 'Wi-Fi', 'Ethernet'];
      
      // First, try to find preferred interfaces
      for (final preferredName in preferredNames) {
        for (final interface in interfaces) {
          if (interface.name.toLowerCase().contains(preferredName.toLowerCase())) {
            for (final address in interface.addresses) {
              if (_isValidLocalIP(address.address)) {
                return address.address;
              }
            }
          }
        }
      }

      // If no preferred interface found, use any valid local IP
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (_isValidLocalIP(address.address)) {
            return address.address;
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error detecting network interface IP: $e');
      return null;
    }
  }

  /// Check if an IP address is a valid local network IP
  bool _isValidLocalIP(String ip) {
    // Check for common local network ranges
    return ip.startsWith('192.168.') ||
           ip.startsWith('10.') ||
           ip.startsWith('172.16.') ||
           ip.startsWith('172.17.') ||
           ip.startsWith('172.18.') ||
           ip.startsWith('172.19.') ||
           ip.startsWith('172.20.') ||
           ip.startsWith('172.21.') ||
           ip.startsWith('172.22.') ||
           ip.startsWith('172.23.') ||
           ip.startsWith('172.24.') ||
           ip.startsWith('172.25.') ||
           ip.startsWith('172.26.') ||
           ip.startsWith('172.27.') ||
           ip.startsWith('172.28.') ||
           ip.startsWith('172.29.') ||
           ip.startsWith('172.30.') ||
           ip.startsWith('172.31.');
  }

  /// Check if running on Android emulator
  Future<bool> _isAndroidEmulator() async {
    if (!Platform.isAndroid) return false;
    
    try {
      // Android emulators typically have this characteristic IP
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          // Emulator typically uses 10.0.2.x range
          if (address.address.startsWith('10.0.2.')) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get current device's network information for debugging
  Future<Map<String, dynamic>> getNetworkInfo() async {
    try {
      final interfaces = await NetworkInterface.list(includeLoopback: false);
      final networkInfo = <String, dynamic>{
        'platform': Platform.operatingSystem,
        'isEmulator': Platform.isAndroid ? await _isAndroidEmulator() : false,
        'interfaces': <Map<String, dynamic>>[],
      };

      for (final interface in interfaces) {
        final interfaceInfo = <String, dynamic>{
          'name': interface.name,
          'addresses': interface.addresses.map((addr) => {
            'address': addr.address,
            'type': addr.type.name,
            'isLoopback': addr.isLoopback,
            'isLocalNetwork': _isValidLocalIP(addr.address),
          }).toList(),
        };
        networkInfo['interfaces'].add(interfaceInfo);
      }

      // Add detected host IP
      final hostIP = await detectHostIP();
      networkInfo['detectedHostIP'] = hostIP;
      networkInfo['recommendedURL'] = await getRecommendedBackendUrl();

      return networkInfo;
    } catch (e) {
      return {
        'error': e.toString(),
        'platform': Platform.operatingSystem,
      };
    }
  }

  /// Clear cached IP (useful when network changes)
  void clearCache() {
    _cachedHostIP = null;
    _lastDetectionTime = null;
  }

  /// Test if a given URL is reachable
  Future<bool> testConnection(String url, {Duration timeout = const Duration(seconds: 5)}) async {
    try {
      final uri = Uri.parse(url);
      final client = HttpClient();
      client.connectionTimeout = timeout;
      
      final request = await client.getUrl(uri);
      final response = await request.close();
      
      client.close();
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      return false;
    }
  }

  /// Get common backend URL presets for development
  List<BackendPreset> getCommonPresets() {
    return [
      BackendPreset(
        name: 'Local Development (Auto-detect)',
        description: 'Automatically detected host machine IP',
        url: '', // Will be populated dynamically
        isAutoDetect: true,
      ),
      BackendPreset(
        name: 'Android Emulator',
        description: 'Use 10.0.2.2 for Android emulator',
        url: 'http://10.0.2.2:8100/api/v1',
        isAutoDetect: false,
      ),
      BackendPreset(
        name: 'iOS Simulator',
        description: 'Use localhost for iOS simulator',
        url: 'http://localhost:8100/api/v1',
        isAutoDetect: false,
      ),
      BackendPreset(
        name: 'Custom IP',
        description: 'Enter custom IP address',
        url: 'http://192.168.1.100:8100/api/v1',
        isAutoDetect: false,
      ),
      BackendPreset(
        name: 'Production',
        description: 'Production server',
        url: 'https://api.open-noisenet.org/api/v1',
        isAutoDetect: false,
      ),
    ];
  }
}

/// Backend URL preset for easy configuration
class BackendPreset {
  final String name;
  final String description;
  final String url;
  final bool isAutoDetect;

  const BackendPreset({
    required this.name,
    required this.description,
    required this.url,
    required this.isAutoDetect,
  });

  /// Create a copy with updated URL (useful for auto-detect presets)
  BackendPreset withUrl(String newUrl) {
    return BackendPreset(
      name: name,
      description: description,
      url: newUrl,
      isAutoDetect: isAutoDetect,
    );
  }

  @override
  String toString() => '$name: $url';
}