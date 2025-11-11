import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../data/mock_data.dart';
import '../models/parking_zone.dart';
import '../models/search_suggestion.dart';
import 'zone_details_screen.dart';
import 'total_fare_screen.dart';


class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  List<ParkingZone> zones = []; // Start with empty list
  Timer? _simulationTimer;
  final Random _random = Random();
  late MapController _mapController;

  LatLng _userLocation = const LatLng(18.604792, 73.716666);
  bool _locationFetched = false;
  String _currentPlacename = "Locating...";
  bool _isLocating = false; // <--- NEW: To prevent multiple requests
  bool _isLoadingZones = false; // Track if zones are being fetched
  
  // Store original location for back button functionality
  LatLng? _originalLocation;
  String? _originalPlacename;

  StreamSubscription<ServiceStatus>? _gpsServiceSubscription;
  StreamSubscription<Position>? _positionStreamSubscription; // <--- NEW: For location stream

  bool _isParked = false;
  ParkingZone? _parkedZone;
  Timer? _parkingTimer;
  Duration _parkingDuration = Duration.zero;

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<SearchSuggestion> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchDebounceTimer;
  bool _showSearchOverlay = false; // Full-screen search overlay
  SearchSuggestion? _selectedLocation; // Track selected location for zone fetching

  // Track bottom sheet size for FAB positioning
  double _bottomSheetHeight = 0.0;
  
  // Track current zoom level
  double _currentZoom = 18.0;
  
  // Track external navigation state
  bool _isNavigatingExternally = false;
  ParkingZone? _zoneToParkAfterNavigation;

  @override
  void initState() {
    super.initState();
    try {
      WidgetsBinding.instance.addObserver(this); // Add lifecycle observer
      _mapController = MapController();
      // Store the initial default location as original location
      _originalLocation = _userLocation;
      _originalPlacename = _currentPlacename;
      // Initialize bottom sheet height to initial size (25% of screen)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          try {
            final screenHeight = MediaQuery.of(context).size.height;
            setState(() {
              _bottomSheetHeight = screenHeight * 0.25;
            });
          } catch (e) {
            debugPrint('Error in postFrameCallback: $e');
          }
        }
      });
      // Don't start simulation or load zones yet - wait for location

      // On web, try to get location but don't use service status stream (not supported on web)
      if (kIsWeb) {
        // On web, directly try to get location
        _determinePosition();
      } else {
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
                    _currentZoom = 18.0;
                    _mapController.move(_userLocation, _currentZoom);
                  });
                }
              }
            }
        );
        _determinePosition();
      }
    } catch (e) {
      debugPrint('Error in initState: $e');
    }
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
    // On web, handle location differently
    if (kIsWeb) {
      // Prevent multiple requests
      if (_isLocating) return;

      if (mounted) {
        setState(() {
          _isLocating = true;
          _currentPlacename = "Locating...";
        });
      }

      try {
        // On web, skip service check and go straight to permission
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          if (mounted) {
            setState(() {
              _currentPlacename = "Location permission denied";
              _locationFetched = true;
              _isLocating = false;
            });
            _fetchParkingZones();
          }
          return;
        }

        // Get current position
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        
        // Get address from coordinates
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
          
          String address = placemarks.isNotEmpty
              ? '${placemarks.first.street ?? ''}, ${placemarks.first.locality ?? ''}, ${placemarks.first.administrativeArea ?? ''}'
              : '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
          
          if (address.trim().isEmpty || address.trim() == ',') {
            address = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
          }

          if (mounted) {
            setState(() {
              _userLocation = LatLng(position.latitude, position.longitude);
              _locationFetched = true;
              _currentPlacename = address;
              _isLocating = false;
              _currentZoom = 18.0;
              _mapController.move(_userLocation, _currentZoom);
              
              // Update original location with the actual GPS location
              _originalLocation = _userLocation;
              _originalPlacename = address;
            });
            // Now that location is found, fetch parking zones
            _fetchParkingZones();
          }
        } catch (geocodeError) {
          // If geocoding fails, still use the coordinates
          String address = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
          if (mounted) {
            setState(() {
              _userLocation = LatLng(position.latitude, position.longitude);
              _locationFetched = true;
              _currentPlacename = address;
              _isLocating = false;
              _currentZoom = 18.0;
              _mapController.move(_userLocation, _currentZoom);
              _originalLocation = _userLocation;
              _originalPlacename = address;
            });
            _fetchParkingZones();
          }
        }
      } catch (error) {
        debugPrint('Location error: $error');
        if (mounted) {
          setState(() {
            _currentPlacename = "Error finding location. Using default location.";
            _isLocating = false;
            _locationFetched = true;
            
            if (_originalLocation == null) {
              _originalLocation = _userLocation;
              _originalPlacename = _currentPlacename;
            }
          });
          _fetchParkingZones();
        }
      }
      return;
    }

    // Mobile location logic
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
            
            // Store original location if not already stored (using default)
            if (_originalLocation == null) {
              _originalLocation = _userLocation;
              _originalPlacename = _currentPlacename;
            }
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

    // 5. Start a new location stream (for mobile)
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
              
              // Store original location if not already stored (using default)
              if (_originalLocation == null) {
                _originalLocation = _userLocation;
                _originalPlacename = _currentPlacename;
              }
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
              _currentZoom = 18.0;
              _mapController.move(_userLocation, _currentZoom);
              
              // Update original location with the actual GPS location
              // (This will override the default location set in initState)
              _originalLocation = _userLocation;
              _originalPlacename = address;
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
              
              // Store original location if not already stored (using default)
              if (_originalLocation == null) {
                _originalLocation = _userLocation;
                _originalPlacename = _currentPlacename;
              }
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
                        _currentZoom = 18.0;
                        _mapController.move(_userLocation, _currentZoom);
      }
      // Start the simulation timer now that we have zones
      _startLiveSimulation();
    }
  }

  // Generate parking zones relative to the user's current location
  List<ParkingZone> _generateZonesRelativeToLocation(LatLng userLocation) {
    // Navi Mumbai coordinates (where Mumbai Private Zone should appear)
    const LatLng naviMumbaiCenter = LatLng(19.030826, 73.019854);
    final double distanceToNaviMumbai = _calculateDistance(userLocation, naviMumbaiCenter);
    final bool isNearNaviMumbai = distanceToNaviMumbai < 5.0; // 5km radius
    
    // If user is near Navi Mumbai, show ONLY the Mumbai Private Zone
    // Otherwise, show the regular public zones (shifted relative to location)
    if (isNearNaviMumbai) {
      // Only show Mumbai Private Zone when near Navi Mumbai
      final mumbaiZone = mockParkingZones.firstWhere(
        (zone) => zone.id == 'zone_mumbai_private',
        orElse: () => throw StateError('Mumbai zone not found'),
      );
      return [
        ParkingZone(
          id: mumbaiZone.id,
          name: mumbaiZone.name,
          boundaries: mumbaiZone.boundaries, // Use fixed coordinates
          probability: mumbaiZone.probability,
          isPrivate: mumbaiZone.isPrivate,
          hourlyRate: mumbaiZone.hourlyRate,
        ),
      ];
    } else {
      // Show regular public zones (shifted relative to user location)
      // Original center point (Pune coordinates where zones were originally defined)
      const LatLng originalCenter = LatLng(18.604792, 73.716666);
      
      // Calculate offset from original center to user's location
      final double latOffset = userLocation.latitude - originalCenter.latitude;
      final double lngOffset = userLocation.longitude - originalCenter.longitude;
      
      // Return all zones EXCEPT Mumbai zone, shifted relative to location
      return mockParkingZones.where((zone) => zone.id != 'zone_mumbai_private').map((originalZone) {
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
          isPrivate: originalZone.isPrivate,
          hourlyRate: originalZone.hourlyRate,
        );
      }).toList();
    }
  }
  
  // Helper to calculate distance between two coordinates in kilometers
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // km
    final double dLat = _toRadians(point2.latitude - point1.latitude);
    final double dLon = _toRadians(point2.longitude - point1.longitude);
    final double a = (dLat / 2) * (dLat / 2) +
        _toRadians(point1.latitude) * _toRadians(point2.latitude) *
        (dLon / 2) * (dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }
  
  double _toRadians(double degrees) {
    return degrees * (pi / 180);
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App has returned to the foreground
      if (_isNavigatingExternally && _zoneToParkAfterNavigation != null) {
        setState(() {
          _isNavigatingExternally = false; // Reset flag
        });
        // Show the "Have you parked?" dialog for the zone we were navigating to
        final zone = _zoneToParkAfterNavigation;
        _zoneToParkAfterNavigation = null; // Clear the zone
        if (zone != null && mounted) {
          _showParkConfirmationDialog(context, zone);
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remove lifecycle observer
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

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    // Filter mock suggestions based on query
    final queryLower = query.toLowerCase();
    final filtered = mockSearchSuggestions.where((suggestion) {
      return suggestion.name.toLowerCase().contains(queryLower);
    }).toList();

    if (mounted) {
      setState(() {
        _searchResults = filtered;
        _isSearching = false;
      });
    }
  }

  void _onSearchSuggestionSelected(SearchSuggestion suggestion) {
    // Close search overlay
    _closeSearchOverlay();

    // Store selected location
    _selectedLocation = suggestion;

    // Move map to suggestion location
    _currentZoom = 16.0;
    _mapController.move(suggestion.coordinates, _currentZoom);

    // Update user location to the selected suggestion
    setState(() {
      _userLocation = suggestion.coordinates;
      _currentPlacename = suggestion.name;
      _locationFetched = true; // Mark as fetched so UI shows proper message
    });

    // Fetch zones for this location
    _fetchZonesForLocation(suggestion);
  }

  // Fetch zones based on selected location
  Future<void> _fetchZonesForLocation(SearchSuggestion suggestion) async {
    if (_isLoadingZones) return;

    setState(() {
      _isLoadingZones = true;
    });

    // Simulate network delay
    await Future.delayed(Duration(milliseconds: 1500 + _random.nextInt(500)));

    if (mounted) {
      setState(() {
        if (suggestion.hasParkingZones) {
          // Load zones relative to the selected location
          zones = _generateZonesRelativeToLocation(suggestion.coordinates);
        } else {
          // No zones for this location
          zones = [];
        }
        _isLoadingZones = false;
      });
      
      // Start simulation timer if zones were loaded
      if (zones.isNotEmpty) {
        _startLiveSimulation();
      }
    }
  }

  void _zoomIn() {
    final newZoom = (_currentZoom + 1).clamp(3.0, 20.0);
    _currentZoom = newZoom;
    _mapController.move(_mapController.camera.center, newZoom);
  }

  void _zoomOut() {
    final newZoom = (_currentZoom - 1).clamp(3.0, 20.0);
    _currentZoom = newZoom;
    _mapController.move(_mapController.camera.center, newZoom);
  }

  Future<void> _showParkConfirmationDialog(BuildContext context, ParkingZone zone) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Have you parked?'),
          content: const Text('Confirm that you have parked at this location.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Not yet'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // Call _parkInZone to activate parking
                _parkInZone(zone);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  void _goBackToOriginalLocation() {
    if (_originalLocation == null || _originalPlacename == null) return;
    
    // Clear selected location
    _selectedLocation = null;
    
    // Restore original location
    setState(() {
      _userLocation = _originalLocation!;
      _currentPlacename = _originalPlacename!;
      _currentZoom = 18.0;
    });
    
    // Move map back to original location
    _mapController.move(_originalLocation!, _currentZoom);
    
    // Reload zones for original location
    _fetchParkingZones();
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
                userLocation: _locationFetched ? _userLocation : null,
                onNavigateExternal: (navigatedZone) {
                  // Track that external navigation has started for this zone
                  setState(() {
                    _isNavigatingExternally = true;
                    _zoneToParkAfterNavigation = navigatedZone;
                  });
                },
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
    // Store the zone and duration before clearing them
    final zone = _parkedZone;
    final wasPrivate = zone?.isPrivate ?? false;
    final parkingDuration = _parkingDuration; // Store before clearing
    
    // Always show rewards popup first
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.celebration, color: Colors.white),
            SizedBox(width: 8),
            Text('+20 rewards points! 🔥'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
    
    // Clear parking state
    setState(() {
      _isParked = false;
      _parkedZone = null;
    });
    _parkingTimer?.cancel();
    _parkingDuration = Duration.zero;
    
    // Conditional payment flow
    if (wasPrivate && zone != null) {
      // Calculate total fare based on parking duration
      // Rate is ₹1 per minute
      final totalFare = parkingDuration.inMinutes; // ₹1 per minute
      
      // Navigate to Total Fare screen
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TotalFareScreen(
                zoneName: zone.name,
                parkingDuration: parkingDuration,
                ratePerMinute: 1.0, // ₹1 per minute
                totalFare: totalFare,
              ),
            ),
          );
        }
      });
    }
    // If public zone, just return to map (already done by clearing state)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Simple background first
          Container(
            color: Colors.blue[50],
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map, size: 64, color: Colors.blue[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Map Loading...',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Map widget
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _userLocation,
                initialZoom: 18.0,
                minZoom: 3,
                maxZoom: 19,
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
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.example.spotto',
                  maxZoom: 19,
                  minZoom: 3,
                  errorTileCallback: (tile, error, stackTrace) {
                    debugPrint('Tile error: $error');
                  },
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

          // Zoom buttons (only show if not parked)
          if (!_isParked && !_showSearchOverlay)
            Builder(
              builder: (context) {
                final screenHeight = MediaQuery.of(context).size.height;
                final topPadding = MediaQuery.of(context).padding.top;
                
                // Legend is at top + 90, with ~100px height, plus 8px spacing
                const double legendTop = 90;
                const double legendHeight = 100; // Approximate
                const double spacing = 8;
                const double zoomButtonsTop = legendTop + legendHeight + spacing;
                const double zoomButtonsHeight = 100; // 2 buttons * 40px + spacing
                
                // Calculate bottom position of zoom buttons from top of screen
                final double zoomButtonsBottomFromTop = topPadding + zoomButtonsTop + zoomButtonsHeight;
                
                // Calculate bottom position from bottom of screen
                final double zoomButtonsBottomFromBottom = screenHeight - zoomButtonsBottomFromTop;
                
                // Hide zoom buttons if bottom sheet covers them
                final bool shouldShow = _bottomSheetHeight < zoomButtonsBottomFromBottom;
                
                if (!shouldShow) return const SizedBox.shrink();
                
                return Positioned(
                  top: topPadding + zoomButtonsTop,
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Zoom In button
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _zoomIn,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                            child: Container(
                              width: 48,
                              height: 48,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.add,
                                color: Colors.black87,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                        // Divider
                        Container(
                          height: 1,
                          width: 48,
                          color: Colors.grey.withOpacity(0.2),
                        ),
                        // Zoom Out button
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _zoomOut,
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                            child: Container(
                              width: 48,
                              height: 48,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.remove,
                                color: Colors.black87,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
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
                  // Back button (only show when a search location is selected)
                  if (_selectedLocation != null)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _goBackToOriginalLocation,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.arrow_back,
                            color: Colors.black87,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  if (_selectedLocation != null) const SizedBox(width: 8),
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
                
                // Hide FAB if bottom sheet covers it (sheet height > FAB bottom position)
                final bool shouldShow = _bottomSheetHeight < fabBottomPosition;
                
                if (!shouldShow) return const SizedBox.shrink();
                
                return Positioned(
                  bottom: fabBottomPosition,
                  right: 16,
                  child: FloatingActionButton(
                    onPressed: () {
                      if(_locationFetched) {
                        _currentZoom = 18.0;
                _mapController.move(_userLocation, _currentZoom);
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
        snap: true,
        snapSizes: const [0.25, 0.5, 0.8],
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
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.all(0),
            children: [
              // Drag handle
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
              else if (zones.isEmpty && _locationFetched)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.local_parking_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No parking zones found nearby',
                          style: GoogleFonts.inter(
                            color: Colors.grey[600],
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try searching for another location',
                          style: GoogleFonts.inter(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (zones.isEmpty && !_locationFetched)
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
                          : _searchResults.isEmpty && _searchController.text.isNotEmpty
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
                                    final suggestion = _searchResults[index];
                                    return _buildSearchResultItem(suggestion);
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

  Widget _buildSearchResultItem(SearchSuggestion suggestion) {
    return InkWell(
      onTap: () => _onSearchSuggestionSelected(suggestion),
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
              suggestion.hasParkingZones ? Icons.local_parking : Icons.location_on,
              color: suggestion.hasParkingZones 
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
                    suggestion.name,
                    style: GoogleFonts.inter(
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${suggestion.coordinates.latitude.toStringAsFixed(4)}, ${suggestion.coordinates.longitude.toStringAsFixed(4)}',
                    style: GoogleFonts.inter(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (suggestion.hasParkingZones)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Zones',
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
                // Show rate only if zone is private
                if (_parkedZone!.isPrivate)
                  _buildStatColumn("Rate", _parkedZone!.hourlyRate)
                else
                  _buildStatColumn("Type", "Free"),
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