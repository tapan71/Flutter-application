import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
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

class _LocationPickerScreenState extends State<LocationPickerScreen>
    with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late LatLng _selectedLocation;
  LatLng? _liveUserLocation;
  bool _isLocatingLive = false;
  bool _hasCenteredOnLive = false;
  bool _isLiveGps = false;

  String? _statusBannerText;
  VoidCallback? _statusBannerAction;
  String _statusBannerActionLabel = '';

  String _currentAddress = '';
  bool _isLoadingAddress = false;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final GeocodingService _geocodingService = GeocodingService();

  List<LocationSearchResult> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounceTimer;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // Default fallback center (Ahmedabad / Western India region for initial fallback)
  static const LatLng defaultLocation = LatLng(23.0225, 72.5714);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 18.0, end: 42.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    final bool hasExplicitCoord = widget.initialLatitude != null &&
        widget.initialLongitude != null &&
        widget.initialLatitude != 0.0 &&
        widget.initialLongitude != 0.0 &&
        !(widget.initialLatitude == defaultLocation.latitude &&
            widget.initialLongitude == defaultLocation.longitude);

    if (hasExplicitCoord) {
      _selectedLocation = LatLng(widget.initialLatitude!, widget.initialLongitude!);
    } else {
      _selectedLocation = defaultLocation;
    }

    _currentAddress = widget.initialAddress ?? '';
    if (_currentAddress.isEmpty && hasExplicitCoord) {
      _reverseGeocodeLocation(_selectedLocation);
    }

    // Automatically locate user via high-accuracy live GPS on map load!
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchLiveLocation(isAutoCenter: !hasExplicitCoord);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveLocation({
    bool isAutoCenter = false,
    bool showFeedbackToast = false,
  }) async {
    if (!mounted) return;

    setState(() {
      _isLocatingLive = true;
      _statusBannerText = null;
    });

    try {
      // 1. Check if device location service is enabled
      final isServiceOn = await _geocodingService.isLocationServiceEnabled();
      if (!isServiceOn) {
        if (mounted) {
          setState(() {
            _isLocatingLive = false;
            _statusBannerText = 'Device location is turned off. Turn on GPS for live location.';
            _statusBannerActionLabel = 'Turn On';
            _statusBannerAction = () async {
              await _geocodingService.openLocationSettings();
            };
          });
          if (showFeedbackToast) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Please turn on Location / GPS in device settings.'),
                action: SnackBarAction(
                  label: 'Settings',
                  onPressed: () => _geocodingService.openLocationSettings(),
                ),
              ),
            );
          }
        }
        return;
      }

      // 2. Check permission
      LocationPermission perm = await _geocodingService.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await _geocodingService.requestPermission();
      }

      if (perm == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isLocatingLive = false;
            _statusBannerText = 'Location permission is denied. Enable it in App Settings.';
            _statusBannerActionLabel = 'Settings';
            _statusBannerAction = () async {
              await _geocodingService.openAppSettings();
            };
          });
          if (showFeedbackToast) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Location permission is required for live GPS.'),
                action: SnackBarAction(
                  label: 'Settings',
                  onPressed: () => _geocodingService.openAppSettings(),
                ),
              ),
            );
          }
        }
        return;
      }

      // 3. Acquire live location
      final locationResult = await _geocodingService.detectCurrentLocation();

      if (!mounted) return;

      if (locationResult != null) {
        final livePoint = LatLng(locationResult.latitude, locationResult.longitude);
        final liveAddr = locationResult.shortAddress.isNotEmpty
            ? locationResult.shortAddress
            : locationResult.displayName;

        setState(() {
          _liveUserLocation = livePoint;
          _isLiveGps = locationResult.isLiveGps;
          _isLocatingLive = false;
          _statusBannerText = null;

          if (isAutoCenter || !_hasCenteredOnLive) {
            _hasCenteredOnLive = true;
            _selectedLocation = livePoint;
            _currentAddress = liveAddr;
          }
        });

        if (isAutoCenter || showFeedbackToast) {
          _mapController.move(livePoint, 16.5);
          if (showFeedbackToast) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.gps_fixed, color: Colors.greenAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        locationResult.isLiveGps
                            ? '📍 Live GPS detected: $liveAddr'
                            : '📍 Location detected: $liveAddr',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } else {
        setState(() {
          _isLocatingLive = false;
        });
        if (showFeedbackToast) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not detect live location. You can search or tap on map.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error getting live location in map picker: $e');
      if (mounted) {
        setState(() {
          _isLocatingLive = false;
        });
      }
    }
  }

  void _snapToLiveLocation() {
    if (_liveUserLocation != null) {
      setState(() {
        _selectedLocation = _liveUserLocation!;
      });
      _mapController.move(_liveUserLocation!, 16.5);
      _reverseGeocodeLocation(_liveUserLocation!);
    } else {
      _fetchLiveLocation(isAutoCenter: true, showFeedbackToast: true);
    }
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
    _mapController.move(_selectedLocation, 16.0);
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
            tooltip: 'My Live Location (GPS)',
            icon: _isLocatingLive
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.gps_fixed),
            onPressed: () => _fetchLiveLocation(isAutoCenter: true, showFeedbackToast: true),
          ),
          IconButton(
            tooltip: 'Center on Pin',
            icon: const Icon(Icons.pin_drop_outlined),
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
              initialZoom: 16.0,
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
                  // Real-time "You Are Here" blue live GPS marker
                  if (_liveUserLocation != null)
                    Marker(
                      point: _liveUserLocation!,
                      width: 60,
                      height: 60,
                      alignment: Alignment.center,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Radar pulse ring
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Container(
                                width: _pulseAnimation.value,
                                height: _pulseAnimation.value,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                                ),
                              );
                            },
                          ),
                          // Outer white circle
                          Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black38,
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                          // Inner blue dot
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Selected Pin Marker
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

          // 2. Search Bar overlay with Nominatim Auto-suggestions & Status Banner
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

                // Device Location Status Banner (e.g. GPS disabled / Permission denied)
                if (_statusBannerText != null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 20, color: Colors.amber.shade900),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _statusBannerText!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (_statusBannerAction != null)
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: _statusBannerAction,
                            child: Text(
                              _statusBannerActionLabel,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                      ],
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

          // 3. Floating Action Controls: "My Live Location" & Zoom
          Positioned(
            right: 16,
            bottom: 230,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Prominent "My Live Location" Button
                FloatingActionButton.extended(
                  heroTag: 'myLiveLocationFab',
                  elevation: 5,
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  icon: _isLocatingLive
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.my_location, size: 20),
                  label: Text(
                    _isLocatingLive ? 'Locating...' : 'My Live Location',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () => _fetchLiveLocation(isAutoCenter: true, showFeedbackToast: true),
                ),
                const SizedBox(height: 12),
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
                              Row(
                                children: [
                                  Text(
                                    'Coordinates: ${_selectedLocation.latitude.toStringAsFixed(4)}, ${_selectedLocation.longitude.toStringAsFixed(4)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  if (_isLiveGps &&
                                      _liveUserLocation != null &&
                                      (_selectedLocation.latitude == _liveUserLocation!.latitude &&
                                          _selectedLocation.longitude == _liveUserLocation!.longitude)) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check_circle, size: 12, color: Color(0xFF16A34A)),
                                          SizedBox(width: 3),
                                          Text(
                                            'Live GPS',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF16A34A),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Quick Snap-to-Live-Location Button (when user moves pin away from their current spot)
                    if (_liveUserLocation != null &&
                        (_selectedLocation.latitude != _liveUserLocation!.latitude ||
                            _selectedLocation.longitude != _liveUserLocation!.longitude)) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          side: const BorderSide(color: Color(0xFF93C5FD)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.my_location, size: 16, color: Color(0xFF2563EB)),
                        label: const Text(
                          'Snap pin to My Live Location',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        onPressed: _snapToLiveLocation,
                      ),
                    ],

                    const SizedBox(height: 14),
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
