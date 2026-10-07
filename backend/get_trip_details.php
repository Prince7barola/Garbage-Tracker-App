<?php
header("Content-Type: application/json");
require_once 'db_config.php';

$trip_id = $_GET['trip_id'] ?? null;

if (empty($trip_id)) {
    echo json_encode(["success" => false, "message" => "Missing required parameter trip_id"]);
    exit;
}

try {
    $trip = null;
    $points = [];
    $events = [];

    // Query trip metadata
    $historyCheck = $conn->query("SHOW TABLES LIKE 'driver_trip_history'");
    if ($historyCheck->rowCount() > 0) {
        $stmt = $conn->prepare("SELECT * FROM driver_trip_history WHERE trip_id = ?");
        $stmt->execute([$trip_id]);
        $trip = $stmt->fetch(PDO::FETCH_ASSOC);
    }

    if (!$trip) {
        $routesCheck = $conn->query("SHOW TABLES LIKE 'driver_routes'");
        if ($routesCheck->rowCount() > 0) {
            $stmt = $conn->prepare("SELECT route_id as trip_id, driver_id, route_name, route_date, total_distance_km, total_stops as detected_stops_count, route_status, created_at as start_time FROM driver_routes WHERE route_id = ?");
            $stmt->execute([$trip_id]);
            $trip = $stmt->fetch(PDO::FETCH_ASSOC);
        }
    }

    // Query points
    $pointsCheck = $conn->query("SHOW TABLES LIKE 'driver_trip_gps_points'");
    if ($pointsCheck->rowCount() > 0) {
        $pStmt = $conn->prepare("SELECT point_id, trip_id, driver_id, truck_id, latitude, longitude, speed_kmh, heading, accuracy_m, status, recorded_at FROM driver_trip_gps_points WHERE trip_id = ? ORDER BY recorded_at ASC");
        $pStmt->execute([$trip_id]);
        $points = $pStmt->fetchAll(PDO::FETCH_ASSOC);
    }

    // Query events
    $eventsCheck = $conn->query("SHOW TABLES LIKE 'driver_trip_events'");
    if ($eventsCheck->rowCount() > 0) {
        $eStmt = $conn->prepare("SELECT event_id, trip_id, driver_id, event_type, description, latitude, longitude, recorded_at FROM driver_trip_events WHERE trip_id = ? ORDER BY recorded_at ASC");
        $eStmt->execute([$trip_id]);
        $events = $eStmt->fetchAll(PDO::FETCH_ASSOC);
    }

    echo json_encode([
        "success" => true,
        "trip" => $trip,
        "points_count" => count($points),
        "points" => $points,
        "events_count" => count($events),
        "events" => $events
    ]);

} catch (PDOException $e) {
    echo json_encode(["success" => false, "message" => "Database Error: " . $e->getMessage()]);
}
?>
