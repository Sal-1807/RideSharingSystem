// routes/ratings.js - Rating and review routes
const express = require('express');
const router  = express.Router();
const db      = require('../config/db');

// ── POST /api/ratings ─────────────────────────────────────────
// Trigger trg_check_rating fires to validate rating range (1–5)
// Body: { trip_id, passenger_id, driver_id, passenger_rating, driver_rating, comments }
router.post('/', async (req, res) => {
    const { trip_id, passenger_id, driver_id, passenger_rating, driver_rating, comments } = req.body;

    if (!trip_id || !passenger_id || !driver_id)
        return res.status(400).json({ error: 'trip_id, passenger_id and driver_id are required' });

    // Client-side validation (trigger also enforces this server-side)
    if (passenger_rating < 1 || passenger_rating > 5 || driver_rating < 1 || driver_rating > 5)
        return res.status(400).json({ error: 'Ratings must be between 1 and 5' });

    try {
        // Check if already rated
        const [existing] = await db.execute(
            'SELECT Rating_ID FROM Rating_Review WHERE Trip_ID = ? AND Passenger_ID = ?',
            [trip_id, passenger_id]
        );
        if (existing.length > 0)
            return res.status(409).json({ error: 'You have already rated this trip' });

        const [result] = await db.execute(
            `INSERT INTO Rating_Review
             (Trip_ID, Passenger_ID, Driver_ID, Passenger_Rating, Driver_Rating, Comments)
             VALUES (?, ?, ?, ?, ?, ?)`,
            [trip_id, passenger_id, driver_id, passenger_rating, driver_rating, comments || '']
        );

        res.json({
            success:   true,
            rating_id: result.insertId,
            message:   'Rating submitted successfully!'
        });
    } catch (err) {
        console.error(err);
        // MySQL trigger violations come through as ER_SIGNAL_EXCEPTION
        if (err.sqlState === '45000')
            return res.status(400).json({ error: err.message });
        res.status(500).json({ error: 'Failed to submit rating' });
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
