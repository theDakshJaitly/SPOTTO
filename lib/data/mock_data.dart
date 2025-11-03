import 'package:latlong2/latlong.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/parking_zone.dart';
import '../models/zone_details.dart';
import '../models/user_profile.dart';

final List<ParkingZone> mockParkingZones = [
  ParkingZone(
    id: 'zone_a',
    name: 'Zone A - Main St',
    boundaries: [
      const LatLng(37.7749, -122.4194),
      const LatLng(37.7759, -122.4194),
      const LatLng(37.7759, -122.4174),
      const LatLng(37.7749, -122.4174),
    ],
    probability: 0.75,
  ),
  ParkingZone(
    id: 'zone_b',
    name: 'Zone B - Market St',
    boundaries: [
      const LatLng(37.7739, -122.4194),
      const LatLng(37.7749, -122.4194),
      const LatLng(37.7749, -122.4174),
      const LatLng(37.7739, -122.4174),
    ],
    probability: 0.45,
  ),
  ParkingZone(
    id: 'zone_c',
    name: 'Zone C - Mission St',
    boundaries: [
      const LatLng(37.7729, -122.4194),
      const LatLng(37.7739, -122.4194),
      const LatLng(37.7739, -122.4174),
      const LatLng(37.7729, -122.4174),
    ],
    probability: 0.25,
  ),
  ParkingZone(
    id: 'zone_d',
    name: 'Zone D - Castro St',
    boundaries: [
      const LatLng(37.7749, -122.4214),
      const LatLng(37.7759, -122.4214),
      const LatLng(37.7759, -122.4194),
      const LatLng(37.7749, -122.4194),
    ],
    probability: 0.85,
  ),
  ParkingZone(
    id: 'zone_e',
    name: 'Zone E - Valencia St',
    boundaries: [
      const LatLng(37.7739, -122.4214),
      const LatLng(37.7749, -122.4214),
      const LatLng(37.7749, -122.4194),
      const LatLng(37.7739, -122.4194),
    ],
    probability: 0.55,
  ),
  ParkingZone(
    id: 'zone_f',
    name: 'Zone F - 16th St',
    boundaries: [
      const LatLng(37.7729, -122.4214),
      const LatLng(37.7739, -122.4214),
      const LatLng(37.7739, -122.4194),
      const LatLng(37.7729, -122.4194),
    ],
    probability: 0.35,
  ),
  ParkingZone(
    id: 'zone_g',
    name: 'Zone G - Hayes St',
    boundaries: [
      const LatLng(37.7759, -122.4214),
      const LatLng(37.7769, -122.4214),
      const LatLng(37.7769, -122.4194),
      const LatLng(37.7759, -122.4194),
    ],
    probability: 0.65,
  ),
];

final Map<String, ZoneDetails> mockZoneDetails = {
  'zone_a': ZoneDetails(
    avgParkingTime: '43 min',
    lastUpdated: '2 min ago',
    probabilityHistory: [
      const FlSpot(0, 0.5),
      const FlSpot(1, 0.6),
      const FlSpot(2, 0.7),
      const FlSpot(3, 0.65),
      const FlSpot(4, 0.75),
      const FlSpot(5, 0.8),
    ],
  ),
  'zone_b': ZoneDetails(
    avgParkingTime: '52 min',
    lastUpdated: '1 min ago',
    probabilityHistory: [
      const FlSpot(0, 0.3),
      const FlSpot(1, 0.4),
      const FlSpot(2, 0.45),
      const FlSpot(3, 0.5),
      const FlSpot(4, 0.45),
      const FlSpot(5, 0.45),
    ],
  ),
  'zone_c': ZoneDetails(
    avgParkingTime: '38 min',
    lastUpdated: '3 min ago',
    probabilityHistory: [
      const FlSpot(0, 0.2),
      const FlSpot(1, 0.25),
      const FlSpot(2, 0.3),
      const FlSpot(3, 0.28),
      const FlSpot(4, 0.25),
      const FlSpot(5, 0.25),
    ],
  ),
  'zone_d': ZoneDetails(
    avgParkingTime: '35 min',
    lastUpdated: '1 min ago',
    probabilityHistory: [
      const FlSpot(0, 0.7),
      const FlSpot(1, 0.75),
      const FlSpot(2, 0.8),
      const FlSpot(3, 0.85),
      const FlSpot(4, 0.9),
      const FlSpot(5, 0.85),
    ],
  ),
  'zone_e': ZoneDetails(
    avgParkingTime: '47 min',
    lastUpdated: '4 min ago',
    probabilityHistory: [
      const FlSpot(0, 0.4),
      const FlSpot(1, 0.5),
      const FlSpot(2, 0.55),
      const FlSpot(3, 0.6),
      const FlSpot(4, 0.55),
      const FlSpot(5, 0.55),
    ],
  ),
  'zone_f': ZoneDetails(
    avgParkingTime: '41 min',
    lastUpdated: '2 min ago',
    probabilityHistory: [
      const FlSpot(0, 0.3),
      const FlSpot(1, 0.35),
      const FlSpot(2, 0.4),
      const FlSpot(3, 0.35),
      const FlSpot(4, 0.35),
      const FlSpot(5, 0.35),
    ],
  ),
  'zone_g': ZoneDetails(
    avgParkingTime: '39 min',
    lastUpdated: '1 min ago',
    probabilityHistory: [
      const FlSpot(0, 0.5),
      const FlSpot(1, 0.6),
      const FlSpot(2, 0.65),
      const FlSpot(3, 0.7),
      const FlSpot(4, 0.65),
      const FlSpot(5, 0.65),
    ],
  ),
};

final UserProfile mockUserProfile = UserProfile(
  name: 'Jordan Lee',
  points: 1840,
  badges: [
    'Eco Parker',
    'Early Bird',
    'Top Rated',
    'Feedback Pro',
    'City Explorer',
    'Weekend Warrior',
  ],
);
