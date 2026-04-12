// routes/locations.js - Location lookup routes
const express = require('express');
const router  = express.Router();
const db      = require('../config/db');

// ── GET /api/locations ────────────────────────────────────────
router.get('/', async (req, res) => {
    try {
        const [rows] = await db.execute(
            'SELECT * FROM Location ORDER BY Location_ID ASC'
        );
        res.json(rows);
    } catch (err) {
        res.status(500).json({ error: 'Failed to fetch locations' });
    }
});

// ── GET /api/locations/vehicle-types ─────────────────────────
router.get('/vehicle-types', async (req, res) => {
    try {
        const [rows] = await db.execute('SELECT * FROM Vehicle_Type');
        res.json(rows);
    } catch (err) {
        res.status(500).json({ error: 'Failed to fetch vehicle types' });
    }
});

module.exports = router;
