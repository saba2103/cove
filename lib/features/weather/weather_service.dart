import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'weather_model.dart';

class WeatherService {
  final http.Client _client;

  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  /// Pure network IP-based location resolver.
  /// Strictly avoids any device GPS, sensors, or Android location permissions.
  Future<({double lat, double lon, String city})?> fetchIpLocation() async {
    // 1. Primary lookup via ip-api.com
    try {
      final response = await _client
          .get(Uri.parse('http://ip-api.com/json'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'success') {
          final lat = (data['lat'] as num).toDouble();
          final lon = (data['lon'] as num).toDouble();
          final city = data['city'] as String? ?? 'Your Location';
          return (lat: lat, lon: lon, city: city);
        }
      }
    } catch (e) {
      debugPrint('[WeatherService] IP location lookup failed (ip-api): $e');
    }

    // 2. Fallback lookup via ipapi.co (HTTPS)
    try {
      final response = await _client
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final lat = (data['latitude'] as num?)?.toDouble();
        final lon = (data['longitude'] as num?)?.toDouble();
        final city = data['city'] as String? ?? 'Your Location';
        if (lat != null && lon != null) {
          return (lat: lat, lon: lon, city: city);
        }
      }
    } catch (e) {
      debugPrint('[WeatherService] IP location lookup fallback failed (ipapi): $e');
    }

    return null;
  }

  /// Reverse geocode coordinates to a human-readable city or district name.
  Future<String> reverseGeocode(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&zoom=10',
      );
      final response = await _client.get(
        url,
        headers: {'User-Agent': 'CoveApp/1.0 (cove-companion)'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          final city = address['city'] as String? ??
              address['town'] as String? ??
              address['municipality'] as String? ??
              address['village'] as String? ??
              address['county'] as String? ??
              address['state_district'] as String?;
          if (city != null && city.trim().isNotEmpty) {
            return city.trim();
          }
        }
      }
    } catch (e) {
      debugPrint('[WeatherService] Reverse geocode error: $e');
    }
    return 'Your City';
  }

  /// Fetches weather from Open-Meteo for the given coordinates.
  Future<WeatherData?> fetchWeather({
    required double latitude,
    required double longitude,
    String? cityName,
    bool isLiveGps = true,
  }) async {
    try {
      String resolvedCity = cityName ?? '';
      if (resolvedCity.isEmpty) {
        resolvedCity = await reverseGeocode(latitude, longitude);
      }

      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?'
        'latitude=$latitude&longitude=$longitude&'
        'current=temperature_2m,apparent_temperature,is_day,weather_code&'
        'timezone=auto',
      );

      final response =
          await _client.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) {
        debugPrint(
            '[WeatherService] Open-Meteo returned status ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final current = data['current'] as Map<String, dynamic>?;
      if (current == null) return null;

      final temp = (current['temperature_2m'] as num?)?.toDouble() ?? 0.0;
      final apparentTemp =
          (current['apparent_temperature'] as num?)?.toDouble() ?? temp;
      final isDay = (current['is_day'] as num?)?.toInt() == 1;
      final weatherCode = (current['weather_code'] as num?)?.toInt() ?? 0;
      final (_, condition) =
          WeatherData.getWeatherIconAndCondition(weatherCode, isDay);

      return WeatherData(
        cityName: resolvedCity,
        temperatureC: temp,
        apparentTemperatureC: apparentTemp,
        weatherCode: weatherCode,
        isDay: isDay,
        condition: condition,
        updatedAt: DateTime.now(),
        latitude: latitude,
        longitude: longitude,
        isLiveGps: isLiveGps,
      );
    } catch (e) {
      debugPrint('[WeatherService] Error fetching weather: $e');
      return null;
    }
  }
}
