import 'package:latlong2/latlong.dart';

class SearchSuggestion {
  final String name;
  final LatLng coordinates;
  final bool hasParkingZones; // Whether this location has parking zones

  SearchSuggestion({
    required this.name,
    required this.coordinates,
    required this.hasParkingZones,
  });
}

