import 'package:fl_chart/fl_chart.dart';

class ZoneDetails {
  final String avgParkingTime;
  final String lastUpdated;
  final List<FlSpot> probabilityHistory;

  ZoneDetails({
    required this.avgParkingTime,
    required this.lastUpdated,
    required this.probabilityHistory,
  });
}
