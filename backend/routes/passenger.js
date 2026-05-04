// routes/passenger.js - All passenger-specific API routes
const express = require('express');
const router  = express.Router();
const db      = require('../config/db');

// ── GET /api/passenger/profile/:id ───────────────────────────
router.get('/profile/:id', async (req, res) => {
    try {
        const [rows] = await db.execute(
            'SELECT Passenger_ID, Name, Phone, Email FROM Passenger WHERE Passenger_ID = ?',
            [req.params.id]
        );
        if (rows.length === 0) return res.status(404).json({ error: 'Passenger not found' });
        res.json(rows[0]);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to fetch profile' });
    }
});

// ── GET /api/passenger/wallet/:passengerId ────────────────────
router.get('/wallet/:passengerId', async (req, res) => {
    try {
        const [rows] = await db.execute(
            'SELECT * FROM Wallet WHERE Passenger_ID = ?',
            [req.params.passengerId]
        );
        if (rows.length === 0) return res.status(404).json({ error: 'Wallet not found' });
        res.json(rows[0]);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to fetch wallet' });
    }
});

// ── POST /api/passenger/ride-request ─────────────────────────
// Passenger creates a new ride request
// Body: { passenger_id, pickup_address, pickup_city, pickup_pincode,
//         drop_address, drop_city, drop_pincode, promo_code }
router.post('/ride-request', async (req, res) => {
    const {
        passenger_id,
        pickup_address, pickup_city, pickup_pincode,
        drop_address,   drop_city,   drop_pincode,
        promo_code,     vehicle_type_id
    } = req.body;

    if (!passenger_id || !pickup_address || !drop_address)
        return res.status(400).json({ error: 'Passenger ID and locations are required' });

    try {
        // Insert pickup location
        const [pickupResult] = await db.execute(
            'INSERT INTO Location (Address, City, Pincode) VALUES (?, ?, ?)',
            [pickup_address, pickup_city || 'Unknown', pickup_pincode || '000000']
        );

        // Insert drop location
        const [dropResult] = await db.execute(
            'INSERT INTO Location (Address, City, Pincode) VALUES (?, ?, ?)',
            [drop_address, drop_city || 'Unknown', drop_pincode || '000000']
        );

        // Validate promo code if provided
        let promoMessage = '';
        if (promo_code) {
            const [promo] = await db.execute(
                'SELECT * FROM Promo_Details WHERE Code = ? AND Expiry_Date >= CURDATE()',
                [promo_code]
            );
            if (promo.length > 0)
                promoMessage = `Promo applied: ${promo[0].Discount_Percentage}% off`;
            else
                promoMessage = 'Invalid or expired promo code';
        }

        // Create ride request
        const [reqResult] = await db.execute(
            `INSERT INTO Ride_Request
             (Passenger_ID, Pickup_Location_ID, Drop_Location_ID, Request_Time, Status, Vehicle_Type_ID)
             VALUES (?, ?, ?, NOW(), 'Pending', ?)`,
            [passenger_id, pickupResult.insertId, dropResult.insertId, vehicle_type_id || 1]
        );

        res.json({
            success:    true,
            request_id: reqResult.insertId,
            message:    `Ride request created! ${promoMessage}`.trim()
        });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to create ride request' });
    }
});

// ── GET /api/passenger/ride-requests/:passengerId ─────────────
// Lists all ride requests for a passenger with location details
router.get('/ride-requests/:passengerId', async (req, res) => {
    try {
        const [rows] = await db.execute(
            `SELECT
                rr.Request_ID,
                rr.Request_Time,
                rr.Status,
                pl.Address  AS Pickup_Address,
                pl.City     AS Pickup_City,
                dl.Address  AS Drop_Address,
                dl.City     AS Drop_City
             FROM Ride_Request rr
             JOIN Location pl ON rr.Pickup_Location_ID = pl.Location_ID
             JOIN Location dl ON rr.Drop_Location_ID   = dl.Location_ID
             WHERE rr.Passenger_ID = ?
             ORDER BY rr.Request_Time DESC`,
            [req.params.passengerId]
        );
        res.json(rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to fetch ride requests' });
    }
});

// ── GET /api/passenger/trips/:passengerId ─────────────────────
// Trip history with driver name and fare (JOIN query)
router.get('/trips/:passengerId', async (req, res) => {
    try {
        const [rows] = await db.execute(
            `SELECT
                t.Trip_ID,
                t.Start_Time,
                t.End_Time,
                t.Distance,
                t.Fare,
                t.Status,
                t.Driver_ID,
                d.Name        AS Driver_Name,
                d.Phone       AS Driver_Phone,
                pl.Address    AS Pickup_Address,
                dl.Address    AS Drop_Address,
                vt.Type_Name  AS Vehicle_Type,
                vt.Price_Per_KM,
                (SELECT COUNT(*) FROM Payment py WHERE py.Trip_ID = t.Trip_ID) AS Has_Paid,
                (SELECT COUNT(*) FROM Rating_Review r WHERE r.Trip_ID = t.Trip_ID AND r.Passenger_ID = rr.Passenger_ID) AS Has_Rated
             FROM Trip t
             JOIN Ride_Request rr ON t.Request_ID          = rr.Request_ID
             JOIN Driver       d  ON t.Driver_ID           = d.Driver_ID
             JOIN Location     pl ON rr.Pickup_Location_ID = pl.Location_ID
             JOIN Location     dl ON rr.Drop_Location_ID   = dl.Location_ID
             JOIN Vehicle      v  ON t.Vehicle_ID          = v.Vehicle_ID
             JOIN Vehicle_Type vt ON v.Vehicle_Type_ID     = vt.Vehicle_Type_ID
             WHERE rr.Passenger_ID = ?
             ORDER BY t.Start_Time DESC`,
            [req.params.passengerId]
        );
        res.json(rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to fetch trips' });
    }
});

// ── POST /api/passenger/wallet/topup ─────────────────────────
router.post('/wallet/topup', async (req, res) => {
    const { passenger_id, amount } = req.body;
    if (!passenger_id || !amount || parseFloat(amount) <= 0)
        return res.status(400).json({ error: 'Valid passenger_id and amount are required' });

    try {
        const [result] = await db.execute(
            'UPDATE Wallet SET Balance = Balance + ? WHERE Passenger_ID = ?',
            [parseFloat(amount), passenger_id]
        );
        if (result.affectedRows === 0)
            return res.status(404).json({ error: 'Wallet not found' });

        const [wallets] = await db.execute(
            'SELECT Balance FROM Wallet WHERE Passenger_ID = ?',
            [passenger_id]
        );
        res.json({
            success:     true,
            new_balance: parseFloat(wallets[0].Balance).toFixed(2),
            message:     `₹${parseFloat(amount).toFixed(2)} added to your wallet!`
        });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Top-up failed' });
    }
});

// ── GET /api/passenger/payment/:tripId ───────────────────────
router.get('/payment/:tripId', async (req, res) => {
    try {
        const [rows] = await db.execute(
            `SELECT p.*, t.Fare, t.Distance, t.Status AS Trip_Status
             FROM Payment p
             JOIN Trip t ON p.Trip_ID = t.Trip_ID
             WHERE p.Trip_ID = ?`,
            [req.params.tripId]
        );
        res.json(rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to fetch payment' });
    }
});

// ── GET /api/passenger/promos ─────────────────────────────────
router.get('/promos', async (req, res) => {
    try {
        const [rows] = await db.execute(
            'SELECT * FROM Promo_Details WHERE Expiry_Date >= CURDATE()'
        );
        res.json(rows);
    } catch (err) {
        res.status(500).json({ error: 'Failed to fetch promos' });
    }
});

// ── GET /api/passenger/tickets/:userId ───────────────────────
router.get('/tickets/:userId', async (req, res) => {
    try {
        const [rows] = await db.execute(
            "SELECT * FROM Support_Ticket WHERE User_ID = ? AND User_Type = 'Passenger' ORDER BY Created_At DESC",
            [req.params.userId]
        );
        res.json(rows);
    } catch (err) {
        res.status(500).json({ error: 'Failed to fetch tickets' });
    }
});

module.exports = router;
