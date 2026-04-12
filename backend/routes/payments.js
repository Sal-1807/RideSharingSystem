// routes/payments.js - Payment processing routes
const express = require('express');
const router  = express.Router();
const db      = require('../config/db');

// ── POST /api/payments ────────────────────────────────────────
// Creates a payment record. Triggers fire automatically:
//   trg_update_trip_status → sets Trip.Status = 'Completed'
//   trg_update_wallet      → deducts wallet balance if mode = 'Wallet'
// Body: { trip_id, passenger_id, amount, payment_mode }
router.post('/', async (req, res) => {
    const { trip_id, passenger_id, amount, payment_mode } = req.body;

    if (!trip_id || !amount || !payment_mode)
        return res.status(400).json({ error: 'trip_id, amount and payment_mode are required' });

    try {
        // Get wallet ID for this passenger (if paying by wallet)
        let walletId = null;
        if (payment_mode === 'Wallet') {
            const [wallets] = await db.execute(
                'SELECT Wallet_ID, Balance FROM Wallet WHERE Passenger_ID = ?',
                [passenger_id]
            );
            if (wallets.length === 0)
                return res.status(400).json({ error: 'Wallet not found' });
            if (wallets[0].Balance < amount)
                return res.status(400).json({ error: 'Insufficient wallet balance' });
            walletId = wallets[0].Wallet_ID;
        }

        // Insert payment — triggers fire automatically here
        const [result] = await db.execute(
            `INSERT INTO Payment (Trip_ID, Wallet_ID, Amount, Payment_Mode, Payment_Status)
             VALUES (?, ?, ?, ?, 'Paid')`,
            [trip_id, walletId, amount, payment_mode]
        );

        res.json({
            success:    true,
            payment_id: result.insertId,
            message:    `Payment of ₹${amount} via ${payment_mode} successful!`
        });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Payment failed: ' + err.message });
    }
});

// ── GET /api/payments/trip/:tripId ────────────────────────────
router.get('/trip/:tripId', async (req, res) => {
    try {
        const [rows] = await db.execute(
            `SELECT py.*, t.Fare, t.Distance, t.Status AS Trip_Status,
                    p.Name AS Passenger_Name, d.Name AS Driver_Name
             FROM Payment py
             JOIN Trip         t  ON py.Trip_ID   = t.Trip_ID
             JOIN Ride_Request rr ON t.Request_ID = rr.Request_ID
             JOIN Passenger    p  ON rr.Passenger_ID = p.Passenger_ID
             JOIN Driver       d  ON t.Driver_ID  = d.Driver_ID
             WHERE py.Trip_ID = ?`,
            [req.params.tripId]
        );
        res.json(rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to fetch payment' });
    }
});

// ── GET /api/payments/all ────────────────────────────────────
router.get('/all', async (req, res) => {
    try {
        const [rows] = await db.execute(
            'SELECT * FROM Payment ORDER BY Payment_ID DESC'
        );
        res.json(rows);
    } catch (err) {
        res.status(500).json({ error: 'Failed to fetch payments' });
    }
});

module.exports = router;
