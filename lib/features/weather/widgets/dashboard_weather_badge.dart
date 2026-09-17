import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/cove_theme.dart';
import '../weather_controller.dart';
import '../weather_model.dart';
import 'weather_detail_sheet.dart';

class DashboardWeatherBadge extends ConsumerWidget {
  const DashboardWeatherBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weather = ref.watch(weatherProvider);
    final colors = context.colors;
    final typography = context.typography;

    if (weather == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colors.surfaceRow.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.borderHairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_outlined, size: 14, color: colors.textMuted),
            const SizedBox(width: 5),
            Text(
              'Weather',
              style: typography.caption.copyWith(
                fontSize: 11,
                color: colors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    final (iconData, _) = WeatherData.getWeatherIconAndCondition(
      weather.weatherCode,
      weather.isDay,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => WeatherDetailSheet.show(context, weather),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: colors.surfaceRow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.borderHairline,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                iconData,
                size: 18,
                color: colors.accentPrimary,
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${weather.temperatureC.round()}°',
                        style: typography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'C',
                        style: typography.caption.copyWith(
                          fontSize: 9,
                          color: colors.textMuted,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 80),
                    child: Text(
                      weather.cityName,
                      style: typography.caption.copyWith(
                        fontSize: 10,
                        color: colors.textMuted,
                        fontWeight: FontWeight.w500,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
