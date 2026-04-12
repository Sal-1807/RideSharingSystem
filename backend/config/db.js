// db.js - MySQL connection pool
// Uses mysql2 with promise support for async/await queries
const mysql = require('mysql2/promise');
require('dotenv').config();

const pool = mysql.createPool({
    host:               process.env.DB_HOST     || 'localhost',
    user:               process.env.DB_USER     || 'root',
    password:           process.env.DB_PASSWORD || 'password',
    database:           process.env.DB_NAME     || 'RideSharingSystem',
    waitForConnections: true,
    connectionLimit:    10,    // max simultaneous connections
    queueLimit:         0
});

// Test connection on startup
pool.getConnection()
    .then(conn => {
        console.log('✅ MySQL connected to:', process.env.DB_NAME || 'RideSharingSystem');
        conn.release();
    })
    .catch(err => {
        console.error('❌ MySQL connection failed:', err.message);
        console.error('   Check your .env file: DB_HOST, DB_USER, DB_PASSWORD, DB_NAME');
    });

module.exports = pool;
