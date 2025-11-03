import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../data/mock_data.dart';
import '../models/parking_zone.dart';
import 'zone_details_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late List<ParkingZone> zones;
  Timer? _timer;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    zones = List.from(mockParkingZones);
    _startLiveSimulation();
  }

  void _startLiveSimulation() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      setState(() {
        final numZonesToUpdate = _random.nextInt(2) + 1;
        for (var i = 0; i < numZonesToUpdate; i++) {
          final randomIndex = _random.nextInt(zones.length);
          zones[randomIndex].probability = _random.nextDouble();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Color _getZoneColor(double probability) {
    if (probability > 0.7) {
      return Colors.green.withOpacity(0.5);
    } else if (probability > 0.3) {
      return Colors.yellow.withOpacity(0.5);
    } else {
      return Colors.red.withOpacity(0.5);
    }
  }

  void _onZoneTap(ParkingZone zone) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ZoneDetailsScreen(zone: zone),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spotto'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(37.7744, -122.4194),
              initialZoom: 15.0,
              // Handle taps on the map and test which polygon (zone) contains the tapped point.
              onTap: (tapPos, latlng) {
                for (final zone in zones) {
                  if (_pointInPolygon(latlng, zone.boundaries)) {
                    _onZoneTap(zone);
                    return;
                  }
                }
              },
            ),
            children: [
              TileLayer(
                // Carto Voyager tiles: modern, clean and free to use with attribution
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.spotto',
                // minimal attribution is added by the package automatically in many setups;
                // if you need to show attribution manually, add a widget.
              ),
              PolygonLayer(
                polygons: zones.map((zone) {
                  final baseColor = _getZoneColor(zone.probability);
                  return Polygon(
                    points: zone.boundaries,
                    color: baseColor.withOpacity(0.30),
                    borderColor: baseColor.withOpacity(0.9),
                    borderStrokeWidth: 2.0,
                    isFilled: true,
                  );
                }).toList(),
              ),
              // Markers at polygon centroids so users can tap zones reliably.
              MarkerLayer(
                markers: zones.map((zone) {
                  final centroid = _centroid(zone.boundaries);
                  return Marker(
                    width: 28,
                    height: 28,
                    point: centroid,
                    child: GestureDetector(
                      onTap: () => _onZoneTap(zone),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getZoneColor(zone.probability).withOpacity(0.95),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        label: const Text('Find Parking'),
        icon: const Icon(Icons.search),
        backgroundColor: Theme.of(context).colorScheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // Compute a simple centroid (average of vertices). Good-enough for UI marker placement.
  LatLng _centroid(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(0, 0);
    double lat = 0.0;
    double lng = 0.0;
    for (final p in points) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / points.length, lng / points.length);
  }

  // Ray-casting algorithm for point-in-polygon test. Works with lat/lng points.
  bool _pointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;
    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].latitude;
      final yi = polygon[i].longitude;
      final xj = polygon[j].latitude;
      final yj = polygon[j].longitude;

      final intersect = ((yi > point.longitude) != (yj > point.longitude)) &&
          (point.latitude < (xj - xi) * (point.longitude - yi) / (yj - yi + 0.0) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }
}
