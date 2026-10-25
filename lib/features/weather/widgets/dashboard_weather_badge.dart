import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/cove_tokens.dart';
import '../weather_controller.dart';
import '../weather_model.dart';
import 'weather_detail_sheet.dart';

class DashboardWeatherBadge extends ConsumerWidget {
  const DashboardWeatherBadge({super.key});

  static const double _kCloudIconSize =
      14.0; // (literal) 14dp fallback weather badge cloud icon
  static const double _kBorderWidth =
      1.0; // (literal) 1dp weather badge hairline border width
  static const double _kWeatherIconSize =
      18.0; // (literal) 18dp active weather badge condition icon
  static const double _kRowGap =
      1.0; // (literal) 1dp vertical gap between temperature and city name
  static const double _kMaxCityWidth =
      80.0; // (literal) 80dp max width for city name truncation

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weather = ref.watch(weatherProvider);
    final cv = context.cv;

    if (weather == null) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: CoveSpace.sm,
          vertical: CoveSpace.sm,
        ),
        decoration: BoxDecoration(
          color: cv.surfaceRow.withValues(alpha: 0.6),
          borderRadius: const BorderRadius.all(
            Radius.circular(CoveRadius.inline),
          ),
          border: Border.all(color: cv.lineHairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_outlined,
              size: _kCloudIconSize,
              color: cv.textSecondary,
            ),
            const SizedBox(width: CoveSpace.xs),
            Text(
              'Weather',
              style: CoveType.barLabel.copyWith(
                color: cv.textSecondary,
                fontWeight: FontWeight.w400,
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
        borderRadius: const BorderRadius.all(
          Radius.circular(CoveRadius.inline),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: CoveSpace.md,
            vertical: CoveSpace.sm,
          ),
          decoration: BoxDecoration(
            color: cv.surfaceRow,
            borderRadius: const BorderRadius.all(
              Radius.circular(CoveRadius.inline),
            ),
            border: Border.all(color: cv.lineHairline, width: _kBorderWidth),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(iconData, size: _kWeatherIconSize, color: cv.accentFill),
              const SizedBox(width: CoveSpace.sm),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${weather.temperatureC.round()}°',
                        style: CoveType.readout.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cv.textPrimary,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'C',
                        style: CoveType.barLabel.copyWith(
                          color: cv.textSecondary,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: _kRowGap),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _kMaxCityWidth),
                    child: Text(
                      weather.cityName,
                      style: CoveType.barLabel.copyWith(
                        color: cv.textSecondary,
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
