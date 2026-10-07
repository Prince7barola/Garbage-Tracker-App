import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size, Visibility;
import '../utils/session_manager.dart';
import '../models/user.dart';
import '../models/driver_trip.dart';
import '../services/driver_route_history_service.dart';
import '../utils/app_theme.dart';
import '../utils/responsive.dart';
import '../api/api_service.dart';

class RouteHistoryScreen extends StatefulWidget {
  final bool isEmbedded;
  final VoidCallback? onBack;

  const RouteHistoryScreen({
    super.key,
    this.isEmbedded = false,
    this.onBack,
  });

  @override
  State<RouteHistoryScreen> createState() => _RouteHistoryScreenState();
}

class _RouteHistoryScreenState extends State<RouteHistoryScreen> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  UserData? _currentUser;
  bool _isLoadingUser = true;
  bool _isLoadingTrips = false;

  List<DriverTrip> _trips = [];
  DriverTrip? _selectedTrip;
  DriverTrip? _analyzedTrip;

  // Filter state
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedDriverId = "all";
  String _selectedTruckId = "all";
  String _selectedArea = "all";
  String _selectedStatus = "all";

  // Dropdown options
  List<Map<String, String>> _driverOptions = [
    {"id": "all", "name": "All Drivers"}
  ];
  List<Map<String, String>> _truckOptions = [
    {"id": "all", "name": "All Trucks"}
  ];
  final List<String> _areaOptions = [
    "all", "Purok 1", "Purok 2", "Purok 3", "Purok 4", "Purok 5", "Purok 6", "Purok 7", "San Nicolas"
  ];
  final List<String> _statusOptions = [
    "all", "COMPLETED", "ACTIVE", "PAUSED"
  ];

  // Mapbox controller state
  MapboxMap? _mapboxMap;
  bool _isMapReady = false;
  bool _isUpdatingPolyline = false;

  // Replay Control state
  bool _isReplaying = false;
  double _replayProgress = 0.0; // 0.0 to 1.0
  int _replaySpeedMultiplier = 1; // 1x, 2x, 5x, 10x
  Timer? _replayTimer;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now().subtract(const Duration(days: 7));
    _endDate = DateTime.now();
    _loadUserAndData();
  }

  @override
  void dispose() {
    _replayTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserAndData() async {
    setState(() => _isLoadingUser = true);
    final user = await SessionManager.getUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
        _isLoadingUser = false;
      });
      if (_currentUser != null && _currentUser!.role.toLowerCase() != 'resident') {
        _loadFilterOptions();
        _fetchTrips();
      }
    }
  }

  Future<void> _loadFilterOptions() async {
    try {
      final response = await _apiService.getUsers();
      if (response.data['success'] == true) {
        final List rawUsers = response.data['users'] ?? [];
        final List<Map<String, String>> drivers = [
          {"id": "all", "name": "All Drivers"}
        ];
        final List<Map<String, String>> trucks = [
          {"id": "all", "name": "All Trucks"}
        ];
        final Set<String> seenTrucks = {};

        for (var u in rawUsers) {
          if (u is Map) {
            final String role = (u['role'] ?? '').toString().toLowerCase();
            if (role == 'driver') {
              drivers.add({
                "id": u['user_id'].toString(),
                "name": (u['name'] ?? u['username'] ?? 'Driver').toString(),
              });
              final String t = (u['preferred_truck'] ?? '').toString();
              if (t.isNotEmpty && !seenTrucks.contains(t)) {
                seenTrucks.add(t);
                trucks.add({"id": t, "name": t});
              }
            }
          }
        }
        if (mounted) {
          setState(() {
            _driverOptions = drivers;
            _truckOptions = trucks;
          });
        }
      }
    } catch (e) {
      debugPrint("[ROUTE HISTORY] Error loading filter options: $e");
    }
  }

  Future<void> _fetchTrips() async {
    if (_currentUser == null) return;
    setState(() => _isLoadingTrips = true);

    final trips = await DriverRouteHistoryService.fetchRouteHistory(
      currentUser: _currentUser!,
      startDate: _startDate,
      endDate: _endDate,
      selectedDriverId: _selectedDriverId,
      selectedTruckId: _selectedTruckId,
      selectedArea: _selectedArea,
      selectedStatus: _selectedStatus,
    );

    if (mounted) {
      setState(() {
        _trips = trips;
        _isLoadingTrips = false;
        if (_trips.isNotEmpty) {
          _selectTrip(_trips.first);
        } else {
          _selectedTrip = null;
          _analyzedTrip = null;
        }
      });
    }
  }

  void _selectTrip(DriverTrip trip) {
    _replayTimer?.cancel();
    final analyzed = DriverRouteHistoryService.analyzeTrip(trip);
    setState(() {
      _selectedTrip = trip;
      _analyzedTrip = analyzed;
      _isReplaying = false;
      _replayProgress = 0.0;
    });
    _updateMapForTrip(analyzed);
  }

  void _setDatePreset(String preset) {
    final now = DateTime.now();
    setState(() {
      if (preset == 'today') {
        _startDate = DateTime(now.year, now.month, now.day);
        _endDate = now;
      } else if (preset == 'yesterday') {
        final y = now.subtract(const Duration(days: 1));
        _startDate = DateTime(y.year, y.month, y.day);
        _endDate = DateTime(y.year, y.month, y.day, 23, 59, 59);
      } else if (preset == 'week') {
        _startDate = now.subtract(const Duration(days: 7));
        _endDate = now;
      }
    });
    _fetchTrips();
  }

  void _toggleReplay() {
    if (_analyzedTrip == null || _analyzedTrip!.points.isEmpty) return;

    if (_isReplaying) {
      _replayTimer?.cancel();
      setState(() => _isReplaying = false);
    } else {
      setState(() => _isReplaying = true);
      const intervalMs = 100;
      _replayTimer?.cancel();
      _replayTimer = Timer.periodic(const Duration(milliseconds: intervalMs), (timer) {
        if (!mounted || _analyzedTrip == null || _analyzedTrip!.points.isEmpty) {
          timer.cancel();
          return;
        }
        setState(() {
          _replayProgress += (0.005 * _replaySpeedMultiplier);
          if (_replayProgress >= 1.0) {
            _replayProgress = 1.0;
            _isReplaying = false;
            timer.cancel();
          }
        });
        _updateReplayMapPosition();
      });
    }
  }

  void _updateReplayMapPosition() async {
    if (_mapboxMap == null || _analyzedTrip == null || _analyzedTrip!.points.isEmpty) return;
    final points = _analyzedTrip!.points;
    final int idx = ((points.length - 1) * _replayProgress).clamp(0, points.length - 1).toInt();
    final currentP = points[idx];

    try {
      _mapboxMap!.setCamera(CameraOptions(
        center: Point(coordinates: Position(currentP.longitude, currentP.latitude)),
        zoom: 15.0,
      ));
    } catch (_) {}
  }

  // --- MAPBOX MAP CREATION & ROUTE DRAWING ---
  void _onMapCreated(MapboxMap map) {
    _mapboxMap = map;
    _isMapReady = true;
    if (_analyzedTrip != null) {
      _updateMapForTrip(_analyzedTrip!);
    }
  }

  Future<void> _updateMapForTrip(DriverTrip trip) async {
    if (_mapboxMap == null || _isUpdatingPolyline) return;
    _isUpdatingPolyline = true;

    try {
      final style = _mapboxMap!.style;
      const String sourceId = "trip-history-source";
      const String layerId = "trip-history-layer";

      final List<Map<String, dynamic>> features = [];
      final points = trip.points;

      if (points.length >= 2) {
        List<List<double>> currentSegment = [];
        String currentColor = "#4CAF50";

        for (int i = 0; i < points.length; i++) {
          final p = points[i];
          final colorHex = p.status == "PAUSED" || p.status == "IDLE"
              ? "#FFC107" // Amber
              : (p.status == "FULL" ? "#2196F3" : "#4CAF50"); // Blue or Green

          if (p.isGapStart && currentSegment.length >= 2) {
            // Break polyline across data gap
            features.add({
              "type": "Feature",
              "geometry": {
                "type": "LineString",
                "coordinates": List<List<double>>.from(currentSegment)
              },
              "properties": {"color": currentColor}
            });
            currentSegment = [[p.longitude, p.latitude]];
            currentColor = colorHex;
          } else {
            currentSegment.add([p.longitude, p.latitude]);
            currentColor = colorHex;
          }
        }

        if (currentSegment.length >= 2) {
          features.add({
            "type": "Feature",
            "geometry": {
              "type": "LineString",
              "coordinates": List<List<double>>.from(currentSegment)
            },
            "properties": {"color": currentColor}
          });
        }
      }

      final featureCollection = {"type": "FeatureCollection", "features": features};

      if (await style.styleSourceExists(sourceId)) {
        await style.setStyleSourceProperty(sourceId, "data", jsonEncode(featureCollection));
      } else {
        await style.addSource(GeoJsonSource(id: sourceId, data: jsonEncode(featureCollection)));
        if (!(await style.styleLayerExists(layerId))) {
          await style.addLayer(LineLayer(
            id: layerId,
            sourceId: sourceId,
            lineColor: Colors.green.toARGB32(),
            lineWidth: 5.5,
            lineOpacity: 0.9,
            lineCap: LineCap.ROUND,
            lineJoin: LineJoin.ROUND,
          ));
        }
      }

      // Recenter camera over trip start or center
      if (points.isNotEmpty) {
        _mapboxMap?.setCamera(CameraOptions(
          center: Point(coordinates: Position(points.first.longitude, points.first.latitude)),
          zoom: 14.0,
        ));
      }
    } catch (e) {
      debugPrint("[ROUTE HISTORY] Mapbox layer update error: $e");
    } finally {
      _isUpdatingPolyline = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF00897B))),
      );
    }

    if (_currentUser == null || _currentUser!.role.toLowerCase() == 'resident') {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            constraints: const BoxConstraints(maxWidth: 450),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppTheme.balancedPulidongShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded, color: Colors.redAccent, size: 54),
                const SizedBox(height: 16),
                const Text(
                  "Access Restricted",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A)),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Driver Route History is restricted to authorized administrators and drivers.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    if (widget.onBack != null) {
                      widget.onBack!();
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text("Return to Dashboard"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isDesktop = constraints.maxWidth >= 1024;
        bool isMobile = constraints.maxWidth < 600;

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          body: SafeArea(
            child: Column(
              children: [
                _buildTopHeader(isMobile),
                _buildDisclaimerBanner(),
                _buildFilterControls(isMobile),
                Expanded(
                  child: _isLoadingTrips
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF00897B)))
                      : (isDesktop ? _buildDesktopLayout() : _buildMobileTabletLayout(isMobile)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (widget.onBack != null) {
                widget.onBack!();
              } else {
                Navigator.pop(context);
              }
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: Color(0xFFF5F5F5), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1A1A), size: 18),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFE0F2F1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.route_rounded, color: Color(0xFF00796B), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Driver Route History",
                  style: TextStyle(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.w900, color: const Color(0xFF1A1A1A)),
                ),
                Text(
                  "Review recorded GPS trip activities and operational logs",
                  style: TextStyle(fontSize: isMobile ? 11 : 13, color: Colors.grey, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _fetchTrips,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF00796B)),
            tooltip: "Refresh History",
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF8E1),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFFF57F17), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Note: A GPS-detected route or stop indicates vehicle movement and location tracking, but does not independently confirm that waste collection occurred.",
              style: TextStyle(fontSize: 11, color: Color(0xFF5D4037), fontWeight: FontWeight.w600, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterControls(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 12),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Date presets
            OutlinedButton(
              onPressed: () => _setDatePreset('today'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Today", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => _setDatePreset('week'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Past 7 Days", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2025),
                  lastDate: DateTime.now(),
                  initialDateRange: DateTimeRange(start: _startDate ?? DateTime.now().subtract(const Duration(days: 7)), end: _endDate ?? DateTime.now()),
                );
                if (range != null) {
                  setState(() {
                    _startDate = range.start;
                    _endDate = range.end;
                  });
                  _fetchTrips();
                }
              },
              icon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF00796B), size: 20),
              tooltip: "Custom Date Range",
            ),
            const SizedBox(width: 12),
            const VerticalDivider(width: 24, thickness: 1),
            const SizedBox(width: 12),

            // Driver Dropdown (if admin)
            if (_currentUser?.role.toLowerCase() != 'driver') ...[
              _buildDropdownFilter("Driver", _selectedDriverId, _driverOptions.map((d) => DropdownMenuItem(value: d['id'], child: Text(d['name']!))).toList(), (val) {
                if (val != null) {
                  setState(() => _selectedDriverId = val);
                  _fetchTrips();
                }
              }),
              const SizedBox(width: 12),
            ],

            // Truck Dropdown
            _buildDropdownFilter("Truck", _selectedTruckId, _truckOptions.map((t) => DropdownMenuItem(value: t['id'], child: Text(t['name']!))).toList(), (val) {
              if (val != null) {
                setState(() => _selectedTruckId = val);
                _fetchTrips();
              }
            }),
            const SizedBox(width: 12),

            // Area Dropdown
            _buildDropdownFilter("Area", _selectedArea, _areaOptions.map((a) => DropdownMenuItem(value: a, child: Text(a == 'all' ? 'All Areas' : a))).toList(), (val) {
              if (val != null) {
                setState(() => _selectedArea = val);
                _fetchTrips();
              }
            }),
            const SizedBox(width: 12),

            // Status Dropdown
            _buildDropdownFilter("Status", _selectedStatus, _statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s == 'all' ? 'All Statuses' : s))).toList(), (val) {
              if (val != null) {
                setState(() => _selectedStatus = val);
                _fetchTrips();
              }
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownFilter<T>(String label, T currentValue, List<DropdownMenuItem<T>> items, ValueChanged<T?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: currentValue,
          items: items,
          onChanged: onChanged,
          isDense: true,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
        ),
      ),
    );
  }

  // --- DESKTOP LAYOUT (Side-by-side: Trip List 380px left, Map & Details right) ---
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        SizedBox(
          width: 380,
          child: _buildTripListView(),
        ),
        const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFEEEEEE)),
        Expanded(
          child: _analyzedTrip == null ? _buildNoTripSelected() : _buildTripMapAndDetailsView(),
        ),
      ],
    );
  }

  // --- MOBILE / TABLET LAYOUT ---
  Widget _buildMobileTabletLayout(bool isMobile) {
    return _selectedTrip == null
        ? _buildTripListView()
        : Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => setState(() => _selectedTrip = null),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text("Back to Trip List", style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    const Spacer(),
                    Text(_selectedTrip!.tripId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Expanded(child: _buildTripMapAndDetailsView()),
            ],
          );
  }

  Widget _buildTripListView() {
    if (_trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route_outlined, size: 54, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text("No route history trips found", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 4),
            const Text("Try adjusting your date or filter options.", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _trips.length,
      itemBuilder: (context, index) {
        final trip = _trips[index];
        final bool isSelected = _selectedTrip?.tripId == trip.tripId;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: isSelected ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isSelected ? const Color(0xFF00796B) : Colors.grey.shade200, width: isSelected ? 2 : 1),
          ),
          child: InkWell(
            onTap: () => _selectTrip(trip),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: trip.routeStatus == 'COMPLETED' ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          trip.routeStatus,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: trip.routeStatus == 'COMPLETED' ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('MMM d, yyyy').format(trip.startTime),
                        style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    trip.driverName,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF1A1A1A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Truck: ${trip.truckId} | Area: ${trip.routeName}",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF00796B)),
                      const SizedBox(width: 4),
                      Text(
                        "${DateFormat('h:mm a').format(trip.startTime)} - ${trip.endTime != null ? DateFormat('h:mm a').format(trip.endTime!) : 'In Progress'}",
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      if (trip.totalDistanceKm > 0)
                        Text(
                          "${trip.totalDistanceKm.toStringAsFixed(1)} km",
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF00796B)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoTripSelected() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("Select a trip from the list to view route history details", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildTripMapAndDetailsView() {
    final trip = _analyzedTrip!;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Mapbox Map View
          Container(
            height: 380,
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppTheme.balancedPulidongShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  MapWidget(
                    onMapCreated: _onMapCreated,
                  ),
                  // Map Legend Overlay
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Map Legend", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                          SizedBox(height: 6),
                          Row(children: [CircleAvatar(radius: 4, backgroundColor: Colors.green), SizedBox(width: 6), Text("Active Moving", style: TextStyle(fontSize: 10))]),
                          SizedBox(height: 4),
                          Row(children: [CircleAvatar(radius: 4, backgroundColor: Colors.amber), SizedBox(width: 6), Text("Stopped / Idle", style: TextStyle(fontSize: 10))]),
                          SizedBox(height: 4),
                          Row(children: [CircleAvatar(radius: 4, backgroundColor: Colors.blue), SizedBox(width: 6), Text("Truck Full", style: TextStyle(fontSize: 10))]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Replay Control Bar
          if (trip.points.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.balancedPulidongShadow,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _toggleReplay,
                    icon: Icon(_isReplaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: const Color(0xFF00796B), size: 32),
                  ),
                  Expanded(
                    child: Slider(
                      value: _replayProgress,
                      onChanged: (val) {
                        setState(() => _replayProgress = val);
                        _updateReplayMapPosition();
                      },
                      activeColor: const Color(0xFF00796B),
                    ),
                  ),
                  DropdownButton<int>(
                    value: _replaySpeedMultiplier,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text("1x", style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 2, child: Text("2x", style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 5, child: Text("5x", style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 10, child: Text("10x", style: TextStyle(fontSize: 12))),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _replaySpeedMultiplier = val);
                    },
                  ),
                ],
              ),
            ),

          // Summary Metrics Cards
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildMetricTile("Distance", "${trip.totalDistanceKm.toStringAsFixed(1)} km", Icons.straighten_rounded),
                const SizedBox(width: 12),
                _buildMetricTile("Stopped Time", "${(trip.stoppedTimeSeconds / 60).toStringAsFixed(0)} min", Icons.timer_outlined),
                const SizedBox(width: 12),
                _buildMetricTile("Possible Stops", "${trip.detectedStopsCount}", Icons.pin_drop_outlined),
              ],
            ),
          ),

          // Timeline of Driver Events
          if (trip.events.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppTheme.balancedPulidongShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Operational Event Timeline", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: trip.events.length,
                    itemBuilder: (context, idx) {
                      final evt = trip.events[idx];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            const CircleAvatar(radius: 4, backgroundColor: Color(0xFF00796B)),
                            const SizedBox(width: 10),
                            Text(DateFormat('h:mm:ss a').format(evt.timestamp), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(width: 12),
                            Expanded(child: Text(evt.description.isNotEmpty ? evt.description : evt.eventType, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.balancedPulidongShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF00796B), size: 20),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A))),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
