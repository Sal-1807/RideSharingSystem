// routes/trips.js - Trip analytics and detail routes
const express = require('express');
const router  = express.Router();
const db      = require('../config/db');

// ── GET /api/trips/:tripId ────────────────────────────────────
router.get('/:tripId', async (req, res) => {
    try {
        const [rows] = await db.execute(
            `SELECT t.*, d.Name AS Driver_Name, d.Phone AS Driver_Phone,
                    p.Name AS Passenger_Name,
                    pl.Address AS Pickup_Address, pl.City AS Pickup_City,
                    dl.Address AS Drop_Address,   dl.City AS Drop_City
             FROM Trip t
             JOIN Ride_Request rr ON t.Request_ID = rr.Request_ID
             JOIN Driver       d  ON t.Driver_ID  = d.Driver_ID
             JOIN Passenger    p  ON rr.Passenger_ID = p.Passenger_ID
             JOIN Location     pl ON rr.Pickup_Location_ID = pl.Location_ID
             JOIN Location     dl ON rr.Drop_Location_ID   = dl.Location_ID
             WHERE t.Trip_ID = ?`,
            [req.params.tripId]
        );
        if (rows.length === 0) return res.status(404).json({ error: 'Trip not found' });
        res.json(rows[0]);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to fetch trip' });
    }
});

// ── GET /api/trips/analytics/driver-trips ────────────────────
// Total trips per driver – Aggregate Function (Chapter 3.2)
router.get('/analytics/driver-trips', async (req, res) => {
    try {
        const [rows] = await db.execute(
            `SELECT d.Driver_ID, d.Name AS Driver_Name,
                    COUNT(t.Trip_ID) AS Total_Trips
             FROM Driver d
             LEFT JOIN Trip t ON d.Driver_ID = t.Driver_ID
             GROUP BY d.Driver_ID, d.Name
             ORDER BY Total_Trips DESC`
        );
        res.json(rows);
    } catch (err) {
        res.status(500).json({ error: 'Failed to fetch driver trip counts' });
    }
});

// ── GET /api/trips/analytics/avg-fare ────────────────────────
// Average fare – Aggregate Function (Chapter 3.2)
router.get('/analytics/avg-fare', async (req, res) => {
    try {
        const [[row]] = await db.execute('SELECT AVG(Fare) AS Avg_Fare FROM Trip');
        res.json({ avg_fare: row.Avg_Fare ? parseFloat(row.Avg_Fare).toFixed(2) : 0 });
    } catch (err) {
        res.status(500).json({ error: 'Failed to fetch average fare' });
    }
});

// ── GET /api/trips/analytics/distance ────────────────────────
// Max and Min trip distance – Aggregate Function (Chapter 3.2)
router.get('/analytics/distance', async (req, res) => {
    try {
        const [[row]] = await db.execute(
            'SELECT MAX(Distance_KM) AS Max_Distance, MIN(Distance_KM) AS Min_Distance FROM Route_Details'
        );
        res.json(row);
    } catch (err) {
        res.status(500).json({ error: 'Failed to fetch distance stats' });
    }
});

// ── GET /api/trips/analytics/driver-earnings ─────────────────
// Total earnings per driver – JOIN + GROUP BY (Chapter 3.5)
router.get('/analytics/driver-earnings', async (req, res) => {
    try {
        const [rows] = await db.execute(
            `SELECT d.Name AS Driver_Name, SUM(t.Fare) AS Total_Earnings
             FROM Trip t
             JOIN Driver d ON t.Driver_ID = d.Driver_ID
             GROUP BY d.Driver_ID, d.Name
             ORDER BY Total_Earnings DESC`
        );
        res.json(rows);
    } catch (err) {
        res.status(500).json({ error: 'Failed to fetch driver earnings' });
    }
});

// ── GET /api/trips/analytics/above-avg ───────────────────────
// Trips with fare above average – Subquery (Chapter 3.4)
router.get('/analytics/above-avg', async (req, res) => {
    try {
        const [rows] = await db.execute(
            `SELECT t.Trip_ID, t.Fare, d.Name AS Driver_Name,
                    p.Name AS Passenger_Name
             FROM Trip t
             JOIN Ride_Request rr ON t.Request_ID = rr.Request_ID
             JOIN Driver       d  ON t.Driver_ID  = d.Driver_ID
             JOIN Passenger    p  ON rr.Passenger_ID = p.Passenger_ID
             WHERE t.Fare > (SELECT AVG(Fare) FROM Trip)
             ORDER BY t.Fare DESC`
        );
        res.json(rows);
    } catch (err) {
        res.status(500).json({ error: 'Failed to fetch above-average trips' });
    }
});

// ── GET /api/trips/analytics/long-trips ──────────────────────
// Trips > 15 km OR fare > 300 – UNION set operation (Chapter 3.3)
router.get('/analytics/long-trips', async (req, res) => {
    try {
        const [rows] = await db.execute(
            `SELECT Trip_ID FROM Route_Details WHERE Distance_KM > 15
             UNION
             SELECT Trip_ID FROM Trip WHERE Fare > 300`
        );
        res.json(rows);
    } catch (err) {
        res.status(500).json({ error: 'Failed to fetch long trips' });
    }
});

module.exports = router;
