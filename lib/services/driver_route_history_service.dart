import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../api/api_service.dart';
import '../models/driver_trip.dart';
import '../models/user.dart';

class DriverRouteHistoryService {
  static final ApiService _apiService = ApiService();
  static final FirebaseDatabase _database = FirebaseDatabase.instance;

  /// Fetches route history list with security role verification.
  /// [currentUser] - the logged in user
  /// [startDate], [endDate] - date filter
  /// [selectedDriverId] - optional driver filter
  /// [selectedTruckId] - optional truck filter
  /// [selectedArea] - optional area filter
  /// [selectedStatus] - optional status filter
  static Future<List<DriverTrip>> fetchRouteHistory({
    required UserData currentUser,
    DateTime? startDate,
    DateTime? endDate,
    String? selectedDriverId,
    String? selectedTruckId,
    String? selectedArea,
    String? selectedStatus,
  }) async {
    // SECURITY CHECK: Residents are forbidden from accessing historical driver routes
    if (currentUser.role.toLowerCase() == 'resident') {
      debugPrint("[ROUTE HISTORY SECURITY] Access denied for Resident role.");
      return [];
    }

    // Role Scoping: Drivers can view ONLY their own history
    String? effectiveDriverId = selectedDriverId;
    if (currentUser.role.toLowerCase() == 'driver') {
      effectiveDriverId = currentUser.userId.toString();
    }

    final String startDateStr = startDate != null ? "${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}" : "";
    final String endDateStr = endDate != null ? "${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}" : "";

    final List<DriverTrip> tripsList = [];
    final Set<String> seenTripIds = {};

    // 1. Fetch from Firebase Realtime Database (`driver_routes` node)
    try {
      final DataSnapshot snapshot = await _database.ref('driver_routes').get();
      if (snapshot.exists && snapshot.value is Map) {
        final Map routesData = snapshot.value as Map;
        routesData.forEach((key, value) {
          if (value is Map) {
            final String tripId = key.toString();
            final String dId = (value['driver_id'] ?? value['driverId'] ?? '').toString();
            final String tId = (value['truck_id'] ?? value['truckId'] ?? '').toString();
            final String rName = (value['route_name'] ?? value['routeName'] ?? '').toString();
            final String status = (value['route_status'] ?? value['status'] ?? '').toString().toUpperCase();

            // Permissions filter
            if (currentUser.role.toLowerCase() == 'driver' && dId != effectiveDriverId) {
              return;
            }
            if (effectiveDriverId != null && effectiveDriverId.isNotEmpty && effectiveDriverId != 'all' && dId != effectiveDriverId) {
              return;
            }
            if (selectedTruckId != null && selectedTruckId.isNotEmpty && selectedTruckId != 'all' && tId != selectedTruckId) {
              return;
            }
            if (selectedArea != null && selectedArea.isNotEmpty && selectedArea != 'all' && !rName.toLowerCase().contains(selectedArea.toLowerCase())) {
              return;
            }
            if (selectedStatus != null && selectedStatus.isNotEmpty && selectedStatus != 'all' && status != selectedStatus.toUpperCase()) {
              return;
            }

            // Date filtering
            DateTime tripDate;
            if (value['start_time'] != null) {
              tripDate = DateTime.tryParse(value['start_time'].toString()) ?? DateTime.now();
            } else if (value['server_start_time'] != null) {
              final raw = int.tryParse(value['server_start_time'].toString());
              tripDate = raw != null ? DateTime.fromMillisecondsSinceEpoch(raw) : DateTime.now();
            } else {
              tripDate = DateTime.now();
            }

            if (startDate != null) {
              final sDateOnly = DateTime(startDate.year, startDate.month, startDate.day);
              final tDateOnly = DateTime(tripDate.year, tripDate.month, tripDate.day);
              if (tDateOnly.isBefore(sDateOnly)) return;
            }
            if (endDate != null) {
              final eDateOnly = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
              if (tripDate.isAfter(eDateOnly)) return;
            }

            final Map<String, dynamic> jsonMap = Map<String, dynamic>.from(value);
            jsonMap['trip_id'] = tripId;

            // Parse Route Points from Firebase
            final List<GpsPoint> points = [];
            if (value['route'] is Map) {
              final Map routeMap = value['route'] as Map;
              routeMap.forEach((_, pVal) {
                if (pVal is Map) {
                  points.add(GpsPoint.fromJson(Map<String, dynamic>.from(pVal)));
                }
              });
              points.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            }

            final trip = DriverTrip.fromJson(jsonMap, pointsList: points);
            tripsList.add(trip);
            seenTripIds.add(tripId);
          }
        });
      }
    } catch (e) {
      debugPrint("[ROUTE HISTORY SERVICE] Firebase fetch error: $e");
    }

    // 2. Fetch from PHP / MySQL API
    try {
      final response = await _apiService.getDriverRouteHistory(
        startDate: startDateStr,
        endDate: endDateStr,
        driverId: effectiveDriverId,
        truckId: selectedTruckId,
        area: selectedArea,
        status: selectedStatus,
      );

      if (response.data['success'] == true && response.data['trips'] is List) {
        final List rawTrips = response.data['trips'];
        for (var t in rawTrips) {
          if (t is Map) {
            final String tId = (t['trip_id'] ?? t['route_id'] ?? '').toString();
            if (!seenTripIds.contains(tId)) {
              tripsList.add(DriverTrip.fromJson(Map<String, dynamic>.from(t)));
              seenTripIds.add(tId);
            }
          }
        }
      }
    } catch (e) {
      debugPrint("[ROUTE HISTORY SERVICE] MySQL API fetch error: $e");
    }

    // Sort trips descending by start time
    tripsList.sort((a, b) => b.startTime.compareTo(a.startTime));
    return tripsList;
  }

  /// Analyzes trip GPS points, detects data gaps, stops, and compiles event timeline.
  static DriverTrip analyzeTrip(DriverTrip trip) {
    if (trip.points.isEmpty) return trip;

    final List<GpsPoint> rawPoints = List.from(trip.points);
    rawPoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Deduplicate and filter stale/invalid points (accuracy > 100m or 0,0 coords)
    final List<GpsPoint> cleanPoints = [];
    GpsPoint? prev;

    for (var p in rawPoints) {
      if (p.latitude == 0.0 && p.longitude == 0.0) continue;
      if (p.accuracyM > 100.0) continue; // Filter inaccurate points

      if (prev != null) {
        final dist = DriverTrip.haversineDistance(
          prev.latitude, prev.longitude, p.latitude, p.longitude,
        ) * 1000; // in meters
        final dtSec = p.timestamp.difference(prev.timestamp).inSeconds;

        // Skip exact duplicate points within 2 seconds and < 1 meter
        if (dtSec <= 2 && dist < 1.0) continue;
      }
      cleanPoints.add(p);
      prev = p;
    }

    if (cleanPoints.isEmpty) return trip;

    // Detect Data Gaps (> 3 mins or > 300m jump)
    final List<DataGap> gaps = [];
    final List<GpsPoint> processedPoints = [];

    for (int i = 0; i < cleanPoints.length; i++) {
      final curr = cleanPoints[i];
      if (i > 0) {
        final prevP = cleanPoints[i - 1];
        final dtSec = curr.timestamp.difference(prevP.timestamp).inSeconds;
        final distM = DriverTrip.haversineDistance(
          prevP.latitude, prevP.longitude, curr.latitude, curr.longitude,
        ) * 1000;

        // Flag gap if time gap > 180s (3 mins) or distance jump > 300m without points
        if (dtSec > 180 || distM > 300.0) {
          gaps.add(DataGap(
            startTime: prevP.timestamp,
            endTime: curr.timestamp,
            gapDurationSeconds: dtSec,
            distanceJumpMeters: distM,
            reason: dtSec > 180 ? "Missing GPS signal interval (${(dtSec/60).toStringAsFixed(1)}m)" : "Large location jump (${distM.toStringAsFixed(0)}m)",
          ));
          processedPoints.add(curr.copyWith(isGapStart: true));
        } else {
          processedPoints.add(curr);
        }
      } else {
        processedPoints.add(curr);
      }
    }

    // Detect Stops (1-3 min idle/slow points with labels as "possible collection stop")
    final List<DetectedStop> stops = [];
    int movingSeconds = 0;
    int stoppedSeconds = 0;
    double calcDistanceKm = 0.0;

    DateTime? stopStart;
    GpsPoint? stopAnchor;

    for (int i = 0; i < processedPoints.length; i++) {
      final p = processedPoints[i];
      if (i > 0) {
        final prevP = processedPoints[i - 1];
        final distM = DriverTrip.haversineDistance(
          prevP.latitude, prevP.longitude, p.latitude, p.longitude,
        ) * 1000;
        final dtSec = p.timestamp.difference(prevP.timestamp).inSeconds;

        if (dtSec > 0 && dtSec < 180) {
          calcDistanceKm += (distM / 1000.0);
          if (p.speedKmh < 3.0 || distM < 5.0) {
            stoppedSeconds += dtSec;
            stopAnchor ??= p;
            stopStart ??= prevP.timestamp;
          } else {
            movingSeconds += dtSec;
            if (stopStart != null && stopAnchor != null) {
              final stopDurSec = p.timestamp.difference(stopStart).inSeconds;
              // 1 to 3 minutes or more idle duration
              if (stopDurSec >= 60) {
                stops.add(DetectedStop(
                  latitude: stopAnchor.latitude,
                  longitude: stopAnchor.longitude,
                  startTime: stopStart,
                  endTime: p.timestamp,
                  durationSeconds: stopDurSec,
                  label: "Possible collection stop (${(stopDurSec / 60).toStringAsFixed(1)}m idle)",
                ));
              }
              stopStart = null;
              stopAnchor = null;
            }
          }
        }
      }
    }

    // Close remaining open stop
    if (stopStart != null && stopAnchor != null && processedPoints.isNotEmpty) {
      final stopDurSec = processedPoints.last.timestamp.difference(stopStart).inSeconds;
      if (stopDurSec >= 60) {
        stops.add(DetectedStop(
          latitude: stopAnchor.latitude,
          longitude: stopAnchor.longitude,
          startTime: stopStart,
          endTime: processedPoints.last.timestamp,
          durationSeconds: stopDurSec,
          label: "Possible collection stop (${(stopDurSec / 60).toStringAsFixed(1)}m idle)",
        ));
      }
    }

    // Compile Events Timeline
    final List<TripEvent> eventTimeline = List.from(trip.events);
    if (eventTimeline.isEmpty) {
      eventTimeline.add(TripEvent(
        eventType: "ACTIVE",
        description: "Trip Started",
        timestamp: trip.startTime,
        latitude: trip.startLat,
        longitude: trip.startLng,
      ));

      if (trip.endTime != null) {
        eventTimeline.add(TripEvent(
          eventType: "COMPLETED",
          description: "Trip Completed",
          timestamp: trip.endTime!,
          latitude: trip.finishLat ?? processedPoints.last.latitude,
          longitude: trip.finishLng ?? processedPoints.last.longitude,
        ));
      }
    }

    return DriverTrip(
      tripId: trip.tripId,
      driverId: trip.driverId,
      driverName: trip.driverName,
      truckId: trip.truckId,
      routeName: trip.routeName,
      routeStatus: trip.routeStatus,
      startTime: trip.startTime,
      endTime: trip.endTime ?? (processedPoints.isNotEmpty ? processedPoints.last.timestamp : null),
      startLat: trip.startLat != 0.0 ? trip.startLat : (processedPoints.isNotEmpty ? processedPoints.first.latitude : 0.0),
      startLng: trip.startLng != 0.0 ? trip.startLng : (processedPoints.isNotEmpty ? processedPoints.first.longitude : 0.0),
      finishLat: trip.finishLat ?? (processedPoints.isNotEmpty ? processedPoints.last.latitude : null),
      finishLng: trip.finishLng ?? (processedPoints.isNotEmpty ? processedPoints.last.longitude : null),
      totalDistanceKm: trip.totalDistanceKm > 0 ? trip.totalDistanceKm : calcDistanceKm,
      movingTimeSeconds: movingSeconds,
      stoppedTimeSeconds: stoppedSeconds,
      detectedStopsCount: stops.length,
      points: processedPoints,
      events: eventTimeline,
      detectedStops: stops,
      dataGaps: gaps,
    );
  }
}
