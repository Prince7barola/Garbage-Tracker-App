# Service Area Data and Route Optimization Fix

Comprehensive fix for service area dataset configuration, coordinate verification, route optimization logic, admin management, and map rendering for Barangay Balintawak, Lipa City, Batangas.

## User Review Required

> [!IMPORTANT]
> - **Canonical Service Area Dataset**: Standardized to the 11 documented Barangay Balintawak areas:
>   - **7 Garbage Truck Collection Stops** (`isTruckStop = true`): Central (Purok 1), Purok Paraiso, Riverside, T.M. Kalaw Street, Ayala Highway (Almaris to Apat Grill), Brixton Homes, El Pueblo.
>   - **4 Stationary Street-Sweeping Assignments** (`isTruckStop = false`): San Nicolas, Paraiso (Street Sweeping), Purok 2, Purok 3.
> - **Stationary Sweeping Exclusion**: Stationary sweeping locations are excluded from truck collection route optimization unless explicitly configured as truck stops.
> - **Road-Network Optimization**: Route optimization uses Mapbox Matrix & Directions APIs to compute travel time/distance along road networks and solve stop order via a heuristic Traveling Salesperson/Nearest-Neighbor solver.
> - **GPS Route Distinction**: Planned optimized routes (`optimized_route`) are rendered distinctly (dashed blue road line) and never overwrite actual driver GPS history (`route`).

## Proposed Changes

### Service Area Data Layer

#### [service_area_service.dart](file:///C:/xampp/htdocs/DITO-MUNA-master/lib/services/service_area_service.dart)

- Define canonical 11 Balintawak service areas with verified road network/entrance coordinates.
- Purge any spurious or undocumented Puroks (e.g. Purok 4..8, Sentro, Dos Riles, San Isidro) on initialization/reset without deleting trip history.
- Filter `getTruckCollectionStops()` to return only verified truck collection stops (`isTruckStop == true` and `verificationStatus == 'VERIFIED'`).
- Filter `getStationarySweepingAreas()` for sweeping assignments (`isTruckStop == false`).

#### [geofence_service.dart](file:///C:/xampp/htdocs/DITO-MUNA-master/lib/services/geofence_service.dart)

- Filter out stationary sweeping areas (`isTruckStop == false`) from triggering truck collection arrival alerts.

---

### Route Optimization Layer

#### [route_optimization_service.dart](file:///C:/xampp/htdocs/DITO-MUNA-master/lib/services/route_optimization_service.dart)

- Exclude stationary sweeping assignments and `UNVERIFIED` service areas from truck route calculations.
- Use Mapbox Driving Matrix API for road-network travel matrix calculations from active truck position.
- Solve stop sequence using heuristic road-matrix Nearest-Neighbor solver.
- Fetch road geometry via Mapbox Directions API and format GeoJSON as `[longitude, latitude]`.
- Return clear warning/error payloads when coordinates are unverified or API failures occur instead of fake results.

---

### UI & Dashboard Integration

#### [driver_dashboard.dart](file:///C:/xampp/htdocs/DITO-MUNA-master/lib/screens/driver_dashboard.dart)

- Load truck collection stops from `ServiceAreaService`.
- Correct initial `_totalPuroks` state to match active collection stops.
- Update UI labels to accurately describe "Heuristic Road-Network Route Optimization".

#### [analytics_screen.dart](file:///C:/xampp/htdocs/DITO-MUNA-master/lib/screens/analytics_screen.dart)

- Synchronize `_purokNames` with the official 11 documented service areas.
- Fix bar chart array indexing for the 11 documented locations.

#### [resident_register.dart](file:///C:/xampp/htdocs/DITO-MUNA-master/lib/screens/resident_register.dart) & [resident_settings_screen.dart](file:///C:/xampp/htdocs/DITO-MUNA-master/lib/screens/resident_settings_screen.dart) & [data_management_modal.dart](file:///C:/xampp/htdocs/DITO-MUNA-master/lib/widgets/data_management_modal.dart)

- Update dropdown options to use official documented service area names (including `Paraiso (Street Sweeping)`).

#### [prediction_engine.dart](file:///C:/xampp/htdocs/DITO-MUNA-master/lib/utils/prediction_engine.dart) & [export_report.php](file:///C:/xampp/htdocs/DITO-MUNA-master/backend/export_report.php)

- Update service area maps/arrays to align with the 11 documented locations.

---

### Admin Management

#### [admin_settings_screen.dart](file:///C:/xampp/htdocs/DITO-MUNA-master/lib/screens/admin_settings_screen.dart)

- Allow viewing all 11 documented service areas, reviewing coordinates and verification status (`VERIFIED`/`UNVERIFIED`).
- Provide coordinate editing, `isTruckStop` toggle, truck assignment, and reloading Balintawak defaults without affecting trip history.
- Validate input coordinates (range -90..90, -180..180, non-zero).

## Verification Plan

### Automated Tests
- Run `flutter test` or Dart syntax checks on updated files if test suite is configured.
- Execute standalone verification script to test Mapbox Matrix & Directions routing and coordinate validation.

### Manual Verification
- Verify database node `puroks` contains only the 11 documented Balintawak locations.
- Verify Central is named `Central (Purok 1)`.
- Verify stationary sweeping locations (San Nicolas, Paraiso, Purok 2, Purok 3) are excluded from truck collection route optimization.
- Verify route optimization generates road-following geometry between stops.
- Verify actual driver GPS history is stored in `driver_routes/$sessionId/route` while planned route is stored in `driver_routes/$sessionId/optimized_route`.
- Verify admin interface can view, edit, and reset Balintawak service areas.
