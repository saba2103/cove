import 'package:flutter/material.dart';

class WeatherData {
  final String cityName;
  final double temperatureC;
  final double apparentTemperatureC;
  final int weatherCode;
  final bool isDay;
  final String condition;
  final DateTime updatedAt;
  final double latitude;
  final double longitude;
  final bool isLiveGps;

  const WeatherData({
    required this.cityName,
    required this.temperatureC,
    required this.apparentTemperatureC,
    required this.weatherCode,
    required this.isDay,
    required this.condition,
    required this.updatedAt,
    required this.latitude,
    required this.longitude,
    this.isLiveGps = true,
  });

  WeatherData copyWith({
    String? cityName,
    double? temperatureC,
    double? apparentTemperatureC,
    int? weatherCode,
    bool? isDay,
    String? condition,
    DateTime? updatedAt,
    double? latitude,
    double? longitude,
    bool? isLiveGps,
  }) {
    return WeatherData(
      cityName: cityName ?? this.cityName,
      temperatureC: temperatureC ?? this.temperatureC,
      apparentTemperatureC: apparentTemperatureC ?? this.apparentTemperatureC,
      weatherCode: weatherCode ?? this.weatherCode,
      isDay: isDay ?? this.isDay,
      condition: condition ?? this.condition,
      updatedAt: updatedAt ?? this.updatedAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isLiveGps: isLiveGps ?? this.isLiveGps,
    );
  }

  Map<String, dynamic> toJson() => {
        'cityName': cityName,
        'temperatureC': temperatureC,
        'apparentTemperatureC': apparentTemperatureC,
        'weatherCode': weatherCode,
        'isDay': isDay,
        'condition': condition,
        'updatedAt': updatedAt.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'isLiveGps': isLiveGps,
      };

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      cityName: json['cityName'] as String? ?? 'Unknown',
      temperatureC: (json['temperatureC'] as num?)?.toDouble() ?? 0.0,
      apparentTemperatureC:
          (json['apparentTemperatureC'] as num?)?.toDouble() ?? 0.0,
      weatherCode: (json['weatherCode'] as num?)?.toInt() ?? 0,
      isDay: json['isDay'] as bool? ?? true,
      condition: json['condition'] as String? ?? 'Clear',
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      isLiveGps: json['isLiveGps'] as bool? ?? false,
    );
  }

  static (IconData, String) getWeatherIconAndCondition(
      int code, bool isDay) {
    switch (code) {
      case 0:
        return isDay
            ? (Icons.wb_sunny_rounded, 'Clear Sky')
            : (Icons.nightlight_round, 'Clear Night');
      case 1:
        return isDay
            ? (Icons.wb_sunny_outlined, 'Mainly Clear')
            : (Icons.nightlight_outlined, 'Mainly Clear');
      case 2:
        return isDay
            ? (Icons.wb_cloudy_outlined, 'Partly Cloudy')
            : (Icons.cloud_outlined, 'Partly Cloudy');
      case 3:
        return (Icons.cloud_rounded, 'Overcast');
      case 45:
      case 48:
        return (Icons.foggy, 'Foggy');
      case 51:
      case 53:
      case 55:
        return (Icons.grain_rounded, 'Drizzle');
      case 56:
      case 57:
        return (Icons.ac_unit_rounded, 'Freezing Drizzle');
      case 61:
        return (Icons.water_drop_outlined, 'Light Rain');
      case 63:
        return (Icons.water_drop_rounded, 'Rain');
      case 65:
        return (Icons.beach_access_rounded, 'Heavy Rain');
      case 66:
      case 67:
        return (Icons.ac_unit_rounded, 'Freezing Rain');
      case 71:
      case 73:
      case 75:
      case 77:
        return (Icons.ac_unit_rounded, 'Snow');
      case 80:
      case 81:
      case 82:
        return (Icons.shower_rounded, 'Rain Showers');
      case 85:
      case 86:
        return (Icons.ac_unit_rounded, 'Snow Showers');
      case 95:
        return (Icons.thunderstorm_rounded, 'Thunderstorm');
      case 96:
      case 99:
        return (Icons.thunderstorm_rounded, 'Severe Storm');
      default:
        return isDay
            ? (Icons.wb_sunny_rounded, 'Clear')
            : (Icons.nightlight_round, 'Clear');
    }
  }
}
