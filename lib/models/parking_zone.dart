import 'package:latlong2/latlong.dart';

class ParkingZone {
  final String id;
  final String name;
  final List<LatLng> boundaries;
  double probability;

  ParkingZone({
    required this.id,
    required this.name,
    required this.boundaries,
    required this.probability,
  });
}
