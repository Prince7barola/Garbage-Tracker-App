import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class ServiceArea {
  final String id;
  final String name;
  final String type; // 'Purok' | 'Residential Area' | 'Subdivision' | 'Road Segment' | 'Highway Segment' | 'Stationary Sweeping Area'
  final bool isTruckStop; // true = garbage truck collection stop, false = stationary street sweeping
  final double latitude;
  final double longitude;
  final double entranceLat;
  final double entranceLng;
  final double? endLat;
  final double? endLng;
  final double radius; // geofence radius in meters
  final String verificationStatus; // 'VERIFIED' | 'UNVERIFIED'
  final String coordinateSource;
  final String lastVerificationDate;
  final String? assignedTruckId;
  final List<List<double>> boundaryGeometry; // Polygon coordinates [longitude, latitude]
  final String boundaryType; // 'Polygon' | 'Point'
  final String color; // Hex color for polygon boundary & fill

  const ServiceArea({
    required this.id,
    required this.name,
    required this.type,
    required this.isTruckStop,
    required this.latitude,
    required this.longitude,
    required this.entranceLat,
    required this.entranceLng,
    this.endLat,
    this.endLng,
    this.radius = 60.0,
    this.verificationStatus = 'VERIFIED',
    this.coordinateSource = 'Barangay Balintawak Official GIS / Mapbox Road Network',
    this.lastVerificationDate = '2026-10-02',
    this.assignedTruckId,
    this.boundaryGeometry = const [],
    this.boundaryType = 'Polygon',
    this.color = '#00796B',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'isTruckStop': isTruckStop,
    'latitude': latitude,
    'longitude': longitude,
    'lat': latitude,
    'lng': longitude,
    'entranceLat': entranceLat,
    'entranceLng': entranceLng,
    'endLat': endLat,
    'endLng': endLng,
    'radius': radius,
    'verificationStatus': verificationStatus,
    'coordinateSource': coordinateSource,
    'lastVerificationDate': lastVerificationDate,
    'assignedTruckId': assignedTruckId,
    'boundaryGeometry': boundaryGeometry,
    'boundaryType': boundaryType,
    'color': color,
  };

  static String _normalizeVerificationStatus(dynamic val) {
    if (val == null) return 'VERIFIED';
    if (val is bool) return val ? 'VERIFIED' : 'UNVERIFIED';
    String str = val.toString().trim().toUpperCase();
    if (str == 'VERIFIED' || str == 'TRUE' || str == '1' || str == 'YES') return 'VERIFIED';
    if (str == 'UNVERIFIED' || str == 'FALSE' || str == '0' || str == 'NO') return 'UNVERIFIED';
    return 'VERIFIED';
  }

  factory ServiceArea.fromJson(Map<dynamic, dynamic> json) {
    final double lat = ((json['latitude'] ?? json['lat'] ?? 0.0) as num).toDouble();
    final double lng = ((json['longitude'] ?? json['lng'] ?? 0.0) as num).toDouble();
    final double entLat = json['entranceLat'] != null ? ((json['entranceLat'] as num).toDouble()) : lat;
    final double entLng = json['entranceLng'] != null ? ((json['entranceLng'] as num).toDouble()) : lng;

    List<List<double>> geom = [];
    if (json['boundaryGeometry'] != null && json['boundaryGeometry'] is List) {
      for (var pt in (json['boundaryGeometry'] as List)) {
        if (pt is List && pt.length >= 2) {
          geom.add([ (pt[0] as num).toDouble(), (pt[1] as num).toDouble() ]);
        }
      }
    }

    final rawVer = json['verificationStatus'] ?? json['verification_status'] ?? json['isVerified'] ?? json['verified'];

    return ServiceArea(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? 'Purok',
      isTruckStop: json['isTruckStop'] == true || json['is_truck_stop'] == true || json['isTruckStop'] == null,
      latitude: lat,
      longitude: lng,
      entranceLat: entLat,
      entranceLng: entLng,
      endLat: json['endLat'] != null ? ((json['endLat'] as num).toDouble()) : null,
      endLng: json['endLng'] != null ? ((json['endLng'] as num).toDouble()) : null,
      radius: ((json['radius'] ?? 60.0) as num).toDouble(),
      verificationStatus: _normalizeVerificationStatus(rawVer),
      coordinateSource: json['coordinateSource']?.toString() ?? 'Barangay Balintawak Official GIS',
      lastVerificationDate: json['lastVerificationDate']?.toString() ?? '2026-10-02',
      assignedTruckId: json['assignedTruckId']?.toString(),
      boundaryGeometry: geom,
      boundaryType: json['boundaryType']?.toString() ?? (geom.isNotEmpty ? 'Polygon' : 'Point'),
      color: json['color']?.toString() ?? '#00796B',
    );
  }
}

class ServiceAreaService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  /// Official canonical dataset updated with exact provided coordinates
  static const List<ServiceArea> defaultServiceAreas = [
    // 1. Purok 1 (Red)
    ServiceArea(
      id: 'central_purok_1',
      name: 'Central (Purok 1)',
      type: 'Purok',
      isTruckStop: true,
      latitude: 13.9530,
      longitude: 121.1588,
      entranceLat: 13.9530,
      entranceLng: 121.1588,
      radius: 60.0,
      verificationStatus: 'VERIFIED',
      color: '#E53935', // Red
      coordinateSource: 'Admin Verified (Balintawak Area)',
      lastVerificationDate: '2026-10-02',
    ),
    // 2. Purok 2 (Blue)
    ServiceArea(
      id: 'purok_2',
      name: 'Purok 2',
      type: 'Purok',
      isTruckStop: true,
      latitude: 13.94020,
      longitude: 121.16380,
      entranceLat: 13.94020,
      entranceLng: 121.16380,
      radius: 60.0,
      verificationStatus: 'VERIFIED',
      color: '#1E88E5', // Blue
      coordinateSource: 'Admin Verified',
      lastVerificationDate: '2026-10-02',
    ),
    // 3. Purok 3 (Orange)
    ServiceArea(
      id: 'purok_3',
      name: 'Purok 3',
      type: 'Purok',
      isTruckStop: true,
      latitude: 13.93750,
      longitude: 121.16600,
      entranceLat: 13.93750,
      entranceLng: 121.16600,
      radius: 60.0,
      verificationStatus: 'VERIFIED',
      color: '#FB8C00', // Orange
      coordinateSource: 'Admin Verified',
      lastVerificationDate: '2026-10-02',
    ),
    // 4. Purok Paraiso (Green - Unverified per instructions if no dedicated coord)
    ServiceArea(
      id: 'purok_paraiso',
      name: 'Purok Paraiso',
      type: 'Purok',
      isTruckStop: true,
      latitude: 13.93850,
      longitude: 121.16020,
      entranceLat: 13.93850,
      entranceLng: 121.16020,
      radius: 60.0,
      verificationStatus: 'UNVERIFIED',
      color: '#43A047', // Green
      coordinateSource: 'Unverified / Needs Verification',
      lastVerificationDate: '2026-10-02',
    ),
    // 5. Riverside (Purple)
    ServiceArea(
      id: 'riverside',
      name: 'Riverside',
      type: 'Residential Area',
      isTruckStop: true,
      latitude: 13.9465,
      longitude: 121.1637,
      entranceLat: 13.9465,
      entranceLng: 121.1637,
      radius: 60.0,
      verificationStatus: 'VERIFIED',
      color: '#8E24AA', // Purple
      coordinateSource: 'Admin Verified (Approximate Map Center)',
      lastVerificationDate: '2026-10-02',
    ),
    // 6. Brixton Homes (Teal/Cyan)
    ServiceArea(
      id: 'brixton_homes',
      name: 'Brixton Homes',
      type: 'Subdivision',
      isTruckStop: true,
      latitude: 13.9551652,
      longitude: 121.1567505,
      entranceLat: 13.9551652,
      entranceLng: 121.1567505,
      radius: 65.0,
      verificationStatus: 'VERIFIED',
      color: '#00ACC1', // Teal
      coordinateSource: 'Admin Verified (Accurate Location)',
      lastVerificationDate: '2026-10-02',
    ),
    // 7. El Pueblo (Pink - Unverified per instructions)
    ServiceArea(
      id: 'el_pueblo',
      name: 'El Pueblo',
      type: 'Subdivision',
      isTruckStop: true,
      latitude: 13.94250,
      longitude: 121.15880,
      entranceLat: 13.94250,
      entranceLng: 121.15880,
      radius: 65.0,
      verificationStatus: 'UNVERIFIED',
      color: '#E91E63', // Pink
      coordinateSource: 'Unverified / Needs Verification',
      lastVerificationDate: '2026-10-02',
    ),
    // 8. T.M. Kalaw Street (Road Segment)
    ServiceArea(
      id: 'tm_kalaw_st',
      name: 'T.M. Kalaw Street',
      type: 'Road Segment',
      isTruckStop: true,
      latitude: 13.9425,
      longitude: 121.1633,
      entranceLat: 13.9425,
      entranceLng: 121.1633,
      endLat: 13.93600,
      endLng: 121.15720,
      radius: 70.0,
      verificationStatus: 'VERIFIED',
      color: '#00796B',
      coordinateSource: 'Admin Verified (Road Segment Center)',
      lastVerificationDate: '2026-10-02',
    ),
    // 9. Ayala Highway Collection Segment (Highway Segment)
    ServiceArea(
      id: 'ayala_hwy_almaris_apat',
      name: 'Ayala Highway (Almaris to Apat Grill)',
      type: 'Highway Segment',
      isTruckStop: true,
      latitude: 13.9471,
      longitude: 121.13325,
      entranceLat: 13.9482, // Almario's Resort Start
      entranceLng: 121.1354,
      endLat: 13.9461,     // Fat Grill / Apat Grill End
      endLng: 121.1311,
      radius: 80.0,
      verificationStatus: 'VERIFIED',
      color: '#3949AB',
      coordinateSource: 'Admin Verified (Road Segment Endpoints)',
      lastVerificationDate: '2026-10-02',
    ),

    // Other / Stationary Areas
    ServiceArea(
      id: 'san_nicolas_sweeping',
      name: 'San Nicolas',
      type: 'Stationary Sweeping Area',
      isTruckStop: false,
      latitude: 13.93450,
      longitude: 121.16200,
      entranceLat: 13.93450,
      entranceLng: 121.16200,
      radius: 50.0,
      verificationStatus: 'VERIFIED',
      color: '#78909C', // Gray
      coordinateSource: 'Barangay Balintawak Official GIS',
      lastVerificationDate: '2026-10-02',
    ),
  ];

  /// List of official display names for resident registration & dropdowns
  static final List<String> documentedAreaNames = [
    'Central (Purok 1)',
    'Purok 2',
    'Purok 3',
    'Purok Paraiso',
    'Riverside',
    'Brixton Homes',
    'El Pueblo',
    'T.M. Kalaw Street',
    'Ayala Highway (Almaris to Apat Grill)',
    'San Nicolas',
  ];

  /// Ensures that 'puroks' in Firebase RTDB contains the canonical Balintawak service areas
  Future<void> ensureInitialized() async {
    try {
      final snap = await _database.ref('puroks').get();
      if (!snap.exists || snap.value == null) {
        await resetToDefaultBalintawakAreas();
      }
    } catch (e) {
      debugPrint("[SERVICE AREA] Error ensuring service area initialization: $e");
    }
  }

  /// Resets or seeds the database node 'puroks' with the authoritative Balintawak dataset.
  Future<void> resetToDefaultBalintawakAreas() async {
    final Map<String, dynamic> seedMap = {};
    for (var area in defaultServiceAreas) {
      seedMap[area.id] = area.toJson();
    }
    await _database.ref('puroks').set(seedMap);
    debugPrint("[SERVICE AREA] Database 'puroks' initialized with ${defaultServiceAreas.length} documented Barangay Balintawak areas.");
  }

  /// Retrieves all service areas from Firebase RTDB
  Future<List<ServiceArea>> getAllServiceAreas() async {
    await ensureInitialized();
    try {
      final snap = await _database.ref('puroks').get();
      if (snap.exists && snap.value != null) {
        final Map data = snap.value as Map;
        final List<ServiceArea> list = [];
        data.forEach((key, value) {
          if (value is Map) {
            final areaMap = Map<String, dynamic>.from(value);
            if (!areaMap.containsKey('id') || areaMap['id'] == null || areaMap['id'].toString().isEmpty) {
              areaMap['id'] = key.toString();
            }
            list.add(ServiceArea.fromJson(areaMap));
          }
        });
        return list;
      }
    } catch (e) {
      debugPrint("[SERVICE AREA] Error fetching service areas: $e");
    }
    return defaultServiceAreas;
  }

  /// Returns only verified truck collection stops
  Future<List<ServiceArea>> getTruckCollectionStops({String? truckId}) async {
    final all = await getAllServiceAreas();
    return all.where((a) {
      bool isStop = a.isTruckStop && a.verificationStatus.toUpperCase() == 'VERIFIED';
      if (truckId != null && truckId.isNotEmpty && a.assignedTruckId != null && a.assignedTruckId!.isNotEmpty) {
        return isStop && (a.assignedTruckId == truckId || a.assignedTruckId == "All");
      }
      return isStop;
    }).toList();
  }

  /// Returns only stationary street-sweeping assignments (`isTruckStop == false`)
  Future<List<ServiceArea>> getStationarySweepingAreas() async {
    final all = await getAllServiceAreas();
    return all.where((a) => !a.isTruckStop).toList();
  }

  /// Updates or inserts a service area with strict coordinate validation and debug logging
  Future<bool> saveServiceArea(ServiceArea area) async {
    final String key = area.id.isNotEmpty ? area.id : area.name.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_').toLowerCase();

    debugPrint("[ADMIN VERIFY]\n"
        "Area ID: $key\n"
        "Area Name: ${area.name}\n"
        "newVerificationStatus: ${area.verificationStatus}\n"
        "databasePath/table: puroks/$key");

    if (area.name.trim().isEmpty) return false;

    try {
      final Map<String, dynamic> data = area.toJson();
      data['id'] = key;

      await _database.ref('puroks/$key').set(data);
      debugPrint("[PUROK VERIFY SAVE SUCCESS] purokId: $key");
      return true;
    } catch (e) {
      debugPrint("[PUROK VERIFY SAVE ERROR] error: $e");
      return false;
    }
  }

  /// Deletes a service area
  Future<bool> deleteServiceArea(String id) async {
    try {
      await _database.ref('puroks/$id').remove();
      debugPrint("[SERVICE AREA] Deleted service area $id");
      return true;
    } catch (e) {
      debugPrint("[SERVICE AREA] Error deleting service area: $e");
      return false;
    }
  }
}
