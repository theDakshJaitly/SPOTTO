import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:latlong2/latlong.dart';
import '../models/parking_zone.dart';
import '../data/mock_data.dart';
import '../services/navigation_service.dart';

class ZoneDetailsScreen extends StatelessWidget {
  final ParkingZone zone;
  final ScrollController? scrollController;
  final void Function(ParkingZone) onParkHere;
  final LatLng? userLocation; // User's current location for navigation
  final void Function(ParkingZone) onNavigateExternal; // Callback when external navigation starts

  const ZoneDetailsScreen({
    super.key,
    required this.zone,
    this.scrollController,
    required this.onParkHere,
    this.userLocation, // Optional user location
    required this.onNavigateExternal, // Required callback
  });

  @override
  Widget build(BuildContext context) {
    final details = mockZoneDetails[zone.id];

    if (details == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: const Center(
          child: Text('Zone details not found'),
        ),
      );
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            zone.name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatCard(
                    'Availability',
                    '${(zone.probability * 100).toStringAsFixed(0)}%',
                    Icons.local_parking,
                    _getAvailabilityColor(zone.probability),
                  ),
                  _buildStatCard(
                    'Last Updated',
                    details.lastUpdated,
                    Icons.access_time,
                    Theme.of(context).colorScheme.primary,
                  ),
                  _buildStatCard(
                    'Avg',
                    details.avgParkingTime,
                    Icons.timer,
                    Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Probability of Spot by Time',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          horizontalInterval: 0.2,
                          verticalInterval: 1,
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  '${(value * 100).toInt()}%',
                                  style: const TextStyle(fontSize: 12),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  '${value.toInt()}h',
                                  style: const TextStyle(fontSize: 12),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        minX: 0,
                        maxX: 5,
                        minY: 0,
                        maxY: 1,
                        lineBarsData: [
                          LineChartBarData(
                            spots: details.probabilityHistory,
                            isCurved: true,
                            color: Theme.of(context).colorScheme.primary,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.15),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    // Calculate destination (center of parking zone)
                    final destination = _calculateZoneCenter(zone.boundaries);
                    
                    // Show navigation app selection dialog
                    NavigationService.showNavigationOptions(
                      context,
                      destination,
                      userLocation, // Pass user's current location as origin
                    );
                    
                    // Inform MapScreen that external navigation has started for this zone
                    onNavigateExternal(zone);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Navigate',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    // --- THIS IS THE CHANGE ---
                    onParkHere(zone); // Call the function!
                    // --- END OF CHANGE ---
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'I Parked Here',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Color _getAvailabilityColor(double probability) {
    if (probability > 0.7) {
      return Colors.green;
    } else if (probability > 0.3) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  // Calculate center point of a polygon (for navigation destination)
  LatLng _calculateZoneCenter(List<LatLng> boundaries) {
    if (boundaries.isEmpty) return const LatLng(0, 0);
    
    double lat = 0.0;
    double lng = 0.0;
    for (final point in boundaries) {
      lat += point.latitude;
      lng += point.longitude;
    }
    return LatLng(lat / boundaries.length, lng / boundaries.length);
  }
}