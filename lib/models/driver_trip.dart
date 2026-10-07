import 'dart:math' as math;

class GpsPoint {
  final double latitude;
  final double longitude;
  final double speedKmh;
  final double heading;
  final double accuracyM;
  final String status;
  final DateTime timestamp;
  final bool isGapStart;

  GpsPoint({
    required this.latitude,
    required this.longitude,
    this.speedKmh = 0.0,
    this.heading = 0.0,
    this.accuracyM = 0.0,
    this.status = "ACTIVE",
    required this.timestamp,
    this.isGapStart = false,
  });

  factory GpsPoint.fromJson(Map<String, dynamic> json) {
    double lat = double.tryParse((json['latitude'] ?? json['lat'] ?? 0).toString()) ?? 0.0;
    double lng = double.tryParse((json['longitude'] ?? json['lng'] ?? 0).toString()) ?? 0.0;
    double spd = double.tryParse((json['speed_kmh'] ?? json['speed'] ?? 0).toString()) ?? 0.0;
    double hdg = double.tryParse((json['heading'] ?? 0).toString()) ?? 0.0;
    double acc = double.tryParse((json['accuracy_m'] ?? json['accuracy'] ?? 0).toString()) ?? 0.0;
    String st = (json['status'] ?? "ACTIVE").toString();

    DateTime ts;
    if (json['recorded_at'] != null) {
      ts = DateTime.tryParse(json['recorded_at'].toString()) ?? DateTime.now();
    } else if (json['timestamp'] != null) {
      final rawTs = int.tryParse(json['timestamp'].toString());
      ts = rawTs != null ? DateTime.fromMillisecondsSinceEpoch(rawTs) : DateTime.now();
    } else {
      ts = DateTime.now();
    }

    return GpsPoint(
      latitude: lat,
      longitude: lng,
      speedKmh: spd,
      heading: hdg,
      accuracyM: acc,
      status: st,
      timestamp: ts,
      isGapStart: json['isGapStart'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'speed_kmh': speedKmh,
      'heading': heading,
      'accuracy_m': accuracyM,
      'status': status,
      'recorded_at': timestamp.toIso8601String(),
      'isGapStart': isGapStart,
    };
  }

  GpsPoint copyWith({
    double? latitude,
    double? longitude,
    double? speedKmh,
    double? heading,
    double? accuracyM,
    String? status,
    DateTime? timestamp,
    bool? isGapStart,
  }) {
    return GpsPoint(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speedKmh: speedKmh ?? this.speedKmh,
      heading: heading ?? this.heading,
      accuracyM: accuracyM ?? this.accuracyM,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      isGapStart: isGapStart ?? this.isGapStart,
    );
  }
}

class TripEvent {
  final String eventType;
  final String description;
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;

  TripEvent({
    required this.eventType,
    required this.description,
    required this.timestamp,
    this.latitude,
    this.longitude,
  });

  factory TripEvent.fromJson(Map<String, dynamic> json) {
    DateTime ts;
    if (json['recorded_at'] != null) {
      ts = DateTime.tryParse(json['recorded_at'].toString()) ?? DateTime.now();
    } else if (json['timestamp'] != null) {
      final rawTs = int.tryParse(json['timestamp'].toString());
      ts = rawTs != null ? DateTime.fromMillisecondsSinceEpoch(rawTs) : DateTime.now();
    } else {
      ts = DateTime.now();
    }

    return TripEvent(
      eventType: (json['event_type'] ?? json['type'] ?? json['status'] ?? "ACTIVE").toString(),
      description: (json['description'] ?? json['message'] ?? "").toString(),
      timestamp: ts,
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_type': eventType,
      'description': description,
      'recorded_at': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class DetectedStop {
  final double latitude;
  final double longitude;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final String label;

  DetectedStop({
    required this.latitude,
    required this.longitude,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.label,
  });
}

class DataGap {
  final DateTime startTime;
  final DateTime endTime;
  final int gapDurationSeconds;
  final double distanceJumpMeters;
  final String reason;

  DataGap({
    required this.startTime,
    required this.endTime,
    required this.gapDurationSeconds,
    required this.distanceJumpMeters,
    required this.reason,
  });
}

class DriverTrip {
  final String tripId;
  final dynamic driverId;
  final String driverName;
  final String truckId;
  final String routeName;
  final String routeStatus;
  final DateTime startTime;
  final DateTime? endTime;
  final double startLat;
  final double startLng;
  final double? finishLat;
  final double? finishLng;
  final double totalDistanceKm;
  final int movingTimeSeconds;
  final int stoppedTimeSeconds;
  final int detectedStopsCount;
  final List<GpsPoint> points;
  final List<TripEvent> events;
  final List<DetectedStop> detectedStops;
  final List<DataGap> dataGaps;

  DriverTrip({
    required this.tripId,
    required this.driverId,
    this.driverName = "Driver",
    this.truckId = "Unknown",
    this.routeName = "Collection Route",
    this.routeStatus = "ACTIVE",
    required this.startTime,
    this.endTime,
    this.startLat = 0.0,
    this.startLng = 0.0,
    this.finishLat,
    this.finishLng,
    this.totalDistanceKm = 0.0,
    this.movingTimeSeconds = 0,
    this.stoppedTimeSeconds = 0,
    this.detectedStopsCount = 0,
    this.points = const [],
    this.events = const [],
    this.detectedStops = const [],
    this.dataGaps = const [],
  });

  factory DriverTrip.fromJson(Map<String, dynamic> json, {List<GpsPoint>? pointsList, List<TripEvent>? eventsList}) {
    DateTime st;
    if (json['start_time'] != null) {
      st = DateTime.tryParse(json['start_time'].toString()) ?? DateTime.now();
    } else if (json['server_start_time'] != null) {
      final raw = int.tryParse(json['server_start_time'].toString());
      st = raw != null ? DateTime.fromMillisecondsSinceEpoch(raw) : DateTime.now();
    } else if (json['created_at'] != null) {
      st = DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now();
    } else {
      st = DateTime.now();
    }

    DateTime? et;
    if (json['end_time'] != null) {
      et = DateTime.tryParse(json['end_time'].toString());
    } else if (json['finishTime'] != null) {
      final raw = int.tryParse(json['finishTime'].toString());
      if (raw != null) et = DateTime.fromMillisecondsSinceEpoch(raw);
    }

    return DriverTrip(
      tripId: (json['trip_id'] ?? json['route_id'] ?? json['key'] ?? "0").toString(),
      driverId: json['driver_id'] ?? json['driverId'] ?? 0,
      driverName: (json['driver_name'] ?? json['driverName'] ?? "Driver").toString(),
      truckId: (json['truck_id'] ?? json['truckId'] ?? "Unknown").toString(),
      routeName: (json['route_name'] ?? json['routeName'] ?? "Collection Route").toString(),
      routeStatus: (json['route_status'] ?? json['status'] ?? "ACTIVE").toString().toUpperCase(),
      startTime: st,
      endTime: et,
      startLat: double.tryParse((json['start_lat'] ?? 0).toString()) ?? 0.0,
      startLng: double.tryParse((json['start_lng'] ?? 0).toString()) ?? 0.0,
      finishLat: json['finish_lat'] != null ? double.tryParse(json['finish_lat'].toString()) : null,
      finishLng: json['finish_lng'] != null ? double.tryParse(json['finish_lng'].toString()) : null,
      totalDistanceKm: double.tryParse((json['total_distance_km'] ?? json['total_distance'] ?? 0).toString()) ?? 0.0,
      movingTimeSeconds: int.tryParse((json['moving_time_seconds'] ?? 0).toString()) ?? 0,
      stoppedTimeSeconds: int.tryParse((json['stopped_time_seconds'] ?? 0).toString()) ?? 0,
      detectedStopsCount: int.tryParse((json['detected_stops_count'] ?? json['total_stops'] ?? 0).toString()) ?? 0,
      points: pointsList ?? [],
      events: eventsList ?? [],
    );
  }

  // Calculate distance between two GPS positions using Haversine formula
  static double haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295; // pi / 180
    final double a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a)); // 2 * R; R = 6371 km
  }
}
