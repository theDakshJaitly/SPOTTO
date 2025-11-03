import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/parking_zone.dart';

class TappablePolygonLayer extends StatelessWidget {
  final List<ParkingZone> zones;
  final Function(ParkingZone) onZoneTap;
  final Color Function(double) getZoneColor;

  const TappablePolygonLayer({
    super.key,
    required this.zones,
    required this.onZoneTap,
    required this.getZoneColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: zones.map((zone) {
        return GestureDetector(
          onTap: () => onZoneTap(zone),
          child: Container(),
        );
      }).toList(),
    );
  }
}
