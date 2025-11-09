import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';

class NavigationService {
  /// Show dialog to select navigation app and open it
  static Future<void> showNavigationOptions(
    BuildContext context,
    LatLng destination,
    LatLng? origin,
  ) async {
    // Build URLs for all navigation apps
    final googleMapsUrl = _buildGoogleMapsUrl(destination, origin);
    final appleMapsUrl = _buildAppleMapsUrl(destination, origin);
    final wazeUrl = _buildWazeUrl(destination);

    // Create list of available navigation apps
    final apps = <NavigationApp>[
      NavigationApp(
        name: 'Google Maps',
        icon: Icons.map,
        color: const Color(0xFF4285F4),
        onTap: () async {
          try {
            await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not open Google Maps')),
              );
            }
          }
        },
      ),
      NavigationApp(
        name: 'Apple Maps',
        icon: Icons.map_outlined,
        color: Colors.black,
        onTap: () async {
          try {
            await launchUrl(appleMapsUrl, mode: LaunchMode.externalApplication);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not open Apple Maps')),
              );
            }
          }
        },
      ),
      NavigationApp(
        name: 'Waze',
        icon: Icons.navigation,
        color: const Color(0xFF00D4FF),
        onTap: () async {
          try {
            await launchUrl(wazeUrl, mode: LaunchMode.externalApplication);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not open Waze')),
              );
            }
          }
        },
      ),
    ];

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => _NavigationDialog(
          apps: apps,
          destination: destination,
          origin: origin,
        ),
      );
    }
  }

  /// Build Google Maps URL
  static Uri _buildGoogleMapsUrl(LatLng destination, LatLng? origin) {
    String url = 'https://www.google.com/maps/dir/?api=1';
    
    if (origin != null) {
      url += '&origin=${origin.latitude},${origin.longitude}';
    }
    
    url += '&destination=${destination.latitude},${destination.longitude}';
    url += '&travelmode=driving';
    
    return Uri.parse(url);
  }

  /// Build Apple Maps URL
  static Uri _buildAppleMapsUrl(LatLng destination, LatLng? origin) {
    String url = 'https://maps.apple.com/?';
    
    if (origin != null) {
      url += 'saddr=${origin.latitude},${origin.longitude}&';
    }
    
    url += 'daddr=${destination.latitude},${destination.longitude}';
    url += '&dirflg=d'; // driving directions
    
    return Uri.parse(url);
  }

  /// Build Waze URL
  static Uri _buildWazeUrl(LatLng destination) {
    // Waze doesn't support origin in URL, only destination
    final url = 'https://waze.com/ul?ll=${destination.latitude},${destination.longitude}&navigate=yes';
    return Uri.parse(url);
  }
}

class NavigationApp {
  final String name;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  NavigationApp({
    required this.name,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _NavigationDialog extends StatelessWidget {
  final List<NavigationApp> apps;
  final LatLng destination;
  final LatLng? origin;

  const _NavigationDialog({
    required this.apps,
    required this.destination,
    this.origin,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Text(
        'Open directions in...',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: apps.map((app) {
          return InkWell(
            onTap: () {
              Navigator.pop(context);
              app.onTap();
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: app.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(app.icon, color: app.color, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      app.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey[400]),
                ],
              ),
            ),
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

