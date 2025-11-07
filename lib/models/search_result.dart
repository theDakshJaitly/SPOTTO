import 'package:latlong2/latlong.dart';

class SearchResult {
  final String id;
  final String name;
  final String? address;
  final String? city;
  final String? country;
  final LatLng center; // Center point of the result
  final List<LatLng>? polygon; // Polygon boundary if available
  final String? type; // e.g., "place", "address", "poi"
  final double? relevance; // Relevance score (0-1)

  SearchResult({
    required this.id,
    required this.name,
    this.address,
    this.city,
    this.country,
    required this.center,
    this.polygon,
    this.type,
    this.relevance,
  });

  String get displayName {
    if (address != null && address!.isNotEmpty) {
      return address!;
    }
    return name;
  }

  String get fullAddress {
    final parts = <String>[];
    if (name.isNotEmpty) parts.add(name);
    if (address != null && address!.isNotEmpty) parts.add(address!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (country != null && country!.isNotEmpty) parts.add(country!);
    return parts.join(', ');
  }
}

