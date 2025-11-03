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
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.spotto',
              ),
              PolygonLayer(
                polygons: zones.map((zone) {
                  return Polygon(
                    points: zone.boundaries,
                    color: _getZoneColor(zone.probability),
                    borderColor: Colors.black,
                    borderStrokeWidth: 2.0,
                    isFilled: true,
                  );
                }).toList(),
              ),
            ],
          ),
          Positioned.fill(
            child: Stack(
              children: zones.map((zone) {
                return GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => _onZoneTap(zone),
                  child: Container(
                    color: Colors.transparent,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        label: const Text('Find Parking'),
        icon: const Icon(Icons.search),
      ),
    );
  }
}
