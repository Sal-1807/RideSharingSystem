// routes/auth.js - Registration, Login, Logout
const express = require('express');
const router  = express.Router();
const db      = require('../config/db');
const bcrypt  = require('bcryptjs');

// ── POST /api/auth/register/passenger ────────────────────────
// Registers a new passenger and creates their wallet
router.post('/register/passenger', async (req, res) => {
    const { name, phone, email, password } = req.body;

    if (!name || !phone || !email || !password)
        return res.status(400).json({ error: 'All fields are required' });

    try {
        const hashed = await bcrypt.hash(password, 10);

        // Insert passenger
        const [result] = await db.execute(
            'INSERT INTO Passenger (Name, Phone, Email, Password) VALUES (?, ?, ?, ?)',
            [name, phone, email, hashed]
        );
        const passengerId = result.insertId;

        // Auto-create wallet with 500 welcome balance
        await db.execute(
            'INSERT INTO Wallet (Passenger_ID, Balance) VALUES (?, 500.00)',
            [passengerId]
        );

        res.json({ success: true, message: 'Passenger registered successfully! Wallet created with ₹500 welcome balance.' });
    } catch (err) {
        if (err.code === 'ER_DUP_ENTRY')
            return res.status(409).json({ error: 'Email already registered' });
        console.error(err);
        res.status(500).json({ error: 'Registration failed' });
    }
});

// ── POST /api/auth/register/driver ───────────────────────────
// Registers a new driver and their vehicle
router.post('/register/driver', async (req, res) => {
    const { name, phone, email, password, license_no, vehicle_model, registration_no, vehicle_type_id } = req.body;

    if (!name || !phone || !email || !password || !license_no)
        return res.status(400).json({ error: 'Name, phone, email, password and license number are required' });

    try {
        const hashed = await bcrypt.hash(password, 10);

        // Insert driver
        const [result] = await db.execute(
            'INSERT INTO Driver (Name, License_No, Phone, Email, Password) VALUES (?, ?, ?, ?, ?)',
            [name, license_no, phone, email, hashed]
        );
        const driverId = result.insertId;

        // Insert vehicle if provided
        if (vehicle_model && registration_no) {
            await db.execute(
                'INSERT INTO Vehicle (Driver_ID, Vehicle_Type_ID, Model, Registration_No) VALUES (?, ?, ?, ?)',
                [driverId, vehicle_type_id || 1, vehicle_model, registration_no]
            );
        }

        res.json({ success: true, message: 'Driver registered successfully!' });
    } catch (err) {
        if (err.code === 'ER_DUP_ENTRY')
            return res.status(409).json({ error: 'Email or License Number already registered' });
        console.error(err);
        res.status(500).json({ error: 'Registration failed' });
    }
});

// ── POST /api/auth/login ─────────────────────────────────────
// Logs in a passenger, driver, or admin
router.post('/login', async (req, res) => {
    const { email, password, user_type } = req.body;  // user_type: 'passenger' | 'driver' | 'admin'

    if (!email || !password || !user_type)
        return res.status(400).json({ error: 'Email, password and user type are required' });

    try {
        let user, table, idField;

        if (user_type === 'passenger') {
            table   = 'Passenger';
            idField = 'Passenger_ID';
        } else if (user_type === 'driver') {
            table   = 'Driver';
            idField = 'Driver_ID';
        } else if (user_type === 'admin') {
            table   = 'Admin';
            idField = 'Admin_ID';
        } else {
            return res.status(400).json({ error: 'Invalid user type' });
        }

        let whereClause, queryParams;
        if (user_type === 'admin') {
            whereClause  = 'WHERE Contact = ?';
            queryParams  = [email];
        } else if (user_type === 'driver') {
            whereClause  = 'WHERE Email = ? OR Phone = ?';
            queryParams  = [email, email];
        } else {
            whereClause  = 'WHERE Email = ? OR Phone = ?';
            queryParams  = [email, email];
        }

        const [rows] = await db.execute(
            `SELECT * FROM ${table} ${whereClause}`,
            queryParams
        );

        if (rows.length === 0)
            return res.status(401).json({ error: 'Invalid email or password' });

        user = rows[0];

        // For admin: plain text comparison (for demo)
        // For passenger/driver: bcrypt — if no password stored (legacy data), allow any password
        let passwordMatch;
        if (user_type === 'admin') {
            passwordMatch = (password === user.Password);
        } else if (!user.Password) {
            passwordMatch = true;   // legacy row with no password — let them in
        } else {
            passwordMatch = await bcrypt.compare(password, user.Password);
        }

        if (!passwordMatch)
            return res.status(401).json({ error: 'Invalid email or password' });

        // Store session
        req.session.user = {
            id:        user[idField],
            name:      user.Name,
            email:     user.Email || user.Contact,
            user_type: user_type
        };

        res.json({
            success:   true,
            user_type: user_type,
            user_id:   user[idField],
            name:      user.Name,
            message:   `Welcome, ${user.Name}!`
        });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Login failed' });
    }
});

// ── POST /api/auth/logout ────────────────────────────────────
router.post('/logout', (req, res) => {
    req.session.destroy();
    res.json({ success: true, message: 'Logged out successfully' });
});

// ── GET /api/auth/me ─────────────────────────────────────────
// Returns current session user info
router.get('/me', (req, res) => {
    if (req.session.user)
        return res.json({ loggedIn: true, user: req.session.user });
    res.json({ loggedIn: false });
});

module.exports = router;
