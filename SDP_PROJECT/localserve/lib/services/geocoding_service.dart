import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LocationSearchResult {
  final double latitude;
  final double longitude;
  final String displayName;
  final String? road;
  final String? suburb;
  final String? city;
  final String? state;
  final String? postcode;

  const LocationSearchResult({
    required this.latitude,
    required this.longitude,
    required this.displayName,
    this.road,
    this.suburb,
    this.city,
    this.state,
    this.postcode,
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

  /// Automatically detect user's current approximate location via IP and reverse geocode with Nominatim
  Future<LocationSearchResult?> detectCurrentLocation() async {
    try {
      final response = await http
          .get(Uri.parse('http://ip-api.com/json/'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['status'] == 'success') {
          final lat = (data['lat'] as num).toDouble();
          final lon = (data['lon'] as num).toDouble();
          final address = await reverseGeocode(lat, lon);

          return LocationSearchResult(
            latitude: lat,
            longitude: lon,
            displayName: address,
            city: data['city']?.toString(),
            state: data['regionName']?.toString(),
            postcode: data['zip']?.toString(),
          );
        }
      }
    } catch (e) {
      debugPrint('Error detecting current location via IP: $e');
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
