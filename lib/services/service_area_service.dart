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
    this.verificationStatus = 'UNVERIFIED',
    this.coordinateSource = 'Unverified Dataset',
    this.lastVerificationDate = '2026-10-02',
    this.assignedTruckId,
    this.boundaryGeometry = const [],
    this.boundaryType = 'Point',
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
  };

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

    return ServiceArea(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? 'Purok',
      isTruckStop: json['isTruckStop'] == true || json['is_truck_stop'] == true,
      latitude: lat,
      longitude: lng,
      entranceLat: entLat,
      entranceLng: entLng,
      endLat: json['endLat'] != null ? ((json['endLat'] as num).toDouble()) : null,
      endLng: json['endLng'] != null ? ((json['endLng'] as num).toDouble()) : null,
      radius: ((json['radius'] ?? 60.0) as num).toDouble(),
      verificationStatus: json['verificationStatus']?.toString() ?? 'UNVERIFIED',
      coordinateSource: json['coordinateSource']?.toString() ?? 'Unverified Dataset',
      lastVerificationDate: json['lastVerificationDate']?.toString() ?? '2026-10-02',
      assignedTruckId: json['assignedTruckId']?.toString(),
      boundaryGeometry: geom,
      boundaryType: json['boundaryType']?.toString() ?? (geom.isNotEmpty ? 'Polygon' : 'Point'),
    );
  }
}

class ServiceAreaService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  /// Official canonical dataset for Barangay Balintawak, Lipa City, Batangas
  static const List<ServiceArea> defaultServiceAreas = [
    // A. Garbage Truck Collection Coverage Stops (isTruckStop = true)
    ServiceArea(
      id: 'central_purok_1',
      name: 'Central (Purok 1)',
      type: 'Purok',
      isTruckStop: true,
      latitude: 13.94120,
      longitude: 121.16180,
      entranceLat: 13.94120,
      entranceLng: 121.16180,
      radius: 60.0,
      verificationStatus: 'UNVERIFIED',
      coordinateSource: 'Unverified Centerpoint Dataset',
      lastVerificationDate: '2026-10-02',
    ),
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
      coordinateSource: 'Unverified Centerpoint Dataset',
      lastVerificationDate: '2026-10-02',
    ),
    ServiceArea(
      id: 'riverside',
      name: 'Riverside',
      type: 'Residential Area',
      isTruckStop: true,
      latitude: 13.93650,
      longitude: 121.16520,
      entranceLat: 13.93650,
      entranceLng: 121.16520,
      radius: 60.0,
      verificationStatus: 'UNVERIFIED',
      coordinateSource: 'Unverified Centerpoint Dataset',
      lastVerificationDate: '2026-10-02',
    ),
    ServiceArea(
      id: 'tm_kalaw_st',
      name: 'T.M. Kalaw Street',
      type: 'Road Segment',
      isTruckStop: true,
      latitude: 13.93820,
      longitude: 121.15830,
      entranceLat: 13.94050,
      entranceLng: 121.15950,
      endLat: 13.93600,
      endLng: 121.15720,
      radius: 70.0,
      verificationStatus: 'UNVERIFIED',
      coordinateSource: 'Unverified Centerpoint Dataset',
      lastVerificationDate: '2026-10-02',
    ),
    ServiceArea(
      id: 'ayala_hwy_almaris_apat',
      name: 'Ayala Highway (Almaris to Apat Grill)',
      type: 'Highway Segment',
      isTruckStop: true,
      latitude: 13.94150,
      longitude: 121.16330,
      entranceLat: 13.94320,
      entranceLng: 121.16450,
      endLat: 13.93980,
      endLng: 121.16210,
      radius: 80.0,
      verificationStatus: 'UNVERIFIED',
      coordinateSource: 'Unverified Centerpoint Dataset',
      lastVerificationDate: '2026-10-02',
    ),
    ServiceArea(
      id: 'brixton_homes',
      name: 'Brixton Homes',
      type: 'Subdivision',
      isTruckStop: true,
      latitude: 13.93880,
      longitude: 121.15500,
      entranceLat: 13.93880,
      entranceLng: 121.15500,
      radius: 65.0,
      verificationStatus: 'UNVERIFIED',
      coordinateSource: 'Unverified Centerpoint Dataset',
      lastVerificationDate: '2026-10-02',
    ),
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
      coordinateSource: 'Unverified Centerpoint Dataset',
      lastVerificationDate: '2026-10-02',
    ),

    // B. Stationary Street-Sweeping Assignments (isTruckStop = false)
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
      verificationStatus: 'UNVERIFIED',
      coordinateSource: 'Unverified Centerpoint Dataset',
      lastVerificationDate: '2026-10-02',
    ),
    ServiceArea(
      id: 'paraiso_sweeping',
      name: 'Paraiso (Street Sweeping)',
      type: 'Stationary Sweeping Area',
      isTruckStop: false,
      latitude: 13.93820,
      longitude: 121.16050,
      entranceLat: 13.93820,
      entranceLng: 121.16050,
      radius: 50.0,
      verificationStatus: 'UNVERIFIED',
      coordinateSource: 'Unverified Centerpoint Dataset',
      lastVerificationDate: '2026-10-02',
    ),
    ServiceArea(
      id: 'purok_2_sweeping',
      name: 'Purok 2',
      type: 'Stationary Sweeping Area',
      isTruckStop: false,
      latitude: 13.94000,
      longitude: 121.16300,
      entranceLat: 13.94000,
      entranceLng: 121.16300,
      radius: 50.0,
      verificationStatus: 'UNVERIFIED',
      coordinateSource: 'Unverified Centerpoint Dataset',
      lastVerificationDate: '2026-10-02',
    ),
    ServiceArea(
      id: 'purok_3_sweeping',
      name: 'Purok 3',
      type: 'Stationary Sweeping Area',
      isTruckStop: false,
      latitude: 13.93700,
      longitude: 121.16400,
      entranceLat: 13.93700,
      entranceLng: 121.16400,
      radius: 50.0,
      verificationStatus: 'UNVERIFIED',
      coordinateSource: 'Unverified Centerpoint Dataset',
      lastVerificationDate: '2026-10-02',
    ),
  ];

  /// List of official display names for resident registration & dropdowns
  static final List<String> documentedAreaNames = [
    'Central (Purok 1)',
    'Purok Paraiso',
    'Riverside',
    'T.M. Kalaw Street',
    'Ayala Highway (Almaris to Apat Grill)',
    'Brixton Homes',
    'El Pueblo',
    'San Nicolas',
    'Paraiso (Street Sweeping)',
    'Purok 2',
    'Purok 3',
  ];

  /// Ensures that 'puroks' in Firebase RTDB contains the canonical Balintawak service areas
  /// and purges spurious/undocumented areas (e.g. Purok 4, 5, 6, 7, 8).
  Future<void> ensureInitialized() async {
    try {
      final snap = await _database.ref('puroks').get();
      bool needsReseed = false;

      if (!snap.exists || snap.value == null) {
        needsReseed = true;
      } else {
        final Map data = snap.value as Map;
        bool hasSpurious = false;
        data.forEach((key, value) {
          if (value is Map) {
            final String name = (value['name'] ?? key).toString().toLowerCase();
            if (name.contains('purok 4') || name.contains('purok 5') || name.contains('purok 6') ||
                name.contains('purok 7') || name.contains('purok 8') || name.contains('dos riles') ||
                name.contains('sentro') || name.contains('san isidro')) {
              hasSpurious = true;
            }
          }
        });
        if (hasSpurious) {
          debugPrint("[SERVICE AREA] Spurious/undocumented service areas detected in DB. Cleansing...");
          needsReseed = true;
        }
      }

      if (needsReseed) {
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
      debugPrint("[DRIVER ROUTE OPTIMIZATION READ]\n"
          "Database: Firebase Realtime Database\n"
          "Path: puroks\n"
          "Snapshot exists: ${snap.exists}");
      if (snap.exists && snap.value != null) {
        final Map data = snap.value as Map;
        final List<ServiceArea> list = [];
        List<String> ids = [];
        List<String> names = [];
        List<String> statuses = [];

        data.forEach((key, value) {
          if (value is Map) {
            final areaMap = Map<String, dynamic>.from(value);
            if (!areaMap.containsKey('id') || areaMap['id'] == null || areaMap['id'].toString().isEmpty) {
              areaMap['id'] = key.toString();
            }
            final area = ServiceArea.fromJson(areaMap);
            list.add(area);
            ids.add(area.id);
            names.add(area.name);
            statuses.add("${area.name}:${area.verificationStatus}");
          }
        });

        debugPrint("[DRIVER ROUTE OPTIMIZATION READ] Records found: ${list.length}, Area IDs: ${ids.join(', ')}, Area Names: ${names.join(', ')}, Verification Statuses: ${statuses.join(', ')}");
        return list;
      }
    } catch (e) {
      debugPrint("[SERVICE AREA] Error fetching service areas: $e");
    }
    return defaultServiceAreas;
  }

  /// Returns only verified truck collection stops (`isTruckStop == true` and `verificationStatus == 'VERIFIED'`)
  Future<List<ServiceArea>> getTruckCollectionStops({String? truckId}) async {
    final all = await getAllServiceAreas();
    debugPrint("[DRIVER RAW COLLECTION DATA] Total loaded from DB: ${all.length}");

    List<ServiceArea> verifiedStops = [];
    for (var a in all) {
      bool isTruckStop = a.isTruckStop;
      String verStatus = a.verificationStatus.toUpperCase();
      bool isVerified = verStatus == 'VERIFIED';
      bool hasCoords = (a.latitude != 0.0 && a.longitude != 0.0) || (a.entranceLat != 0.0 && a.entranceLng != 0.0);
      bool truckMatch = true;
      if (truckId != null && truckId.isNotEmpty && a.assignedTruckId != null && a.assignedTruckId!.isNotEmpty) {
        truckMatch = (a.assignedTruckId == truckId || a.assignedTruckId == "All");
      }

      List<String> rejectReasons = [];
      if (!isTruckStop) rejectReasons.add("Not a truck stop (stationary sweeping)");
      if (!isVerified) rejectReasons.add("verificationStatus is '$verStatus' (not VERIFIED)");
      if (!hasCoords) rejectReasons.add("Missing or invalid coordinates");
      if (!truckMatch) rejectReasons.add("Assigned truck mismatch (assigned to ${a.assignedTruckId}, current is $truckId)");

      bool valid = rejectReasons.isEmpty;

      debugPrint("[AREA CHECK]\n"
          "ID: ${a.id}\n"
          "Name: ${a.name}\n"
          "isTruckStop: $isTruckStop\n"
          "verificationStatus: ${a.verificationStatus}\n"
          "isVerified: $isVerified\n"
          "latitude: ${a.latitude}\n"
          "longitude: ${a.longitude}\n"
          "boundary exists: ${a.boundaryGeometry.isNotEmpty}\n"
          "VALID FOR ROUTE: $valid\n"
          "REASON: ${valid ? 'ACCEPTED' : rejectReasons.join('; ')}");

      if (valid) {
        verifiedStops.add(a);
      }
    }

    debugPrint("[DRIVER ROUTE OPTIMIZATION FILTER] Final accepted stops count: ${verifiedStops.length}");
    return verifiedStops;
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
        "Database: Firebase Realtime Database\n"
        "Path: puroks/$key\n"
        "verificationStatus: ${area.verificationStatus}\n"
        "isVerified: ${area.verificationStatus.toUpperCase() == 'VERIFIED'}\n"
        "latitude: ${area.latitude}\n"
        "longitude: ${area.longitude}\n"
        "entranceLat: ${area.entranceLat}\n"
        "entranceLng: ${area.entranceLng}\n"
        "boundary: ${area.boundaryGeometry.isNotEmpty ? 'exists' : 'missing'}\n"
        "coordinateSource: ${area.coordinateSource}");

    if (area.name.trim().isEmpty) return false;
    if (area.latitude < -90 || area.latitude > 90 || area.longitude < -180 || area.longitude > 180) return false;
    if (area.latitude == 0.0 && area.longitude == 0.0) return false;

    try {
      final Map<String, dynamic> data = area.toJson();
      data['id'] = key;

      await _database.ref('puroks/$key').set(data);
      debugPrint("[PUROK VERIFY SAVE SUCCESS]\n"
          "purokId: $key\n"
          "savedVerificationStatus: ${area.verificationStatus}");

      // Read-back verification
      final readBackSnap = await _database.ref('puroks/$key').get();
      if (readBackSnap.exists && readBackSnap.value != null) {
        final Map rbMap = readBackSnap.value as Map;
        debugPrint("[PUROK VERIFY READ-BACK]\n"
            "purokId: $key\n"
            "verificationStatus: ${rbMap['verificationStatus']}\n"
            "boundaryGeometry: ${rbMap['boundaryGeometry'] != null ? 'exists' : 'missing'}\n"
            "latitude: ${rbMap['latitude'] ?? rbMap['lat']}\n"
            "longitude: ${rbMap['longitude'] ?? rbMap['lng']}\n"
            "coordinateSource: ${rbMap['coordinateSource']}");
      } else {
        debugPrint("[PUROK VERIFY READ-BACK ERROR] Record not found after save!");
      }

      return true;
    } catch (e) {
      debugPrint("[PUROK VERIFY SAVE ERROR]\n"
          "error: $e");
      return false;
    }
  }

  /// Deletes a service area (without touching trip history)
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
