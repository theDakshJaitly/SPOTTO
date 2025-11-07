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
import '../models/search_result.dart';
import '../services/maptiler_service.dart';
import 'zone_details_screen.dart';


class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  List<ParkingZone> zones = []; // Start with empty list
  Timer? _simulationTimer;
  final Random _random = Random();
  late MapController _mapController;

  LatLng _userLocation = const LatLng(18.604792, 73.716666);
  bool _locationFetched = false;
  String _currentPlacename = "Locating...";
  bool _isLocating = false; // <--- NEW: To prevent multiple requests
  bool _isLoadingZones = false; // Track if zones are being fetched

  StreamSubscription<ServiceStatus>? _gpsServiceSubscription;
  StreamSubscription<Position>? _positionStreamSubscription; // <--- NEW: For location stream

  bool _isParked = false;
  ParkingZone? _parkedZone;
  Timer? _parkingTimer;
  Duration _parkingDuration = Duration.zero;

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<SearchResult> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchDebounceTimer;
  bool _showSearchOverlay = false; // Full-screen search overlay

  // Track bottom sheet size for FAB positioning
  double _bottomSheetHeight = 0.0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    // Initialize bottom sheet height to initial size (25% of screen)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final screenHeight = MediaQuery.of(context).size.height;
        setState(() {
          _bottomSheetHeight = screenHeight * 0.25;
        });
      }
    });
    // Don't start simulation or load zones yet - wait for location

    // Listen for GPS service status (e.g., user turning it on/off)
    _gpsServiceSubscription = Geolocator.getServiceStatusStream().listen(
            (ServiceStatus status) {
          if (status == ServiceStatus.enabled) {
            _determinePosition(); // GPS was just turned on, try to get location
          } else {
            // GPS was turned off - reset everything
            _positionStreamSubscription?.cancel();
            _simulationTimer?.cancel();
            if (mounted) {
              setState(() {
                zones = []; // Clear all zones
                _locationFetched = false;
                _isLocating = false;
                _isLoadingZones = false;
                _currentPlacename = "Please enable GPS to fetch zones";
                // Reset to default location
                _userLocation = const LatLng(18.604792, 73.716666);
                _mapController.move(_userLocation, 18.0);
              });
            }
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
        setState(() {
          _currentPlacename = "Please enable GPS";
          _locationFetched = true; // Still allow zones to show
        });
        _showEnableGpsDialog();
        // Load zones anyway after a delay (for testing/fallback)
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _fetchParkingZones();
        });
      }
      return;
    }

    // 2. Check for permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _currentPlacename = "Location permission denied";
            _locationFetched = true; // Still allow zones to show
          });
          // Load zones anyway after a delay (for testing/fallback)
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) _fetchParkingZones();
          });
        }
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
              _currentPlacename = "Location timeout. Using default location.";
              _isLocating = false;
              // Still mark as fetched so we can show zones
              _locationFetched = true;
            });
            // Load zones even if location timed out
            _fetchParkingZones();
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
            // Now that location is found, fetch parking zones
            _fetchParkingZones();
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _currentPlacename = "Error finding location. Using default location.";
              _isLocating = false;
              // Still mark as fetched so we can show zones
              _locationFetched = true;
            });
            // Load zones even if location failed
            _fetchParkingZones();
          }
        }
    );
  }
  // --- END REWRITTEN LOGIC ---

  // Simulated network request to fetch parking zones
  Future<void> _fetchParkingZones() async {
    if (_isLoadingZones) return; // Prevent multiple simultaneous requests

    setState(() {
      _isLoadingZones = true;
    });

    // Simulate network delay (1-2 seconds)
    await Future.delayed(Duration(milliseconds: 1500 + _random.nextInt(500)));

    if (mounted) {
      setState(() {
        // Calculate zones relative to current user location
        zones = _generateZonesRelativeToLocation(_userLocation);
        _isLoadingZones = false;
      });
      // Center map on zones if location wasn't fetched (use default location)
      if (!_locationFetched) {
        _mapController.move(_userLocation, 18.0);
      }
      // Start the simulation timer now that we have zones
      _startLiveSimulation();
    }
  }

  // Generate parking zones relative to the user's current location
  List<ParkingZone> _generateZonesRelativeToLocation(LatLng userLocation) {
    // Original center point (Pune coordinates where zones were originally defined)
    const LatLng originalCenter = LatLng(18.604792, 73.716666);
    
    // Calculate offset from original center to user's location
    final double latOffset = userLocation.latitude - originalCenter.latitude;
    final double lngOffset = userLocation.longitude - originalCenter.longitude;
    
    // Create zones by applying the offset to each boundary point
    return mockParkingZones.map((originalZone) {
      final List<LatLng> adjustedBoundaries = originalZone.boundaries.map((point) {
        return LatLng(
          point.latitude + latOffset,
          point.longitude + lngOffset,
        );
      }).toList();
      
      return ParkingZone(
        id: originalZone.id,
        name: originalZone.name,
        boundaries: adjustedBoundaries,
        probability: originalZone.probability,
      );
    }).toList();
  }

  void _startLiveSimulation() {
    // Only start simulation if we have zones loaded
    if (zones.isEmpty) return;

    _simulationTimer?.cancel(); // Cancel any existing timer
    _simulationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted || zones.isEmpty) {
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
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
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

  // Search functionality
  void _openSearchOverlay() {
    setState(() {
      _showSearchOverlay = true;
    });
    // Focus search field after overlay opens
    Future.delayed(const Duration(milliseconds: 100), () {
      _searchFocusNode.requestFocus();
    });
  }

  void _closeSearchOverlay() {
    setState(() {
      _showSearchOverlay = false;
      _searchResults = [];
      _isSearching = false;
    });
    _searchController.clear();
    _searchFocusNode.unfocus();
  }

  void _onSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    // Debounce search - wait 300ms after user stops typing
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;

    try {
      final results = await MapTilerService.searchPlaces(
        query,
        proximity: _locationFetched ? _userLocation : null,
      );

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
      print('Search error: $e');
    }
  }

  void _onSearchResultSelected(SearchResult result) {
    // Close search overlay
    _closeSearchOverlay();

    // Move map to result location
    _mapController.move(result.center, 16.0);

    // If result has a polygon, create a parking zone from it
    if (result.polygon != null && result.polygon!.isNotEmpty) {
      _createParkingZoneFromSearch(result);
    } else {
      // Show a marker or info for point results
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result.displayName} - No polygon boundary available'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _createParkingZoneFromSearch(SearchResult result) {
    // Create a new parking zone from the search result polygon
    final newZone = ParkingZone(
      id: 'search_${result.id}',
      name: result.displayName,
      boundaries: result.polygon!,
      probability: _random.nextDouble() * 0.5 + 0.3, // Random between 0.3-0.8
    );

    setState(() {
      // Add to existing zones or replace if it's a search zone
      zones.removeWhere((z) => z.id.startsWith('search_'));
      zones.add(newZone);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added parking zone: ${result.displayName}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
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
                if (!_isParked && zones.isNotEmpty) {
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
              if (zones.isNotEmpty)
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

              if (!_isParked && zones.isNotEmpty)
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

          // --- "My Location" FAB - Hide when bottom sheet covers it ---
          if (!_isParked && !_showSearchOverlay)
            // FAB is positioned at fixed 100px from bottom
            // Hide it when bottom sheet height exceeds this position
            Builder(
              builder: (context) {
                const double fabBottomPosition = 100.0; // Fixed position from bottom
                const double fabHeight = 56.0; // Standard FAB height
                const double fabTopPosition = fabBottomPosition + fabHeight; // Top of FAB
                
                // Hide FAB if bottom sheet covers it (sheet height > FAB bottom position)
                final bool shouldShow = _bottomSheetHeight < fabBottomPosition;
                
                if (!shouldShow) return const SizedBox.shrink();
                
                return Positioned(
                  bottom: fabBottomPosition,
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
                );
              },
            ),

          // --- Full-screen Search Overlay ---
          if (_showSearchOverlay)
            _buildSearchOverlay(),

        ],
      ),
    );
  }

  // --- WIDGETS (Unchanged) ---

  Widget _buildSearchSheet() {
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        // Track the bottom sheet's current height
        final screenHeight = MediaQuery.of(context).size.height;
        final currentHeight = notification.extent * screenHeight;
        if (mounted && _bottomSheetHeight != currentHeight) {
          setState(() {
            _bottomSheetHeight = currentHeight;
          });
        }
        return true;
      },
      child: DraggableScrollableSheet(
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
              // Search button that opens full-screen overlay
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: InkWell(
                  onTap: _openSearchOverlay,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Colors.grey),
                        const SizedBox(width: 12),
                        Text(
                          'Search destination or zone...',
                          style: GoogleFonts.inter(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
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
              if (_isLoadingZones)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Loading parking zones...',
                          style: GoogleFonts.inter(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (zones.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.location_off,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No zones found',
                          style: GoogleFonts.inter(
                            color: Colors.grey[600],
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Waiting for location...',
                          style: GoogleFonts.inter(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...zones.map((zone) => _buildZoneListItem(zone)),
              ],
            ),
          );
        },
      ),
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

  // Full-screen search overlay (light theme)
  Widget _buildSearchOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              // Search bar at top
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: _closeSearchOverlay,
                    ),
                    Expanded(
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _searchController,
                        builder: (context, value, child) {
                          return TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            onChanged: _onSearchChanged,
                            autofocus: true,
                            style: const TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              hintText: 'Search destination or zone...',
                              hintStyle: TextStyle(color: Colors.grey[500]),
                              border: InputBorder.none,
                              prefixIcon: const Icon(Icons.search, color: Colors.grey),
                              suffixIcon: value.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, color: Colors.grey),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {
                                          _searchResults = [];
                                          _isSearching = false;
                                        });
                                      },
                                    )
                                  : _isSearching
                                      ? const Padding(
                                          padding: EdgeInsets.all(12.0),
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        )
                                      : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // Search results list
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: _isSearching && _searchResults.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(),
                        )
                      : _searchResults.isEmpty && _searchController.text.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Search for places',
                                    style: GoogleFonts.inter(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _searchResults.isEmpty
                              ? Center(
                                  child: Text(
                                    'No results found',
                                    style: GoogleFonts.inter(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _searchResults.length,
                                  itemBuilder: (context, index) {
                                    final result = _searchResults[index];
                                    return _buildSearchResultItem(result);
                                  },
                                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultItem(SearchResult result) {
    final hasPolygon = result.polygon != null && result.polygon!.isNotEmpty;
    
    return InkWell(
      onTap: () => _onSearchResultSelected(result),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasPolygon ? Icons.map : Icons.location_on,
              color: hasPolygon 
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.displayName,
                    style: GoogleFonts.inter(
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  if (result.fullAddress.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      result.fullAddress,
                      style: GoogleFonts.inter(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (hasPolygon)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Zone',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
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