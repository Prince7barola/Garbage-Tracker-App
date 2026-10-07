<?php
header("Content-Type: application/json");
require_once 'db_config.php';

$start_date = $_GET['start_date'] ?? null;
$end_date = $_GET['end_date'] ?? null;
$driver_id = $_GET['driver_id'] ?? null;
$truck_id = $_GET['truck_id'] ?? null;
$area = $_GET['area'] ?? null;
$status = $_GET['status'] ?? null;

try {
    $trips = [];
    $tableCheck = $conn->query("SHOW TABLES LIKE 'driver_trip_history'");
    if ($tableCheck->rowCount() > 0) {
        $where = ["1=1"];
        $params = [];

        if (!empty($start_date)) {
            $where[] = "DATE(start_time) >= ?";
            $params[] = $start_date;
        }
        if (!empty($end_date)) {
            $where[] = "DATE(start_time) <= ?";
            $params[] = $end_date;
        }
        if (!empty($driver_id) && $driver_id !== 'all') {
            $where[] = "driver_id = ?";
            $params[] = intval($driver_id);
        }
        if (!empty($truck_id) && $truck_id !== 'all') {
            $where[] = "truck_id = ?";
            $params[] = $truck_id;
        }
        if (!empty($area) && $area !== 'all') {
            $where[] = "route_name LIKE ?";
            $params[] = "%" . $area . "%";
        }
        if (!empty($status) && $status !== 'all') {
            $where[] = "UPPER(route_status) = ?";
            $params[] = strtoupper($status);
        }

        $sql = "SELECT * FROM driver_trip_history WHERE " . implode(" AND ", $where) . " ORDER BY start_time DESC";
        $stmt = $conn->prepare($sql);
        $stmt->execute($params);
        $trips = $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    // Also fetch driver_routes table if present
    $driverRoutesCheck = $conn->query("SHOW TABLES LIKE 'driver_routes'");
    if ($driverRoutesCheck->rowCount() > 0) {
        $drWhere = ["1=1"];
        $drParams = [];
        if (!empty($start_date)) {
            $drWhere[] = "route_date >= ?";
            $drParams[] = $start_date;
        }
        if (!empty($end_date)) {
            $drWhere[] = "route_date <= ?";
            $drParams[] = $end_date;
        }
        if (!empty($driver_id) && $driver_id !== 'all') {
            $drWhere[] = "driver_id = ?";
            $drParams[] = intval($driver_id);
        }
        if (!empty($status) && $status !== 'all') {
            $drWhere[] = "UPPER(route_status) = ?";
            $drParams[] = strtoupper($status);
        }

        $sqlDR = "SELECT route_id as trip_id, driver_id, route_name, route_date, total_distance_km, total_stops as detected_stops_count, route_status, created_at as start_time FROM driver_routes WHERE " . implode(" AND ", $drWhere) . " ORDER BY created_at DESC";
        $stmtDR = $conn->prepare($sqlDR);
        $stmtDR->execute($drParams);
        $legacyRoutes = $stmtDR->fetchAll(PDO::FETCH_ASSOC);

        // Merge without duplicates
        $existingIds = array_column($trips, 'trip_id');
        foreach ($legacyRoutes as $lr) {
            if (!in_array($lr['trip_id'], $existingIds)) {
                $trips[] = $lr;
            }
        }
    }

    echo json_encode([
        "success" => true,
        "count" => count($trips),
        "trips" => $trips
    ]);

} catch (PDOException $e) {
    echo json_encode(["success" => false, "message" => "Database Error: " . $e->getMessage()]);
}
?>
