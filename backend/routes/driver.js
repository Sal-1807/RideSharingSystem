// routes/driver.js - All driver-specific API routes
const express = require('express');
const router  = express.Router();
const db      = require('../config/db');

// ── GET /api/driver/profile/:id ──────────────────────────────
router.get('/profile/:id', async (req, res) => {
    try {
        const [rows] = await db.execute(
            `SELECT d.Driver_ID, d.Name, d.Phone, d.Email, d.License_No, d.Is_Available,
                    v.Model, v.Registration_No, vt.Type_Name AS Vehicle_Type
             FROM Driver d
             LEFT JOIN Vehicle      v  ON v.Driver_ID = d.Driver_ID
             LEFT JOIN Vehicle_Type vt ON vt.Vehicle_Type_ID = v.Vehicle_Type_ID
             WHERE d.Driver_ID = ?`,
            [req.params.id]
        );
        if (rows.length === 0) return res.status(404).json({ error: 'Driver not found' });
        res.json(rows[0]);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to fetch profile' });
    }
});

// ── GET /api/driver/pending-rides ────────────────────────────
// Returns Pending ride requests matching the driver's vehicle type
router.get('/pending-rides', async (req, res) => {
    const { driver_id } = req.query;
    try {
        const [rows] = await db.execute(
            `SELECT
                rr.Request_ID,
                rr.Passenger_ID,
                p.Name      AS Passenger_Name,
                p.Phone     AS Passenger_Phone,
                rr.Request_Time,
                pl.Address  AS Pickup_Address,
                pl.City     AS Pickup_City,
                dl.Address  AS Drop_Address,
                dl.City     AS Drop_City,
                vt.Type_Name   AS Requested_Vehicle_Type,
                vt.Price_Per_KM
             FROM Ride_Request rr
             JOIN Passenger    p  ON rr.Passenger_ID       = p.Passenger_ID
             JOIN Location     pl ON rr.Pickup_Location_ID = pl.Location_ID
             JOIN Location     dl ON rr.Drop_Location_ID   = dl.Location_ID
             JOIN Vehicle_Type vt ON rr.Vehicle_Type_ID    = vt.Vehicle_Type_ID
             WHERE rr.Status = 'Pending'
               AND (? IS NULL OR rr.Vehicle_Type_ID = (
                 SELECT v.Vehicle_Type_ID FROM Vehicle v WHERE v.Driver_ID = ? LIMIT 1
               ))
             ORDER BY rr.Request_Time ASC`,
            [driver_id || null, driver_id || null]
        );
        res.json(rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to fetch pending rides' });
    }
});

// ── POST /api/driver/accept-ride ─────────────────────────────
// Driver accepts a ride request → creates a Trip record
// Body: { driver_id, request_id }
router.post('/accept-ride', async (req, res) => {
    const { driver_id, request_id } = req.body;

    if (!driver_id || !request_id)
        return res.status(400).json({ error: 'driver_id and request_id are required' });

    try {
        // Get driver's vehicle
        const [vehicles] = await db.execute(
            'SELECT Vehicle_ID FROM Vehicle WHERE Driver_ID = ? LIMIT 1',
            [driver_id]
        );
        if (vehicles.length === 0)
            return res.status(400).json({ error: 'Driver has no vehicle registered' });

        const vehicleId = vehicles[0].Vehicle_ID;

        // Create trip record
        const [tripResult] = await db.execute(
            `INSERT INTO Trip (Request_ID, Driver_ID, Vehicle_ID, Start_Time, Status)
             VALUES (?, ?, ?, NOW(), 'Accepted')`,
            [request_id, driver_id, vehicleId]
        );

        // Update ride request status
        await db.execute(
            "UPDATE Ride_Request SET Status = 'Accepted' WHERE Request_ID = ?",
            [request_id]
        );

        // Mark driver as unavailable
        await db.execute(
            'UPDATE Driver SET Is_Available = 0 WHERE Driver_ID = ?',
            [driver_id]
        );

        res.json({
            success: true,
            trip_id: tripResult.insertId,
            message: 'Ride accepted! Trip has started.'
        });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to accept ride' });
    }
});

// ── POST /api/driver/start-trip/:tripId ──────────────────────
router.post('/start-trip/:tripId', async (req, res) => {
    try {
        await db.execute(
            "UPDATE Trip SET Status = 'Ongoing', Start_Time = NOW() WHERE Trip_ID = ?",
            [req.params.tripId]
        );
        // Update ride request too
        await db.execute(
            `UPDATE Ride_Request SET Status = 'Ongoing'
             WHERE Request_ID = (SELECT Request_ID FROM Trip WHERE Trip_ID = ?)`,
            [req.params.tripId]
        );
        res.json({ success: true, message: 'Trip started!' });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to start trip' });
    }
});

// ── POST /api/driver/end-trip/:tripId ────────────────────────
// Body: { distance }  — fare calculated as Rs.15 per km, min Rs.50
router.post('/end-trip/:tripId', async (req, res) => {
    const { distance } = req.body;
    const dist = parseFloat(distance) || 5.0;

    try {
        const [tripRows] = await db.execute(
            `SELECT t.Driver_ID, vt.Price_Per_KM, vt.Min_Fare
             FROM Trip t
             JOIN Vehicle      v  ON t.Vehicle_ID      = v.Vehicle_ID
             JOIN Vehicle_Type vt ON v.Vehicle_Type_ID = vt.Vehicle_Type_ID
             WHERE t.Trip_ID = ?`,
            [req.params.tripId]
        );
        if (tripRows.length === 0)
            return res.status(404).json({ error: 'Trip not found' });

        const rate    = parseFloat(tripRows[0].Price_Per_KM) || 15.00;
        const minFare = parseFloat(tripRows[0].Min_Fare)     || 50.00;
        const fare    = Math.max(minFare, dist * rate).toFixed(2);

        await db.execute(
            `UPDATE Trip
             SET Status = 'Completed', End_Time = NOW(), Distance = ?, Fare = ?
             WHERE Trip_ID = ?`,
            [dist, fare, req.params.tripId]
        );

        // Update ride request status
        await db.execute(
            `UPDATE Ride_Request SET Status = 'Completed'
             WHERE Request_ID = (SELECT Request_ID FROM Trip WHERE Trip_ID = ?)`,
            [req.params.tripId]
        );

        // Mark driver available again
        await db.execute(
            'UPDATE Driver SET Is_Available = 1 WHERE Driver_ID = ?',
            [tripRows[0].Driver_ID]
        );

        // Insert route details
        await db.execute(
            `INSERT IGNORE INTO Route_Details
             (Trip_ID, Route_No, Distance_KM, Duration_Min)
             VALUES (?, 1, ?, ?)`,
            [req.params.tripId, dist, Math.ceil(dist * 3)]  // estimate ~3 min/km
        );

        res.json({
            success:  true,
            fare:     parseFloat(fare),
            distance: dist,
            message:  `Trip ended! Fare: ₹${fare}`
        });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to end trip' });
    }
});

// ── GET /api/driver/trips/:driverId ──────────────────────────
// Driver's full trip history with passenger names (JOIN)
router.get('/trips/:driverId', async (req, res) => {
    try {
        const [rows] = await db.execute(
            `SELECT
                t.Trip_ID,
                t.Start_Time,
                t.End_Time,
                t.Distance,
                t.Fare,
                t.Status,
                p.Name      AS Passenger_Name,
                p.Phone     AS Passenger_Phone,
                pl.Address  AS Pickup_Address,
                dl.Address  AS Drop_Address,
                vt.Type_Name AS Vehicle_Type,
                vt.Price_Per_KM,
                rat.Rating_ID,
                rat.Passenger_Rating
             FROM Trip t
             JOIN Ride_Request rr ON t.Request_ID          = rr.Request_ID
             JOIN Passenger    p  ON rr.Passenger_ID       = p.Passenger_ID
             JOIN Location     pl ON rr.Pickup_Location_ID = pl.Location_ID
             JOIN Location     dl ON rr.Drop_Location_ID   = dl.Location_ID
             JOIN Vehicle      v  ON t.Vehicle_ID          = v.Vehicle_ID
             JOIN Vehicle_Type vt ON v.Vehicle_Type_ID     = vt.Vehicle_Type_ID
             LEFT JOIN Rating_Review rat ON rat.Trip_ID    = t.Trip_ID
             WHERE t.Driver_ID = ?
             ORDER BY t.Start_Time DESC`,
            [req.params.driverId]
        );
        res.json(rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to fetch trips' });
    }
});

// ── GET /api/driver/ratings/:driverId ────────────────────────
router.get('/ratings/:driverId', async (req, res) => {
    try {
        const [rows] = await db.execute(
            `SELECT rr.Rating_ID, rr.Driver_Rating, rr.Passenger_Rating,
                    rr.Comments, p.Name AS Passenger_Name, t.Trip_ID
             FROM Rating_Review rr
             JOIN Passenger p ON rr.Passenger_ID = p.Passenger_ID
             JOIN Trip      t ON rr.Trip_ID      = t.Trip_ID
             WHERE rr.Driver_ID = ?
             ORDER BY rr.Rating_ID DESC`,
            [req.params.driverId]
        );

        // Average rating
        const avg = rows.length
            ? (rows.reduce((s, r) => s + (r.Driver_Rating || 0), 0) / rows.length).toFixed(2)
            : 'N/A';

        res.json({ ratings: rows, average_rating: avg });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to fetch ratings' });
    }
});

// ── GET /api/driver/earnings/:driverId ───────────────────────
// Total earnings = SUM of fares (aggregate function)
router.get('/earnings/:driverId', async (req, res) => {
    try {
        const [rows] = await db.execute(
            `SELECT
                COUNT(*)       AS Total_Trips,
                SUM(Fare)      AS Total_Earnings,
                AVG(Fare)      AS Avg_Fare,
                MAX(Fare)      AS Max_Fare,
                MIN(Fare)      AS Min_Fare
             FROM Trip
             WHERE Driver_ID = ? AND Status = 'Completed'`,
            [req.params.driverId]
        );
        res.json(rows[0]);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to fetch earnings' });
    }
});

module.exports = router;
