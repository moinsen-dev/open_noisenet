import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationData {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? altitude;
  final DateTime timestamp;
  final LocationSource source;

  const LocationData({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.altitude,
    required this.timestamp,
    required this.source,
  });

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'altitude': altitude,
      'timestamp': timestamp.toIso8601String(),
      'source': source.name,
    };
  }

  @override
  String toString() {
    return 'LocationData(${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}, ${source.name})';
  }
}

enum LocationSource {
  gps, // GPS/GNSS coordinates
  network, // Network-based location
  fallback, // IP-based or other fallback
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  LocationData? _lastKnownLocation;
  Timer? _periodicLocationTimer;
  final Duration _locationUpdateInterval = const Duration(minutes: 5);

  LocationData? get lastKnownLocation => _lastKnownLocation;

  /// Check if location permission is granted
  Future<bool> hasLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Request location permission with explanatory dialog
  Future<bool> requestLocationPermission(BuildContext context) async {
    // Check current permission status
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      // Show explanation dialog before requesting
      final shouldRequest = await _showLocationExplanationDialog(context);
      if (!shouldRequest) return false;
      
      // Request permission using geolocator
      permission = await Geolocator.requestPermission();
    }
    
    if (permission == LocationPermission.deniedForever) {
      // Show settings dialog for permanently denied permission
      return await _showLocationSettingsDialog(context);
    }
    
    return permission == LocationPermission.whileInUse || 
           permission == LocationPermission.always;
  }

  /// Get current location with all fallbacks
  Future<LocationData?> getCurrentLocation({BuildContext? context}) async {
    // Try GPS first if permission available
    if (await hasLocationPermission()) {
      try {
        final gpsLocation = await _getGpsLocation();
        if (gpsLocation != null) {
          _lastKnownLocation = gpsLocation;
          return gpsLocation;
        }
      } catch (e) {
        print('GPS location failed: $e');
      }
    } else if (context != null) {
      // Request permission if context provided
      final granted = await requestLocationPermission(context);
      if (granted) {
        try {
          final gpsLocation = await _getGpsLocation();
          if (gpsLocation != null) {
            _lastKnownLocation = gpsLocation;
            return gpsLocation;
          }
        } catch (e) {
          print('GPS location failed after permission grant: $e');
        }
      }
    }

    // Fallback to network location or IP-based location
    final fallbackLocation = await _getFallbackLocation();
    if (fallbackLocation != null) {
      _lastKnownLocation = fallbackLocation;
    }

    return fallbackLocation;
  }

  /// Get GPS location using geolocator
  Future<LocationData?> _getGpsLocation() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        altitude: position.altitude,
        timestamp: DateTime.now(),
        source: LocationSource.gps,
      );
    } catch (e) {
      print('GPS location error: $e');
      return null;
    }
  }

  /// Get fallback location (could be network-based, IP-based, or hardcoded)
  Future<LocationData?> _getFallbackLocation() async {
    try {
      // Try less accurate network location first
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );

      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: DateTime.now(),
        source: LocationSource.network,
      );
    } catch (e) {
      print('Network location failed: $e');

      // For now, return null. In the future, we could:
      // 1. Use IP geolocation service
      // 2. Use last known location with a timestamp
      // 3. Use device's stored location
      return null;
    }
  }

  /// Start periodic location updates
  void startPeriodicUpdates({BuildContext? context}) {
    stopPeriodicUpdates();

    _periodicLocationTimer = Timer.periodic(_locationUpdateInterval, (_) async {
      final location = await getCurrentLocation(context: context);
      if (location != null) {
        print('🌍 Location updated: $location');
      }
    });

    // Get initial location
    getCurrentLocation(context: context);

    print(
        '🌍 LocationService: Started periodic updates every ${_locationUpdateInterval.inMinutes} minutes');
  }

  /// Stop periodic location updates
  void stopPeriodicUpdates() {
    _periodicLocationTimer?.cancel();
    _periodicLocationTimer = null;
    print('🛑 LocationService: Stopped periodic updates');
  }

  /// Get distance between two coordinates in meters
  static double getDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Check if location is stale (older than threshold)
  bool isLocationStale({Duration threshold = const Duration(minutes: 30)}) {
    if (_lastKnownLocation == null) return true;
    final age = DateTime.now().difference(_lastKnownLocation!.timestamp);
    return age > threshold;
  }

  /// Get location status for UI display
  Map<String, dynamic> getLocationStatus() {
    return {
      'hasPermission': hasLocationPermission(),
      'lastKnownLocation': _lastKnownLocation?.toJson(),
      'isStale': isLocationStale(),
      'periodicUpdatesActive': _periodicLocationTimer?.isActive ?? false,
    };
  }

  /// Clear cached location data
  void clearCache() {
    _lastKnownLocation = null;
  }

  /// Show explanation dialog before requesting location permission
  Future<bool> _showLocationExplanationDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.location_on, size: 48, color: Colors.blue),
        title: const Text('Location Permission'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('OpenNoiseNet needs location access to:'),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.map, size: 20, color: Colors.green),
                SizedBox(width: 8),
                Expanded(child: Text('Tag noise events with coordinates')),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.public, size: 20, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(child: Text('Create community noise maps')),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'Location is only captured when noise events occur.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Show settings dialog when location permission is permanently denied
  Future<bool> _showLocationSettingsDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.settings, size: 48, color: Colors.orange),
        title: const Text('Location Permission Required'),
        content: const Text(
          'Location access was permanently denied. Please enable it in Settings to tag noise events with location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context, true);
              await Geolocator.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Dispose of resources
  void dispose() {
    stopPeriodicUpdates();
  }
}
