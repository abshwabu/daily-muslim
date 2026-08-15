import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';

class CityLocation {
  final String name;
  final String country;
  final double latitude;
  final double longitude;

  const CityLocation({
    required this.name,
    required this.country,
    required this.latitude,
    required this.longitude,
  });

  String get fullName => '$name, $country';
}

class PrayerService {
  static const List<CityLocation> cities = [
    CityLocation(name: 'Addis Ababa', country: 'Ethiopia', latitude: 9.0300, longitude: 38.7400),
    CityLocation(name: 'Mecca', country: 'Saudi Arabia', latitude: 21.4225, longitude: 39.8262),
    CityLocation(name: 'Medina', country: 'Saudi Arabia', latitude: 24.4672, longitude: 39.6112),
    CityLocation(name: 'Riyadh', country: 'Saudi Arabia', latitude: 24.7136, longitude: 46.6753),
    CityLocation(name: 'Cairo', country: 'Egypt', latitude: 30.0444, longitude: 31.2357),
    CityLocation(name: 'Istanbul', country: 'Turkey', latitude: 41.0082, longitude: 28.9784),
    CityLocation(name: 'Dubai', country: 'UAE', latitude: 25.2048, longitude: 55.2708),
    CityLocation(name: 'Abu Dhabi', country: 'UAE', latitude: 24.4539, longitude: 54.3773),
    CityLocation(name: 'London', country: 'United Kingdom', latitude: 51.5074, longitude: -0.1278),
    CityLocation(name: 'New York', country: 'United States', latitude: 40.7128, longitude: -74.0060),
    CityLocation(name: 'Chicago', country: 'United States', latitude: 41.8781, longitude: -87.6298),
    CityLocation(name: 'Toronto', country: 'Canada', latitude: 43.6532, longitude: -79.3832),
    CityLocation(name: 'Paris', country: 'France', latitude: 48.8566, longitude: 2.3522),
    CityLocation(name: 'Berlin', country: 'Germany', latitude: 52.5200, longitude: 13.4050),
    CityLocation(name: 'Jakarta', country: 'Indonesia', latitude: -6.2088, longitude: 106.8456),
    CityLocation(name: 'Kuala Lumpur', country: 'Malaysia', latitude: 3.1390, longitude: 101.6869),
    CityLocation(name: 'Karachi', country: 'Pakistan', latitude: 24.8607, longitude: 67.0011),
    CityLocation(name: 'Lahore', country: 'Pakistan', latitude: 31.5204, longitude: 74.3587),
    CityLocation(name: 'Dhaka', country: 'Bangladesh', latitude: 23.8103, longitude: 90.4125),
    CityLocation(name: 'Sydney', country: 'Australia', latitude: -33.8688, longitude: 151.2093),
    CityLocation(name: 'Melbourne', country: 'Australia', latitude: -37.8136, longitude: 144.9631),
    CityLocation(name: 'Tashkent', country: 'Uzbekistan', latitude: 41.2995, longitude: 69.2401),
    CityLocation(name: 'Mogadishu', country: 'Somalia', latitude: 2.0469, longitude: 45.3182),
    CityLocation(name: 'Khartoum', country: 'Sudan', latitude: 15.5007, longitude: 32.5599),
    CityLocation(name: 'Nairobi', country: 'Kenya', latitude: -1.2921, longitude: 36.8219),
    CityLocation(name: 'Cape Town', country: 'South Africa', latitude: -33.9249, longitude: 18.4241),
    CityLocation(name: 'Casablanca', country: 'Morocco', latitude: 33.5731, longitude: -7.5898),
    CityLocation(name: 'Algiers', country: 'Algeria', latitude: 36.7538, longitude: 3.0588),
    CityLocation(name: 'Tunis', country: 'Tunisia', latitude: 36.8065, longitude: 10.1815),
    CityLocation(name: 'Amman', country: 'Jordan', latitude: 31.9454, longitude: 35.9284),
    CityLocation(name: 'Beirut', country: 'Lebanon', latitude: 33.8938, longitude: 35.5018),
    CityLocation(name: 'Damascus', country: 'Syria', latitude: 33.5138, longitude: 36.2765),
    CityLocation(name: 'Baghdad', country: 'Iraq', latitude: 33.3152, longitude: 44.3661),
    CityLocation(name: 'Kuwait City', country: 'Kuwait', latitude: 29.3759, longitude: 47.9774),
    CityLocation(name: 'Doha', country: 'Qatar', latitude: 25.2854, longitude: 51.5310),
    CityLocation(name: 'Muscat', country: 'Oman', latitude: 23.5880, longitude: 58.3829),
    CityLocation(name: 'Manama', country: 'Bahrain', latitude: 26.2285, longitude: 50.5860),
    CityLocation(name: 'Los Angeles', country: 'United States', latitude: 34.0522, longitude: -118.2437),
    CityLocation(name: 'Singapore', country: 'Singapore', latitude: 1.3521, longitude: 103.8198),
    CityLocation(name: 'Tokyo', country: 'Japan', latitude: 35.6762, longitude: 139.6503),
  ];

  static const List<Map<String, dynamic>> prayerMethods = [
    {'id': 1, 'name': 'University of Islamic Sciences, Karachi'},
    {'id': 2, 'name': 'Islamic Society of North America (ISNA)'},
    {'id': 3, 'name': 'Muslim World League (MWL)'},
    {'id': 4, 'name': 'Umm Al-Qura University, Makkah'},
    {'id': 5, 'name': 'Egyptian General Authority of Survey'},
    {'id': 7, 'name': 'Institute of Geophysics, University of Tehran'},
    {'id': 8, 'name': 'Gulf Region'},
    {'id': 9, 'name': 'Kuwait'},
    {'id': 10, 'name': 'Qatar'},
    {'id': 11, 'name': 'Majlis Ugama Islam Singapura, Singapore'},
    {'id': 13, 'name': 'Diyanet İşleri Başkanlığı, Turkey'},
    {'id': 15, 'name': 'Moonsighting Committee Worldwide'},
  ];

  static CityLocation findCity(String cityName) {
    final search = cityName.toLowerCase().trim();
    for (final city in cities) {
      if (city.name.toLowerCase() == search ||
          city.fullName.toLowerCase() == search ||
          city.name.toLowerCase().startsWith(search)) {
        return city;
      }
    }
    // Default to Addis Ababa if not found
    return cities[0];
  }

  static CalculationParameters getCalculationParameters(int methodId) {
    switch (methodId) {
      case 1:
        return CalculationMethod.karachi.getParameters();
      case 2:
        return CalculationMethod.north_america.getParameters();
      case 4:
        return CalculationMethod.umm_al_qura.getParameters();
      case 5:
        return CalculationMethod.egyptian.getParameters();
      case 7:
        return CalculationMethod.tehran.getParameters();
      case 8:
        return CalculationMethod.dubai.getParameters();
      case 9:
        return CalculationMethod.kuwait.getParameters();
      case 10:
        return CalculationMethod.qatar.getParameters();
      case 11:
        return CalculationMethod.singapore.getParameters();
      case 13:
        return CalculationMethod.turkey.getParameters();
      case 15:
        return CalculationMethod.other.getParameters();
      case 3:
      default:
        return CalculationMethod.muslim_world_league.getParameters();
    }
  }

  static Map<String, String> calculatePrayerTimes({
    required double latitude,
    required double longitude,
    required DateTime date,
    int methodId = 3,
    bool isHanafi = false,
  }) {
    final coordinates = Coordinates(latitude, longitude);
    final dateComponents = DateComponents.from(date);
    final params = getCalculationParameters(methodId);
    if (isHanafi) {
      params.madhab = Madhab.hanafi;
    } else {
      params.madhab = Madhab.shafi;
    }

    final prayerTimes = PrayerTimes(coordinates, dateComponents, params);
    final DateFormat formatter = DateFormat('HH:mm');

    return {
      'Fajr': formatter.format(prayerTimes.fajr.toLocal()),
      'Sunrise': formatter.format(prayerTimes.sunrise.toLocal()),
      'Dhuhr': formatter.format(prayerTimes.dhuhr.toLocal()),
      'Asr': formatter.format(prayerTimes.asr.toLocal()),
      'Maghrib': formatter.format(prayerTimes.maghrib.toLocal()),
      'Isha': formatter.format(prayerTimes.isha.toLocal()),
    };
  }

  static List<String> searchCities(String query) {
    if (query.trim().length < 2) return [];
    final search = query.toLowerCase().trim();
    return cities
        .where((c) =>
            c.name.toLowerCase().contains(search) ||
            c.country.toLowerCase().contains(search))
        .map((c) => c.fullName)
        .toList();
  }
}
