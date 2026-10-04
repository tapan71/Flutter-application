import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class LocationSearchResult {
  final double latitude;
  final double longitude;
  final String displayName;
  final String? road;
  final String? suburb;
  final String? city;
  final String? state;
  final String? postcode;
  final bool isLiveGps;

  const LocationSearchResult({
    required this.latitude,
    required this.longitude,
    required this.displayName,
    this.road,
    this.suburb,
    this.city,
    this.state,
    this.postcode,
    this.isLiveGps = false,
  });

  String get shortAddress {
    final parts = <String>[];
    if (road != null && road!.isNotEmpty) parts.add(road!);
    if (suburb != null && suburb!.isNotEmpty && suburb != road) parts.add(suburb!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (state != null && state!.isNotEmpty) parts.add(state!);

    if (parts.isNotEmpty) {
      return parts.join(', ');
    }
    return displayName;
  }

  factory LocationSearchResult.fromJson(Map<String, dynamic> json) {
    final address = json['address'] as Map<String, dynamic>? ?? {};

    final road = address['road'] ?? address['pedestrian'] ?? address['street'];
    final suburb = address['suburb'] ?? address['neighbourhood'] ?? address['residential'];
    final city = address['city'] ?? address['town'] ?? address['village'] ?? address['county'];
    final state = address['state'];
    final postcode = address['postcode'];

    return LocationSearchResult(
      latitude: double.tryParse(json['lat']?.toString() ?? '0') ?? 0.0,
      longitude: double.tryParse(json['lon']?.toString() ?? '0') ?? 0.0,
      displayName: json['display_name'] ?? 'Selected Location',
      road: road?.toString(),
      suburb: suburb?.toString(),
      city: city?.toString(),
      state: state?.toString(),
      postcode: postcode?.toString(),
    );
  }
}

class GeocodingService {
  static final GeocodingService _instance = GeocodingService._internal();
  factory GeocodingService() => _instance;
  GeocodingService._internal();

  /// Mock location result for automated testing environments
  static LocationSearchResult? mockLocationForTesting;

  // In-memory cache for reverse geocoding to respect OSM Nominatim usage policy
  final Map<String, String> _reverseCache = {};
  DateTime _lastRequestTime = DateTime.fromMillisecondsSinceEpoch(0);

  static const String _userAgent =
      'LocalServeApp/1.0 (Flutter SDP Project; contact: localserve@example.com)';

  /// Rate-limiting helper to avoid hitting Nominatim faster than 1 req/sec
  Future<void> _throttle() async {
    final now = DateTime.now();
    final elapsed = now.difference(_lastRequestTime);
    if (elapsed.inMilliseconds < 1000) {
      final waitMs = 1000 - elapsed.inMilliseconds;
      await Future.delayed(Duration(milliseconds: waitMs));
    }
    _lastRequestTime = DateTime.now();
  }

  /// Forward geocoding: Search places/addresses by query text using Nominatim
  Future<List<LocationSearchResult>> searchPlaces(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return [];

    try {
      await _throttle();
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(trimmed)}&format=jsonv2&addressdetails=1&limit=6',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': _userAgent,
          'Accept-Language': 'en',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> list = json.decode(response.body);
        return list
            .map((item) => LocationSearchResult.fromJson(item as Map<String, dynamic>))
            .where((r) => r.latitude != 0.0 && r.longitude != 0.0)
            .toList();
      } else {
        debugPrint('Nominatim search failed with status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error searching Nominatim: $e');
    }
    return [];
  }

  /// Reverse geocoding: Get human-readable address from coordinates
  Future<String> reverseGeocode(double latitude, double longitude) async {
    // Round to 4 decimal places (~11m precision) for cache key
    final cacheKey = '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}';
    if (_reverseCache.containsKey(cacheKey)) {
      return _reverseCache[cacheKey]!;
    }

    try {
      await _throttle();
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$latitude&lon=$longitude&format=jsonv2&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': _userAgent,
          'Accept-Language': 'en',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final result = LocationSearchResult.fromJson(data);
        final address = result.shortAddress.isNotEmpty
            ? result.shortAddress
            : result.displayName;

        _reverseCache[cacheKey] = address;
        return address;
      }
    } catch (e) {
      debugPrint('Error in Nominatim reverse geocode: $e');
    }

    // Fallback format
    final fallback = 'Location (${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)})';
    _reverseCache[cacheKey] = fallback;
    return fallback;
  }

  /// Real hardware GPS & device location detector.
  /// 1. Checks if location services are enabled on device.
  /// 2. Checks and requests permission if needed.
  /// 3. Obtains exact high-accuracy GPS position.
  /// 4. Reverse-geocodes with Nominatim for the street/city address.
  /// 5. Falls back to secure HTTPS IP lookup if GPS sensor is unavailable.
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
  }

  Future<LocationPermission> checkPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (_) {
      return LocationPermission.denied;
    }
  }

  Future<LocationPermission> requestPermission() async {
    try {
      return await Geolocator.requestPermission();
    } catch (_) {
      return LocationPermission.denied;
    }
  }

  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }

  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  Future<LocationSearchResult?> detectCurrentLocation({bool requestPermission = true}) async {
    if (mockLocationForTesting != null) {
      return mockLocationForTesting;
    }

    // 1. Try real device hardware GPS via Geolocator
    try {
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location service disabled on device');
      } else {
        LocationPermission permission = await checkPermission();
        if (permission == LocationPermission.denied && requestPermission) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          Position? position;
          // Step A: Check last known position for quick startup
          try {
            position = await Geolocator.getLastKnownPosition();
          } catch (e) {
            debugPrint('Failed to get last known position: $e');
          }

          // Step B: Query high accuracy position
          try {
            final highAccPos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.best,
                timeLimit: Duration(seconds: 7),
              ),
            );
            position = highAccPos;
          } catch (e) {
            debugPrint('Best accuracy GPS timed out or failed: $e, trying medium accuracy');
            try {
              final medAccPos = await Geolocator.getCurrentPosition(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.medium,
                  timeLimit: Duration(seconds: 5),
                ),
              );
              position = medAccPos;
            } catch (e2) {
              debugPrint('Medium accuracy GPS also failed: $e2');
            }
          }

          if (position != null) {
            final address = await reverseGeocode(position.latitude, position.longitude);
            return LocationSearchResult(
              latitude: position.latitude,
              longitude: position.longitude,
              displayName: address,
              isLiveGps: true,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Geolocator live location detection error: $e');
    }

    // 2. Secondary fallback: HTTPS IP geolocation (ipapi.co)
    try {
      final response = await http
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['latitude'] != null && data['longitude'] != null) {
          final lat = (data['latitude'] as num).toDouble();
          final lon = (data['longitude'] as num).toDouble();
          final address = await reverseGeocode(lat, lon);

          return LocationSearchResult(
            latitude: lat,
            longitude: lon,
            displayName: address,
            city: data['city']?.toString(),
            state: data['region']?.toString(),
            postcode: data['postal']?.toString(),
            isLiveGps: false,
          );
        }
      }
    } catch (e) {
      debugPrint('Error detecting fallback location via ipapi: $e');
    }

    // 3. Tertiary fallback: HTTPS IP geolocation (ipwho.is)
    try {
      final response = await http
          .get(Uri.parse('https://ipwho.is/'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['latitude'] != null && data['longitude'] != null) {
          final lat = (data['latitude'] as num).toDouble();
          final lon = (data['longitude'] as num).toDouble();
          final address = await reverseGeocode(lat, lon);

          return LocationSearchResult(
            latitude: lat,
            longitude: lon,
            displayName: address,
            city: data['city']?.toString(),
            state: data['region']?.toString(),
            postcode: data['postal']?.toString(),
            isLiveGps: false,
          );
        }
      }
    } catch (e) {
      debugPrint('Error detecting fallback location via ipwho.is: $e');
    }

    return null;
  }

  /// Convenience helper to forward geocode a text address to coordinates
  Future<LocationSearchResult?> forwardGeocode(String query) async {
    final results = await searchPlaces(query);
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }
}

