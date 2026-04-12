// server.js - Main Express server for Ride Sharing System
const express = require('express');
const session = require('express-session');
const cors    = require('cors');
const path    = require('path');
require('dotenv').config();

const app = express();

// ── Middleware ───────────────────────────────────────────────
app.use(cors({ origin: true, credentials: true }));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Session: keeps user logged in across requests
app.use(session({
    secret:            process.env.SESSION_SECRET || 'rideshare_secret',
    resave:            false,
    saveUninitialized: false,
    cookie: {
        secure:   false,                     // true only if using HTTPS
        maxAge:   24 * 60 * 60 * 1000       // 1 day
    }
}));

// Serve the frontend folder as static files
// So opening http://localhost:3000 shows index.html
app.use(express.static(path.join(__dirname, '../frontend')));

// ── API Routes ───────────────────────────────────────────────
app.use('/api/auth',      require('./routes/auth'));
app.use('/api/passenger', require('./routes/passenger'));
app.use('/api/driver',    require('./routes/driver'));
app.use('/api/admin',     require('./routes/admin'));
app.use('/api/trips',     require('./routes/trips'));
app.use('/api/payments',  require('./routes/payments'));
app.use('/api/ratings',   require('./routes/ratings'));
app.use('/api/support',   require('./routes/support'));
app.use('/api/locations', require('./routes/locations'));

// ── Catch-all: send index.html for any unknown route ────────
app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, '../frontend/index.html'));
});

// ── Start Server ─────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`\n🚗 Ride Sharing System running at:`);
    console.log(`   http://localhost:${PORT}\n`);
});
