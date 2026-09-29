import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/geocoding_service.dart';

class LocationPickerResult {
  final double latitude;
  final double longitude;
  final String address;

  const LocationPickerResult({
    required this.latitude,
    required this.longitude,
    required this.address,
  });
}

class LocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;
  final String title;
  final String confirmButtonText;

  const LocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
    this.title = 'Pick Location on Map',
    this.confirmButtonText = 'Confirm Location',
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late final MapController _mapController;
  late LatLng _selectedLocation;
  String _currentAddress = '';
  bool _isLoadingAddress = false;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final GeocodingService _geocodingService = GeocodingService();

  List<LocationSearchResult> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounceTimer;

  // Default fallback center (Ahmedabad / Western India region for demo)
  static const LatLng defaultLocation = LatLng(23.0225, 72.5714);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    if (widget.initialLatitude != null &&
        widget.initialLongitude != null &&
        widget.initialLatitude != 0.0 &&
        widget.initialLongitude != 0.0) {
      _selectedLocation = LatLng(widget.initialLatitude!, widget.initialLongitude!);
    } else {
      _selectedLocation = defaultLocation;
    }

    _currentAddress = widget.initialAddress ?? '';
    if (_currentAddress.isEmpty) {
      _reverseGeocodeLocation(_selectedLocation);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _reverseGeocodeLocation(LatLng point) async {
    setState(() {
      _isLoadingAddress = true;
    });

    final address = await _geocodingService.reverseGeocode(
      point.latitude,
      point.longitude,
    );

    if (mounted) {
      setState(() {
        _currentAddress = address;
        _isLoadingAddress = false;
      });
    }
  }

  void _onMapTapped(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selectedLocation = point;
      _searchResults = [];
    });
    _searchFocusNode.unfocus();
    _reverseGeocodeLocation(point);
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      setState(() {
        _isSearching = true;
      });

      final results = await _geocodingService.searchPlaces(query);

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  void _selectSearchResult(LocationSearchResult result) {
    final newPoint = LatLng(result.latitude, result.longitude);
    setState(() {
      _selectedLocation = newPoint;
      _currentAddress = result.shortAddress;
      _searchResults = [];
      _searchController.text = result.shortAddress;
    });
    _searchFocusNode.unfocus();
    _mapController.move(newPoint, 16.0);
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_selectedLocation, currentZoom + 1.0);
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_selectedLocation, currentZoom - 1.0);
  }

  void _recenter() {
    _mapController.move(_selectedLocation, 15.0);
  }

  void _confirmSelection() {
    Navigator.pop(
      context,
      LocationPickerResult(
        latitude: _selectedLocation.latitude,
        longitude: _selectedLocation.longitude,
        address: _currentAddress.isNotEmpty
            ? _currentAddress
            : 'Lat: ${_selectedLocation.latitude.toStringAsFixed(4)}, Lng: ${_selectedLocation.longitude.toStringAsFixed(4)}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        elevation: 2,
        actions: [
          IconButton(
            tooltip: 'Reset to My Pin',
            icon: const Icon(Icons.my_location),
            onPressed: _recenter,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. FlutterMap with OpenStreetMap tiles
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: 15.0,
              onTap: _onMapTapped,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.localserve.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedLocation,
                    width: 50,
                    height: 50,
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 2. Search Bar overlay with Nominatim Auto-suggestions
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(30),
                  shadowColor: Colors.black26,
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search city, street, or landmark...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchResults = [];
                                });
                              },
                            )
                          : (_isSearching
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Padding(
                                    padding: EdgeInsets.all(12),
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : null),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      filled: true,
                      fillColor: colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                // Search Results Dropdown
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _searchResults[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined, color: Colors.blueAccent),
                          title: Text(
                            item.shortAddress,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            item.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () => _selectSearchResult(item),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // 3. Zoom Controls
          Positioned(
            right: 16,
            bottom: 180,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoomInBtn',
                  backgroundColor: colorScheme.surface,
                  foregroundColor: colorScheme.onSurface,
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoomOutBtn',
                  backgroundColor: colorScheme.surface,
                  foregroundColor: colorScheme.onSurface,
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),

          // 4. Bottom Info Card & Confirmation Button
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.location_on,
                            color: colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selected Location',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (_isLoadingAddress)
                                Row(
                                  children: [
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Fetching address from OpenStreetMap...',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Text(
                                  _currentAddress.isNotEmpty
                                      ? _currentAddress
                                      : 'Tap on the map to choose a location',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 4),
                              Text(
                                'Coordinates: ${_selectedLocation.latitude.toStringAsFixed(4)}, ${_selectedLocation.longitude.toStringAsFixed(4)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(
                        widget.confirmButtonText,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _confirmSelection,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
