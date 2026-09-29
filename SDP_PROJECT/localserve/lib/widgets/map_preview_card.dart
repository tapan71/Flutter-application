import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'location_picker_screen.dart';

class MapPreviewCard extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String? address;
  final String title;
  final double? workerLatitude;
  final double? workerLongitude;
  final String? workerName;
  final VoidCallback? onEditLocation;
  final bool isInteractive;

  const MapPreviewCard({
    super.key,
    required this.latitude,
    required this.longitude,
    this.address,
    this.title = 'Service Location',
    this.workerLatitude,
    this.workerLongitude,
    this.workerName,
    this.onEditLocation,
    this.isInteractive = false,
  });

  String? get formattedDistance {
    if (workerLatitude != null && workerLongitude != null) {
      const distanceCalc = Distance();
      final km = distanceCalc.as(
        LengthUnit.Kilometer,
        LatLng(latitude, longitude),
        LatLng(workerLatitude!, workerLongitude!),
      );
      if (km < 1) {
        final meters = distanceCalc.as(
          LengthUnit.Meter,
          LatLng(latitude, longitude),
          LatLng(workerLatitude!, workerLongitude!),
        );
        return '${meters.toStringAsFixed(0)} m away';
      }
      return '${km.toStringAsFixed(1)} km away';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryPoint = LatLng(latitude, longitude);

    final markers = <Marker>[
      // Customer / Service Marker
      Marker(
        point: primaryPoint,
        width: 44,
        height: 44,
        alignment: Alignment.topCenter,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.red.shade700,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.location_on,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    ];

    // Worker marker if present
    if (workerLatitude != null && workerLongitude != null) {
      markers.add(
        Marker(
          point: LatLng(workerLatitude!, workerLongitude!),
          width: 44,
          height: 44,
          alignment: Alignment.topCenter,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.engineering,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.map_outlined, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                if (formattedDistance != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions_walk, size: 14, color: Colors.green.shade800),
                        const SizedBox(width: 4),
                        Text(
                          formattedDistance!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (onEditLocation != null)
                  IconButton(
                    icon: const Icon(Icons.edit_location_alt_outlined, size: 20),
                    tooltip: 'Change location on map',
                    onPressed: onEditLocation,
                  ),
              ],
            ),
          ),

          // Map View
          SizedBox(
            height: 180,
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: primaryPoint,
                    initialZoom: 14.5,
                    interactionOptions: InteractionOptions(
                      flags: isInteractive ? InteractiveFlag.all : InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.localserve.app',
                    ),
                    MarkerLayer(markers: markers),
                  ],
                ),

                // Tap overlay to view full map if not already interactive
                if (!isInteractive)
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LocationPickerScreen(
                                initialLatitude: latitude,
                                initialLongitude: longitude,
                                initialAddress: address,
                                title: title,
                              ),
                            ),
                          );
                        },
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.fullscreen, color: Colors.white, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'Expand Map',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Address Footer
          if (address != null && address!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.place, size: 18, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      address!,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
