import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/cove_tokens.dart';
import '../../../core/widgets/cove_card.dart';
import '../../../core/widgets/cove_pill_button.dart';
import '../weather_controller.dart';
import '../weather_model.dart';

class WeatherDetailSheet extends ConsumerWidget {
  final WeatherData weather;

  const WeatherDetailSheet({super.key, required this.weather});

  static const double _kTopPadding =
      16.0; // (literal) 16dp weather detail sheet top inset, icon gap, and refresh icon size
  static const double _kHandleWidth =
      36.0; // (literal) 36dp sheet drag handle width
  static const double _kHandleRadius =
      2.0; // (literal) 2dp sheet drag handle pill corner radius
  static const double _kWeatherCircleSize =
      54.0; // (literal) 54dp weather condition icon circle diameter
  static const double _kScheduleIconSize =
      13.0; // (literal) 13dp updated-at clock icon glyph

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
    final cv = context.cv;
    final liveWeather = ref.watch(weatherProvider) ?? weather;

    final (iconData, conditionName) = WeatherData.getWeatherIconAndCondition(
      liveWeather.weatherCode,
      liveWeather.isDay,
    );

    final timeFormat = DateFormat('h:mm a');
    final updatedTimeStr = timeFormat.format(liveWeather.updatedAt);

    return Container(
      decoration: BoxDecoration(
        color: cv.surfaceSheet,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(CoveRadius.hero),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        CoveSpace.lg,
        _kTopPadding,
        CoveSpace.lg,
        MediaQuery.of(context).padding.bottom + CoveSpace.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: _kHandleWidth,
              height: CoveSpace.xs,
              decoration: BoxDecoration(
                color: cv.textSecondary.withValues(alpha: 0.3),
                borderRadius: const BorderRadius.all(
                  Radius.circular(_kHandleRadius),
                ),
              ),
            ),
          ),
          const SizedBox(height: CoveSpace.gutter),

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
                      style: CoveType.capsCard.copyWith(
                        color: cv.textSecondary,
                      ),
                    ),
                    const SizedBox(height: CoveSpace.xs),
                    Text(
                      conditionName,
                      style: CoveType.slipTitle.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cv.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: CoveSpace.sm,
                  vertical: CoveSpace.xs,
                ),
                decoration: BoxDecoration(
                  color: liveWeather.isLiveGps ? cv.accentWash : cv.surfaceRow,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(CoveRadius.pill),
                  ),
                  border: Border.all(
                    color: liveWeather.isLiveGps
                        ? cv.accentFill.withValues(alpha: 0.3)
                        : cv.lineHairline,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      liveWeather.isLiveGps
                          ? Icons.my_location
                          : Icons.location_history,
                      size: CoveSpace.md,
                      color: liveWeather.isLiveGps
                          ? cv.accentFill
                          : cv.textSecondary,
                    ),
                    const SizedBox(width: CoveSpace.xs),
                    Text(
                      liveWeather.isLiveGps ? 'Live GPS' : 'Last Detected',
                      style: CoveType.barLabel.copyWith(
                        fontWeight: FontWeight.w500,
                        color: liveWeather.isLiveGps
                            ? cv.accentText
                            : cv.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: CoveSpace.lg),

          // Main temperature card
          CoveCard(
            padding: const EdgeInsets.symmetric(
              horizontal: CoveSpace.gutter,
              vertical: CoveSpace.gutter,
            ),
            child: Row(
              children: [
                Container(
                  width: _kWeatherCircleSize,
                  height: _kWeatherCircleSize,
                  decoration: BoxDecoration(
                    color: cv.accentWash,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    iconData,
                    size: CoveSize.avatarRow,
                    color: cv.accentFill,
                  ),
                ),
                const SizedBox(width: _kTopPadding),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${liveWeather.temperatureC.round()}°C',
                        style: CoveType.slipFigure.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cv.textPrimary,
                        ),
                      ),
                      Text(
                        'Feels like ${liveWeather.apparentTemperatureC.round()}°C',
                        style: CoveType.readout.copyWith(
                          color: cv.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: _kTopPadding),

          // Updated time note
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.schedule,
                size: _kScheduleIconSize,
                color: cv.textSecondary,
              ),
              const SizedBox(width: CoveSpace.xs),
              Text(
                'Updated at $updatedTimeStr',
                style: CoveType.rowSub.copyWith(color: cv.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: CoveSpace.gutter),

          // Action button
          CovePillButton(
            label: 'Refresh Weather',
            icon: const Icon(Icons.refresh, size: _kTopPadding),
            onPressed: () async {
              await ref
                  .read(weatherProvider.notifier)
                  .refreshWeather(force: true);
            },
            isFullWidth: true,
          ),
        ],
      ),
    );
  }
}
