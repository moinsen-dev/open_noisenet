import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionDialogService {
  static final PermissionDialogService _instance = PermissionDialogService._internal();
  factory PermissionDialogService() => _instance;
  PermissionDialogService._internal();

  /// Request location permission with explanatory dialog
  Future<bool> requestLocationPermission(BuildContext context) async {
    const permission = Permission.location;
    
    // Check current status
    final status = await permission.status;
    
    if (status.isGranted) {
      return true;
    }
    
    // If permission was permanently denied, show settings dialog
    if (status.isPermanentlyDenied) {
      if (!context.mounted) return false;
      return _showLocationPermanentlyDeniedDialog(context);
    }
    
    // If permission should show rationale, show explanation first
    if (status.isDenied) {
      if (!context.mounted) return false;
      final shouldRequest = await _showLocationExplanationDialog(context);
      if (!shouldRequest) {
        return false;
      }
    }
    
    // Request the permission
    final newStatus = await permission.request();
    
    // If still denied after request, check if permanently denied
    if (newStatus.isPermanentlyDenied) {
      if (!context.mounted) return false;
      return _showLocationPermanentlyDeniedDialog(context);
    }
    
    return newStatus.isGranted;
  }

  /// Request microphone permission with explanatory dialog
  Future<bool> requestMicrophonePermission(BuildContext context) async {
    const permission = Permission.microphone;
    
    // Check current status
    final status = await permission.status;
    
    if (status.isGranted) {
      return true;
    }
    
    // If permission was permanently denied, show settings dialog
    if (status.isPermanentlyDenied) {
      if (!context.mounted) return false;
      return _showPermanentlyDeniedDialog(context);
    }
    
    // If permission should show rationale, show explanation first
    if (status.isDenied) {
      if (!context.mounted) return false;
      final shouldRequest = await _showExplanationDialog(context);
      if (!shouldRequest) {
        return false;
      }
    }
    
    // Request the permission
    final newStatus = await permission.request();
    
    // If still denied after request, check if permanently denied
    if (newStatus.isPermanentlyDenied) {
      if (!context.mounted) return false;
      return _showPermanentlyDeniedDialog(context);
    }
    
    return newStatus.isGranted;
  }

  /// Show location explanation dialog before requesting permission
  Future<bool> _showLocationExplanationDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: const Icon(
            Icons.location_on,
            size: 48,
            color: Colors.blue,
          ),
          title: const Text('Location Permission'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OpenNoiseNet needs access to your location to:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.map, size: 20, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Associate noise measurements with geographic coordinates'),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.public, size: 20, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Contribute to community noise mapping efforts'),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.analytics, size: 20, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Enable location-based noise analysis and trends'),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                'Your location is only used when submitting noise events. No continuous tracking.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not Now'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Allow Access'),
            ),
          ],
        );
      },
    );
    
    return result ?? false;
  }

  /// Show dialog when location permission is permanently denied
  Future<bool> _showLocationPermanentlyDeniedDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: const Icon(
            Icons.settings,
            size: 48,
            color: Colors.orange,
          ),
          title: const Text('Location Permission Required'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Location access is needed for noise event mapping. Please enable it in your device settings.',
              ),
              SizedBox(height: 12),
              Text(
                'Go to: Settings > Privacy & Security > Location Services > OpenNoiseNet',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
    
    return result ?? false;
  }

  /// Show explanation dialog before requesting permission
  Future<bool> _showExplanationDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: const Icon(
            Icons.mic,
            size: 48,
            color: Colors.blue,
          ),
          title: const Text('Microphone Permission'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OpenNoiseNet needs access to your microphone to:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.volume_up, size: 20, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Measure environmental noise levels in real-time'),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.analytics, size: 20, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Generate noise monitoring data and statistics'),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.public, size: 20, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Contribute to community noise monitoring efforts'),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                'Your audio data is processed locally and only noise levels are stored.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not Now'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Allow Access'),
            ),
          ],
        );
      },
    );
    
    return result ?? false;
  }

  /// Show dialog when permission is permanently denied
  Future<bool> _showPermanentlyDeniedDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: const Icon(
            Icons.settings,
            size: 48,
            color: Colors.orange,
          ),
          title: const Text('Permission Required'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Microphone access is required for noise monitoring. Please enable it in your device settings.',
              ),
              SizedBox(height: 12),
              Text(
                'Go to: Settings > Privacy & Security > Microphone > OpenNoiseNet',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
    
    return result ?? false;
  }

  /// Show permission status information
  Future<void> showPermissionStatus(BuildContext context) async {
    final status = await Permission.microphone.status;
    
    String title;
    String message;
    IconData icon;
    Color color;
    
    switch (status) {
      case PermissionStatus.granted:
        title = 'Permission Granted';
        message = 'Microphone access is enabled. You can start noise monitoring.';
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case PermissionStatus.denied:
        title = 'Permission Denied';
        message = 'Microphone access was denied. Tap "Request Permission" to try again.';
        icon = Icons.cancel;
        color = Colors.orange;
        break;
      case PermissionStatus.permanentlyDenied:
        title = 'Permission Permanently Denied';
        message = 'Please enable microphone access in device settings to use noise monitoring.';
        icon = Icons.block;
        color = Colors.red;
        break;
      case PermissionStatus.restricted:
        title = 'Permission Restricted';
        message = 'Microphone access is restricted on this device.';
        icon = Icons.security;
        color = Colors.red;
        break;
      case PermissionStatus.limited:
        title = 'Permission Limited';
        message = 'Microphone access is limited on this device.';
        icon = Icons.warning;
        color = Colors.orange;
        break;
      case PermissionStatus.provisional:
        title = 'Permission Provisional';
        message = 'Microphone access is provisional on this device.';
        icon = Icons.info;
        color = Colors.blue;
        break;
    }
    
    if (!context.mounted) return;
    
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: Icon(icon, size: 48, color: color),
          title: Text(title),
          content: Text(message),
          actions: [
            if (status.isPermanentlyDenied)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              )
            else
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
          ],
        );
      },
    );
  }

  /// Get user-friendly permission status text
  static String getPermissionStatusText(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return 'Granted';
      case PermissionStatus.denied:
        return 'Denied';
      case PermissionStatus.permanentlyDenied:
        return 'Permanently Denied';
      case PermissionStatus.restricted:
        return 'Restricted';
      case PermissionStatus.limited:
        return 'Limited';
      case PermissionStatus.provisional:
        return 'Provisional';
    }
  }

  /// Get color based on permission status
  static Color getPermissionStatusColor(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return Colors.green;
      case PermissionStatus.denied:
        return Colors.orange;
      case PermissionStatus.permanentlyDenied:
      case PermissionStatus.restricted:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}