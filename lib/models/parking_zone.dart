import 'package:latlong2/latlong.dart';

class ParkingZone {
  final String id;
  final String name;
  final List<LatLng> boundaries;
  double probability;
  final bool isPrivate; // true for paid lots, false for public/street parking
  final String hourlyRate; // e.g., "₹25/hr" or "Free"

  ParkingZone({
    required this.id,
    required this.name,
    required this.boundaries,
    required this.probability,
    this.isPrivate = false, // Default to public
    this.hourlyRate = "Free", // Default to free
  });
}
