import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../data/mock_data.dart';
import '../models/parking_zone.dart';
import 'zone_details_screen.dart';


class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  late List<ParkingZone> zones;
  Timer? _simulationTimer;
  final Random _random = Random();
  late MapController _mapController;

  LatLng _userLocation = const LatLng(18.604792, 73.716666);
  bool _locationFetched = false;
  String _currentPlacename = "Locating...";
  bool _isLocating = false; // <--- NEW: To prevent multiple requests

  StreamSubscription<ServiceStatus>? _gpsServiceSubscription;
  StreamSubscription<Position>? _positionStreamSubscription; // <--- NEW: For location stream

  bool _isParked = false;
  ParkingZone? _parkedZone;
  Timer? _parkingTimer;
  Duration _parkingDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    zones = List.from(mockParkingZones);
    _mapController = MapController();
    _startLiveSimulation();

    // Listen for GPS service status (e.g., user turning it on/off)
    _gpsServiceSubscription = Geolocator.getServiceStatusStream().listen(
            (ServiceStatus status) {
          if (status == ServiceStatus.enabled) {
            _determinePosition(); // GPS was just turned on, try to get location
          } else {
            setState(() {
              _locationFetched = false;
              _currentPlacename = "Please enable GPS";
            });
          }
        }
    );
    // Also run the check once on init
    _determinePosition();
  }

  Future<void> _showEnableGpsDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('GPS is Disabled'),
          content: const SingleChildScrollView(
            child: Text('Please enable GPS to find parking zones near you.'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Turn On'),
              onPressed: () {
                Geolocator.openLocationSettings();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // --- COMPLETELY REWRITTEN LOCATION LOGIC ---
  Future<void> _determinePosition() async {
    // 1. Check if GPS service is enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() => _currentPlacename = "Please enable GPS");
        _showEnableGpsDialog();
      }
      return;
    }

    // 2. Check for permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _currentPlacename = "Location permission denied");
        return;
      }
    }

    // 3. Prevent multiple streams if one is already running
    if (_isLocating) return;

    if (mounted) {
      setState(() {
        _isLocating = true;
        _currentPlacename = "Locating...";
      });
    }

    // 4. Cancel any old stream
    await _positionStreamSubscription?.cancel();

    // 5. Start a new location stream
    _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Only update if moved 10 meters
        )
    ).timeout(
      // 6. Add a timeout to the *entire stream*
        const Duration(seconds: 15),
        onTimeout: (sink) {
          if (mounted) {
            setState(() {
              _currentPlacename = "Location timeout. Try again.";
              _isLocating = false;
            });
          }
          sink.close();
        }
    ).listen(
            (Position position) async {
          // 7. WE GOT A LOCATION!

          // Stop listening, we only need one good location
          await _positionStreamSubscription?.cancel();

          List<Placemark> placemarks = await placemarkFromCoordinates(
              position.latitude,
              position.longitude
          );

          String address = "Current Location";
          if (placemarks.isNotEmpty) {
            final pm = placemarks.first;
            address = "${pm.street ?? ''}, ${pm.locality ?? ''}";
            if (address.trim() == ",") address = pm.name ?? "Current Location";
          }

          if (mounted) {
            setState(() {
              _userLocation = LatLng(position.latitude, position.longitude);
              _locationFetched = true;
              _currentPlacename = address;
              _isLocating = false; // We are done
              _mapController.move(_userLocation, 18.0);
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _currentPlacename = "Error finding location";
              _isLocating = false;
            });
          }
        }
    );
  }
  // --- END REWRITTEN LOGIC ---

  void _startLiveSimulation() {
    _simulationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        final numZonesToUpdate = _random.nextInt(2) + 1;
        for (var i = 0; i < numZonesToUpdate; i++) {
          final randomIndex = _random.nextInt(zones.length);
          zones[randomIndex].probability = _random.nextDouble();
        }
      });
    });
  }

  void _startParkingTimer() {
    _parkingDuration = Duration.zero;
    _parkingTimer?.cancel();
    _parkingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _parkingDuration = _parkingDuration + const Duration(seconds: 1);
      });
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  void dispose() {
    _gpsServiceSubscription?.cancel();
    _positionStreamSubscription?.cancel(); // <--- NEW: Cancel position stream
    _simulationTimer?.cancel();
    _parkingTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Color _getZoneColor(double probability) {
    if (probability > 0.7) {
      return const Color(0xFF10B981);
    } else if (probability > 0.3) {
      return const Color(0xFFF59E0B);
    } else {
      return const Color(0xFFEF4444);
    }
  }

  void _onZoneTap(ParkingZone zone) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: ZoneDetailsScreen(
                zone: zone,
                scrollController: scrollController,
                onParkHere: _parkInZone,
              ),
            );
          },
        );
      },
    );
  }

  void _parkInZone(ParkingZone zone) {
    Navigator.pop(context);
    setState(() {
      _isParked = true;
      _parkedZone = zone;
    });
    _startParkingTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Parked at ${zone.name}! +20 points'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _leaveZone() {
    setState(() {
      _isParked = false;
      _parkedZone = null;
    });
    _parkingTimer?.cancel();
    _parkingDuration = Duration.zero;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Parking session ended.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation,
              initialZoom: 18.0,
              onTap: (tapPos, latlng) {
                if (!_isParked) {
                  for (final zone in zones) {
                    if (_pointInPolygon(latlng, zone.boundaries)) {
                      _onZoneTap(zone);
                      return;
                    }
                  }
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.spotto',
                retinaMode: true,
              ),
              PolygonLayer(
                polygons: zones.map((zone) {
                  final baseColor = _getZoneColor(zone.probability);
                  return Polygon(
                    points: zone.boundaries,
                    color: _isParked
                        ? baseColor.withOpacity(0.1)
                        : baseColor.withOpacity(0.20),
                    borderColor: _isParked
                        ? baseColor.withOpacity(0.3)
                        : baseColor.withOpacity(0.85),
                    borderStrokeWidth: 3.0,
                  );
                }).toList(),
              ),

              MarkerLayer(
                markers: [
                  if (_locationFetched)
                    Marker(
                      width: 24,
                      height: 24,
                      point: _userLocation,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.primary,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              if (!_isParked)
                MarkerLayer(
                  markers: zones.map((zone) {
                    final centroid = _centroid(zone.boundaries);
                    return Marker(
                      width: 48,
                      height: 48,
                      point: centroid,
                      child: GestureDetector(
                        onTap: () => _onZoneTap(zone),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                _getZoneColor(zone.probability),
                                _getZoneColor(zone.probability)
                                    .withOpacity(0.8),
                              ],
                            ),
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: _getZoneColor(zone.probability)
                                    .withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '${(zone.probability * 100).toInt()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),

          // --- CONDITIONAL UI ---
          if (_isParked)
            _buildActiveParkingCard()
          else
            _buildSearchSheet(),

          // Legend overlay (only show if not parked)
          if (!_isParked)
            Positioned(
              top: MediaQuery.of(context).padding.top + 90,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                    )
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLegendItem('High', const Color(0xFF10B981)),
                    const SizedBox(height: 8),
                    _buildLegendItem('Medium', const Color(0xFFF59E0B)),
                    const SizedBox(height: 8),
                    _buildLegendItem('Low', const Color(0xFFEF4444)),
                  ],
                ),
              ),
            ),

          // --- Top Address Bar ---
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                  )
                ],
              ),
              child: Row(
                children: [
                  Icon(
                      _isLocating
                          ? Icons.sync // Show a spinner
                          : (_locationFetched ? Icons.location_on : Icons.location_off),
                      color: _locationFetched
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                      size: 20
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _currentPlacename,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- "My Location" FAB ("Eye" Icon) ---
          if (!_isParked)
            Positioned(
              bottom: 250, // Adjust this to sit above your sheet
              right: 16,
              child: FloatingActionButton(
                onPressed: () {
                  if(_locationFetched) {
                    _mapController.move(_userLocation, 18.0);
                  } else {
                    // Try to get it again
                    _determinePosition();
                  }
                },
                backgroundColor: Colors.white,
                foregroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(Icons.my_location),
              ),
            ),

        ],
      ),
    );
  }

  // --- WIDGETS (Unchanged) ---

  Widget _buildSearchSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.25,
      minChildSize: 0.1,
      maxChildSize: 0.8,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
              )
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(0),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    hintText: 'Search destination or zone...',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Top-rated near you",
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              ...zones.map((zone) => _buildZoneListItem(zone)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildZoneListItem(ParkingZone zone) {
    final color = _getZoneColor(zone.probability);
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.location_on, color: color),
      ),
      title: Text(
        zone.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${(zone.probability * 100).toInt()}% chance', // UNTOUCHED
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _onZoneTap(zone),
    );
  }

  Widget _buildActiveParkingCard() {
    if (_parkedZone == null) return Container();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
            )
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _parkedZone!.name,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Text(
                  "Spot confirmed",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn(
                  "Time",
                  _formatDuration(_parkingDuration),
                ),
                _buildStatColumn("Rate", "\$2.50/hr"), // UNTOUCHED (Mock data)
                _buildStatColumn("Points", "+20"), // Mock data
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.warning_amber_rounded, size: 20),
                    label: const Text("Report Full"),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Report sent! Thanks.')),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.directions_car, size: 20),
                    label: const Text("Leaving Now"),
                    onPressed: _leaveZone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 4,
              )
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

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

  bool _pointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;
    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].latitude;
      final yi = polygon[i].longitude;
      final xj = polygon[j].latitude;
      final yj = polygon[j].longitude;

      final intersect = ((yi > point.longitude) != (yj > point.longitude)) &&
          (point.latitude <
              (xj - xi) * (point.longitude - yi) / (yj - yi + 0.0) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }
}