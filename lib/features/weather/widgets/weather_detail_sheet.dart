import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/cove_theme.dart';
import '../../../core/widgets/cove_card.dart';
import '../../../core/widgets/cove_pill_button.dart';
import '../weather_controller.dart';
import '../weather_model.dart';

class WeatherDetailSheet extends ConsumerWidget {
  final WeatherData weather;

  const WeatherDetailSheet({super.key, required this.weather});

  static void show(BuildContext context, WeatherData weather) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => WeatherDetailSheet(weather: weather),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typography = context.typography;
    final liveWeather = ref.watch(weatherProvider) ?? weather;

    final (iconData, conditionName) = WeatherData.getWeatherIconAndCondition(
      liveWeather.weatherCode,
      liveWeather.isDay,
    );

    final timeFormat = DateFormat('h:mm a');
    final updatedTimeStr = timeFormat.format(liveWeather.updatedAt);

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header: City and GPS status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      liveWeather.cityName.toUpperCase(),
                      style: typography.caption.copyWith(
                        letterSpacing: 1.0,
                        color: colors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      conditionName,
                      style: typography.title.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: liveWeather.isLiveGps
                      ? colors.accentPrimary.withValues(alpha: 0.12)
                      : colors.surfaceRow,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: liveWeather.isLiveGps
                        ? colors.accentPrimary.withValues(alpha: 0.3)
                        : colors.borderHairline,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      liveWeather.isLiveGps
                          ? Icons.my_location
                          : Icons.location_history,
                      size: 12,
                      color: liveWeather.isLiveGps
                          ? colors.accentPrimary
                          : colors.textMuted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      liveWeather.isLiveGps ? 'Live GPS' : 'Last Detected',
                      style: typography.caption.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: liveWeather.isLiveGps
                            ? colors.accentPrimary
                            : colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Main temperature card
          CoveCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: colors.accentPrimary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    iconData,
                    size: 28,
                    color: colors.accentPrimary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${liveWeather.temperatureC.round()}°C',
                        style: typography.headline.copyWith(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Feels like ${liveWeather.apparentTemperatureC.round()}°C',
                        style: typography.caption.copyWith(
                          color: colors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Updated time note
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.schedule, size: 13, color: colors.textMuted),
              const SizedBox(width: 5),
              Text(
                'Updated at $updatedTimeStr',
                style: typography.caption.copyWith(
                  color: colors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Action button
          CovePillButton(
            label: 'Refresh Weather',
            icon: const Icon(Icons.refresh, size: 16),
            onPressed: () async {
              await ref.read(weatherProvider.notifier).refreshWeather(force: true);
            },
            isFullWidth: true,
          ),
        ],
      ),
    );
  }
}
