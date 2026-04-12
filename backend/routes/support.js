// routes/support.js - Support ticket routes
const express = require('express');
const router  = express.Router();
const db      = require('../config/db');

// ── POST /api/support ─────────────────────────────────────────
// Body: { user_id, user_type, issue_description }
router.post('/', async (req, res) => {
    const { user_id, user_type, issue_description } = req.body;

    if (!user_id || !user_type || !issue_description)
        return res.status(400).json({ error: 'All fields are required' });

    try {
        const [result] = await db.execute(
            `INSERT INTO Support_Ticket (User_ID, User_Type, Issue_Description, Status)
             VALUES (?, ?, ?, 'Open')`,
            [user_id, user_type, issue_description]
        );
        res.json({
            success:   true,
            ticket_id: result.insertId,
            message:   'Support ticket raised! We will get back to you soon.'
        });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to create support ticket' });
    }
});

// ── GET /api/support/user/:userId/:userType ───────────────────
router.get('/user/:userId/:userType', async (req, res) => {
    try {
        const [rows] = await db.execute(
            'SELECT * FROM Support_Ticket WHERE User_ID = ? AND User_Type = ? ORDER BY Created_At DESC',
            [req.params.userId, req.params.userType]
        );
        res.json(rows);
    } catch (err) {
        res.status(500).json({ error: 'Failed to fetch tickets' });
    }
});

// ── GET /api/support/all ──────────────────────────────────────
router.get('/all', async (req, res) => {
    try {
        const [rows] = await db.execute(
            'SELECT * FROM Support_Ticket ORDER BY Created_At DESC'
        );
        res.json(rows);
    } catch (err) {
        res.status(500).json({ error: 'Failed to fetch tickets' });
    }
});

module.exports = router;
