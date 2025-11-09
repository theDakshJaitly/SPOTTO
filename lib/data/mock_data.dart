import 'package:latlong2/latlong.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/parking_zone.dart';
import '../models/zone_details.dart';
import '../models/user_profile.dart';
import '../models/search_suggestion.dart';

// --- NEW MOCK ZONES FOR PUNE ---
// Coordinates based on user input for main parking lot

final List<ParkingZone> mockParkingZones = [
  ParkingZone(
    id: 'zone_a',
    name: 'Main Parking Lot',
    boundaries: [
      // Your coordinates, converted to Decimal Degrees
      const LatLng(18.605556, 73.716389), // 18°36'20"N 73°42'59"E
      const LatLng(18.605556, 73.717222), // 18°36'20"N 73°43'02"E
      const LatLng(18.603889, 73.716944), // 18°36'14"N 73°43'01"E
      const LatLng(18.604167, 73.716111), // 18°36'15"N 73°42'58"E
      const LatLng(18.605556, 73.716389), // Closing the loop
    ],
    probability: 0.35, // Let's make it somewhat full
    isPrivate: false, // Public zone
    hourlyRate: "Free",
  ),
  ParkingZone(
    id: 'zone_b',
    name: 'Street (East)',
    boundaries: [
      const LatLng(18.605556, 73.71728), // East of Zone A
      const LatLng(18.605556, 73.71750),
      const LatLng(18.603889, 73.71716),
      const LatLng(18.603889, 73.716944),
      const LatLng(18.605556, 73.71728),
    ],
    probability: 0.75,
    isPrivate: false, // Public zone
    hourlyRate: "Free",
  ),
  ParkingZone(
    id: 'zone_c',
    name: 'Street (South)',
    boundaries: [
      const LatLng(18.603611, 73.716944), // South of Zone A
      const LatLng(18.603889, 73.716944),
      const LatLng(18.603889, 73.716111),
      const LatLng(18.603611, 73.716111),
      const LatLng(18.603611, 73.716944),
    ],
    probability: 0.90, // High chance
    isPrivate: false, // Public zone
    hourlyRate: "Free",
  ),
  ParkingZone(
    id: 'zone_d',
    name: 'West Lot',
    boundaries: [
      const LatLng(18.605556, 73.71580), // West of Zone A
      const LatLng(18.605556, 73.71630),
      const LatLng(18.604167, 73.716111),
      const LatLng(18.604167, 73.71560),
      const LatLng(18.605556, 73.71580),
    ],
    probability: 0.15, // Super full
    isPrivate: false, // Public zone
    hourlyRate: "Free",
  ),
  // Mumbai Private Zone - Large paid parking lot
  ParkingZone(
    id: 'zone_mumbai_private',
    name: 'Mumbai Private Zone',
    boundaries: [
      // Large zone in Navi Mumbai, Thane area (around 19.030826, 73.019854)
      const LatLng(19.035, 73.015), // Northwest
      const LatLng(19.035, 73.025), // Northeast
      const LatLng(19.025, 73.025), // Southeast
      const LatLng(19.025, 73.015), // Southwest
      const LatLng(19.035, 73.015), // Closing the loop
    ],
    probability: 0.60,
    isPrivate: true, // Private paid zone
    hourlyRate: "₹1/min",
  ),
];

// Mock details mapped to the new IDs
final Map<String, ZoneDetails> mockZoneDetails = {
  'zone_a': ZoneDetails(
    avgParkingTime: '65 min',
    lastUpdated: '2 min ago',
    probabilityHistory: [
      const FlSpot(0, 0.3),
      const FlSpot(1, 0.4),
      const FlSpot(2, 0.45),
      const FlSpot(3, 0.5),
      const FlSpot(4, 0.35),
      const FlSpot(5, 0.35),
    ],
  ),
  'zone_b': ZoneDetails(
    avgParkingTime: '30 min',
    lastUpdated: '1 min ago',
    probabilityHistory: [
      const FlSpot(0, 0.7),
      const FlSpot(1, 0.75),
      const FlSpot(2, 0.8),
      const FlSpot(3, 0.85),
      const FlSpot(4, 0.9),
      const FlSpot(5, 0.75),
    ],
  ),
  'zone_c': ZoneDetails(
    avgParkingTime: '25 min',
    lastUpdated: '5 min ago',
    probabilityHistory: [
      const FlSpot(0, 0.8),
      const FlSpot(1, 0.85),
      const FlSpot(2, 0.9),
      const FlSpot(3, 0.95),
      const FlSpot(4, 0.9),
      const FlSpot(5, 0.90),
    ],
  ),
  'zone_d': ZoneDetails(
    avgParkingTime: '150 min',
    lastUpdated: '1 min ago',
    probabilityHistory: [
      const FlSpot(0, 0.2),
      const FlSpot(1, 0.1),
      const FlSpot(2, 0.15),
      const FlSpot(3, 0.2),
      const FlSpot(4, 0.15),
      const FlSpot(5, 0.15),
    ],
  ),
  'zone_mumbai_private': ZoneDetails(
    avgParkingTime: '120 min',
    lastUpdated: '1 min ago',
    probabilityHistory: [
      const FlSpot(0, 0.55),
      const FlSpot(1, 0.60),
      const FlSpot(2, 0.65),
      const FlSpot(3, 0.60),
      const FlSpot(4, 0.58),
      const FlSpot(5, 0.60),
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

// Mock Search Suggestions
final List<SearchSuggestion> mockSearchSuggestions = [
  // A
  SearchSuggestion(
    name: 'Ansal Plaza, Gurgaon',
    coordinates: const LatLng(28.51116, 77.041901),
    hasParkingZones: true,
  ),
  SearchSuggestion(
    name: 'Ahmedabad, Gujarat',
    coordinates: const LatLng(23.021537, 72.580057),
    hasParkingZones: false,
  ),
  SearchSuggestion(
    name: 'Asian Hospital, Faridabad',
    coordinates: const LatLng(28.337973, 77.300301),
    hasParkingZones: true,
  ),
  SearchSuggestion(
    name: 'Aizawl, Tlangnuam',
    coordinates: const LatLng(23.727763, 92.717995),
    hasParkingZones: false,
  ),
  // C
  SearchSuggestion(
    name: 'California, United States of America',
    coordinates: const LatLng(36.701463, -118.755997),
    hasParkingZones: true,
  ),
  SearchSuggestion(
    name: 'Crown Interiorz Mall, Faridabad',
    coordinates: const LatLng(28.469708, 77.307265),
    hasParkingZones: false,
  ),
  SearchSuggestion(
    name: 'Cairo, Egypt',
    coordinates: const LatLng(30.044388, 31.235712),
    hasParkingZones: false,
  ),
  SearchSuggestion(
    name: 'Cuttack, Odisha ',
    coordinates: const LatLng(20.4686, 85.8792),
    hasParkingZones: true,
  ),
  // G
  SearchSuggestion(
    name: 'Greenfield Main Market',
    coordinates: const LatLng(28.461802, 77.29383), // New Delhi coordinates
    hasParkingZones: true,
  ),
  SearchSuggestion(
    name: 'GIP Mall, Noida',
    coordinates: const LatLng(28.568017, 77.327199),
    hasParkingZones: false,
  ),
  SearchSuggestion(
    name: 'Gurgaon Central',
    coordinates: const LatLng(28.479581, 77.075754),
    hasParkingZones: false,
  ),
  SearchSuggestion(
    name: 'Gandhinagar',
    coordinates: const LatLng(23.223288, 72.649227),
    hasParkingZones: true,
  ),
  // N
  SearchSuggestion(
    name: 'Noida',
    coordinates: const LatLng(28.570633, 77.327215),
    hasParkingZones: true,
  ),
  SearchSuggestion(
    name: 'Navi Mumbai, Thane, Mumbai',
    coordinates: const LatLng(19.030826,  73.019854),
    hasParkingZones: true,
  ),
  SearchSuggestion(
    name: 'Noida Sector 18 Market',
    coordinates: const LatLng(28.570172,  77.326425),
    hasParkingZones: false,
  ),
  SearchSuggestion(
    name: 'New Friends Colony, Delhi',
    coordinates: const LatLng(28.567101, 77.269764),
    hasParkingZones: false,
  ),
  // P
  SearchSuggestion(
    name: 'Pitampura',
    coordinates: const LatLng(28.699512, 77.130105),
    hasParkingZones: true,
  ),
  SearchSuggestion(
    name: 'PVR Cinemas, Pitampura',
    coordinates: const LatLng(28.68964, 77.13126),
    hasParkingZones: false,
  ),
  SearchSuggestion(
    name: 'Pacific Mall, Vivek Vihar Tehsil, Delhi',
    coordinates: const LatLng(28.646387, 77.319992),
    hasParkingZones: false,
  ),
  SearchSuggestion(
    name: 'Punjabi Bagh, Delhi',
    coordinates: const LatLng(28.672995, 77.146124),
    hasParkingZones: true,
  ),
  // R
  SearchSuggestion(
    name: 'Rohini Sector 18 Market',
    coordinates: const LatLng(28.737508, 77.136429),
    hasParkingZones: true,
  ),
  SearchSuggestion(
    name: 'Rithala Metro Station, Delhi',
    coordinates: const LatLng(28.719867,  77.107763),
    hasParkingZones: false,
  ),
  SearchSuggestion(
    name: 'Rajouri Garden Market, Delhi',
    coordinates: const LatLng(28.645644,  77.127007),
    hasParkingZones: false,
  ),
  // S
  SearchSuggestion(
    name: 'Shimla, India',
    coordinates: const LatLng(31.1048, 77.1734),
    hasParkingZones: false,
  ),
  SearchSuggestion(
    name: 'Srinagar, Kashmir',
    coordinates: const LatLng(34.074744, 74.820444),
    hasParkingZones: true,
  ),
  SearchSuggestion(
    name: 'South Extension Market, Delhi',
    coordinates: const LatLng(28.65381, 77.22897),
    hasParkingZones: false,
  ),
  // V
  SearchSuggestion(
    name: 'Vivekananda Institute of Professional Studies, Delhi',
    coordinates: const LatLng(28.720917, 77.141574),
    hasParkingZones: true,
  ),
  SearchSuggestion(
    name: 'Vasant Kunj Mall, Delhi',
    coordinates: const LatLng(28.542754, 77.157398),
    hasParkingZones: false,
  ),
  SearchSuggestion(
    name: 'Vasant Vihar, Delhi',
    coordinates: const LatLng(28.557827, 77.161117),
    hasParkingZones: false,
  ),
  SearchSuggestion(
    name: 'Vaishali Metro Station, Delhi',
    coordinates: const LatLng(28.649748, 77.340139),
    hasParkingZones: true,
  ),
];