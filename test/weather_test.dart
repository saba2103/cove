import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/core/widgets/cove_pill_button.dart';
import 'package:cove/features/weather/weather_controller.dart';
import 'package:cove/features/weather/weather_model.dart';
import 'package:cove/features/weather/widgets/dashboard_weather_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeWeatherNotifier extends Notifier<WeatherData?>
    implements WeatherNotifier {
  final WeatherData? initial;

  FakeWeatherNotifier(this.initial);

  @override
  WeatherData? build() => initial;

  @override
  Future<void> refreshWeather({bool force = false}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WeatherData Model Tests', () {
    test('WeatherData serializes to/from JSON correctly', () {
      final now = DateTime(2026, 9, 12, 10, 30);
      final weather = WeatherData(
        cityName: 'Bengaluru',
        temperatureC: 24.5,
        apparentTemperatureC: 25.0,
        weatherCode: 2,
        isDay: true,
        condition: 'Partly Cloudy',
        updatedAt: now,
        latitude: 12.9716,
        longitude: 77.5946,
        isLiveGps: true,
      );

      final json = weather.toJson();
      expect(json['cityName'], 'Bengaluru');
      expect(json['temperatureC'], 24.5);
      expect(json['apparentTemperatureC'], 25.0);
      expect(json['weatherCode'], 2);
      expect(json['isDay'], true);
      expect(json['condition'], 'Partly Cloudy');
      expect(json['isLiveGps'], true);

      final restored = WeatherData.fromJson(json);
      expect(restored.cityName, 'Bengaluru');
      expect(restored.temperatureC, 24.5);
      expect(restored.condition, 'Partly Cloudy');
      expect(restored.latitude, 12.9716);
      expect(restored.longitude, 77.5946);
      expect(restored.isLiveGps, true);
    });

    test('WMO weather code maps to appropriate icons and descriptions', () {
      final (clearIconDay, clearDescDay) =
          WeatherData.getWeatherIconAndCondition(0, true);
      expect(clearIconDay, Icons.wb_sunny_rounded);
      expect(clearDescDay, 'Clear Sky');

      final (clearIconNight, clearDescNight) =
          WeatherData.getWeatherIconAndCondition(0, false);
      expect(clearIconNight, Icons.nightlight_round);
      expect(clearDescNight, 'Clear Night');

      final (rainIcon, rainDesc) =
          WeatherData.getWeatherIconAndCondition(63, true);
      expect(rainIcon, Icons.water_drop_rounded);
      expect(rainDesc, 'Rain');

      final (stormIcon, stormDesc) =
          WeatherData.getWeatherIconAndCondition(95, true);
      expect(stormIcon, Icons.thunderstorm_rounded);
      expect(stormDesc, 'Thunderstorm');
    });
  });

  group('Button Icon Color Equality Tests', () {
    testWidgets('CovePillButton forces icon color to match effective text color',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CoveTheme.lightTheme,
          home: Scaffold(
            body: Center(
              child: CovePillButton(
                label: 'Test Button',
                icon: const Icon(Icons.add, color: Colors.purple), // Explicit mismatch passed
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      // In light mode primary variant: textColor is 0xFFFFFFFF
      final iconFinder = find.byType(Icon);
      expect(iconFinder, findsOneWidget);
      final iconWidget = tester.widget<Icon>(iconFinder);

      final textFinder = find.text('Test Button');
      final textWidget = tester.widget<Text>(textFinder);

      expect(iconWidget.color, textWidget.style?.color);
      expect(iconWidget.color, const Color(0xFFFFFFFF));
    });

    testWidgets('CovePillButton in dark mode matches icon to dark text color',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CoveTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: CovePillButton(
                label: 'Dark Button',
                icon: const Icon(Icons.check),
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      final iconFinder = find.byType(Icon);
      final iconWidget = tester.widget<Icon>(iconFinder);
      final textFinder = find.text('Dark Button');
      final textWidget = tester.widget<Text>(textFinder);

      expect(iconWidget.color, textWidget.style?.color);
      expect(iconWidget.color, const Color(0xFF0B1F1E));
    });

    testWidgets('Disabled CovePillButton tints both icon and text with muted alpha',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CoveTheme.lightTheme,
          home: const Scaffold(
            body: Center(
              child: CovePillButton(
                label: 'Disabled',
                icon: Icon(Icons.lock),
                onPressed: null, // Disabled
              ),
            ),
          ),
        ),
      );

      final iconFinder = find.byType(Icon);
      final iconWidget = tester.widget<Icon>(iconFinder);
      final textFinder = find.text('Disabled');
      final textWidget = tester.widget<Text>(textFinder);

      expect(iconWidget.color, textWidget.style?.color);
      expect(
        iconWidget.color,
        const Color(0xFFFFFFFF).withValues(alpha: 0.38),
      );
    });
  });

  group('Dashboard Weather Badge Widget Tests', () {
    testWidgets('Displays city and temperature when weather data is present',
        (tester) async {
      final sampleWeather = WeatherData(
        cityName: 'Bengaluru',
        temperatureC: 25.4,
        apparentTemperatureC: 26.0,
        weatherCode: 1,
        isDay: true,
        condition: 'Mainly Clear',
        updatedAt: DateTime.now(),
        latitude: 12.9716,
        longitude: 77.5946,
        isLiveGps: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            weatherProvider.overrideWith(() => FakeWeatherNotifier(sampleWeather)),
          ],
          child: MaterialApp(
            theme: CoveTheme.lightTheme,
            home: const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(20),
                child: DashboardWeatherBadge(),
              ),
            ),
          ),
        ),
      );

      expect(find.text('25°'), findsOneWidget);
      expect(find.text('Bengaluru'), findsOneWidget);
      expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget);
    });

    testWidgets('Tapping DashboardWeatherBadge opens WeatherDetailSheet',
        (tester) async {
      final sampleWeather = WeatherData(
        cityName: 'Bengaluru',
        temperatureC: 25.0,
        apparentTemperatureC: 26.0,
        weatherCode: 0,
        isDay: true,
        condition: 'Clear Sky',
        updatedAt: DateTime.now(),
        latitude: 12.9716,
        longitude: 77.5946,
        isLiveGps: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            weatherProvider.overrideWith(() => FakeWeatherNotifier(sampleWeather)),
          ],
          child: MaterialApp(
            theme: CoveTheme.lightTheme,
            home: const Scaffold(
              body: DashboardWeatherBadge(),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(DashboardWeatherBadge));
      await tester.pumpAndSettle();

      expect(find.text('BENGALURU'), findsOneWidget);
      expect(find.text('Clear Sky'), findsOneWidget);
      expect(find.text('25°C'), findsOneWidget);
      expect(find.text('Feels like 26°C'), findsOneWidget);
      expect(find.text('Live GPS'), findsOneWidget);
      expect(find.text('Refresh Weather'), findsOneWidget);
    });
  });
}
