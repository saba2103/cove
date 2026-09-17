import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'weather_model.dart';
import 'weather_service.dart';

class WeatherNotifier extends Notifier<WeatherData?> {
  static const _storage = FlutterSecureStorage();
  static const _cacheKey = 'cove_weather_cached_data_v1';
  final _service = WeatherService();
  bool _isRefreshing = false;

  @override
  WeatherData? build() {
    _loadAndRefresh();
    return null;
  }

  Future<void> _loadAndRefresh() async {
    // 1. Immediately load cached data so the UI renders instantly
    try {
      final cachedJsonStr = await _storage.read(key: _cacheKey);
      if (cachedJsonStr != null) {
        final map = jsonDecode(cachedJsonStr) as Map<String, dynamic>;
        state = WeatherData.fromJson(map);
      }
    } catch (e) {
      debugPrint('[WeatherNotifier] Cache read error: $e');
    }

    // 2. Refresh silently in background
    await refreshWeather();
  }

  /// Silently refresh weather data purely over standard HTTPS network.
  /// Strictly avoids any device GPS, sensors, or Android location permissions.
  Future<void> refreshWeather({bool force = false}) async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      // Step A: If not forced and we have a valid previously resolved location, fetch fresh weather for it
      if (!force && state != null && state!.latitude != 0.0 && state!.longitude != 0.0) {
        final cachedWeather = await _service.fetchWeather(
          latitude: state!.latitude,
          longitude: state!.longitude,
          cityName: state!.cityName,
          isLiveGps: true,
        );

        if (cachedWeather != null) {
          state = cachedWeather;
          await _saveToStorage(cachedWeather);
          _isRefreshing = false;
          return;
        }
      }

      // Step B: Resolve location via network IP geolocation (zero device sensors/GPS)
      final ipLoc = await _service.fetchIpLocation();
      if (ipLoc != null) {
        final ipWeather = await _service.fetchWeather(
          latitude: ipLoc.lat,
          longitude: ipLoc.lon,
          cityName: ipLoc.city,
          isLiveGps: true,
        );
        if (ipWeather != null) {
          state = ipWeather;
          await _saveToStorage(ipWeather);
          _isRefreshing = false;
          return;
        }
      }

      // Step C: Fallback to existing state coordinates if IP lookup was unavailable
      if (state != null && state!.latitude != 0.0 && state!.longitude != 0.0) {
        final cachedWeather = await _service.fetchWeather(
          latitude: state!.latitude,
          longitude: state!.longitude,
          cityName: state!.cityName,
          isLiveGps: true,
        );

        if (cachedWeather != null) {
          state = cachedWeather;
          await _saveToStorage(cachedWeather);
        }
      }
    } catch (e) {
      debugPrint('[WeatherNotifier] Error refreshing weather: $e');
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _saveToStorage(WeatherData data) async {
    try {
      await _storage.write(
        key: _cacheKey,
        value: jsonEncode(data.toJson()),
      );
    } catch (e) {
      debugPrint('[WeatherNotifier] Cache write error: $e');
    }
  }
}

final weatherProvider =
    NotifierProvider<WeatherNotifier, WeatherData?>(WeatherNotifier.new);
