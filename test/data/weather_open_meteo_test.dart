import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/repositories/default_weather_repository.dart';
import 'package:slnews_mobile/core/domain/models/follow_models.dart';

void main() {
  const NewsLocation freetown = NewsLocation(
    id: 'city:freetown',
    label: 'Freetown',
    region: 'Sierra Leone',
    latitude: 8.48,
    longitude: -13.23,
  );

  test('maps an Open-Meteo current block to a snapshot', () {
    final snapshot = DefaultWeatherRepository.mapOpenMeteo(<String, dynamic>{
      'temperature_2m': 29.4,
      'weather_code': 0,
      'relative_humidity_2m': 82,
    }, freetown);
    expect(snapshot, isNotNull);
    expect(snapshot!.locationLabel, 'Freetown');
    expect(snapshot.temperatureC, 29);
    expect(snapshot.conditionLabel, 'Sunny');
    expect(snapshot.glyph, 'sun');
    expect(snapshot.humidityPercent, 82);
  });

  test('groups WMO codes into the app glyph vocabulary', () {
    expect(DefaultWeatherRepository.describeWeatherCode(3).$2, 'cloud');
    expect(DefaultWeatherRepository.describeWeatherCode(61).$2, 'rain');
    expect(DefaultWeatherRepository.describeWeatherCode(75).$2, 'snow');
    expect(DefaultWeatherRepository.describeWeatherCode(96).$2, 'storm');
    expect(DefaultWeatherRepository.describeWeatherCode(null), (
      'Cloudy',
      'cloud',
    ));
  });

  test('a payload without a temperature is not a weather snapshot', () {
    expect(
      DefaultWeatherRepository.mapOpenMeteo(<String, dynamic>{
        'weather_code': 0,
      }, freetown),
      isNull,
    );
  });
}
