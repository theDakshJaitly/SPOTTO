import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/search_result.dart';

class MapTilerService {
  // You'll need to get a free API key from https://cloud.maptiler.com/
  // For now, using a placeholder - replace with your actual key
  static const String _apiKey = 'YOUR_MAPTILER_API_KEY';
  static const String _baseUrl = 'https://api.maptiler.com';

  /// Search for places with autocomplete
  /// Returns list of search results with potential polygon boundaries
  static Future<List<SearchResult>> searchPlaces(
    String query, {
    LatLng? proximity, // Bias results towards this location
    int limit = 10,
  }) async {
    if (_apiKey == 'YOUR_MAPTILER_API_KEY') {
      // Fallback to mock data if API key not set
      return _getMockSearchResults(query);
    }

    try {
      final queryParams = {
        'key': _apiKey,
        'q': query,
        'limit': limit.toString(),
        'types': 'poi,address,place', // Get places, addresses, and POIs
        'geometry': 'true', // Request geometry (polygons)
      };

      if (proximity != null) {
        queryParams['proximity'] = '${proximity.longitude},${proximity.latitude}';
      }

      final uri = Uri.parse('$_baseUrl/geocoding/$query.json').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseSearchResults(data);
      } else {
        print('MapTiler API error: ${response.statusCode}');
        return _getMockSearchResults(query);
      }
    } catch (e) {
      print('Error fetching search results: $e');
      return _getMockSearchResults(query);
    }
  }

  /// Parse MapTiler API response
  static List<SearchResult> _parseSearchResults(Map<String, dynamic> data) {
    final List<SearchResult> results = [];
    final features = data['features'] as List<dynamic>? ?? [];

    for (final feature in features) {
      final geometry = feature['geometry'];
      final properties = feature['properties'] as Map<String, dynamic>;
      final coordinates = geometry['coordinates'] as List<dynamic>;

      // Extract center point
      LatLng center;
      List<LatLng>? polygon;

      if (geometry['type'] == 'Point') {
        // Point geometry
        center = LatLng(
          coordinates[1] as double,
          coordinates[0] as double,
        );
      } else if (geometry['type'] == 'Polygon') {
        // Polygon geometry - first ring is the outer boundary
        final ring = coordinates[0] as List<dynamic>;
        polygon = ring.map((coord) {
          return LatLng(
            coord[1] as double,
            coord[0] as double,
          );
        }).toList();
        // Center is calculated from polygon bounds
        center = _calculateCentroid(polygon);
      } else {
        // For other types, try to extract a point
        center = LatLng(
          coordinates[1] as double,
          coordinates[0] as double,
        );
      }

      results.add(SearchResult(
        id: feature['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: properties['name'] ?? properties['place_name'] ?? 'Unknown',
        address: properties['address'] ?? properties['street'],
        city: properties['city'] ?? properties['locality'],
        country: properties['country'],
        center: center,
        polygon: polygon,
        type: properties['type'],
        relevance: (properties['relevance'] as num?)?.toDouble(),
      ));
    }

    return results;
  }

  /// Calculate centroid of a polygon
  static LatLng _calculateCentroid(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(0, 0);
    double lat = 0.0;
    double lng = 0.0;
    for (final p in points) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / points.length, lng / points.length);
  }

  /// Mock search results for testing (when API key not set)
  /// Returns multiple suggestions like Google Maps
  static List<SearchResult> _getMockSearchResults(String query) {
    final queryLower = query.toLowerCase();
    final mockResults = <SearchResult>[];

    // Mumbai/Mum related results
    if (queryLower.contains('mum') || queryLower.contains('mumbai')) {
      mockResults.addAll([
        SearchResult(
          id: 'mock_mum_1',
          name: 'Mumbai',
          address: 'Maharashtra',
          city: 'Mumbai',
          country: 'India',
          center: const LatLng(19.0760, 72.8777),
          type: 'place',
          relevance: 0.95,
        ),
        SearchResult(
          id: 'mock_mum_2',
          name: 'Mumbai Junction',
          address: 'Block 2, West Patel Nagar',
          city: 'Mumbai',
          country: 'India',
          center: const LatLng(19.0800, 72.8800),
          type: 'poi',
          relevance: 0.90,
        ),
        SearchResult(
          id: 'mock_mum_3',
          name: 'Mumbai Central',
          address: 'Mumbai, Maharashtra',
          city: 'Mumbai',
          country: 'India',
          center: const LatLng(18.9700, 72.8200),
          type: 'poi',
          relevance: 0.88,
        ),
        SearchResult(
          id: 'mock_mum_4',
          name: 'Mumbra',
          address: 'Thane, Maharashtra',
          city: 'Thane',
          country: 'India',
          center: const LatLng(19.1800, 73.0400),
          type: 'place',
          relevance: 0.85,
        ),
        SearchResult(
          id: 'mock_mum_5',
          name: 'Mumbai Street Food',
          address: 'Sector 29, Faridabad',
          city: 'Faridabad',
          country: 'India',
          center: const LatLng(28.4000, 77.3000),
          type: 'poi',
          relevance: 0.80,
        ),
      ]);
    }

    // Market/Mall results
    if (queryLower.contains('market') || queryLower.contains('mall')) {
      mockResults.addAll([
        SearchResult(
          id: 'mock_market_1',
          name: 'Main Market',
          address: 'Connaught Place',
          city: 'New Delhi',
          country: 'India',
          center: const LatLng(28.6304, 77.2177),
          polygon: [
            const LatLng(28.6310, 77.2165),
            const LatLng(28.6310, 77.2185),
            const LatLng(28.6295, 77.2185),
            const LatLng(28.6295, 77.2165),
            const LatLng(28.6310, 77.2165),
          ],
          type: 'poi',
          relevance: 0.9,
        ),
        SearchResult(
          id: 'mock_market_2',
          name: 'Shopping Mall',
          address: 'Sector 18',
          city: 'Noida',
          country: 'India',
          center: const LatLng(28.5700, 77.3200),
          type: 'poi',
          relevance: 0.85,
        ),
      ]);
    }

    // Park results
    if (queryLower.contains('park')) {
      mockResults.add(SearchResult(
        id: 'mock_park_1',
        name: 'Central Park',
        address: 'Near India Gate',
        city: 'New Delhi',
        country: 'India',
        center: const LatLng(28.6129, 77.2295),
        polygon: [
          const LatLng(28.6140, 77.2280),
          const LatLng(28.6140, 77.2310),
          const LatLng(28.6115, 77.2310),
          const LatLng(28.6115, 77.2280),
          const LatLng(28.6140, 77.2280),
        ],
        type: 'poi',
        relevance: 0.85,
      ));
    }

    // If no specific matches, return generic results
    if (mockResults.isEmpty && query.isNotEmpty) {
      mockResults.addAll([
        SearchResult(
          id: 'mock_gen_1',
          name: query,
          address: 'Search Result',
          city: 'New Delhi',
          country: 'India',
          center: const LatLng(28.6139, 77.2090),
          type: 'place',
          relevance: 0.7,
        ),
        SearchResult(
          id: 'mock_gen_2',
          name: '$query Location',
          address: 'Nearby area',
          city: 'New Delhi',
          country: 'India',
          center: const LatLng(28.6200, 77.2100),
          type: 'place',
          relevance: 0.65,
        ),
      ]);
    }

    // Sort by relevance
    mockResults.sort((a, b) => (b.relevance ?? 0).compareTo(a.relevance ?? 0));

    return mockResults;
  }
}

