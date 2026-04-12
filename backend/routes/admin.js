// routes/admin.js - Admin dashboard data routes
const express = require('express');
const router  = express.Router();
const db      = require('../config/db');

// ── GET /api/admin/passengers ─────────────────────────────────
router.get('/passengers', async (req, res) => {
    try {
        const [rows] = await db.execute(
            `SELECT p.Passenger_ID, p.Name, p.Phone, p.Email,
                    w.Balance AS Wallet_Balance,
                    COUNT(rr.Request_ID) AS Total_Requests
             FROM Passenger p
             LEFT JOIN Wallet       w  ON w.Passenger_ID = p.Passenger_ID
             LEFT JOIN Ride_Request rr ON rr.Passenger_ID = p.Passenger_ID
             GROUP BY p.Passenger_ID, p.Name, p.Phone, p.Email, w.Balance
             ORDER BY p.Passenger_ID DESC`
        );
        res.json(rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to fetch passengers' });
    }
});

// ── GET /api/admin/drivers ────────────────────────────────────
router.get('/drivers', async (req, res) => {
    try {
        const [rows] = await db.execute(
            `SELECT d.Driver_ID, d.Name, d.Phone, d.Email, d.License_No,
                    d.Is_Available,
                    v.Model, v.Registration_No,
                    vt.Type_Name      AS Vehicle_Type,
                    COUNT(t.Trip_ID)  AS Total_Trips,
                    SUM(t.Fare)       AS Total_Earnings
             FROM Driver d
             LEFT JOIN Vehicle      v  ON v.Driver_ID       = d.Driver_ID
             LEFT JOIN Vehicle_Type vt ON vt.Vehicle_Type_ID = v.Vehicle_Type_ID
             LEFT JOIN Trip         t  ON t.Driver_ID        = d.Driver_ID
             GROUP BY d.Driver_ID, d.Name, d.Phone, d.Email, d.License_No,
                      d.Is_Available, v.Model, v.Registration_No, vt.Type_Name
             ORDER BY d.Driver_ID DESC`
        );
        res.json(rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to fetch drivers' });
    }
});

// ── GET /api/admin/trips ──────────────────────────────────────
// Uses the Trip_Details_View (Chapter 3.6)
router.get('/trips', async (req, res) => {
    try {
        const [rows] = await db.execute(
            'SELECT * FROM Trip_Details_View ORDER BY Trip_ID DESC'
        );
        res.json(rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to fetch trips' });
    }
});

// ── GET /api/admin/payments ───────────────────────────────────
router.get('/payments', async (req, res) => {
    try {
        const [rows] = await db.execute(
            `SELECT py.Payment_ID, py.Amount, py.Payment_Mode, py.Payment_Status,
                    p.Name AS Passenger_Name, d.Name AS Driver_Name, t.Fare
             FROM Payment py
             JOIN Trip         t  ON py.Trip_ID    = t.Trip_ID
             JOIN Ride_Request rr ON t.Request_ID  = rr.Request_ID
             JOIN Passenger    p  ON rr.Passenger_ID = p.Passenger_ID
             JOIN Driver       d  ON t.Driver_ID   = d.Driver_ID
             ORDER BY py.Payment_ID DESC`
        );
        res.json(rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to fetch payments' });
    }
});

// ── GET /api/admin/support-tickets ───────────────────────────
router.get('/support-tickets', async (req, res) => {
    try {
        const [rows] = await db.execute(
            'SELECT * FROM Support_Ticket ORDER BY Created_At DESC'
        );
        res.json(rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to fetch support tickets' });
    }
});

// ── PATCH /api/admin/support-tickets/:id ─────────────────────
router.patch('/support-tickets/:id', async (req, res) => {
    const { status } = req.body;
    try {
        await db.execute(
            'UPDATE Support_Ticket SET Status = ? WHERE Ticket_ID = ?',
            [status, req.params.id]
        );
        res.json({ success: true, message: 'Ticket updated' });
    } catch (err) {
        res.status(500).json({ error: 'Failed to update ticket' });
    }
});

// ── GET /api/admin/stats ──────────────────────────────────────
// Dashboard statistics using aggregate functions (Chapter 3.2)
router.get('/stats', async (req, res) => {
    try {
        const [[passengers]] = await db.execute('SELECT COUNT(*) AS count FROM Passenger');
        const [[drivers]]    = await db.execute('SELECT COUNT(*) AS count FROM Driver');
        const [[trips]]      = await db.execute('SELECT COUNT(*) AS count FROM Trip');
        const [[revenue]]    = await db.execute(
            "SELECT SUM(Amount) AS total FROM Payment WHERE Payment_Status = 'Paid'"
        );
        const [[avgFare]]    = await db.execute('SELECT AVG(Fare) AS avg FROM Trip');
        const [[maxDist]]    = await db.execute('SELECT MAX(Distance_KM) AS max, MIN(Distance_KM) AS min FROM Route_Details');
        const [openTickets]  = await db.execute(
            "SELECT COUNT(*) AS count FROM Support_Ticket WHERE Status = 'Open'"
        );

        // Trips per driver (Chapter 3.2)
        const [driverTrips] = await db.execute(
            `SELECT d.Name AS Driver_Name, COUNT(t.Trip_ID) AS Total_Trips,
                    SUM(t.Fare) AS Total_Earnings
             FROM Driver d LEFT JOIN Trip t ON d.Driver_ID = t.Driver_ID
             GROUP BY d.Driver_ID, d.Name`
        );

        // Trips with fare above average (Subquery – Chapter 3.4)
        const [aboveAvg] = await db.execute(
            'SELECT Trip_ID, Fare FROM Trip WHERE Fare > (SELECT AVG(Fare) FROM Trip)'
        );

        res.json({
            total_passengers:   passengers.count,
            total_drivers:      drivers.count,
            total_trips:        trips.count,
            total_revenue:      revenue.total || 0,
            avg_fare:           avgFare.avg   ? parseFloat(avgFare.avg).toFixed(2) : 0,
            max_distance:       maxDist.max   || 0,
            min_distance:       maxDist.min   || 0,
            open_tickets:       openTickets[0].count,
            driver_trips:       driverTrips,
            above_avg_fare_trips: aboveAvg
        });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to fetch stats' });
    }
});

// ── GET /api/admin/promos ─────────────────────────────────────
router.get('/promos', async (req, res) => {
    try {
        const [rows] = await db.execute('SELECT * FROM Promo_Details ORDER BY Promo_ID DESC');
        res.json(rows);
    } catch (err) {
        res.status(500).json({ error: 'Failed to fetch promos' });
    }
});

// ── POST /api/admin/promos ────────────────────────────────────
router.post('/promos', async (req, res) => {
    const { code, discount_percentage, expiry_date } = req.body;
    try {
        await db.execute(
            'INSERT INTO Promo_Details (Code, Discount_Percentage, Expiry_Date) VALUES (?, ?, ?)',
            [code, discount_percentage, expiry_date]
        );
        res.json({ success: true, message: 'Promo code added!' });
    } catch (err) {
        if (err.code === 'ER_DUP_ENTRY')
            return res.status(409).json({ error: 'Promo code already exists' });
        res.status(500).json({ error: 'Failed to add promo' });
    }
});

// ── GET /api/admin/high-payments ─────────────────────────────
// Uses High_Payments view (Chapter 3.6)
router.get('/high-payments', async (req, res) => {
    try {
        const [rows] = await db.execute('SELECT * FROM High_Payments');
        res.json(rows);
    } catch (err) {
        res.status(500).json({ error: 'Failed to fetch high payments' });
    }
});

module.exports = router;
