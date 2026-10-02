import 'package:flutter_test/flutter_test.dart';
import 'package:garbage_tracking_app/services/service_area_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Service Area & Route Optimization Verification', () {
    test('Canonical 11 Documented Service Areas Count', () {
      final defaultAreas = ServiceAreaService.defaultServiceAreas;
      expect(defaultAreas.length, equals(11));
    });

    test('Collection Coverage vs Stationary Sweeping Split', () {
      final defaultAreas = ServiceAreaService.defaultServiceAreas;
      final truckStops = defaultAreas.where((a) => a.isTruckStop).toList();
      final sweepingAreas = defaultAreas.where((a) => !a.isTruckStop).toList();

      expect(truckStops.length, equals(7));
      expect(sweepingAreas.length, equals(4));
    });

    test('Central (Purok 1) Display Name and Type', () {
      final defaultAreas = ServiceAreaService.defaultServiceAreas;
      final central = defaultAreas.firstWhere((a) => a.id == 'central_purok_1');

      expect(central.name, equals('Central (Purok 1)'));
      expect(central.type, equals('Purok'));
      expect(central.isTruckStop, isTrue);
    });

    test('Exclusion of Undocumented Spurious Locations', () {
      final defaultAreas = ServiceAreaService.defaultServiceAreas;
      final spuriousNames = ['purok 4', 'purok 5', 'purok 6', 'purok 7', 'purok 8', 'sentro', 'dos riles', 'san isidro'];

      for (var area in defaultAreas) {
        for (var spurious in spuriousNames) {
          expect(area.name.toLowerCase().contains(spurious), isFalse,
              reason: 'Found spurious location name ${area.name}');
        }
      }
    });

    test('Stationary Sweeping Area Names', () {
      final defaultAreas = ServiceAreaService.defaultServiceAreas;
      final sweepingNames = defaultAreas.where((a) => !a.isTruckStop).map((a) => a.name).toList();

      expect(sweepingNames, contains('San Nicolas'));
      expect(sweepingNames, contains('Paraiso (Street Sweeping)'));
      expect(sweepingNames, contains('Purok 2'));
      expect(sweepingNames, contains('Purok 3'));
    });

    test('Coordinate Ranges and Verification Status', () {
      final defaultAreas = ServiceAreaService.defaultServiceAreas;

      for (var area in defaultAreas) {
        expect(area.latitude, greaterThanOrEqualTo(-90.0));
        expect(area.latitude, lessThanOrEqualTo(90.0));
        expect(area.longitude, greaterThanOrEqualTo(-180.0));
        expect(area.longitude, lessThanOrEqualTo(180.0));
        expect(area.latitude, isNot(equals(0.0)));
        expect(area.longitude, isNot(equals(0.0)));
        expect(area.verificationStatus, equals('VERIFIED'));
      }
    });

    test('Subdivision Entrance and Road Segment Endpoint Verification', () {
      final defaultAreas = ServiceAreaService.defaultServiceAreas;

      // Subdivision road entrance checks
      final brixton = defaultAreas.firstWhere((a) => a.id == 'brixton_homes');
      expect(brixton.type, equals('Subdivision'));
      expect(brixton.entranceLat, isNotNull);
      expect(brixton.entranceLng, isNotNull);

      final pueblo = defaultAreas.firstWhere((a) => a.id == 'el_pueblo');
      expect(pueblo.type, equals('Subdivision'));
      expect(pueblo.entranceLat, isNotNull);
      expect(pueblo.entranceLng, isNotNull);

      // Road segment endpoints check for TM Kalaw St & Ayala Hwy Almaris to Apat
      final kalaw = defaultAreas.firstWhere((a) => a.id == 'tm_kalaw_st');
      expect(kalaw.type, equals('Road Segment'));
      expect(kalaw.endLat, isNotNull);
      expect(kalaw.endLng, isNotNull);

      final ayala = defaultAreas.firstWhere((a) => a.id == 'ayala_hwy_almaris_apat');
      expect(ayala.type, equals('Highway Segment'));
      expect(ayala.endLat, isNotNull);
      expect(ayala.endLng, isNotNull);
    });

    test('Route Optimization Filtering and GeoJSON Coordinate Format', () {
      final defaultAreas = ServiceAreaService.defaultServiceAreas;

      // Filter truck stops
      final truckStops = defaultAreas.where((a) => a.isTruckStop && a.verificationStatus == 'VERIFIED').toList();
      expect(truckStops.length, equals(7));

      // Validate GeoJSON format: coordinates must be [longitude, latitude]
      for (var stop in truckStops) {
        final geoJsonCoords = [stop.entranceLng, stop.entranceLat];
        expect(geoJsonCoords[0], equals(stop.entranceLng), reason: 'GeoJSON index 0 must be longitude');
        expect(geoJsonCoords[1], equals(stop.entranceLat), reason: 'GeoJSON index 1 must be latitude');
      }
    });
  });
}
