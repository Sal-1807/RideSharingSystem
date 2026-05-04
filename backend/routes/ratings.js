// routes/ratings.js - Rating and review routes
const express = require('express');
const router  = express.Router();
const db      = require('../config/db');

// ── POST /api/ratings ─────────────────────────────────────────
// Passenger rates a driver. passenger_rating (driver rates passenger) is left NULL
// and filled separately via PATCH below.
// Body: { trip_id, passenger_id, driver_id, driver_rating, comments }
router.post('/', async (req, res) => {
    const { trip_id, passenger_id, driver_id, driver_rating, comments } = req.body;

    if (!trip_id || !passenger_id || !driver_id)
        return res.status(400).json({ error: 'trip_id, passenger_id and driver_id are required' });

    if (!driver_rating || driver_rating < 1 || driver_rating > 5)
        return res.status(400).json({ error: 'Driver rating must be between 1 and 5' });

    try {
        const [existing] = await db.execute(
            'SELECT Rating_ID, Driver_Rating FROM Rating_Review WHERE Trip_ID = ? AND Passenger_ID = ?',
            [trip_id, passenger_id]
        );

        let ratingId;
        if (existing.length > 0) {
            if (existing[0].Driver_Rating !== null)
                return res.status(409).json({ error: 'You have already rated this trip' });
            // Driver rated first — update Driver_Rating and Comments
            await db.execute(
                'UPDATE Rating_Review SET Driver_Rating = ?, Comments = ? WHERE Rating_ID = ?',
                [driver_rating, comments || '', existing[0].Rating_ID]
            );
            ratingId = existing[0].Rating_ID;
        } else {
            const [result] = await db.execute(
                `INSERT INTO Rating_Review
                 (Trip_ID, Passenger_ID, Driver_ID, Passenger_Rating, Driver_Rating, Comments)
                 VALUES (?, ?, ?, NULL, ?, ?)`,
                [trip_id, passenger_id, driver_id, driver_rating, comments || '']
            );
            ratingId = result.insertId;
        }

        res.json({
            success:   true,
            rating_id: ratingId,
            message:   'Rating submitted successfully!'
        });
    } catch (err) {
        console.error(err);
        if (err.sqlState === '45000')
            return res.status(400).json({ error: err.message });
        res.status(500).json({ error: 'Failed to submit rating' });
    }
});

// ── PATCH /api/ratings/trip/:tripId/passenger ─────────────────
// Driver rates a passenger on a completed trip (independent of whether passenger has rated)
// Body: { driver_id, passenger_rating }
router.patch('/trip/:tripId/passenger', async (req, res) => {
    const { driver_id, passenger_rating } = req.body;

    if (!driver_id || !passenger_rating || passenger_rating < 1 || passenger_rating > 5)
        return res.status(400).json({ error: 'driver_id and a rating between 1–5 are required' });

    try {
        // Verify driver owns this trip and get passenger_id
        const [trips] = await db.execute(
            `SELECT t.Trip_ID, rr.Passenger_ID
             FROM Trip t
             JOIN Ride_Request rr ON t.Request_ID = rr.Request_ID
             WHERE t.Trip_ID = ? AND t.Driver_ID = ?`,
            [req.params.tripId, driver_id]
        );
        if (!trips.length)
            return res.status(403).json({ error: 'You are not the driver for this trip' });

        const passengerId = trips[0].Passenger_ID;

        const [existing] = await db.execute(
            'SELECT Rating_ID, Passenger_Rating FROM Rating_Review WHERE Trip_ID = ?',
            [req.params.tripId]
        );

        if (existing.length > 0) {
            if (existing[0].Passenger_Rating !== null)
                return res.status(409).json({ error: 'You have already rated this passenger' });
            await db.execute(
                'UPDATE Rating_Review SET Passenger_Rating = ? WHERE Trip_ID = ?',
                [passenger_rating, req.params.tripId]
            );
        } else {
            // Driver rates first — insert row with Driver_Rating NULL (passenger fills later)
            await db.execute(
                `INSERT INTO Rating_Review
                 (Trip_ID, Passenger_ID, Driver_ID, Passenger_Rating, Driver_Rating, Comments)
                 VALUES (?, ?, ?, ?, NULL, '')`,
                [req.params.tripId, passengerId, driver_id, passenger_rating]
            );
        }

        res.json({ success: true, message: 'Passenger rated successfully!' });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to rate passenger' });
    }
});

// ── GET /api/ratings/driver/:driverId ────────────────────────
router.get('/driver/:driverId', async (req, res) => {
    try {
        const [rows] = await db.execute(
            `SELECT rr.*, p.Name AS Passenger_Name
             FROM Rating_Review rr
             JOIN Passenger p ON rr.Passenger_ID = p.Passenger_ID
             WHERE rr.Driver_ID = ?
             ORDER BY rr.Rating_ID DESC`,
            [req.params.driverId]
        );
        const avg = rows.length
            ? (rows.reduce((s, r) => s + (r.Driver_Rating || 0), 0) / rows.length).toFixed(2)
            : null;
        res.json({ ratings: rows, average: avg });
    } catch (err) {
        res.status(500).json({ error: 'Failed to fetch ratings' });
    }
});

// ── GET /api/ratings/trip/:tripId ────────────────────────────
router.get('/trip/:tripId', async (req, res) => {
    try {
        const [rows] = await db.execute(
            'SELECT * FROM Rating_Review WHERE Trip_ID = ?',
            [req.params.tripId]
        );
        res.json(rows);
    } catch (err) {
        res.status(500).json({ error: 'Failed to fetch rating' });
    }
});

// ── GET /api/ratings/view ─────────────────────────────────────
// Uses Trip_Ratings view (Chapter 3.6)
router.get('/view', async (req, res) => {
    try {
        const [rows] = await db.execute('SELECT * FROM Trip_Ratings');
        res.json(rows);
    } catch (err) {
        res.status(500).json({ error: 'Failed to fetch ratings view' });
    }
});

module.exports = router;
