import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

class RouteOptimizationService {
  final String _mapboxToken = "pk.eyJ1IjoicHJpbmNlNjcwMyIsImEiOiJjbW9zeHB2ODIwNDFnMnRwdWxsam9sYWJmIn0.8DQhyf9Z9-yP8lCuP2WS3g";
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  // In-memory route result cache for the current session
  static String? _cachedConfigHash;
  static Map<String, dynamic>? _cachedRouteResult;
  static double? _cachedLat;
  static double? _cachedLng;

  Future<Map<String, dynamic>?> getOptimizedRoute({
    required String sessionId,
    required double currentLat,
    required double currentLng,
    required List<Map<String, dynamic>> remainingPuroks,
    String? configHash,
  }) async {
    final Stopwatch totalStopwatch = Stopwatch()..start();
    debugPrint("[ROUTE OPTIMIZATION START]");
    debugPrint("========== [OPTIMIZER] ROUTE OPTIMIZATION START ==========");
    debugPrint("PLATFORM: ${kIsWeb ? 'WEB' : 'NATIVE'}");
    debugPrint("SESSION ID: $sessionId");
    debugPrint("CONFIG HASH: $configHash");
    debugPrint("PENDING STOP COUNT: ${remainingPuroks.length}");

    // Check cache to avoid redundant network requests if config & position haven't changed significantly (< 50 meters)
    if (configHash != null && _cachedConfigHash == configHash && _cachedRouteResult != null && _cachedLat != null && _cachedLng != null) {
      double dist = Geolocator.distanceBetween(currentLat, currentLng, _cachedLat!, _cachedLng!);
      if (dist < 50.0) {
        debugPrint("[ROUTE OPTIMIZATION CACHE HIT] Reusing cached route result (distance from cached start: ${dist.toStringAsFixed(1)}m)");
        totalStopwatch.stop();
        return _cachedRouteResult;
      }
    }

    final Stopwatch swLoad = Stopwatch()..start();
    debugPrint("[LOADING VERIFIED AREAS]");

    if (remainingPuroks.isEmpty) {
      swLoad.stop();
      debugPrint("[ROUTE OPTIMIZATION ERROR] No pending collection areas found.");
      return {'success': false, 'error': 'NO_PENDING_STOPS', 'message': 'No verified pending collection areas found. (Note: Unverified Puroks are excluded until officially verified in Admin Settings).'};
    }

    // Validate Coordinates & Collection Stop Type
    List<Map<String, dynamic>> validPuroks = [];
    List<String> rejectedReasons = [];
    int verifiedCount = 0;
    int rejectedCount = 0;

    for (var p in remainingPuroks) {
      final double lat = ((p['latitude'] ?? p['lat'] ?? 0.0) as num).toDouble();
      final double lng = ((p['longitude'] ?? p['lng'] ?? 0.0) as num).toDouble();
      final String name = (p['name'] ?? 'Unknown').toString();
      final bool isTruckStop = p['isTruckStop'] != false && p['is_truck_stop'] != false;
      final String verStatus = (p['verificationStatus'] ?? 'UNVERIFIED').toString().toUpperCase();

      List<String> reasons = [];
      if (!isTruckStop) reasons.add("Stationary sweeping assignment (not truck stop)");
      if (verStatus != 'VERIFIED') reasons.add("verificationStatus is '$verStatus' (expected 'VERIFIED')");
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180 || (lat == 0 && lng == 0)) reasons.add("Invalid or missing coordinates ($lat, $lng)");

      if (reasons.isEmpty) {
        verifiedCount++;
        validPuroks.add({
          'name': name,
          'lat': lat,
          'lng': lng,
        });
      } else {
        rejectedCount++;
        rejectedReasons.add("$name: ${reasons.join('; ')}");
      }
    }

    swLoad.stop();
    debugPrint("[VERIFIED AREAS LOADED] Count: ${verifiedCount}, Rejected: ${rejectedCount} (Duration: ${swLoad.elapsedMilliseconds} ms)");

    if (validPuroks.isEmpty) {
      debugPrint("[ROUTE OPTIMIZATION ERROR] No verified valid Purok coordinates available for optimization.");
      return {
        'success': false,
        'error': 'NO_VERIFIED_STOPS',
        'message': 'No verified collection area coordinates available. Please mark areas as VERIFIED in Admin Settings after obtaining official boundary data.'
      };
    }

    debugPrint("[VALID DESTINATIONS] Count: ${validPuroks.length}");

    debugPrint("[ROUTING REQUEST START]");
    final Stopwatch swRoute = Stopwatch()..start();

    Map<String, dynamic>? result;

    // WEB PROXY LOGIC (With direct Mapbox fallback)
    if (kIsWeb) {
      debugPrint("[ROUTING REQUEST] TRANSPORT: HOSTINGER_PROXY_WITH_FALLBACK");
      try {
        final proxyResult = await _getOptimizedRouteViaProxy(
          sessionId: sessionId,
          currentLat: currentLat,
          currentLng: currentLng,
          remainingPuroks: validPuroks,
          configHash: configHash,
        ).timeout(const Duration(seconds: 12));

        if (proxyResult != null && proxyResult['success'] == true) {
          result = proxyResult;
        }
      } catch (e) {
        debugPrint("[ROUTING TIMEOUT/ERROR] Proxy timed out or failed: $e. Falling back to direct Mapbox.");
      }
    }

    if (result == null || result['success'] != true) {
      debugPrint("[ROUTING REQUEST] TRANSPORT: DIRECT_MAPBOX");
      try {
        result = await _getOptimizedRouteDirectMapbox(
          sessionId: sessionId,
          currentLat: currentLat,
          currentLng: currentLng,
          validPuroks: validPuroks,
          configHash: configHash,
        ).timeout(const Duration(seconds: 12));
      } catch (e) {
        swRoute.stop();
        debugPrint("[ROUTE OPTIMIZATION TIMEOUT] Direct Mapbox request timed out: $e");
        return {
          'success': false,
          'error': 'TIMEOUT',
          'message': 'Route optimization request timed out. Please check your network connection and retry.'
        };
      }
    }

    swRoute.stop();
    debugPrint("[ROUTING RESPONSE RECEIVED] (Duration: ${swRoute.elapsedMilliseconds} ms)");

    if (result != null && result['success'] == true) {
      debugPrint("[OPTIMIZATION CALCULATION START]");
      final Stopwatch swOpt = Stopwatch()..start();
      
      // Update cache
      _cachedConfigHash = configHash;
      _cachedRouteResult = result;
      _cachedLat = currentLat;
      _cachedLng = currentLng;

      swOpt.stop();
      debugPrint("[OPTIMIZATION COMPLETE] (Duration: ${swOpt.elapsedMilliseconds} ms)");
      debugPrint("[ROUTE DISPLAYED]");

      totalStopwatch.stop();
      debugPrint("[ROUTE TIMING]\n"
          "Load & Filter areas: ${swLoad.elapsedMilliseconds} ms\n"
          "Routing request & Matrix/Directions: ${swRoute.elapsedMilliseconds} ms\n"
          "Optimization calculation & cache: ${swOpt.elapsedMilliseconds} ms\n"
          "TOTAL: ${totalStopwatch.elapsedMilliseconds} ms");

      return result;
    } else {
      debugPrint("[ROUTE OPTIMIZATION ERROR] ${result?['message'] ?? 'Unknown optimization failure'}");
      return result ?? {'success': false, 'error': 'UNKNOWN_ERROR', 'message': 'Route optimization failed.'};
    }
  }

  Future<Map<String, dynamic>> _getOptimizedRouteDirectMapbox({
    required String sessionId,
    required double currentLat,
    required double currentLng,
    required List<Map<String, dynamic>> validPuroks,
    String? configHash,
  }) async {
    try {
      List<List<double>> allCoords = [[currentLng, currentLat]];
      for (var p in validPuroks) {
        allCoords.add([(p['lng'] as num).toDouble(), (p['lat'] as num).toDouble()]);
      }

      String coordsString = allCoords.map((c) => "${c[0]},${c[1]}").join(";");

      debugPrint("[ROUTING REQUEST] MATRIX URL & COORDS: $coordsString");
      
      final String matrixUrl = "https://api.mapbox.com/directions-matrix/v1/mapbox/driving/$coordsString";
      
      final matrixResponse = await _dio.get(
        matrixUrl, 
        queryParameters: {
          "access_token": _mapboxToken,
          "annotations": "duration,distance",
          "sources": "0", 
        },
        options: Options(
          headers: {'Accept': 'application/json'},
          validateStatus: (status) => true,
        ),
      );

      debugPrint("[ROUTING RESPONSE] MATRIX HTTP STATUS: ${matrixResponse.statusCode}");

      if (matrixResponse.statusCode != 200 || matrixResponse.data == null || matrixResponse.data['code'] != 'Ok') {
        String msg = matrixResponse.data?['message'] ?? 'Mapbox Matrix service returned status ${matrixResponse.statusCode}';
        debugPrint("[ROUTE OPTIMIZATION ERROR] MATRIX MAPBOX ERROR: $msg");
        return {
          'success': false, 
          'error': 'MATRIX_API_FAILED', 
          'message': 'Routing Matrix API error: $msg'
        };
      }

      final List durationsFromStart = matrixResponse.data['durations'][0];
      List<int> optimizedIndices = _solveNN(durationsFromStart);
      debugPrint("[OPTIMIZATION RESULT] OPTIMIZED ORDER INDICES: ${optimizedIndices.join(' -> ')}");

      List<Map<String, dynamic>> optimizedStops = [];
      for (int i = 0; i < optimizedIndices.length; i++) {
        int originalIndex = optimizedIndices[i] - 1; 
        final purok = validPuroks[originalIndex];
        optimizedStops.add({
          'area_name': purok['name'],
          'latitude': purok['lat'],
          'longitude': purok['lng'],
          'sequence': i + 1,
          'status': 'PENDING',
        });
      }

      List<List<double>> routeWaypoints = [[currentLng, currentLat]];
      for (var s in optimizedStops) {
        routeWaypoints.add([(s['longitude'] as num).toDouble(), (s['latitude'] as num).toDouble()]);
      }

      String directionsCoords = routeWaypoints.map((c) => "${c[0]},${c[1]}").join(";");
      final String directionsUrl = "https://api.mapbox.com/directions/v1/mapbox/driving/$directionsCoords";

      final dirResponse = await _dio.get(
        directionsUrl, 
        queryParameters: {
          "access_token": _mapboxToken,
          "geometries": "geojson",
          "overview": "full",
          "steps": "true",
        },
        options: Options(
          headers: {'Accept': 'application/json'},
          validateStatus: (status) => true,
        ),
      );

      debugPrint("[ROUTING RESPONSE] DIRECTIONS HTTP STATUS: ${dirResponse.statusCode}");

      if (dirResponse.statusCode != 200 || dirResponse.data == null || dirResponse.data['code'] != 'Ok') {
        String msg = dirResponse.data?['message'] ?? 'Mapbox Directions service returned status ${dirResponse.statusCode}';
        debugPrint("[ROUTE OPTIMIZATION ERROR] DIRECTIONS MAPBOX ERROR: $msg");
        return {
          'success': false, 
          'error': 'DIRECTIONS_API_FAILED', 
          'message': 'Directions API error: $msg'
        };
      }

      final route = dirResponse.data['routes'][0];
      final List legs = route['legs'];
      final DateTime now = DateTime.now();
      double cumulativeDuration = 0;

      for (int i = 0; i < optimizedStops.length; i++) {
        cumulativeDuration += (legs[i]['duration'] as num).toDouble();
        optimizedStops[i]['estimated_arrival'] = "${DateFormat('h:mm a').format(now.add(Duration(seconds: cumulativeDuration.toInt())))} (est)";
        optimizedStops[i]['distance_to_reach'] = ((legs[i]['distance'] as num).toDouble()) / 1000.0;
      }

      final double totalDistanceKm = ((route['distance'] as num).toDouble()) / 1000.0;
      final int totalDurationMins = (((route['duration'] as num).toDouble()) / 60.0).round();

      final Map<String, dynamic> optimizedData = {
        'generated_at': ServerValue.timestamp,
        'config_hash': configHash,
        'start_lat': currentLat,
        'start_lng': currentLng,
        'total_distance_km': totalDistanceKm,
        'estimated_duration_minutes': totalDurationMins,
        'estimated_completion': "${DateFormat('h:mm a').format(now.add(Duration(seconds: ((route['duration'] as num).toDouble()).toInt())))} (est)",
        'geometry': jsonEncode(route['geometry']),
        'stops': optimizedStops,
        'success': true,
      };

      try {
        await _database.ref('driver_routes/$sessionId/optimized_route').set(optimizedData);
        debugPrint("[ROUTE OPTIMIZATION SUCCESS] Firebase save completed for optimized route.");
      } catch (e) {
        debugPrint("[ROUTE OPTIMIZATION ERROR] Firebase save failed: $e");
        optimizedData['firebase_save_error'] = e.toString();
      }

      return optimizedData;
    } on DioException catch (e) {
      debugPrint("[ROUTE OPTIMIZATION ERROR] DIO EXCEPTION: ${e.message}");
      return {
        'success': false,
        'error': 'NETWORK_ERROR',
        'message': e.response == null 
            ? 'Network Error: Unable to connect to routing service.' 
            : 'Routing Service Error: HTTP ${e.response?.statusCode}'
      };
    } catch (e) {
      debugPrint("[ROUTE OPTIMIZATION ERROR] CRITICAL FAILURE: $e");
      return {'success': false, 'error': 'CRITICAL_FAILURE', 'message': 'Route optimization failed: $e'};
    }
  }

  /// Greedy Nearest Neighbor solver
  List<int> _solveNN(List durationsFromStart) {
    List<MapEntry<int, double>> stops = [];
    for (int i = 1; i < durationsFromStart.length; i++) {
      stops.add(MapEntry(i, (durationsFromStart[i] as num).toDouble()));
    }
    stops.sort((a, b) => a.value.compareTo(b.value));
    return stops.map((e) => e.key).toList();
  }

  Future<Map<String, dynamic>?> _getOptimizedRouteViaProxy({
    required String sessionId,
    required double currentLat,
    required double currentLng,
    required List<Map<String, dynamic>> remainingPuroks,
    String? configHash,
  }) async {
    try {
      final String proxyUrl = "https://indigo-bear-885857.hostingersite.com/backend/route_optimization.php";
      final response = await _dio.post(
        proxyUrl,
        data: {
          "driver_lat": currentLat,
        },
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => true,
        ),
      );

      if (response.statusCode == 200 && response.data != null && response.data['success'] == true) {
        final Map<String, dynamic> optimizedData = Map<String, dynamic>.from(response.data);
        optimizedData['config_hash'] = configHash;
        
        try {
          await _database.ref('driver_routes/$sessionId/optimized_route').set(optimizedData);
        } catch (fbErr) {
          debugPrint("[ROUTE OPTIMIZATION ERROR] Proxy Firebase sync failed: $fbErr");
        }
        return optimizedData;
      }
      return {'success': false, 'message': 'Proxy server error: ${response.statusCode}'};
    } catch (e) {
      debugPrint("[ROUTE OPTIMIZATION ERROR] Proxy exception: $e");
      return {'success': false, 'message': 'Proxy exception: $e'};
    }
  }
}
